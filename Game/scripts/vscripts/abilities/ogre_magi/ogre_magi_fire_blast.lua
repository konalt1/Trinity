LinkLuaModifier("modifier_ogre_fire_blast_stun", "abilities/ogre_magi/ogre_magi_fire_blast", LUA_MODIFIER_MOTION_NONE)

local SMASH_PARTICLE = "particles/units/heroes/hero_centaur/centaur_warstomp.vpcf"
local MIN_EFFECT_FACTOR = 0.3

ogre_magi_fire_blast = class({})

function ogre_magi_fire_blast:Precache(context)
	PrecacheResource("particle", SMASH_PARTICLE, context)
	PrecacheResource("soundfile", "soundevents/game_sounds_creeps.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_centaur.vsndevts", context)
end

function ogre_magi_fire_blast:GetBehavior()
	return DOTA_ABILITY_BEHAVIOR_POINT + DOTA_ABILITY_BEHAVIOR_AOE
end

function ogre_magi_fire_blast:GetAOERadius()
	return self:GetSpecialValueFor("wave_start_radius")
end

function ogre_magi_fire_blast:GetEffectiveLength()
	local caster = self:GetCaster()
	local base_length = self:GetSpecialValueFor("length")
	local strength_bonus = self:GetSpecialValueFor("strength_length_bonus")
	local strength = 0
	if caster and not caster:IsNull() and caster.GetStrength then
		strength = caster:GetStrength() or 0
	end
	return math.min(base_length + strength * strength_bonus, self:GetSpecialValueFor("max_length"))
end

function ogre_magi_fire_blast:GetStartRadius()
	return self:GetSpecialValueFor("wave_start_radius")
end

function ogre_magi_fire_blast:GetEndRadius()
	return self:GetStartRadius() + self:GetEffectiveLength()
end

function ogre_magi_fire_blast:GetWidthAtDistance(distance)
	local length = self:GetEffectiveLength()
	local start_radius = self:GetStartRadius()
	local end_radius = self:GetEndRadius()
	if length <= 0 then
		return end_radius
	end

	local t = math.min(1, math.max(0, distance / length))
	return start_radius + (end_radius - start_radius) * t
end

function ogre_magi_fire_blast:GetEffectiveDamage()
	local caster = self:GetCaster()
	local base_damage = self:GetSpecialValueFor("damage")
	local strength_bonus = self:GetSpecialValueFor("strength_damage_bonus")
	local strength = 0
	if caster and not caster:IsNull() and caster.GetStrength then
		strength = caster:GetStrength() or 0
	end
	return base_damage + strength * strength_bonus
end

function ogre_magi_fire_blast:OnSpellStart()
	local caster = self:GetCaster()
	self.target_point = self:GetCursorPosition()
	EmitSoundOn("n_creep_OgreBruiser.Smash.Charge", caster)
	self:ExecuteSpell()
end

function ogre_magi_fire_blast:ExecuteSpell()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	if not caster or caster:IsNull() or not caster:IsAlive() then
		return
	end

	local caster_origin = caster:GetAbsOrigin()
	local origin = GetGroundPosition(self.target_point or caster_origin, caster)
	local direction = origin - caster_origin
	direction.z = 0
	if direction:Length2D() < 1 then
		direction = caster:GetForwardVector()
		direction.z = 0
	end
	direction = direction:Normalized()

	local length = self:GetEffectiveLength()
	local start_radius = self:GetStartRadius()
	local end_radius = self:GetEndRadius()
	local speed = math.max(1, self:GetSpecialValueFor("wave_speed"))
	local fx_spacing = math.max(160, start_radius * 0.55)

	self:PlaySmash(origin, start_radius)
	EmitSoundOnLocationWithCaster(origin, "n_creep_OgreBruiser.Smash.Stun", caster)

	self.wave_serial = (self.wave_serial or 0) + 1
	local wave_id = self.wave_serial
	self.wave_states = self.wave_states or {}
	self.wave_states[wave_id] = {
		origin = origin,
		length = length,
		start_radius = start_radius,
		end_radius = end_radius,
		hit = {},
	}

	local has_shard = caster:HasModifier("modifier_item_aghanims_shard")
	ProjectileManager:CreateLinearProjectile({
		Ability = self,
		EffectName = "",
		vSpawnOrigin = origin,
		fDistance = length,
		fStartRadius = start_radius,
		fEndRadius = end_radius,
		Source = caster,
		bHasFrontalCone = false,
		bReplaceExisting = false,
		iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
		iUnitTargetFlags = has_shard and DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES or DOTA_UNIT_TARGET_FLAG_NONE,
		iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		fExpireTime = GameRules:GetGameTime() + length / speed + 0.5,
		bDeleteOnHit = false,
		vVelocity = direction * speed,
		bProvidesVision = true,
		iVisionRadius = start_radius,
		iVisionTeamNumber = caster:GetTeamNumber(),
		ExtraData = {
			wave_id = wave_id,
		},
	})

	local traveled = 0
	local interval = fx_spacing / speed
	Timers:CreateTimer(interval, function()
		if not self or self:IsNull() then
			return nil
		end

		traveled = traveled + fx_spacing
		if traveled >= length then
			self:PlaySmash(origin + direction * length, end_radius)
			return nil
		end

		local t = traveled / length
		local radius = start_radius + (end_radius - start_radius) * t
		self:PlaySmash(origin + direction * traveled, radius)
		return interval
	end)
