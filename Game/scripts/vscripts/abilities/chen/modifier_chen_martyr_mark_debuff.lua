modifier_chen_martyr_mark_debuff = class({})

function modifier_chen_martyr_mark_debuff:IsHidden()
	return false
end

function modifier_chen_martyr_mark_debuff:IsDebuff()
	return true
end

function modifier_chen_martyr_mark_debuff:IsPurgable()
	return true
end

function modifier_chen_martyr_mark_debuff:OnCreated()
	self.slow_ms_pct = 0
	local ability = self:GetAbility()
	if ability and not ability:IsNull() then
		self.slow_ms_pct = ability:GetSpecialValueFor("slow_ms_pct")
	end
end

function modifier_chen_martyr_mark_debuff:OnRefresh()
	self:OnCreated()
end

function modifier_chen_martyr_mark_debuff:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
	}
end

function modifier_chen_martyr_mark_debuff:GetModifierMoveSpeedBonus_Percentage()
	return self.slow_ms_pct or 0
end

function modifier_chen_martyr_mark_debuff:GetEffectName()
	return "particles/units/heroes/hero_chen/chen_penitence.vpcf"
end

function modifier_chen_martyr_mark_debuff:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end
