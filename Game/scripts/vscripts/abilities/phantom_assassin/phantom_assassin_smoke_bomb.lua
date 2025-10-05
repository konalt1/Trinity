-- Created by Assistant
--[[
Ability checklist (erase if done/checked):
- Scepter Upgrade
- Break behavior
- Linken/Reflect behavior
- Spell Immune/Invulnerable/Invisible behavior
- Illusion behavior
- Stolen behavior
]]
--------------------------------------------------------------------------------
phantom_assassin_smoke_bomb = class({})
LinkLuaModifier( "modifier_phantom_assassin_smoke_bomb_aura", "abilities/phantom_assassin/phantom_assassin_smoke_bomb", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------------
-- Init Abilities
function phantom_assassin_smoke_bomb:Precache( context )
	PrecacheResource( "soundfile", "soundevents/game_sounds_heroes/game_sounds_phantom_assassin.vsndevts", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_phantom_assassin/phantom_assassin_blur.vpcf", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_phantom_assassin/phantom_assassin_blur_active.vpcf", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_slark/slark_shard_depth_shroud.vpcf", context )
end

function phantom_assassin_smoke_bomb:Spawn()
	if not IsServer() then return end
end

--------------------------------------------------------------------------------
-- Ability Start
function phantom_assassin_smoke_bomb:OnSpellStart()
	local caster = self:GetCaster()
	local duration = self:GetSpecialValueFor( "duration" )
	local radius = self:GetSpecialValueFor( "radius" )

	-- Create modifier thinker (like Kinetic Field) - no collision issues!
	CreateModifierThinker(
		caster, -- player source
		self, -- ability source
		"modifier_phantom_assassin_smoke_bomb_aura", -- modifier name
		{ duration = duration }, -- kv
		caster:GetOrigin(), -- position
		caster:GetTeamNumber(), -- team
		false -- requires vision
	)
end


--------------------------------------------------------------------------------
-- Aura Modifier
--------------------------------------------------------------------------------
modifier_phantom_assassin_smoke_bomb_aura = class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_phantom_assassin_smoke_bomb_aura:IsHidden()
	return true
end

function modifier_phantom_assassin_smoke_bomb_aura:IsDebuff()
	return false
end

function modifier_phantom_assassin_smoke_bomb_aura:IsPurgable()
	return false
end

function modifier_phantom_assassin_smoke_bomb_aura:IsPurgeException()
	return false
end

function modifier_phantom_assassin_smoke_bomb_aura:IsStunDebuff()
	return false
end

function modifier_phantom_assassin_smoke_bomb_aura:RemoveOnDeath()
	return true
end

function modifier_phantom_assassin_smoke_bomb_aura:AllowIllusionDuplicate()
	return false
end

function modifier_phantom_assassin_smoke_bomb_aura:GetAttributes()
	return MODIFIER_ATTRIBUTE_MULTIPLE
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_phantom_assassin_smoke_bomb_aura:OnCreated( kv )
	if not IsServer() then return end
	
	-- Check if this is the owner (thinker) or aura target
	self.owner = kv.isProvidedByAura~=1
	
	if self.owner then
		-- This is the thinker - set up the aura
		self.ability = self:GetAbility()
		self.parent = self:GetParent()
		self.radius = self.ability:GetSpecialValueFor( "radius" )
		self.duration = kv.duration or self.ability:GetSpecialValueFor( "duration" )
		
		-- Set duration
		self:SetDuration( self.duration, false )
		
		-- Play effects
		self:PlayEffects()
		
		-- Create smoke particle
		self:CreateSmokeEffect()
	else
		-- This is an aura target - set up invisibility
		self.ability = self:GetAbility()
		self.parent = self:GetParent()
		self.aura_origin = Vector( kv.aura_origin_x, kv.aura_origin_y, 0 )
		
		-- Apply invisibility
		self:ApplyInvisibility()
	end
end

function modifier_phantom_assassin_smoke_bomb_aura:OnRefresh( kv )
	if not IsServer() then return end
	
	if self.owner then
		self.radius = self.ability:GetSpecialValueFor( "radius" )
	else
		-- Reapply invisibility when refreshed
		self:ApplyInvisibility()
	end
end

function modifier_phantom_assassin_smoke_bomb_aura:OnRemoved()
	if not IsServer() then return end
	
	-- If this is an aura target (not the thinker), remove invisibility when leaving
	if not self.owner then
		local invis_modifier = self.parent:FindModifierByName( "modifier_invisible" )
		if invis_modifier and invis_modifier.smoke_bomb_source then
			invis_modifier:Destroy()
			print("[Smoke Bomb] Removed invisibility from:", self.parent:GetUnitName(), "OnRemoved")
		end
	end
end

function modifier_phantom_assassin_smoke_bomb_aura:OnDestroy()
	if not IsServer() then return end
	
	if self.owner then
		-- Clean up particles
		if self.smoke_particle then
			ParticleManager:DestroyParticle( self.smoke_particle, false )
		end
		if self.additional_particle then
			ParticleManager:DestroyParticle( self.additional_particle, false )
		end
		
		-- Remove thinker
		UTIL_Remove( self:GetParent() )
	else
		-- If this is an aura target, remove invisibility when destroyed
		local invis_modifier = self.parent:FindModifierByName( "modifier_invisible" )
		if invis_modifier and invis_modifier.smoke_bomb_source then
			invis_modifier:Destroy()
			print("[Smoke Bomb] Removed invisibility from:", self.parent:GetUnitName(), "OnDestroy")
		end
	end
end

--------------------------------------------------------------------------------
-- Aura Settings
function modifier_phantom_assassin_smoke_bomb_aura:IsAura()
	return self.owner
end

function modifier_phantom_assassin_smoke_bomb_aura:GetModifierAura()
	return "modifier_phantom_assassin_smoke_bomb_aura"
end

function modifier_phantom_assassin_smoke_bomb_aura:GetAuraRadius()
	return self.radius
end

function modifier_phantom_assassin_smoke_bomb_aura:GetAuraDuration()
	return 0.1
end

function modifier_phantom_assassin_smoke_bomb_aura:GetAuraSearchTeam()
	return DOTA_UNIT_TARGET_TEAM_FRIENDLY
end

function modifier_phantom_assassin_smoke_bomb_aura:GetAuraSearchType()
	return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC
end

function modifier_phantom_assassin_smoke_bomb_aura:GetAuraSearchFlags()
	return DOTA_UNIT_TARGET_FLAG_NONE
end

--------------------------------------------------------------------------------
-- Helper Functions
function modifier_phantom_assassin_smoke_bomb_aura:ApplyInvisibility()
	if not IsServer() then return end
	
	-- Remove existing invisibility from smoke bomb
	local existing_invis = self.parent:FindModifierByName( "modifier_invisible" )
	if existing_invis and existing_invis.smoke_bomb_source then
		existing_invis:Destroy()
	end
	
	-- Apply new invisibility
	local invis_modifier = self.parent:AddNewModifier(
		self.parent,
		self.ability,
		"modifier_invisible",
		{ duration = -1 }
	)
	
	-- Mark as smoke bomb source
	if invis_modifier then
		invis_modifier.smoke_bomb_source = true
		print("[Smoke Bomb] Applied invisibility to:", self.parent:GetUnitName())
	end
end

function modifier_phantom_assassin_smoke_bomb_aura:PlayEffects()
	if not IsServer() then return end
	
	-- Play cast effects
	local sound_cast = "Hero_PhantomAssassin.Blur"
	local particle_cast = "particles/units/heroes/hero_phantom_assassin/phantom_assassin_blur_active.vpcf"

	-- Create particle with ability radius and duration
	local nFXIndex = ParticleManager:CreateParticle( particle_cast, PATTACH_WORLDORIGIN, nil )
	ParticleManager:SetParticleControl( nFXIndex, 0, self.parent:GetOrigin() )
	ParticleManager:SetParticleControl( nFXIndex, 1, Vector( self.radius, self.radius, self.radius ) )
	ParticleManager:SetParticleControl( nFXIndex, 2, Vector( self.duration, 0, 0 ) )
	ParticleManager:ReleaseParticleIndex( nFXIndex )

	-- Play sound
	EmitSoundOn( sound_cast, self.parent )
end

function modifier_phantom_assassin_smoke_bomb_aura:CreateSmokeEffect()
	if not IsServer() then return end
	
	-- Create main smoke effect with ability parameters
	self.smoke_particle = ParticleManager:CreateParticle( 
		"particles/units/heroes/hero_slark/slark_shard_depth_shroud.vpcf", 
		PATTACH_ABSORIGIN_FOLLOW, 
		self.parent 
	)
	
	-- Set particle controls with ability radius and duration
	ParticleManager:SetParticleControl( self.smoke_particle, 0, self.parent:GetOrigin() )
	ParticleManager:SetParticleControl( self.smoke_particle, 1, Vector( self.radius, self.radius, self.radius ) )
	ParticleManager:SetParticleControl( self.smoke_particle, 2, Vector( self.duration, 0, 0 ) )
	
	-- Create additional effect with ability parameters
	self.additional_particle = ParticleManager:CreateParticle( 
		"particles/units/heroes/hero_phantom_assassin/phantom_assassin_blur.vpcf", 
		PATTACH_ABSORIGIN_FOLLOW, 
		self.parent 
	)
	
	-- Set additional particle controls with ability radius and duration
	ParticleManager:SetParticleControl( self.additional_particle, 0, self.parent:GetOrigin() )
	ParticleManager:SetParticleControl( self.additional_particle, 1, Vector( self.radius, self.radius, self.radius ) )
	ParticleManager:SetParticleControl( self.additional_particle, 2, Vector( self.duration, 0, 0 ) )
	
	print("[Smoke Bomb] Created smoke effects with radius:", self.radius, "and duration:", self.duration)
end

