chen_whip = class({})

local function GetTalentValue(hero, talentName, valueName, fallback)
	if not hero or hero:IsNull() then
		return fallback or 0
	end

	local talent = hero:FindAbilityByName(talentName)
	if not talent or talent:IsNull() or talent:GetLevel() <= 0 then
		return fallback or 0
	end

	local value = 0
	if valueName then
		value = talent:GetSpecialValueFor(valueName)
	end
	if value == 0 then
		value = talent:GetSpecialValueFor("value")
	end

	return value or fallback or 0
end

local function HasShardUpgrade(hero)
	if not hero or hero:IsNull() then
		return false
	end
	if hero.HasShard and hero:HasShard() then
		return true
	end
	return hero:HasModifier("modifier_item_aghanims_shard")
end

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

local function IsChenBarrackUnit(unit)
	if not unit or unit:IsNull() then
		return false
	end

	local unitName = unit:GetUnitName() or ""
	return string.find(unitName, "npc_chen_barrack", 1, true) == 1
end

local function IsValidWhipTarget(target, caster)
	if not target or target:IsNull() or not target:IsAlive() then
		return false
	end

	-- Allow enemy targets
	if target:GetTeamNumber() ~= caster:GetTeamNumber() then
		return true
	end

	if not target:IsCreep() or target:IsHero() or target:IsBuilding() or target:IsAncient() then
		return false
	end

	if IsChenBarrackUnit(target) then
		return false
	end

	return true
end

local function IsCastableByWhip(ability)
	if not ability or ability:IsNull() then
		return false
	end

	if ability:IsHidden() or ability:IsPassive() or not ability:IsActivated() or ability:GetLevel() <= 0 then
		return false
	end

	-- Allow AOE abilities
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
		
		-- Vector targeting support
		if bit.band(behavior, vectorBehavior) ~= 0 then
			-- Most vector abilities in OAA/Custom games use a "direction" which is position2 - position1
			-- We can simulate this by providing a position that is further in the same direction
			local direction = (pos - source:GetAbsOrigin()):Normalized()
			order.OrderType = DOTA_UNIT_ORDER_VECTOR_TARGET_POSITION
			-- For some reason, the order table for vector target needs Position and VectorTargetPosition
			order.VectorTargetPosition = pos + direction * 100
		end

		-- Add vision at the position for point-target abilities
		AddFOWViewer(caster:GetTeamNumber(), pos, radius, 1.0, false)
	else
		return false
	end

	-- Grant temporary vision for unit-target abilities
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

function chen_whip:CastFilterResultTarget(target)
	if IsValidWhipTarget(target, self:GetCaster()) then
		return UF_SUCCESS
	end

	return UF_FAIL_CUSTOM
end

function chen_whip:GetCustomCastErrorTarget(target)
	return "#dota_hud_error_chen_whip_invalid_target"
end

function chen_whip:GetCooldown(level)
	local baseCooldown = self.BaseClass.GetCooldown(self, level) or 24
	local caster = self:GetCaster()
	return math.max(0, baseCooldown - GetTalentValue(caster, "special_bonus_unique_custom_chen_6", "cooldown_reduction", 0))
end

local function CreateWhipEffect(caster, target)
	if not caster or caster:IsNull() or not target or target:IsNull() then
		return
	end

	local particle = ParticleManager:CreateParticle("particles/items4_fx/thorn_whip.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:SetParticleControlEnt(particle, 0, caster, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)
	ParticleManager:SetParticleControlEnt(particle, 1, target, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), true)
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
	local target = self:GetCursorTarget()
	
	-- Redirection logic for enemies
	if target:GetTeamNumber() ~= caster:GetTeamNumber() then
		local radius = self:GetSpecialValueFor("search_radius")
		local enemies = FindUnitsInRadius(
			caster:GetTeamNumber(),
			target:GetAbsOrigin(),
			nil,
			radius,
			DOTA_UNIT_TARGET_TEAM_ENEMY,
			DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
			DOTA_UNIT_TARGET_FLAG_NONE,
			FIND_CLOSEST,
			false
		)
		
		local bestEnemy = nil
		for _, enemy in pairs(enemies) do
			if enemy:IsRealHero() then
				bestEnemy = enemy
				break
			end
		end
		
		if not bestEnemy then
			bestEnemy = enemies[1]
		end
		
		if bestEnemy then
			target = bestEnemy
		else
			-- No enemy found in radius, just use the original target if it's still valid
			if not target:IsAlive() then return end
		end
	end

	if not IsValidWhipTarget(target, caster) then
		return
	end

	local radius = self:GetSpecialValueFor("search_radius")
	radius = radius + GetTalentValue(caster, "special_bonus_unique_custom_chen_5", "bonus_radius", 0)

	local targets = { target }
	if HasShardUpgrade(caster) then
		targets = {}
		local shardRadius = self:GetSpecialValueFor("shard_radius")
		if shardRadius <= 0 then
			shardRadius = 600
		end

		local allies = FindUnitsInRadius(
			caster:GetTeamNumber(),
			target:GetAbsOrigin(),
			nil,
			shardRadius,
			DOTA_UNIT_TARGET_TEAM_FRIENDLY,
			DOTA_UNIT_TARGET_BASIC,
			DOTA_UNIT_TARGET_FLAG_NONE,
			FIND_ANY_ORDER,
			false
		)

		for _, unit in pairs(allies) do
			if IsValidWhipTarget(unit, caster) then
				table.insert(targets, unit)
			end
		end
	end

	local totalCastCount = 0
	for _, unit in pairs(targets) do
		local castCount = CastAllWhippedAbilities(caster, unit, radius)
		if castCount > 0 then
			totalCastCount = totalCastCount + castCount
		end
		CreateWhipEffect(caster, unit)
	end

	if totalCastCount > 0 then
		EmitSoundOn("Hero_Chen.PenitenceCast", target)
	else
		EmitSoundOn("Hero_Chen.PenitenceCast", caster)
	end
end