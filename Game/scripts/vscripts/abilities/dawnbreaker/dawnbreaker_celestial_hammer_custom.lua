LinkLuaModifier(
	"modifier_dawnbreaker_celestial_hammer_custom",
	"abilities/dawnbreaker/dawnbreaker_celestial_hammer_custom",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_dawnbreaker_celestial_hammer_custom_nohammer",
	"abilities/dawnbreaker/dawnbreaker_celestial_hammer_custom",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_dawnbreaker_celestial_hammer_custom_thinker",
	"abilities/dawnbreaker/dawnbreaker_celestial_hammer_custom",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_dawnbreaker_celestial_hammer_custom_trail",
	"abilities/dawnbreaker/dawnbreaker_celestial_hammer_custom",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_dawnbreaker_celestial_hammer_custom_debuff",
	"abilities/dawnbreaker/dawnbreaker_celestial_hammer_custom",
	LUA_MODIFIER_MOTION_NONE
)

dawnbreaker_celestial_hammer_custom = class({})

local HAMMER_NAME = "dawnbreaker_celestial_hammer_custom"
local CONVERGE_NAME = "dawnbreaker_converge_custom"
local HAMMER_REQUIRED_ABILITIES = {
	"dawnbreaker_fire_wreath",
	"dawnbreaker_solar_guardian_custom",
}

local function IsValidEntity(entity)
	return entity and not entity:IsNull()
end

local function SendDawnbreakerHudError(caster, message)
	if not IsValidEntity(caster) then
		return
	end

	local playerID = caster:GetPlayerOwnerID()
	if playerID == nil or playerID < 0 then
		return
	end

	local player = PlayerResource:GetPlayer(playerID)
	if not player then
		return
	end

	CustomGameEventManager:Send_ServerToPlayer(player, "dota_hud_error_message", {
		message = message,
		reason = 80,
		sequenceNumber = 0,
	})
end

local function IsAbilityInPhase(ability)
	return ability ~= nil and ability.IsInAbilityPhase ~= nil and ability:IsInAbilityPhase()
end

function dawnbreaker_celestial_hammer_custom:Precache(context)
	if self:GetCaster() and self:GetCaster():IsIllusion() then
		return
	end

	PrecacheResource("particle", "particles/units/heroes/hero_dawnbreaker/dawnbreaker_celestial_hammer_projectile.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_dawnbreaker/dawnbreaker_celestial_hammer_aoe_impact.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_dawnbreaker/dawnbreaker_celestial_hammer_return.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_dawnbreaker/dawnbreaker_celestial_hammer_grounded.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_dawnbreaker/dawnbreaker_converge.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_dawnbreaker/dawnbreaker_converge_trail.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_dawnbreaker/dawnbreaker_converge_burning_trail.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_dawnbreaker/dawnbreaker_converge_debuff.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_dawnbreaker.vsndevts", context)
end

function dawnbreaker_celestial_hammer_custom:GetCastRange(location, target)
	return self:GetSpecialValueFor("range")
end

function dawnbreaker_celestial_hammer_custom:GetHammerDamage()
	local caster = self:GetCaster()
	local base = self:GetSpecialValueFor("hammer_damage")
	local multiplier = self:GetSpecialValueFor("mind_power_multiplier")
	local mind_power = GetHeroMindPower and (GetHeroMindPower(caster) or 0) or 0
	return math.max(0, base + mind_power * multiplier)
end

function dawnbreaker_celestial_hammer_custom:GetActiveHammerThinker()
	for _, thinker in ipairs(self.thinkers or {}) do
		if IsValidEntity(thinker) then
			return thinker
		end
	end
	return nil
end

function dawnbreaker_celestial_hammer_custom:GetHammerWorldOrigin()
	local thinker = self:GetActiveHammerThinker()
	if thinker then
		return thinker:GetAbsOrigin()
	end
	return nil
end

function dawnbreaker_celestial_hammer_custom:IsConverging()
	return self:GetCaster():HasModifier("modifier_dawnbreaker_celestial_hammer_custom")
end

function dawnbreaker_celestial_hammer_custom:IsHammerAway()
	return self:GetCaster():HasModifier("modifier_dawnbreaker_celestial_hammer_custom_nohammer")
end

