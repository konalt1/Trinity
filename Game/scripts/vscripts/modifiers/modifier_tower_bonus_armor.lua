modifier_tower_bonus_armor = class({})

function modifier_tower_bonus_armor:IsHidden()
	return false
end

function modifier_tower_bonus_armor:IsPurgable()
	return false
end

function modifier_tower_bonus_armor:IsDebuff()
	return false
end

function modifier_tower_bonus_armor:GetAttributes()
	return MODIFIER_ATTRIBUTE_MULTIPLE
end

function modifier_tower_bonus_armor:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS
	}
	return funcs
end

function modifier_tower_bonus_armor:GetModifierPhysicalArmorBonus()
	return 5
end

