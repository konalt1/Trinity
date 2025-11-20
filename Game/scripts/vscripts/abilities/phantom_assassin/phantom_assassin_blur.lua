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
phantom_assassin_blur_custom = class({})
LinkLuaModifier( "modifier_phantom_assassin_blur", "abilities/phantom_assassin/phantom_assassin_blur", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_phantom_assassin_blur_active", "abilities/phantom_assassin/phantom_assassin_blur", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_phantom_assassin_blur_scepter", "abilities/phantom_assassin/phantom_assassin_blur", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------------
-- Init Abilities
function phantom_assassin_blur_custom:Precache( context )
	PrecacheResource( "soundfile", "soundevents/game_sounds_heroes/game_sounds_phantom_assassin.vsndevts", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_phantom_assassin/phantom_assassin_blur.vpcf", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_phantom_assassin/phantom_assassin_blur_active.vpcf", context )
end

function phantom_assassin_blur_custom:Spawn()
	if not IsServer() then return end
end

--------------------------------------------------------------------------------
-- Scepter: Reduce cooldown by half
function phantom_assassin_blur_custom:GetCooldown( level )
	local cooldown = self.BaseClass.GetCooldown( self, level )
	
	if self:GetCaster():HasScepter() then
		cooldown = cooldown * 0.5
		print("[PA Blur] Scepter detected! Cooldown reduced to: " .. cooldown)
	end
	
	return cooldown
end

--------------------------------------------------------------------------------
-- Apply passive modifier when hero spawns
function phantom_assassin_blur_custom:OnOwnerSpawned()
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
			
			-- Add scepter modifier if has scepter
			if caster:HasScepter() then
				if not caster:HasModifier("modifier_phantom_assassin_blur_scepter") then
					caster:AddNewModifier(
						caster,
						self,
						"modifier_phantom_assassin_blur_scepter",
						{}
					)
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Ability Start
function phantom_assassin_blur_custom:OnSpellStart()
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
function phantom_assassin_blur_custom:OnUpgrade()
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
		
		-- Add scepter modifier for cooldown refresh on kill
		if caster:HasScepter() then
			if not caster:HasModifier("modifier_phantom_assassin_blur_scepter") then
				caster:AddNewModifier(
					caster,
					self,
					"modifier_phantom_assassin_blur_scepter",
					{}
				)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Effects
function phantom_assassin_blur_custom:PlayEffects()
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
	
	-- Don't check for enemies if active blur is running
	if self.parent:HasModifier("modifier_phantom_assassin_blur_active") then
		return
	end
	
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
	
	-- Check for scepter and apply/remove scepter modifier
	if self.parent:HasScepter() then
		if not self.parent:HasModifier("modifier_phantom_assassin_blur_scepter") then
			self.parent:AddNewModifier(
				self.parent,
				self.ability,
				"modifier_phantom_assassin_blur_scepter",
				{}
			)
		end
	else
		local scepter_modifier = self.parent:FindModifierByName("modifier_phantom_assassin_blur_scepter")
		if scepter_modifier then
			scepter_modifier:Destroy()
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

--------------------------------------------------------------------------------
-- Scepter Modifier - Refresh cooldowns on hero kill
--------------------------------------------------------------------------------
modifier_phantom_assassin_blur_scepter = class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_phantom_assassin_blur_scepter:IsHidden()
	return true
end

function modifier_phantom_assassin_blur_scepter:IsDebuff()
	return false
end

function modifier_phantom_assassin_blur_scepter:IsPurgable()
	return false
end

function modifier_phantom_assassin_blur_scepter:RemoveOnDeath()
	return false
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_phantom_assassin_blur_scepter:OnCreated( kv )
	if not IsServer() then return end
	print("[PA Blur Scepter] Scepter modifier applied! Hero kills will now refresh cooldowns.")
end

function modifier_phantom_assassin_blur_scepter:DeclareFunctions()
	local funcs = {
		MODIFIER_EVENT_ON_HERO_KILLED,
	}
	return funcs
end

--------------------------------------------------------------------------------
-- Scepter effect: Refresh all cooldowns on hero kill
function modifier_phantom_assassin_blur_scepter:OnHeroKilled( params )
	if not IsServer() then return end
	
	local parent = self:GetParent()
	local attacker = params.attacker
	local target = params.target
	
	-- Check if parent killed an enemy hero
	if attacker == parent and target:IsRealHero() and target:GetTeamNumber() ~= parent:GetTeamNumber() then
		print("[PA Blur Scepter] Hero killed! Refreshing all cooldowns...")
		
		-- Refresh all ability cooldowns
		local refreshed_count = 0
		for i = 0, parent:GetAbilityCount() - 1 do
			local ability = parent:GetAbilityByIndex( i )
			if ability and not ability:IsItem() then
				ability:EndCooldown()
				refreshed_count = refreshed_count + 1
				print("[PA Blur Scepter] Refreshed: " .. ability:GetAbilityName())
			end
		end
		
		print("[PA Blur Scepter] Total abilities refreshed: " .. refreshed_count)
		
		-- Play sound effect
		EmitSoundOn( "Hero_PhantomAssassin.CoupDeGrace", parent )
		
		-- Show particle effect
		local particle = ParticleManager:CreateParticle( 
			"particles/units/heroes/hero_phantom_assassin/phantom_assassin_crit_impact.vpcf", 
			PATTACH_ABSORIGIN_FOLLOW, 
			parent 
		)
		ParticleManager:SetParticleControl( particle, 0, parent:GetOrigin() )
		ParticleManager:ReleaseParticleIndex( particle )
	end
end 