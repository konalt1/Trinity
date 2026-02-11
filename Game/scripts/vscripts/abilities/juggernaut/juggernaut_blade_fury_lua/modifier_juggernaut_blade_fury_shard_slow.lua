modifier_juggernaut_blade_fury_shard_slow = class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_juggernaut_blade_fury_shard_slow:IsHidden()
	return false
end

function modifier_juggernaut_blade_fury_shard_slow:IsDebuff()
	return true
end

function modifier_juggernaut_blade_fury_shard_slow:IsPurgable()
	return true
end

function modifier_juggernaut_blade_fury_shard_slow:DestroyOnExpire()
	return true
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_juggernaut_blade_fury_shard_slow:OnCreated( kv )
	if self:GetAbility() then
		self.slow = self:GetAbility():GetSpecialValueFor( "shard_movement_slow" ) or 35
	else
		self.slow = 35
	end
end

function modifier_juggernaut_blade_fury_shard_slow:OnRefresh( kv )
	self:OnCreated( kv )
end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_juggernaut_blade_fury_shard_slow:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
	}
	return funcs
end

function modifier_juggernaut_blade_fury_shard_slow:GetModifierMoveSpeedBonus_Percentage()
	return -self.slow
end

--------------------------------------------------------------------------------
-- Graphics & Animations
function modifier_juggernaut_blade_fury_shard_slow:GetEffectName()
	return "particles/generic_gameplay/generic_slowed_cold.vpcf"
end

function modifier_juggernaut_blade_fury_shard_slow:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end
