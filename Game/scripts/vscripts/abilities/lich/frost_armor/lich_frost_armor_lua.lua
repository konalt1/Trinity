lich_frost_armor_lua = class({})
LinkLuaModifier( "modifier_lich_frost_armor_lua", "abilities/lich/frost_armor/modifier_lich_frost_armor_lua", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_lich_frost_armor_lua_buff", "abilities/lich/frost_armor/modifier_lich_frost_armor_lua_buff", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_lich_frost_armor_lua_debuff", "abilities/lich/frost_armor/modifier_lich_frost_armor_lua_debuff", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------------
-- Ability Start
function lich_frost_armor_lua:OnSpellStart()
	-- unit identifier
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()

	print("Frost Armor cast by: " .. caster:GetUnitName())
	print("Frost Armor target: " .. target:GetUnitName())

	-- add buff
	target:AddNewModifier(
		caster, -- player source
		self, -- ability source
		"modifier_lich_frost_armor_lua_buff", -- modifier name
		{} -- kv
	)

	print("Frost Armor buff applied")

	-- Play effects
	self:PlayEffects( caster, target )
end

--------------------------------------------------------------------------------
-- Effects
function lich_frost_armor_lua:PlayEffects( caster, target )
	-- Get Resources
	local particle_cast = "particles/units/heroes/hero_lich/lich_frost_armor.vpcf"
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