function dawnbreaker_celestial_hammer_custom:IsStarbreakerActive()
	local caster = self:GetCaster()
	if caster:HasModifier("modifier_dawnbreaker_fire_wreath") then
		return true
	end

	local starbreaker = caster:FindAbilityByName("dawnbreaker_fire_wreath")
	return IsAbilityInPhase(starbreaker)
end

function dawnbreaker_celestial_hammer_custom:IsSolarGuardianTrackerActive()
	local caster = self:GetCaster()
	local release = caster:FindAbilityByName("dawnbreaker_solar_guardian_release_custom")
	if release and not release:IsHidden() then
		return true
	end

	local solar = caster:FindAbilityByName("dawnbreaker_solar_guardian_custom")
	return IsAbilityInPhase(solar)
end

function dawnbreaker_celestial_hammer_custom:CanThrowHammer()
	return not self:IsHammerAway()
		and not self:IsStarbreakerActive()
		and not self:IsSolarGuardianTrackerActive()
end

function dawnbreaker_celestial_hammer_custom:SetHammerRequiredAbilitiesActivated(enabled)
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	if not IsValidEntity(caster) then
		return
	end

	for _, name in ipairs(HAMMER_REQUIRED_ABILITIES) do
		local ability = caster:FindAbilityByName(name)
		if ability then
			ability:SetActivated(enabled)
		end
	end
end

function DawnbreakerHandleOrder(data)
	if not data then
		return true
	end

	local abilityIndex = tonumber(data.entindex_ability)
	if not abilityIndex or abilityIndex == 0 then
		return true
	end

	local ability = EntIndexToHScript(abilityIndex)
	if not IsValidEntity(ability) or not ability.GetAbilityName then
		return true
	end

	local caster = ability:GetCaster()
	if not IsValidEntity(caster) then
		return true
	end

	local name = ability:GetAbilityName()
	if caster:HasModifier("modifier_dawnbreaker_celestial_hammer_custom_nohammer")
		and (name == "dawnbreaker_fire_wreath" or name == "dawnbreaker_solar_guardian_custom") then
		ability:SetActivated(false)
		SendDawnbreakerHudError(caster, "#dota_hud_error_nohammer")
		return false
	end

	if name == HAMMER_NAME and ability.CanThrowHammer and not ability:CanThrowHammer() then
		if ability.IsHammerAway and ability:IsHammerAway() then
			SendDawnbreakerHudError(caster, "#dota_hud_error_nohammer")
		else
			SendDawnbreakerHudError(caster, "#dota_hud_error_cant_cast")
		end
		return false
	end

	return true
end

function dawnbreaker_celestial_hammer_custom:OnUpgrade()
	if self:GetLevel() < 1 then
		self:RestoreCastLayout()
		return
	end

	local caster = self:GetCaster()
	local converge = caster:FindAbilityByName(CONVERGE_NAME)
	if not converge then
		return
	end

	if converge:GetLevel() < 1 then
		converge:SetLevel(1)
	end
	converge:SetActivated(false)
	self:RestoreCastLayout()
end

function dawnbreaker_celestial_hammer_custom:CastFilterResultLocation(location)
	if not self:CanThrowHammer() then
		return UF_FAIL_CUSTOM
	end
	return UF_SUCCESS
end

function dawnbreaker_celestial_hammer_custom:GetCustomCastErrorLocation(location)
	if self:IsHammerAway() then
		return "#dota_hud_error_nohammer"
	end
	if self:IsStarbreakerActive() or self:IsSolarGuardianTrackerActive() then
		return "#dota_hud_error_cant_cast"
	end
	return ""
end

