modifier_chen_martyr_mark_ally = class({})

function modifier_chen_martyr_mark_ally:IsHidden()
	return false
end

function modifier_chen_martyr_mark_ally:IsDebuff()
	return false
end

function modifier_chen_martyr_mark_ally:IsPurgable()
	return true
end

function modifier_chen_martyr_mark_ally:OnCreated()
	self.as_bonus = 0
	local ability = self:GetAbility()
	if ability and not ability:IsNull() then
		self.as_bonus = ability:GetSpecialValueFor("creep_bonus_as")
	end
end

function modifier_chen_martyr_mark_ally:OnRefresh()
	self:OnCreated()
end

function modifier_chen_martyr_mark_ally:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
	}
end

function modifier_chen_martyr_mark_ally:GetModifierAttackSpeedBonus_Constant()
	return self.as_bonus or 0
end
