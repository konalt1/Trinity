modifier_lich_frost_shield_lua_debuff = class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_lich_frost_shield_lua_debuff:IsHidden()
	return false
end

function modifier_lich_frost_shield_lua_debuff:IsDebuff()
	return true
end

function modifier_lich_frost_shield_lua_debuff:IsStunDebuff()
	return false
end

function modifier_lich_frost_shield_lua_debuff:IsPurgable()
	return true
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_lich_frost_shield_lua_debuff:OnCreated( kv )
	-- references
	self.slow_movespeed = kv.slow_movespeed
end

function modifier_lich_frost_shield_lua_debuff:OnRefresh( kv )
	-- references
	self.slow_movespeed = kv.slow_movespeed
end

function modifier_lich_frost_shield_lua_debuff:OnDestroy( kv )
	-- Play effect when debuff expires
	if IsServer() then
		local sound_cast = "Hero_Lich.FrostNova"
		EmitSoundOn( sound_cast, self:GetParent() )
	end
end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_lich_frost_shield_lua_debuff:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
	}

	return funcs
end

function modifier_lich_frost_shield_lua_debuff:GetModifierMoveSpeedBonus_Percentage()
	return self.slow_movespeed
end

--------------------------------------------------------------------------------
-- Graphics & Animations
function modifier_lich_frost_shield_lua_debuff:GetStatusEffectName()
	return "particles/status_fx/status_effect_frost_lich.vpcf"
end

function modifier_lich_frost_shield_lua_debuff:GetEffectName()
	return "particles/units/heroes/hero_lich/lich_slowed_cold.vpcf"
end

function modifier_lich_frost_shield_lua_debuff:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end 