function dawnbreaker_celestial_hammer_custom:OnSpellStart()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	local point = self:GetCursorPosition()
	if point == caster:GetAbsOrigin() then
		point = point + caster:GetForwardVector() * 100
	end

	self.projectiles = self.projectiles or {}
	self.thinkers = self.thinkers or {}

	local radius = self:GetSpecialValueFor("projectile_radius")
	if GetHeroBonusSpellAoE then
		radius = radius + GetHeroBonusSpellAoE(caster)
	end

	local speed = self:GetSpecialValueFor("projectile_speed")
	local direction = point - caster:GetAbsOrigin()
	direction.z = 0
	local length = math.min(self:GetSpecialValueFor("range") + caster:GetCastRangeBonus(), direction:Length2D())
	if length < 1 then
		length = 1
	end
	direction = direction:Normalized()

	local thinker = CreateModifierThinker(
		caster,
		self,
		"modifier_dawnbreaker_celestial_hammer_custom_thinker",
		{},
		caster:GetAbsOrigin(),
		caster:GetTeamNumber(),
		false
	)

	local info = {
		Source = caster,
		Ability = self,
		vSpawnOrigin = caster:GetAbsOrigin(),
		iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
		iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_NONE,
		iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		EffectName = "",
		fDistance = length,
		fStartRadius = radius,
		fEndRadius = radius,
		vVelocity = direction * speed,
	}

	local handle = ProjectileManager:CreateLinearProjectile(info)
	thinker.projectile_id = handle
	self.projectiles[handle] = {
		cast = 1,
		targets = {},
		thinker = thinker,
		last_trail = caster:GetAbsOrigin(),
		effect = self:PlayThrowEffects(caster:GetAbsOrigin(), length, direction * speed),
	}
	table.insert(self.thinkers, thinker)

	self:ShowConvergeAbility()

	caster:AddNewModifier(caster, self, "modifier_dawnbreaker_celestial_hammer_custom_nohammer", {})
end

function dawnbreaker_celestial_hammer_custom:OnProjectileThinkHandle(handle)
	local data = self.projectiles[handle]
	if not data or not IsValidEntity(data.thinker) then
		return
	end

	local location
	if data.cast == 1 then
		location = ProjectileManager:GetLinearProjectileLocation(handle)
	else
		location = ProjectileManager:GetTrackingProjectileLocation(handle)
		local radius = self:GetSpecialValueFor("projectile_radius")
		if GetHeroBonusSpellAoE then
			radius = radius + GetHeroBonusSpellAoE(self:GetCaster())
		end
		local enemies = FindUnitsInRadius(
			self:GetCaster():GetTeamNumber(),
			location,
			nil,
			radius,
			DOTA_UNIT_TARGET_TEAM_ENEMY,
			DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
			DOTA_UNIT_TARGET_FLAG_NONE,
			FIND_ANY_ORDER,
			false
		)
		for _, enemy in ipairs(enemies) do
			if not data.targets[enemy] then
				data.targets[enemy] = true
				self:HammerHit(enemy)
			end
		end
	end

	if location then
		data.thinker:SetAbsOrigin(location)
		GridNav:DestroyTreesAroundPoint(location, self:GetSpecialValueFor("projectile_radius"), false)
		self:MaybeDropTrail(data, location)
	end
end

function dawnbreaker_celestial_hammer_custom:MaybeDropTrail(data, location)
	if not data.last_trail then
		data.last_trail = location
		return
	end

	if (location - data.last_trail):Length2D() < 48 then
		return
	end

	CreateModifierThinker(
		self:GetCaster(),
		self,
		"modifier_dawnbreaker_celestial_hammer_custom_trail",
		{
			duration = self:GetSpecialValueFor("flare_debuff_duration"),
			x = data.last_trail.x,
			y = data.last_trail.y,
		},
		location,
		self:GetCaster():GetTeamNumber(),
		false
	)
	data.last_trail = location
end

function dawnbreaker_celestial_hammer_custom:OnProjectileHitHandle(target, location, handle)
	local data = self.projectiles[handle]
	if not data then
		if target == self:GetCaster() then
			self:FinishHammerReturn({
				thinker = self:GetActiveHammerThinker(),
			})
		end
		return true
	end

	if data.cast == 1 then
		if target then
			self:HammerHit(target)
			return false
		end

		local ground = GetGroundPosition(location, self:GetCaster())
		if IsValidEntity(data.thinker) then
			data.thinker:SetAbsOrigin(ground)
			local modifier = data.thinker:FindModifierByName("modifier_dawnbreaker_celestial_hammer_custom_thinker")
			if modifier then
				modifier:Delay()
			end
		end
		self:StopThrowEffects(data.effect)
		self.projectiles[handle] = nil
		return true
	end

	self:FinishHammerReturn(data)
	self.projectiles[handle] = nil
	return true
end

