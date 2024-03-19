modifier_custom_critical_strike = class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_custom_critical_strike:IsHidden()
	return false
end

function modifier_custom_critical_strike:IsDebuff()
	return false
end

function modifier_custom_critical_strike:IsPurgable()
	return false
end

function modifier_custom_critical_strike:GetPriority()
	return MODIFIER_PRIORITY_HIGH
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_custom_critical_strike:OnCreated(kv)
	-- references
	self.crit_chance = self:GetAbility():GetSpecialValueFor("crit_chance")
	self.crit_bonus = self:GetAbility():GetSpecialValueFor("crit_bonus")
end

function modifier_custom_critical_strike:OnRefresh(kv)
	-- references
	self.crit_chance = self:GetAbility():GetSpecialValueFor("crit_chance")
	self.crit_bonus = self:GetAbility():GetSpecialValueFor("crit_bonus")
end

function modifier_custom_critical_strike:OnDestroy(kv)
end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_custom_critical_strike:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE,
		MODIFIER_PROPERTY_PROCATTACK_FEEDBACK,
	}

	return funcs
end

function modifier_custom_critical_strike:GetModifierPreAttack_CriticalStrike(params)
	if IsServer() and (not self:GetParent():PassivesDisabled()) then
		local caster = self:GetCaster()
		if caster and caster:HasModifier("modifier_phantom_assassin_coup_de_grace_lua") then
			local coupDeGraceModifier = caster:FindModifierByName("modifier_phantom_assassin_coup_de_grace_lua")
			if coupDeGraceModifier and coupDeGraceModifier:GetStackCount() == 1 then
				if self:RollChance(self.crit_chance) then
					self.record = params.record
					return self.crit_bonus
				end
			end
		end
	end
end

function modifier_custom_critical_strike:GetModifierProcAttack_Feedback(params)
	if IsServer() then
		if self.record then
			self.record = nil
			self:PlayEffects(params.target)
		end
	end
end
--------------------------------------------------------------------------------
-- Helper
function modifier_custom_critical_strike:RollChance(chance)
	local rand = math.random()
	if rand < chance / 100 then
		return true
	end
	return false
end

--------------------------------------------------------------------------------
-- Graphics & Animations
function modifier_custom_critical_strike:PlayEffects(target)
	-- Load effects
	local particle_cast = "particles/units/heroes/hero_phantom_assassin/phantom_assassin_crit_impact.vpcf"
	local sound_cast = "Hero_PhantomAssassin.CoupDeGrace"

	-- Create Particle
	local effect_cast = ParticleManager:CreateParticle(particle_cast, PATTACH_ABSORIGIN_FOLLOW, target)
	ParticleManager:SetParticleControlEnt(
		effect_cast,
		0,
		target,
		PATTACH_POINT_FOLLOW,
		"attach_hitloc",
		target:GetOrigin(), -- unknown
		true -- unknown, true
	)
	ParticleManager:SetParticleControlForward(effect_cast, 1, (self:GetParent():GetOrigin() - target:GetOrigin()):Normalized())
	ParticleManager:ReleaseParticleIndex(effect_cast)

	EmitSoundOn(sound_cast, target)
end
