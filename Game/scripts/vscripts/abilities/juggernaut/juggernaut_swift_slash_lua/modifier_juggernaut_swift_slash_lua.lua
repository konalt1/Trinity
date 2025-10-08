modifier_juggernaut_swift_slash_lua = class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_juggernaut_swift_slash_lua:IsHidden()
	return false
end

function modifier_juggernaut_swift_slash_lua:IsDebuff()
	return false
end

function modifier_juggernaut_swift_slash_lua:IsPurgable()
	return false
end

function modifier_juggernaut_swift_slash_lua:DestroyOnExpire()
	return true
end

--------------------------------------------------------------------------------
-- Status Effects
function modifier_juggernaut_swift_slash_lua:CheckState()
	local state = {
		[MODIFIER_STATE_MAGIC_IMMUNE] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
	}
	return state
end

function modifier_juggernaut_swift_slash_lua:GetEffectName()
	return "particles/units/heroes/hero_juggernaut/juggernaut_omni_slash_blur.vpcf"
end

function modifier_juggernaut_swift_slash_lua:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end 