function dawnbreaker_celestial_hammer_custom:FinishHammerReturn(data)
	data = data or {}
	local caster = self:GetCaster()
	local thinker = data.thinker

	if self.thinkers then
		for i = #self.thinkers, 1, -1 do
			local entry = self.thinkers[i]
			if entry == thinker or not IsValidEntity(entry) then
				table.remove(self.thinkers, i)
			end
		end
	end

	if IsValidEntity(thinker) then
		local modifier = thinker:FindModifierByName("modifier_dawnbreaker_celestial_hammer_custom_thinker")
		if modifier then
			modifier:Destroy()
		end
	end

	self:RestoreHammerSlot()

	local nohammer = caster:FindModifierByName("modifier_dawnbreaker_celestial_hammer_custom_nohammer")
	if not nohammer then
		return
	end

	caster:StartGesture(ACT_DOTA_CAST_ABILITY_2_END)
	nohammer:Decrement()

	local pull = caster:FindModifierByName("modifier_dawnbreaker_celestial_hammer_custom")
	if pull then
		pull:Destroy()
	end

	self:PlayReturnCatchEffects()
end

function dawnbreaker_celestial_hammer_custom:OnOwnerSpawned()
	if not IsServer() then
		return
	end
	self:RestoreCastLayout()
end

function dawnbreaker_celestial_hammer_custom:ShowConvergeAbility()
	local caster = self:GetCaster()
	local converge = caster:FindAbilityByName(CONVERGE_NAME)
	if not converge then
		return
	end

	if converge:GetLevel() < 1 then
		converge:SetLevel(1)
	end
	converge:SetActivated(true)
	if converge:IsHidden() then
		caster:SwapAbilities(HAMMER_NAME, CONVERGE_NAME, false, true)
	end
	if converge:IsHidden() then
		converge:SetHidden(false)
	end
	converge:StartCooldown(converge:GetCooldown(-1))
end

function dawnbreaker_celestial_hammer_custom:RestoreCastLayout()
	if not IsServer() then
		return
	end
	self:RestoreHammerSlot()
	if self:IsHidden() then
		self:SetHidden(false)
	end
end

function dawnbreaker_celestial_hammer_custom:RestoreHammerSlot()
	local caster = self:GetCaster()
	local converge = caster:FindAbilityByName(CONVERGE_NAME)
	if not converge then
		return
	end

	if not converge:IsHidden() then
		caster:SwapAbilities(CONVERGE_NAME, HAMMER_NAME, false, true)
	end
	if not converge:IsHidden() then
		converge:SetHidden(true)
	end
	converge:SetActivated(false)
end

function dawnbreaker_celestial_hammer_custom:HammerHit(target)
	if not IsValidEntity(target) then
		return
	end

	ApplyDamage({
		victim = target,
		attacker = self:GetCaster(),
		damage = self:GetHammerDamage(),
		damage_type = self:GetAbilityDamageType(),
		ability = self,
	})
	self:PlayHitEffects(target)
end

function dawnbreaker_celestial_hammer_custom:Converge()
	local caster = self:GetCaster()
	if self:IsConverging() then
		return
	end

	local target = self:GetActiveHammerThinker()
	if not target then
		self:RestoreCastLayout()
		return
	end

	local projectile = self.projectiles and self.projectiles[target.projectile_id]
	if projectile and projectile.cast == 1 then
		self:StopThrowEffects(projectile.effect)
		self.projectiles[target.projectile_id] = nil
		ProjectileManager:DestroyLinearProjectile(target.projectile_id)
	end

	local modifier = target:FindModifierByName("modifier_dawnbreaker_celestial_hammer_custom_thinker")
	if modifier then
		modifier:Return()
	end

	caster:AddNewModifier(caster, self, "modifier_dawnbreaker_celestial_hammer_custom", {
		target = target:entindex(),
	})
	caster:EmitSound("Hero_Dawnbreaker.Converge.Cast")
end

function dawnbreaker_celestial_hammer_custom:PlayThrowEffects(start, distance, velocity)
	local min_rate = 1
	local duration = distance / math.max(velocity:Length2D(), 1)
	local rotation = 0.5
	local rate = rotation / math.max(duration, 0.01)
	while rate < min_rate do
		rotation = rotation + 1
		rate = rotation / math.max(duration, 0.01)
	end

	local effect = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_dawnbreaker/dawnbreaker_celestial_hammer_projectile.vpcf",
		PATTACH_WORLDORIGIN,
		self:GetCaster()
	)
	ParticleManager:SetParticleControl(effect, 0, start)
	ParticleManager:SetParticleControl(effect, 1, velocity)
	ParticleManager:SetParticleControl(effect, 4, Vector(rate, 0, 0))
	self:GetCaster():EmitSound("Hero_Dawnbreaker.Celestial_Hammer.Cast")
	return effect
end

