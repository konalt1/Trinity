modifier_omniknight_repel_lua = class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_omniknight_repel_lua:IsHidden()
	return false
end

function modifier_omniknight_repel_lua:IsDebuff()
	return false
end

function modifier_omniknight_repel_lua:IsPurgable()
	return false
end

function modifier_omniknight_repel_lua:CheckState()
	return {
		[MODIFIER_STATE_DEBUFF_IMMUNE] = true,
	}
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_omniknight_repel_lua:OnCreated( kv )
	self.magic_damage_reduction = self:GetAbility():GetSpecialValueFor("magic_damage_reduction")

	if IsServer() then
		-- Play Effects
		self.sound_cast = "Hero_Omniknight.Repel"
		EmitSoundOn( self.sound_cast, self:GetParent() )
	end
end

function modifier_omniknight_repel_lua:OnRefresh( kv )
	self.magic_damage_reduction = self:GetAbility():GetSpecialValueFor("magic_damage_reduction")
end

function modifier_omniknight_repel_lua:OnDestroy( kv )
	if IsServer() then
		StopSoundOn( self.sound_cast, self:GetParent() )
	end
end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_omniknight_repel_lua:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
	}

	return funcs
end

function modifier_omniknight_repel_lua:GetModifierMagicalResistanceBonus()
	return self.magic_damage_reduction or 0
end
--------------------------------------------------------------------------------
-- Graphics & Animations
function modifier_omniknight_repel_lua:GetEffectName()
	return "particles/units/heroes/hero_omniknight/omniknight_repel_buff.vpcf"
end

function modifier_omniknight_repel_lua:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end