modifier_lich_frost_shield_lua = class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_lich_frost_shield_lua:IsHidden()
	return true
end

function modifier_lich_frost_shield_lua:IsDebuff()
	return false
end

function modifier_lich_frost_shield_lua:GetAttributes()
	return MODIFIER_ATTRIBUTE_INVULNERABLE 
end

function modifier_lich_frost_shield_lua:IsPurgable()
	return false
end

function modifier_lich_frost_shield_lua:RemoveOnDeath()
	return true
end 