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
phantom_assassin_blur = class({})
LinkLuaModifier( "modifier_phantom_assassin_blur", "abilities/phantom_assassin/phantom_assassin_blur", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_phantom_assassin_blur_active", "abilities/phantom_assassin/phantom_assassin_blur", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------------
-- Init Abilities
function phantom_assassin_blur:Precache( context )
	PrecacheResource( "soundfile", "soundevents/game_sounds_heroes/game_sounds_phantom_assassin.vsndevts", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_phantom_assassin/phantom_assassin_blur.vpcf", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_phantom_assassin/phantom_assassin_blur_active.vpcf", context )
end

function phantom_assassin_blur:Spawn()
	if not IsServer() then return end
end

--------------------------------------------------------------------------------
-- Apply passive modifier when hero spawns
function phantom_assassin_blur:OnOwnerSpawned()
	if IsServer() then
		local caster = self:GetCaster()
		
		-- Only apply if ability is learned
		if self:GetLevel() > 0 then
			-- Remove old modifier if exists
			local old_modifier = caster:FindModifierByName( "modifier_phantom_assassin_blur" )
			if old_modifier then
				old_modifier:Destroy()
			end
			
			-- Add new modifier
			caster:AddNewModifier(
				caster,
				self,
				"modifier_phantom_assassin_blur",
				{}
			)
		end
	end
end

--------------------------------------------------------------------------------
-- Ability Start
function phantom_assassin_blur:OnSpellStart()
	local caster = self:GetCaster()
	local duration = self:GetSpecialValueFor( "active_duration" )

	-- Add active modifier
	caster:AddNewModifier(
		caster,
		self,
		"modifier_phantom_assassin_blur_active",
		{ duration = duration }
	)

	-- Play effects
	self:PlayEffects()
end

--------------------------------------------------------------------------------
-- Passive Modifier - Apply when ability is learned
function phantom_assassin_blur:OnUpgrade()
	if IsServer() then
		local caster = self:GetCaster()
		
		-- Remove old modifier if exists
		local old_modifier = caster:FindModifierByName( "modifier_phantom_assassin_blur" )
		if old_modifier then
			old_modifier:Destroy()
		end
		
		-- Add new modifier if ability is learned
		if self:GetLevel() > 0 then
			caster:AddNewModifier(
				caster,
				self,
				"modifier_phantom_assassin_blur",
				{}
			)
		end
	end
end

--------------------------------------------------------------------------------
-- Effects
function phantom_assassin_blur:PlayEffects()
	-- get resources
	local sound_cast = "Hero_PhantomAssassin.Blur"
	local particle_cast = "particles/units/heroes/hero_phantom_assassin/phantom_assassin_blur_active.vpcf"

	-- play effects
	local nFXIndex = ParticleManager:CreateParticle( particle_cast, PATTACH_ABSORIGIN_FOLLOW, self:GetCaster() )
	ParticleManager:SetParticleControl( nFXIndex, 0, self:GetCaster():GetOrigin() )
	ParticleManager:ReleaseParticleIndex( nFXIndex )

	-- play sounds
	EmitSoundOn( sound_cast, self:GetCaster() )
end

--------------------------------------------------------------------------------
-- Passive Modifier
--------------------------------------------------------------------------------
modifier_phantom_assassin_blur = class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_phantom_assassin_blur:IsHidden()
	return false
end

function modifier_phantom_assassin_blur:IsDebuff()
	return false
end

function modifier_phantom_assassin_blur:IsPurgable()
	return false
end

function modifier_phantom_assassin_blur:IsPurgeException()
	return false
end

function modifier_phantom_assassin_blur:IsStunDebuff()
	return false
end

function modifier_phantom_assassin_blur:RemoveOnDeath()
	return false
end

function modifier_phantom_assassin_blur:AllowIllusionDuplicate()
	return false
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_phantom_assassin_blur:OnCreated( kv )
	self.ability = self:GetAbility()
	self.parent = self:GetParent()
	
	-- get values
	self.evasion_chance = self.ability:GetSpecialValueFor( "evasion_chance" )
	self.radius = self.ability:GetSpecialValueFor( "radius" )
	self.think_interval = 0.1
	
	if IsServer() then
		-- Start interval
		self:StartIntervalThink( self.think_interval )
		self:OnIntervalThink()
	end
end

function modifier_phantom_assassin_blur:OnRefresh( kv )
	self.evasion_chance = self.ability:GetSpecialValueFor( "evasion_chance" )
	self.radius = self.ability:GetSpecialValueFor( "radius" )
end

function modifier_phantom_assassin_blur:OnRemoved()
end

function modifier_phantom_assassin_blur:OnDestroy()
end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_phantom_assassin_blur:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_EVASION_CONSTANT,
	}

	return funcs