function dawnbreaker_celestial_hammer_custom:PlayHitEffects(target)
	local radius = self:GetSpecialValueFor("projectile_radius")
	local effect = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_dawnbreaker/dawnbreaker_celestial_hammer_aoe_impact.vpcf",
		PATTACH_ABSORIGIN_FOLLOW,
		target
	)
	ParticleManager:SetParticleControl(effect, 1, Vector(radius, radius, radius))
	ParticleManager:ReleaseParticleIndex(effect)
	target:EmitSound("Hero_Dawnbreaker.Celestial_Hammer.Damage")
end

function dawnbreaker_celestial_hammer_custom:PlayReturnCatchEffects()
	local effect = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_dawnbreaker/dawnbreaker_converge.vpcf",
		PATTACH_ABSORIGIN_FOLLOW,
		self:GetCaster()
	)
	ParticleManager:SetParticleControlEnt(
		effect,
		3,
		self:GetCaster(),
		PATTACH_POINT_FOLLOW,
		"attach_attack1",
		Vector(0, 0, 0),
		true
	)
	ParticleManager:ReleaseParticleIndex(effect)
end

function dawnbreaker_celestial_hammer_custom:StopThrowEffects(effect)
	if not effect then
		return
	end
	ParticleManager:DestroyParticle(effect, false)
	ParticleManager:ReleaseParticleIndex(effect)
end

dawnbreaker_converge_custom = class({})

function dawnbreaker_converge_custom:CastFilterResult()
	local caster = self:GetCaster()
	if caster:HasModifier("modifier_dawnbreaker_celestial_hammer_custom") then
		return UF_FAIL_CUSTOM
	end
	if not caster:HasModifier("modifier_dawnbreaker_celestial_hammer_custom_nohammer") then
		return UF_FAIL_CUSTOM
	end
	return UF_SUCCESS
end

function dawnbreaker_converge_custom:GetCustomCastError()
	return "#dota_hud_error_cant_cast"
end

function dawnbreaker_converge_custom:OnSpellStart()
	if not IsServer() then
		return
	end

	self:SetActivated(false)
	local hammer = self:GetCaster():FindAbilityByName(HAMMER_NAME)
	if hammer then
		hammer:Converge()
	end
end

modifier_dawnbreaker_celestial_hammer_custom = class({})

function modifier_dawnbreaker_celestial_hammer_custom:IsHidden()
	return true
end

function modifier_dawnbreaker_celestial_hammer_custom:IsPurgable()
	return false
end

function modifier_dawnbreaker_celestial_hammer_custom:OnCreated(kv)
	self.parent = self:GetParent()
	self.ability = self:GetAbility()
	if not IsServer() then
		return
	end

	self.speed = self.ability:GetSpecialValueFor("projectile_speed") * self.ability:GetSpecialValueFor("travel_speed_pct") / 100
	self.duration = self.ability:GetSpecialValueFor("flare_debuff_duration")
	self.target = EntIndexToHScript(kv.target)
	if not IsValidEntity(self.target) then
		self:Destroy()
		return
	end

	local direction = self.target:GetAbsOrigin() - self.parent:GetAbsOrigin()
	direction.z = 0
	if direction:Length2D() > 0 then
		self.parent:SetForwardVector(direction:Normalized())
	end

	self.prev_pos = self.parent:GetAbsOrigin()
	self:StartIntervalThink(0.03)
	self:PlayEffects()
end

function modifier_dawnbreaker_celestial_hammer_custom:OnDestroy()
	if not IsServer() then
		return
	end
	FindClearSpaceForUnit(self.parent, self.parent:GetAbsOrigin(), true)
end

function modifier_dawnbreaker_celestial_hammer_custom:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_OVERRIDE_ANIMATION,
		MODIFIER_PROPERTY_DISABLE_TURNING,
	}
end

function modifier_dawnbreaker_celestial_hammer_custom:GetOverrideAnimation()
	return ACT_DOTA_OVERRIDE_ABILITY_2
end

function modifier_dawnbreaker_celestial_hammer_custom:GetModifierDisableTurning()
	return 1
end

function modifier_dawnbreaker_celestial_hammer_custom:CheckState()
	return {
		[MODIFIER_STATE_STUNNED] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
	}
end

