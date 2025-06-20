lich_frost_shield_lua = class({})
LinkLuaModifier( "modifier_lich_frost_shield_lua", "lich/frost_shield/modifier_lich_frost_shield_lua", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_lich_frost_shield_lua_buff", "lich/frost_shield/modifier_lich_frost_shield_lua_buff", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_lich_frost_shield_lua_debuff", "lich/frost_shield/modifier_lich_frost_shield_lua_debuff", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------------
-- Ability Start
function lich_frost_shield_lua:OnSpellStart()
	-- unit identifier
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()

	-- Calculate duration with talent
	local duration = self:GetSpecialValueFor("duration")
	local duration_talent = caster:FindAbilityByName("special_bonus_unique_lich_frost_shield_duration")
	if duration_talent and duration_talent:GetLevel() > 0 then
		duration = duration + duration_talent:GetSpecialValueFor("value")
	end

	-- add buff
	target:AddNewModifier(
		caster, -- player source
		self, -- ability source
		"modifier_lich_frost_shield_lua_buff", -- modifier name
		{duration = duration} -- kv
	)

	-- Play effects
	self:PlayEffects( caster, target )
end

--------------------------------------------------------------------------------
-- Effects
function lich_frost_shield_lua:PlayEffects( caster, target )
	-- Get Resources
	local particle_cast = "particles/units/heroes/hero_lich/lich_frost_shield.vpcf"
	local sound_cast = "Hero_Lich.FrostArmor"

	-- Create Particle
	local effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_ABSORIGIN_FOLLOW, target )
	ParticleManager:SetParticleControlEnt(
		effect_cast,
		1,
		caster,
		PATTACH_POINT_FOLLOW,
		"attach_attack1",
		target:GetOrigin(),
		true
	)
	ParticleManager:ReleaseParticleIndex( effect_cast )

	-- Create Sound
	EmitSoundOn( sound_cast, target )
end 