modifier_chen_martyr_mark_creep_haste = class({})

function modifier_chen_martyr_mark_creep_haste:IsHidden()
	return false
end

function modifier_chen_martyr_mark_creep_haste:IsDebuff()
	return false
end

function modifier_chen_martyr_mark_creep_haste:IsPurgable()
	return true
end

function modifier_chen_martyr_mark_creep_haste:OnCreated()
	self.ms_pct = 0
	local ability = self:GetAbility()
	if ability and not ability:IsNull() then
		self.ms_pct = ability:GetSpecialValueFor("chen_creep_bonus_ms_pct")
	end
end

function modifier_chen_martyr_mark_creep_haste:OnRefresh()
	self:OnCreated()
end

function modifier_chen_martyr_mark_creep_haste:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
	}
end

function modifier_chen_martyr_mark_creep_haste:GetModifierMoveSpeedBonus_Percentage()
	return self.ms_pct or 0
end
