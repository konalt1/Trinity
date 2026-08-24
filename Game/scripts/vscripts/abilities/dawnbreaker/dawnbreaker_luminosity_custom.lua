LinkLuaModifier(
	"modifier_dawnbreaker_luminosity_custom",
	"abilities/dawnbreaker/dawnbreaker_luminosity_custom",
	LUA_MODIFIER_MOTION_NONE
)

dawnbreaker_luminosity_custom = class({})

function dawnbreaker_luminosity_custom:Precache(context)
	if self:GetCaster() and self:GetCaster():IsIllusion() then
		return
	end

	PrecacheResource("particle", "particles/units/heroes/hero_dawnbreaker/dawnbreaker_solar_guardian_landing.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_dawnbreaker/dawnbreaker_celestial_hammer_aoe_impact.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_dawnbreaker.vsndevts", context)
end

function dawnbreaker_luminosity_custom:GetIntrinsicModifierName()
	return "modifier_dawnbreaker_luminosity_custom"
end

function dawnbreaker_luminosity_custom:GetAOERadius()
	local radius = self:GetSpecialValueFor("radius")
	if GetHeroBonusSpellAoE then
		radius = radius + GetHeroBonusSpellAoE(self:GetCaster())
	end
	return radius
end

function dawnbreaker_luminosity_custom:GetChargeModifier()
	return self:GetCaster():FindModifierByName("modifier_dawnbreaker_luminosity_custom")
end

function dawnbreaker_luminosity_custom:GetChargeCount()
	local modifier = self:GetChargeModifier()
	if not modifier then
		return 0
	end
	return modifier:GetStackCount()
end

function dawnbreaker_luminosity_custom:CastFilterResult()
	if self:GetChargeCount() < 1 then
		return UF_FAIL_CUSTOM
	end
	return UF_SUCCESS
end

function dawnbreaker_luminosity_custom:GetCustomCastError()
	if self:GetChargeCount() < 1 then
		return "#dota_hud_error_dawnbreaker_luminosity_no_charges"
	end
	return ""
end

function dawnbreaker_luminosity_custom:GetExplosionOrigin()
	local caster = self:GetCaster()
	local hammer = caster:FindAbilityByName("dawnbreaker_celestial_hammer_custom")
	if hammer and hammer.IsHammerAway and hammer:IsHammerAway() and hammer.GetHammerWorldOrigin then
		return hammer:GetHammerWorldOrigin() or caster:GetAbsOrigin()
	end
	return caster:GetAbsOrigin()
end

function dawnbreaker_luminosity_custom:OnSpellStart()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	local charges = self:GetChargeCount()
	if charges < 1 then
		return
	end

	local origin = self:GetExplosionOrigin()
	local radius = self:GetAOERadius()
	local damage = self:GetSpecialValueFor("damage_per_charge") * charges
	local heal = self:GetSpecialValueFor("heal_per_charge") * charges

	local enemies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		origin,
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)
	for _, enemy in ipairs(enemies) do
		ApplyDamage({
			victim = enemy,
			attacker = caster,
			damage = damage,
			damage_type = self:GetAbilityDamageType(),
			ability = self,
		})
	end

	local allies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		origin,
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)
	for _, ally in ipairs(allies) do
		ally:Heal(heal, self)
		SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, ally, heal, nil)
	end

	local charge_modifier = self:GetChargeModifier()
	if charge_modifier then
		charge_modifier:SetStackCount(0)
		charge_modifier:SetDuration(-1, true)
	end

	self:PlayBurstEffects(origin, radius)
	EmitSoundOnLocationWithCaster(origin, "Hero_Dawnbreaker.Luminosity.Heal", caster)
	EmitSoundOnLocationWithCaster(origin, "Hero_Dawnbreaker.Celestial_Hammer.Impact", caster)
end

function dawnbreaker_luminosity_custom:PlayBurstEffects(origin, radius)
	local caster = self:GetCaster()
	local landing = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_dawnbreaker/dawnbreaker_solar_guardian_landing.vpcf",
		PATTACH_WORLDORIGIN,
		caster
	)
	ParticleManager:SetParticleControl(landing, 0, origin)
	ParticleManager:SetParticleControl(landing, 1, Vector(radius, radius, radius))
	ParticleManager:ReleaseParticleIndex(landing)

	local impact = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_dawnbreaker/dawnbreaker_celestial_hammer_aoe_impact.vpcf",
		PATTACH_WORLDORIGIN,
		caster
	)
	ParticleManager:SetParticleControl(impact, 0, origin)
	ParticleManager:SetParticleControl(impact, 1, Vector(radius, radius, radius))
	ParticleManager:ReleaseParticleIndex(impact)
end

modifier_dawnbreaker_luminosity_custom = class({})

function modifier_dawnbreaker_luminosity_custom:IsHidden()
	return self:GetStackCount() < 1
end

function modifier_dawnbreaker_luminosity_custom:IsPurgable()
	return false
end

function modifier_dawnbreaker_luminosity_custom:DestroyOnExpire()
	return false
end

function modifier_dawnbreaker_luminosity_custom:RemoveOnDeath()
	return false
end

function modifier_dawnbreaker_luminosity_custom:OnCreated()
	self.max_charges = self:GetAbility():GetSpecialValueFor("max_charges")
	self.charge_duration = self:GetAbility():GetSpecialValueFor("charge_duration")
	if not IsServer() then
		return
	end
	self:SetStackCount(0)
	self:SetDuration(-1, true)
	self:StartIntervalThink(0.1)
end

function modifier_dawnbreaker_luminosity_custom:OnRefresh()
	self.max_charges = self:GetAbility():GetSpecialValueFor("max_charges")
	self.charge_duration = self:GetAbility():GetSpecialValueFor("charge_duration")
end

function modifier_dawnbreaker_luminosity_custom:OnIntervalThink()
	if not IsServer() then
		return
	end

	local ability = self:GetAbility()
	if not ability or ability:IsNull() or ability:GetLevel() == 0 then
		if self:GetStackCount() > 0 then
			self:SetStackCount(0)
			self:SetDuration(-1, true)
		end
		return
	end

	if self:GetStackCount() < 1 then
		return
	end
	if self:GetRemainingTime() > 0 then
		return
	end
	self:SetStackCount(0)
	self:SetDuration(-1, true)
end

function modifier_dawnbreaker_luminosity_custom:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
end

function modifier_dawnbreaker_luminosity_custom:OnAttackLanded(params)
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if params.attacker ~= parent then
		return
	end

	local ability = self:GetAbility()
	if not ability or ability:IsNull() or ability:GetLevel() == 0 then
		return
	end

	if parent:PassivesDisabled() then
		return
	end
	if parent:GetTeamNumber() == params.target:GetTeamNumber() then
		return
	end
	if params.target:IsBuilding() or params.target:IsOther() then
		return
	end

	local stacks = math.min(self:GetStackCount() + 1, self.max_charges)
	self:SetStackCount(stacks)
	self:SetDuration(self.charge_duration, true)
end