function modifier_dawnbreaker_celestial_hammer_custom:OnIntervalThink()
	if not IsValidEntity(self.target) then
		self:Destroy()
		return
	end

	CreateModifierThinker(
		self.parent,
		self.ability,
		"modifier_dawnbreaker_celestial_hammer_custom_trail",
		{
			duration = self.duration,
			x = self.prev_pos.x,
			y = self.prev_pos.y,
		},
		self.parent:GetAbsOrigin(),
		self.parent:GetTeamNumber(),
		false
	)
	self.prev_pos = self.parent:GetAbsOrigin()

	local destination = self.target:GetAbsOrigin()
	local origin = self.parent:GetAbsOrigin()
	local diff = destination - origin
	diff.z = 0
	local distance = diff:Length2D()
	local step = self.speed * 0.03
	if distance <= step then
		self.parent:SetAbsOrigin(GetGroundPosition(destination, self.parent))
		self:Destroy()
		return
	end

	local next_pos = origin + diff:Normalized() * step
	self.parent:SetAbsOrigin(GetGroundPosition(next_pos, self.parent))
end

function modifier_dawnbreaker_celestial_hammer_custom:PlayEffects()
	local effect = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_dawnbreaker/dawnbreaker_converge_trail.vpcf",
		PATTACH_ABSORIGIN,
		self.parent
	)
	ParticleManager:SetParticleControlEnt(
		effect,
		1,
		self.parent,
		PATTACH_ABSORIGIN_FOLLOW,
		"attach_hitloc",
		Vector(0, 0, 0),
		true
	)
	ParticleManager:SetParticleControlForward(effect, 0, self.parent:GetForwardVector())
	self:AddParticle(effect, false, false, -1, false, false)
end

modifier_dawnbreaker_celestial_hammer_custom_nohammer = class({})

function modifier_dawnbreaker_celestial_hammer_custom_nohammer:IsHidden()
	return true
end

function modifier_dawnbreaker_celestial_hammer_custom_nohammer:IsPurgable()
	return false
end

function modifier_dawnbreaker_celestial_hammer_custom_nohammer:OnCreated()
	if not IsServer() then
		return
	end
	self:IncrementStackCount()
	self:SetWeaponVisible(false)
	self:SetHammerRequiredAbilitiesActivated(false)
	self:StartIntervalThink(0.1)
end

function modifier_dawnbreaker_celestial_hammer_custom_nohammer:OnIntervalThink()
	self:SetHammerRequiredAbilitiesActivated(false)
end

function modifier_dawnbreaker_celestial_hammer_custom_nohammer:OnRefresh()
	self:OnCreated()
end

function modifier_dawnbreaker_celestial_hammer_custom_nohammer:OnDestroy()
	if not IsServer() then
		return
	end
	self:SetWeaponVisible(true)
	self:SetHammerRequiredAbilitiesActivated(true)
	local ability = self:GetAbility()
	if ability and ability.RestoreHammerSlot then
		ability:RestoreHammerSlot()
	end
end

function modifier_dawnbreaker_celestial_hammer_custom_nohammer:SetHammerRequiredAbilitiesActivated(enabled)
	local ability = self:GetAbility()
	if ability and ability.SetHammerRequiredAbilitiesActivated then
		ability:SetHammerRequiredAbilitiesActivated(enabled)
		return
	end

	local caster = self:GetParent()
	if not IsValidEntity(caster) then
		return
	end

	for _, name in ipairs(HAMMER_REQUIRED_ABILITIES) do
		local blocked = caster:FindAbilityByName(name)
		if blocked then
			blocked:SetActivated(enabled)
		end
	end
end

function modifier_dawnbreaker_celestial_hammer_custom_nohammer:Decrement()
	self:DecrementStackCount()
	if self:GetStackCount() < 1 then
		self:Destroy()
	end
end

function modifier_dawnbreaker_celestial_hammer_custom_nohammer:SetWeaponVisible(visible)
	local caster = self:GetCaster()
	if not caster or not caster:IsHero() or not caster.GetTogglableWearable then
		return
	end
	local weapon = caster:GetTogglableWearable(DOTA_LOADOUT_TYPE_WEAPON)
	if not weapon then
		return
	end
	if visible then
		weapon:RemoveEffects(EF_NODRAW)
	else
		weapon:AddEffects(EF_NODRAW)
	end
end

function modifier_dawnbreaker_celestial_hammer_custom_nohammer:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_TRANSLATE_ACTIVITY_MODIFIERS,
		MODIFIER_EVENT_ON_ABILITY_START,
	}
end

