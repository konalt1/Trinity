custom_purification = class({})

--------------------------------------------------------------------------------
-- Ability Start
function custom_purification:OnSpellStart()
	-- unit identifier
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()

	-- load data
	local instant_heal = self:GetSpecialValueFor("instant_heal")
	local duration = self:GetSpecialValueFor("duration")
	local magic_resistance = self:GetSpecialValueFor("magic_resistance")
	
	-- Debug output
	print("Custom Purification: Instant Heal=" .. instant_heal .. ", Duration=" .. duration .. ", Magic Resistance=" .. magic_resistance .. "%")

	-- Сильное развеивание (очищает все негативные эффекты)
	target:Purge(false, true, false, true, false)
	
	-- Мгновенное исцеление
	target:Heal(instant_heal, self)

	-- Применить модификатор защиты
	target:AddNewModifier(caster, self, "modifier_custom_purification_protection", {duration = duration})

	self:PlayEffects1(target)
end

--------------------------------------------------------------------------------
function custom_purification:PlayEffects1(target)
	-- Get Resources
	local particle_cast = "particles/units/heroes/hero_omniknight/omniknight_purification_cast.vpcf"
	local particle_target = "particles/units/heroes/hero_omniknight/omniknight_purification.vpcf"
	local particle_protection = "particles/units/heroes/hero_omniknight/omniknight_guardian_angel_omni.vpcf"
	local sound_target = "Hero_Omniknight.Purification"

	-- Create Target Effects
	local effect_target = ParticleManager:CreateParticle(particle_target, PATTACH_ABSORIGIN_FOLLOW, target)
	ParticleManager:ReleaseParticleIndex(effect_target)
	
	-- Create Protection Effect
	local effect_protection = ParticleManager:CreateParticle(particle_protection, PATTACH_ABSORIGIN_FOLLOW, target)
	ParticleManager:ReleaseParticleIndex(effect_protection)
	
	EmitSoundOn(sound_target, target)

	-- Create Caster Effects
	local effect_cast = ParticleManager:CreateParticle(particle_cast, PATTACH_ABSORIGIN_FOLLOW, self:GetCaster())
	ParticleManager:SetParticleControl(effect_cast, 0, self:GetCaster():GetOrigin())
	ParticleManager:SetParticleControl(effect_cast, 1, target:GetOrigin())
	
	ParticleManager:ReleaseParticleIndex(effect_cast)
end

--------------------------------------------------------------------------------
-- Модификатор защиты
modifier_custom_purification_protection = class({})

function modifier_custom_purification_protection:IsHidden()
	return false
end

function modifier_custom_purification_protection:IsPurgable()
	return false
end

function modifier_custom_purification_protection:IsBuff()
	return true
end

function modifier_custom_purification_protection:RemoveOnDeath()
	return true
end

function modifier_custom_purification_protection:OnCreated()
	if not IsServer() then return end
	
	local ability = self:GetAbility()
	if ability then
		self.magic_resistance = ability:GetSpecialValueFor("magic_resistance")
	else
		self.magic_resistance = 80
	end
end

function modifier_custom_purification_protection:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
		MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING
	}
end

function modifier_custom_purification_protection:GetModifierMagicalResistanceBonus()
	return self.magic_resistance or 80
end

function modifier_custom_purification_protection:GetModifierStatusResistanceStacking()
	return 100 -- Полная защита от эффектов
end

function modifier_custom_purification_protection:GetEffectName()
	return "particles/units/heroes/hero_omniknight/omniknight_guardian_angel_omni.vpcf"
end

function modifier_custom_purification_protection:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end
