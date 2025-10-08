lich_chain_frost_lua = class({})
LinkLuaModifier( "modifier_lich_chain_frost_lua", "lich/chain_frost/modifier_lich_chain_frost_lua", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------------
-- Custom KV
function lich_chain_frost_lua:GetCastRange( vLocation, hTarget )
	if self:GetCaster():HasScepter() then
		return self:GetSpecialValueFor( "cast_range_scepter" )
	end

	return self.BaseClass.GetCastRange( self, vLocation, hTarget )
end

function lich_chain_frost_lua:GetCooldown( level )
	if self:GetCaster():HasScepter() then
		return self:GetSpecialValueFor( "cooldown_scepter" )
	end

	return self.BaseClass.GetCooldown( self, level )
end

--------------------------------------------------------------------------------
-- Ability Start
function lich_chain_frost_lua:OnSpellStart()
	-- unit identifier
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()

	-- cancel if linken
	if target:TriggerSpellAbsorb( self ) then
		return
	end

	-- load data
	local projectile_speed = self:GetSpecialValueFor( "projectile_speed" )
	local damage = self:GetSpecialValueFor( "damage" )
	local slow_duration = self:GetSpecialValueFor( "slow_duration" )
	local vision_radius = self:GetSpecialValueFor( "vision_radius" )

	-- create projectile
	local projectile_info = {
		Target = target,
		Source = caster,
		Ability = self,
		EffectName = "particles/units/heroes/hero_lich/lich_chain_frost.vpcf",
		iMoveSpeed = projectile_speed,
		bDodgeable = false,
		bVisibleToEnemies = true,
		bProvidesVision = true,
		iVisionRadius = vision_radius,
		iVisionTeamNumber = caster:GetTeamNumber(),
		ExtraData = {
			damage = damage,
			slow_duration = slow_duration,
		}
	}
	ProjectileManager:CreateTrackingProjectile( projectile_info )

	-- Play effects
	local sound_cast = "Hero_Lich.ChainFrost"
	EmitSoundOn( sound_cast, caster )
end

--------------------------------------------------------------------------------
-- Projectile
function lich_chain_frost_lua:OnProjectileHit_ExtraData( target, location, extraData )
	if not target then return end

	-- load data
	local damage = extraData.damage
	local slow_duration = extraData.slow_duration

	-- damage
	local damageTable = {
		victim = target,
		attacker = self:GetCaster(),
		damage = damage,
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability = self,
		damage_flags = DOTA_DAMAGE_FLAG_NONE,
	}
	ApplyDamage(damageTable)

	-- slow
	target:AddNewModifier(
		self:GetCaster(),
		self,
		"modifier_lich_chain_frost_lua",
		{ duration = slow_duration }
	)

	-- Play effects
	self:PlayEffects( target )

	return true
end

--------------------------------------------------------------------------------
-- Effects
function lich_chain_frost_lua:PlayEffects( target )
	-- Get Resources
	local particle_cast = "particles/units/heroes/hero_lich/lich_chain_frost.vpcf"
	local sound_cast = "Hero_Lich.ChainFrostImpact"

	-- Create Particle
	local effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_ABSORIGIN_FOLLOW, target )
	ParticleManager:ReleaseParticleIndex( effect_cast )

	-- Create Sound
	EmitSoundOn( sound_cast, target )
end