function modifier_dawnbreaker_celestial_hammer_custom_nohammer:OnAbilityStart(params)
	if not IsServer() then
		return
	end
	if params.unit ~= self:GetParent() or not params.ability then
		return
	end

	local name = params.ability:GetAbilityName()
	if name ~= "dawnbreaker_fire_wreath" and name ~= "dawnbreaker_solar_guardian_custom" then
		return
	end

	self:GetParent():Interrupt()
	params.ability:EndCooldown()
	if params.ability.RefundManaCost then
		params.ability:RefundManaCost()
	end
	SendDawnbreakerHudError(self:GetParent(), "#dota_hud_error_nohammer")
end

function modifier_dawnbreaker_celestial_hammer_custom_nohammer:GetActivityTranslationModifiers()
	return "no_hammer"
end

modifier_dawnbreaker_celestial_hammer_custom_thinker = class({})

function modifier_dawnbreaker_celestial_hammer_custom_thinker:IsHidden()
	return true
end

function modifier_dawnbreaker_celestial_hammer_custom_thinker:IsPurgable()
	return false
end

function modifier_dawnbreaker_celestial_hammer_custom_thinker:OnCreated()
	self.caster = self:GetCaster()
	self.parent = self:GetParent()
	self.ability = self:GetAbility()
	if not IsServer() then
		return
	end
	self.speed = self.ability:GetSpecialValueFor("projectile_speed")
	self.delay = self.ability:GetSpecialValueFor("pause_duration")
	self.duration = self.ability:GetSpecialValueFor("flare_debuff_duration")
	self.parent:EmitSound("Hero_Dawnbreaker.Celestial_Hammer.Projectile")
end

function modifier_dawnbreaker_celestial_hammer_custom_thinker:OnDestroy()
	if not IsServer() then
		return
	end
	UTIL_Remove(self.parent)
end

function modifier_dawnbreaker_celestial_hammer_custom_thinker:OnIntervalThink()
	if not self.returning then
		self:Return()
		return
	end

	CreateModifierThinker(
		self.caster,
		self.ability,
		"modifier_dawnbreaker_celestial_hammer_custom_trail",
		{
			duration = self.duration,
			x = self.prev_pos.x,
			y = self.prev_pos.y,
		},
		self.parent:GetAbsOrigin(),
		self.caster:GetTeamNumber(),
		false
	)
	self.prev_pos = self.parent:GetAbsOrigin()
end

function modifier_dawnbreaker_celestial_hammer_custom_thinker:Delay()
	self:PlayGroundEffects()
	self:StartIntervalThink(self.delay)
	AddFOWViewer(self.caster:GetTeamNumber(), self.parent:GetAbsOrigin(), 200, self.delay, false)
end

function modifier_dawnbreaker_celestial_hammer_custom_thinker:Return()
	if self.returning then
		return
	end

	self.returning = true
	self.prev_pos = self.parent:GetAbsOrigin()
	self:StartIntervalThink(0.1)
	self:OnIntervalThink()

	local distance = (self.parent:GetAbsOrigin() - self.caster:GetAbsOrigin()):Length2D()
	local speed = self.speed
	if distance > speed * 1.5 then
		speed = distance / 1.5
	end

	local info = {
		Target = self.caster,
		Source = self.parent,
		Ability = self.ability,
		EffectName = "particles/units/heroes/hero_dawnbreaker/dawnbreaker_celestial_hammer_return.vpcf",
		iMoveSpeed = speed,
		bDodgeable = false,
	}
	local id = ProjectileManager:CreateTrackingProjectile(info)
	self.ability.projectiles = self.ability.projectiles or {}
	self.ability.projectiles[id] = {
		cast = 2,
		targets = {},
		thinker = self.parent,
		last_trail = self.parent:GetAbsOrigin(),
	}
	self.parent.projectile_id = id
	self:PlayReturnEffects()
end

function modifier_dawnbreaker_celestial_hammer_custom_thinker:PlayGroundEffects()
	local direction = self.parent:GetAbsOrigin() - self.caster:GetAbsOrigin()
	direction.z = 0
	if direction:Length2D() > 0 then
		direction = direction:Normalized()
	end

	local effect = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_dawnbreaker/dawnbreaker_celestial_hammer_grounded.vpcf",
		PATTACH_WORLDORIGIN,
		self.parent
	)
	ParticleManager:SetParticleControl(effect, 0, self.parent:GetAbsOrigin())
	ParticleManager:SetParticleControl(effect, 1, self.caster:GetAbsOrigin())
	ParticleManager:SetParticleControlForward(effect, 0, direction)
	self.ground_effect = effect
	self:AddParticle(effect, false, false, -1, false, false)
	self.parent:EmitSound("Hero_Dawnbreaker.Celestial_Hammer.Impact")