end

function ogre_magi_fire_blast:PlaySmash(origin, radius)
	local fx = ParticleManager:CreateParticle(SMASH_PARTICLE, PATTACH_WORLDORIGIN, nil)
	if not fx or fx == 0 then
		return
	end

	local pos = GetGroundPosition(origin, nil)
	ParticleManager:SetParticleControl(fx, 0, pos)
	ParticleManager:SetParticleControl(fx, 1, Vector(radius, radius, radius))
	ParticleManager:SetParticleControl(fx, 2, pos)
	ParticleManager:ReleaseParticleIndex(fx)
end

function ogre_magi_fire_blast:GetWaveState(extra)
	local wave_id = extra and tonumber(extra.wave_id)
	if not wave_id then
		return nil, nil
	end
	self.wave_states = self.wave_states or {}
	return self.wave_states[wave_id], wave_id
end

function ogre_magi_fire_blast:OnProjectileHit_ExtraData(target, location, extra)
	if not IsServer() then
		return true
	end

	local state, wave_id = self:GetWaveState(extra)
	if not target then
		if wave_id and self.wave_states then
			self.wave_states[wave_id] = nil
		end
		return true
	end

	if not state or target:IsNull() then
		return false
	end

	local target_index = target:entindex()
	if state.hit[target_index] then
		return false
	end
	state.hit[target_index] = true

	if target:TriggerSpellAbsorb(self) then
		return false
	end

	local caster = self:GetCaster()
	local distance = (target:GetAbsOrigin() - state.origin):Length2D()
	local length = state.length
	local distance_factor = math.max(MIN_EFFECT_FACTOR, 1 - (distance / math.max(1, length)))
	local has_shard = caster:HasModifier("modifier_item_aghanims_shard")

	ApplyDamage({
		victim = target,
		attacker = caster,
		damage = self:GetEffectiveDamage() * distance_factor,
		damage_type = has_shard and DAMAGE_TYPE_PURE or DAMAGE_TYPE_MAGICAL,
		ability = self,
		damage_flags = DOTA_DAMAGE_FLAG_NONE,
	})

	local stun_modifier = has_shard and "modifier_ogre_fire_blast_stun" or "modifier_stunned"
	target:AddNewModifier(caster, self, stun_modifier, {
		duration = self:GetSpecialValueFor("stun_duration") * distance_factor,
	})

	return false
end

--------------------------------------------------------------------------------
-- Custom stun modifier (Shard: пробивает БКБ)
--------------------------------------------------------------------------------
modifier_ogre_fire_blast_stun = class({})

function modifier_ogre_fire_blast_stun:IsHidden()
	return false
end

function modifier_ogre_fire_blast_stun:IsPurgable()
	return true
end

function modifier_ogre_fire_blast_stun:IsDebuff()
	return true
end

function modifier_ogre_fire_blast_stun:GetAttributes()
	return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end

function modifier_ogre_fire_blast_stun:CheckState()
	return {
		[MODIFIER_STATE_STUNNED] = true,
	}
end

function modifier_ogre_fire_blast_stun:GetEffectName()
	return "particles/generic_gameplay/generic_stunned.vpcf"
end

function modifier_ogre_fire_blast_stun:GetEffectAttachType()
	return PATTACH_OVERHEAD_FOLLOW
end
