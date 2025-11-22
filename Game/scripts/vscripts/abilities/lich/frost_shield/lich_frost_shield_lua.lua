LinkLuaModifier( "modifier_lich_frost_shield_lua", "abilities/lich/frost_shield/modifier_lich_frost_shield_lua", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_lich_frost_shield_lua_buff", "abilities/lich/frost_shield/modifier_lich_frost_shield_lua_buff", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_lich_frost_shield_lua_debuff", "abilities/lich/frost_shield/modifier_lich_frost_shield_lua_debuff", LUA_MODIFIER_MOTION_NONE )

lich_frost_shield_lua = class({})

function lich_frost_shield_lua:Precache(context)
	PrecacheResource("particle", "particles/lich/lich_ice_age_dmg.vpcf", context)
	PrecacheResource("particle", "particles/lich/lich_ice_age.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_lich.vsndevts", context)
end

--------------------------------------------------------------------------------
-- Ability Start
function lich_frost_shield_lua:OnSpellStart()
	-- unit identifier
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	local sound_cast = "Hero_Lich.IceAge"
	EmitSoundOn( sound_cast, target )
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
	local particle_cast = "particles/lich/lich_ice_age_dmg.vpcf"
	local sound_cast = "Hero_Lich.IceAge.Tick"

	-- Create Particle
	local effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_ABSORIGIN_FOLLOW, target )
	-- Set particle to repeat and fix orientation
	ParticleManager:SetParticleControl(effect_cast, 0, target:GetAbsOrigin())
	ParticleManager:SetParticleControl(effect_cast, 2, Vector(1, 1, 1)) -- Scale
	ParticleManager:SetParticleControl(effect_cast, 3, Vector(0, 0, 0)) -- Rotation
	ParticleManager:ReleaseParticleIndex( effect_cast )

	-- Create Sound
	EmitSoundOn( sound_cast, target )
end 