end

function modifier_dawnbreaker_celestial_hammer_custom_thinker:PlayReturnEffects()
	if self.ground_effect then
		ParticleManager:DestroyParticle(self.ground_effect, false)
		ParticleManager:ReleaseParticleIndex(self.ground_effect)
		self.ground_effect = nil
	end
	self.parent:EmitSound("Hero_Dawnbreaker.Celestial_Hammer.Return")
end

modifier_dawnbreaker_celestial_hammer_custom_trail = class({})

function modifier_dawnbreaker_celestial_hammer_custom_trail:IsHidden()
	return true
end

function modifier_dawnbreaker_celestial_hammer_custom_trail:IsPurgable()
	return false
end

function modifier_dawnbreaker_celestial_hammer_custom_trail:OnCreated(kv)
	self.radius = self:GetAbility():GetSpecialValueFor("flare_radius")
	if GetHeroBonusSpellAoE then
		self.radius = self.radius + GetHeroBonusSpellAoE(self:GetCaster())
	end
	if not IsServer() then
		return
	end
	self.prev_pos = GetGroundPosition(Vector(kv.x, kv.y, 0), self:GetParent())
	self:PlayEffects(kv.duration)
end

function modifier_dawnbreaker_celestial_hammer_custom_trail:OnDestroy()
	if not IsServer() then
		return
	end
	UTIL_Remove(self:GetParent())
end

function modifier_dawnbreaker_celestial_hammer_custom_trail:IsAura()
	return true
end

function modifier_dawnbreaker_celestial_hammer_custom_trail:GetModifierAura()
	return "modifier_dawnbreaker_celestial_hammer_custom_debuff"
end

function modifier_dawnbreaker_celestial_hammer_custom_trail:GetAuraRadius()
	return self.radius
end

function modifier_dawnbreaker_celestial_hammer_custom_trail:GetAuraDuration()
	return 0.5
end

function modifier_dawnbreaker_celestial_hammer_custom_trail:GetAuraSearchTeam()
	return DOTA_UNIT_TARGET_TEAM_ENEMY
end

function modifier_dawnbreaker_celestial_hammer_custom_trail:GetAuraSearchType()
	return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC
end

function modifier_dawnbreaker_celestial_hammer_custom_trail:PlayEffects(duration)
	local effect = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_dawnbreaker/dawnbreaker_converge_burning_trail.vpcf",
		PATTACH_WORLDORIGIN,
		self:GetParent()
	)
	ParticleManager:SetParticleControl(effect, 0, self:GetParent():GetAbsOrigin())
	ParticleManager:SetParticleControl(effect, 1, self.prev_pos)
	ParticleManager:SetParticleControl(effect, 2, Vector(duration, 0, 0))
	ParticleManager:SetParticleControl(effect, 3, Vector(self.radius, self.radius, self.radius))
	ParticleManager:ReleaseParticleIndex(effect)
end

modifier_dawnbreaker_celestial_hammer_custom_debuff = class({})

function modifier_dawnbreaker_celestial_hammer_custom_debuff:IsPurgable()
	return true
end

function modifier_dawnbreaker_celestial_hammer_custom_debuff:OnCreated()
	local ability = self:GetAbility()
	self.interval = ability:GetSpecialValueFor("burn_interval")
	if not IsServer() then
		return
	end
	self.damage = ability:GetSpecialValueFor("burn_damage") * self.interval
	self:StartIntervalThink(self.interval)
	self:OnIntervalThink()
end

function modifier_dawnbreaker_celestial_hammer_custom_debuff:OnIntervalThink()
	ApplyDamage({
		victim = self:GetParent(),
		attacker = self:GetCaster(),
		damage = self.damage,
		damage_type = self:GetAbility():GetAbilityDamageType(),
		ability = self:GetAbility(),
	})
end

function modifier_dawnbreaker_celestial_hammer_custom_debuff:GetEffectName()
	return "particles/units/heroes/hero_dawnbreaker/dawnbreaker_converge_debuff.vpcf"
end

function modifier_dawnbreaker_celestial_hammer_custom_debuff:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end
