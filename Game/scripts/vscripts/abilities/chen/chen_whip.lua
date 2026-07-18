chen_whip = class({})

local WHIP_PARTICLE = "particles/items4_fx/thorn_whip.vpcf"

local function GetAbilitySlotCount(unit)
	if unit and unit.GetAbilityCount then
		return unit:GetAbilityCount()
	end
	return 6
end

local function HasBehavior(ability, behavior)
	if not ability or ability:IsNull() or not behavior then
		return false
	end

	return bit.band(ability:GetBehavior(), behavior) == behavior
end

local function IsTamedCreep(unit, caster)
	if not unit or unit:IsNull() or not unit:IsAlive() then
		return false
	end

	return unit.chen_tamed == true and unit.chen_owner_entindex == caster:entindex()
end

local function FindTamedCreepsInRadius(caster, position, radius)
	local targets = {}
	local units = FindUnitsInRadius(
		caster:GetTeamNumber(),
		position,
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY,
		DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	for _, unit in pairs(units) do
		if IsTamedCreep(unit, caster) then
			table.insert(targets, unit)
		end
	end

	return targets
end

local function ApplyWhipDamageToEnemies(caster, ability, position, radius)
	local damage = ability:GetSpecialValueFor("damage")
	local enemies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		position,
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	for _, enemy in pairs(enemies) do
		if enemy and not enemy:IsNull() and enemy:IsAlive() then
			ApplyDamage({
				victim = enemy,
				attacker = caster,
				damage = damage,
				damage_type = DAMAGE_TYPE_MAGICAL,
				ability = ability,
			})
		end
	end
end

local function IsCastableByWhip(ability)
	if not ability or ability:IsNull() then
		return false
	end

	if ability:IsHidden() or ability:IsPassive() or not ability:IsActivated() or ability:GetLevel() <= 0 then
		return false
	end

	if DOTA_ABILITY_BEHAVIOR_TOGGLE and HasBehavior(ability, DOTA_ABILITY_BEHAVIOR_TOGGLE) then
		return false
	end

	if DOTA_ABILITY_BEHAVIOR_CHANNELLED and HasBehavior(ability, DOTA_ABILITY_BEHAVIOR_CHANNELLED) then
		return false
	end

	return true
end

local function GetSearchTargetType(ability)
	local targetType = ability:GetAbilityTargetType()
	if targetType == nil or targetType == 0 then
		return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC
	end

	return targetType
end

local function GetSearchTargetFlags(ability)
	local flags = ability:GetAbilityTargetFlags()
	if flags == nil then
		return DOTA_UNIT_TARGET_FLAG_NONE
	end

	return flags
end

local function FindBestUnitTarget(caster, source, ability, radius)
	local targetTeam = ability:GetAbilityTargetTeam() or DOTA_UNIT_TARGET_TEAM_ENEMY
	local searchTeam = DOTA_UNIT_TARGET_TEAM_ENEMY
	local friendlyOnly = bit.band(targetTeam, DOTA_UNIT_TARGET_TEAM_FRIENDLY) == DOTA_UNIT_TARGET_TEAM_FRIENDLY and bit.band(targetTeam, DOTA_UNIT_TARGET_TEAM_ENEMY) ~= DOTA_UNIT_TARGET_TEAM_ENEMY

	if friendlyOnly then
		searchTeam = DOTA_UNIT_TARGET_TEAM_FRIENDLY
	end

	local units = FindUnitsInRadius(
		caster:GetTeamNumber(),
		source:GetAbsOrigin(),
		nil,
		radius,
		searchTeam,
		GetSearchTargetType(ability),
		GetSearchTargetFlags(ability),
		FIND_CLOSEST,
		false
	)

	for _, unit in pairs(units) do
		if unit and not unit:IsNull() and unit:IsAlive() and unit ~= source then
			if unit:IsRealHero() then
				return unit
			end
		end
	end

	for _, unit in pairs(units) do
		if unit and not unit:IsNull() and unit:IsAlive() and unit ~= source then
			return unit
		end
	end

	return friendlyOnly and source or nil
end

local function FindBestEnemyPosition(caster, source, radius)
	local units = FindUnitsInRadius(
		caster:GetTeamNumber(),
		source:GetAbsOrigin(),
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_CLOSEST,
		false
	)

	for _, unit in pairs(units) do
		if unit and not unit:IsNull() and unit:IsAlive() and unit:IsRealHero() then
			return unit:GetAbsOrigin()
		end
	end

	if units[1] and not units[1]:IsNull() and units[1]:IsAlive() then
		return units[1]:GetAbsOrigin()
	end

	return source:GetAbsOrigin() + source:GetForwardVector() * 400
end

local function PreserveFreeCastState(source, abilities, originalMana)
	local function restore()
		if source and not source:IsNull() and source:IsAlive() then
			source:SetMana(originalMana)
		end

		for _, ability in pairs(abilities) do
			if ability and not ability:IsNull() then
				ability:EndCooldown()
			end
		end
	end

	Timers:CreateTimer(0, restore)
	Timers:CreateTimer(0.25, restore)
	Timers:CreateTimer(1.0, restore)
end

local function CastAbilityByWhip(caster, source, ability, radius, queue)
	if not IsCastableByWhip(ability) then
		return false
	end

	ability:EndCooldown()

	local level = math.max(ability:GetLevel() - 1, 0)
	local manaCost = ability:GetManaCost(level)
	if manaCost > source:GetMana() then
		source:SetMana(manaCost)
	end

	local order = {
		UnitIndex = source:entindex(),
		AbilityIndex = ability:entindex(),
		Queue = queue,
	}

	local vectorBehavior = 0
	if DOTA_ABILITY_BEHAVIOR_VECTOR_TARGETING then
		vectorBehavior = DOTA_ABILITY_BEHAVIOR_VECTOR_TARGETING
	end
	local visionTarget = nil

	local behavior = ability:GetBehavior()

	if bit.band(behavior, DOTA_ABILITY_BEHAVIOR_NO_TARGET) ~= 0 then
		order.OrderType = DOTA_UNIT_ORDER_CAST_NO_TARGET
	elseif bit.band(behavior, DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) ~= 0 then
		local target = FindBestUnitTarget(caster, source, ability, radius)
		if not target then
			return false
		end
		order.OrderType = DOTA_UNIT_ORDER_CAST_TARGET
		order.TargetIndex = target:entindex()
		visionTarget = target
	elseif bit.band(behavior, DOTA_ABILITY_BEHAVIOR_POINT) ~= 0 or bit.band(behavior, vectorBehavior) ~= 0 then
		order.OrderType = DOTA_UNIT_ORDER_CAST_POSITION
		local pos = FindBestEnemyPosition(caster, source, radius)
		order.Position = pos

		if bit.band(behavior, vectorBehavior) ~= 0 then
			local direction = (pos - source:GetAbsOrigin()):Normalized()
			order.OrderType = DOTA_UNIT_ORDER_VECTOR_TARGET_POSITION
			order.VectorTargetPosition = pos + direction * 100
		end

		AddFOWViewer(caster:GetTeamNumber(), pos, radius, 1.0, false)
	else
		return false
	end

	if visionTarget and visionTarget:GetTeamNumber() ~= caster:GetTeamNumber() then
		AddFOWViewer(caster:GetTeamNumber(), visionTarget:GetAbsOrigin(), radius, 1.0, false)
	end

	local playerID = caster:GetPlayerOwnerID()
	if playerID and playerID >= 0 then
		order.IssuerPlayerID = playerID
	end

	ExecuteOrderFromTable(order)
	return true
end

function chen_whip:GetCooldown(level)
	local baseCooldown = self.BaseClass.GetCooldown(self, level) or 24
	return baseCooldown
end

function chen_whip:Precache(context)
	PrecacheResource("particle", WHIP_PARTICLE, context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_chen.vsndevts", context)
end

local function GetAttachmentPosition(unit, attachmentName, fallbackHeight)
	if not unit or unit:IsNull() then
		return nil
	end

	if unit.ScriptLookupAttachment and unit.GetAttachmentOrigin then
		local attachment = unit:ScriptLookupAttachment(attachmentName)
		if attachment and attachment > 0 then
			return unit:GetAttachmentOrigin(attachment)
		end
	end

	return unit:GetAbsOrigin() + Vector(0, 0, fallbackHeight or 0)
end

local function CreateWhipEffect(caster, endPosition)
	if not caster or caster:IsNull() or not endPosition then
		return
	end

	local startPosition = GetAttachmentPosition(caster, "attach_attack1", 96) or caster:GetAbsOrigin()
	local particle = ParticleManager:CreateParticle(WHIP_PARTICLE, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(particle, 0, startPosition)
	ParticleManager:SetParticleControl(particle, 1, endPosition)
	ParticleManager:SetParticleControl(particle, 2, endPosition)
	ParticleManager:ReleaseParticleIndex(particle)
end

local function CastAllWhippedAbilities(caster, source, radius)
	local originalMana = source:GetMana()
	local castAbilities = {}
	local castCount = 0
	local slotCount = GetAbilitySlotCount(source)

	for slot = 0, slotCount - 1 do
		local ability = source:GetAbilityByIndex(slot)
		if ability and not ability:IsNull() and CastAbilityByWhip(caster, source, ability, radius, castCount > 0) then
			castCount = castCount + 1
			table.insert(castAbilities, ability)
		end
	end

	if castCount > 0 then
		PreserveFreeCastState(source, castAbilities, originalMana)
	end

	return castCount
end

function chen_whip:OnSpellStart()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	local position = self:GetCursorPosition()
	local aoeRadius = self:GetSpecialValueFor("radius")
	local searchRadius = self:GetSpecialValueFor("search_radius")

	CreateWhipEffect(caster, position)
	ApplyWhipDamageToEnemies(caster, self, position, aoeRadius)

	local targets = FindTamedCreepsInRadius(caster, position, aoeRadius)

	local totalCastCount = 0
	for _, unit in pairs(targets) do
		local castCount = CastAllWhippedAbilities(caster, unit, searchRadius)
		if castCount > 0 then
			totalCastCount = totalCastCount + castCount
		end
		CreateWhipEffect(caster, GetAttachmentPosition(unit, "attach_hitloc", 64))
	end

	if totalCastCount > 0 then
		EmitSoundOn("Hero_Chen.PenitenceCast", targets[1])
	else
		EmitSoundOn("Hero_Chen.PenitenceCast", caster)
	end
end