end

function modifier_phantom_assassin_blur:GetModifierEvasion_Constant()
	return self.evasion_chance
end

--------------------------------------------------------------------------------
-- Interval Effects
function modifier_phantom_assassin_blur:OnIntervalThink()
	if not IsServer() then return end
	
	-- Check if there are enemy heroes nearby
	local enemies = FindUnitsInRadius(
		self.parent:GetTeamNumber(),
		self.parent:GetOrigin(),
		nil,
		self.radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO,
		DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_NO_INVIS,
		0,
		false
	)
	
	-- If no enemies nearby, hide the hero
	if #enemies == 0 then
		self.parent:AddNewModifier(
			self.parent,
			self.ability,
			"modifier_invisible",
			{}
		)
	else
		-- Remove invisibility if enemies are nearby
		local invis_modifier = self.parent:FindModifierByName( "modifier_invisible" )
		if invis_modifier then
			invis_modifier:Destroy()
		end
	end
end

--------------------------------------------------------------------------------
-- Graphics & Animations
function modifier_phantom_assassin_blur:GetStatusEffectName()
	return "particles/status_fx/status_effect_phantom_assassin_blur.vpcf"
end

function modifier_phantom_assassin_blur:StatusEffectPriority()
	return MODIFIER_PRIORITY_NORMAL
end

--------------------------------------------------------------------------------
-- Active Modifier
--------------------------------------------------------------------------------
modifier_phantom_assassin_blur_active = class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_phantom_assassin_blur_active:IsHidden()
	return false
end

function modifier_phantom_assassin_blur_active:IsDebuff()
	return false
end

function modifier_phantom_assassin_blur_active:IsPurgable()
	return false
end

function modifier_phantom_assassin_blur_active:IsPurgeException()
	return false
end

function modifier_phantom_assassin_blur_active:IsStunDebuff()
	return false
end

function modifier_phantom_assassin_blur_active:RemoveOnDeath()
	return true
end

function modifier_phantom_assassin_blur_active:AllowIllusionDuplicate()
	return false
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_phantom_assassin_blur_active:OnCreated( kv )
	self.ability = self:GetAbility()
	self.parent = self:GetParent()
	
	-- get values
	self.evasion_chance = self.ability:GetSpecialValueFor( "active_evasion_chance" )
	self.think_interval = 0.1
	
	if IsServer() then
		-- Start interval
		self:StartIntervalThink( self.think_interval )
		self:OnIntervalThink()
	end
end

function modifier_phantom_assassin_blur_active:OnRefresh( kv )
	self.evasion_chance = self.ability:GetSpecialValueFor( "active_evasion_chance" )
end

function modifier_phantom_assassin_blur_active:OnRemoved()
end

function modifier_phantom_assassin_blur_active:OnDestroy()
end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_phantom_assassin_blur_active:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_EVASION_CONSTANT,
	}

	return funcs
end

function modifier_phantom_assassin_blur_active:GetModifierEvasion_Constant()
	return self.evasion_chance
end

--------------------------------------------------------------------------------
-- Interval Effects
function modifier_phantom_assassin_blur_active:OnIntervalThink()
	if not IsServer() then return end
	
	-- Make hero invisible during active duration
	self.parent:AddNewModifier(
		self.parent,
		self.ability,
		"modifier_invisible",
		{}
	)
end

--------------------------------------------------------------------------------
-- Graphics & Animations
function modifier_phantom_assassin_blur_active:GetStatusEffectName()
	return "particles/status_fx/status_effect_phantom_assassin_blur_active.vpcf"
end

function modifier_phantom_assassin_blur_active:StatusEffectPriority()
	return MODIFIER_PRIORITY_HIGH
end 