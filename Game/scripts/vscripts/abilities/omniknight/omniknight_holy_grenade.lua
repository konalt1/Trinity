LinkLuaModifier(
	"modifier_omniknight_holy_grenade_custom",
	"abilities/omniknight/omniknight_holy_grenade",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_omniknight_holy_grenade_custom_motion",
	"abilities/omniknight/omniknight_holy_grenade",
	LUA_MODIFIER_MOTION_BOTH
)
LinkLuaModifier(
	"modifier_omniknight_holy_grenade_activated",
	"abilities/omniknight/omniknight_holy_grenade",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_omniknight_holy_grenade_slow_secondary",
	"abilities/omniknight/omniknight_holy_grenade",
	LUA_MODIFIER_MOTION_NONE
)

omniknight_holy_grenade = class({})

local HOLY_GRENADE_UNIT_NAME = "npc_dota_omniknight_sticky_grenade"
local PARTICLE_EXPLOSION = "particles/events/crownfall/artillery/artillery_explosion_flash.vpcf"
local PARTICLE_EXPLOSION_RADIUS = "particles/lich_frozenchains_frostnova_swipe.vpcf"

function omniknight_holy_grenade:Precache(context)
	PrecacheResource("model", "models/heroes/sniper/concussive_grenade.vmdl", context)
	PrecacheResource("soundfile", "soundevents/trinity_sounds.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_techies.vsndevts", context)
	PrecacheResource("particle", PARTICLE_EXPLOSION, context)
	PrecacheResource("particle", PARTICLE_EXPLOSION_RADIUS, context)
end

function omniknight_holy_grenade:GetAOERadius()
	return self:GetSpecialValueFor("radius")
end

function omniknight_holy_grenade:GetBurstAmount(caster)
	if not caster or caster:IsNull() then
		return math.max(0, self:GetSpecialValueFor("damage"))
	end
	local base = self:GetSpecialValueFor("damage")
	local mult = self:GetSpecialValueFor("mind_power_multiplier")
	local mind_power = 0
	if GetHeroMindPower then
		mind_power = GetHeroMindPower(caster) or 0
	else
		mind_power = caster:GetIntellect(false) or 0
	end
	return math.max(0, base + mind_power * mult)
end

function omniknight_holy_grenade:OnSpellStart()
	if not IsServer() then
		return
	end
	self:ThrowBomb(self:GetCursorPosition())
end

function omniknight_holy_grenade:ThrowBomb(point)
	local grenade = CreateUnitByName(
		HOLY_GRENADE_UNIT_NAME,
		self:GetCaster():GetAbsOrigin(),
		false,
		nil,
		nil,
		self:GetCaster():GetTeamNumber()
	)
	if grenade then
		grenade:AddNewModifier(self:GetCaster(), self, "modifier_omniknight_holy_grenade_custom", {})
		grenade:AddNewModifier(
			self:GetCaster(),
			self,
			"modifier_omniknight_holy_grenade_custom_motion",
			{ vLocX = point.x, vLocY = point.y, vLocZ = point.z }
		)
		grenade:AddNewModifier(self:GetCaster(), self, "modifier_kill", { duration = 10 })
	end
end

modifier_omniknight_holy_grenade_custom = class({})

function modifier_omniknight_holy_grenade_custom:IsHidden()
	return true
end

function modifier_omniknight_holy_grenade_custom:IsPurgable()
	return false
end

function modifier_omniknight_holy_grenade_custom:RemoveOnDeath()
	return false
end

function modifier_omniknight_holy_grenade_custom:IsPurgeException()
	return false
end

function modifier_omniknight_holy_grenade_custom:CheckState()
	return {
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_STUNNED] = true,
		[MODIFIER_STATE_OUT_OF_GAME] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_UNSELECTABLE] = true,
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
		[MODIFIER_STATE_FLYING_FOR_PATHING_PURPOSES_ONLY] = true,
	}
end

local GRENADE_MIN_HEIGHT_ABOVE_LOWEST = 0
local GRENADE_MIN_HEIGHT_ABOVE_HIGHEST = 600
local GRENADE_ACCELERATION_Z = 4000
local GRENADE_MAX_HORIZONTAL_ACCELERATION = 2000

modifier_omniknight_holy_grenade_custom_motion = class({})

function modifier_omniknight_holy_grenade_custom_motion:IsHidden()
	return true
end

function modifier_omniknight_holy_grenade_custom_motion:IsPurgable()
	return false
end

function modifier_omniknight_holy_grenade_custom_motion:IsPurgeException()
	return false
end

function modifier_omniknight_holy_grenade_custom_motion:RemoveOnDeath()
	return false
end

function modifier_omniknight_holy_grenade_custom_motion:OnCreated(kv)
	self.countdown = self:GetAbility():GetSpecialValueFor("countdown")
	if not IsServer() then
		return
	end
	if self:ApplyHorizontalMotionController() == false or self:ApplyVerticalMotionController() == false then
		if not self:IsNull() then
			self:Destroy()
		end
		return
	end
	self.bHorizontalMotionInterrupted = false
	self:GetCaster():RemoveGesture(ACT_DOTA_CAST_ABILITY_2_ES_ROLL_START)
	self.vStartPosition = GetGroundPosition(self:GetParent():GetOrigin(), self:GetParent())
	self.flCurrentTimeHoriz = 0.0
	self.flCurrentTimeVert = 0.0
	self.vLoc = Vector(kv.vLocX, kv.vLocY, kv.vLocZ)
	self.vLastKnownTargetPos = self.vLoc
	local duration = 1.2
	local flDesiredHeight = GRENADE_MIN_HEIGHT_ABOVE_LOWEST * duration * duration
	local flLowZ = math.min(self.vLastKnownTargetPos.z, self.vStartPosition.z)
	local flHighZ = math.max(self.vLastKnownTargetPos.z, self.vStartPosition.z)
	local flArcTopZ = math.max(flLowZ + flDesiredHeight, flHighZ + GRENADE_MIN_HEIGHT_ABOVE_HIGHEST)
	local flArcDeltaZ = flArcTopZ - self.vStartPosition.z
	self.flInitialVelocityZ = math.sqrt(2.0 * flArcDeltaZ * GRENADE_ACCELERATION_Z)
	local flDeltaZ = self.vLastKnownTargetPos.z - self.vStartPosition.z
	local flSqrtDet = math.sqrt(
		math.max(0, (self.flInitialVelocityZ * self.flInitialVelocityZ) - 2.0 * GRENADE_ACCELERATION_Z * flDeltaZ)
	)
	self.flPredictedTotalTime = math.max(
		(self.flInitialVelocityZ + flSqrtDet) / GRENADE_ACCELERATION_Z,
		(self.flInitialVelocityZ - flSqrtDet) / GRENADE_ACCELERATION_Z
	)
	self.vHorizontalVelocity = (self.vLastKnownTargetPos - self.vStartPosition) / self.flPredictedTotalTime
	self.vHorizontalVelocity.z = 0.0
end

function modifier_omniknight_holy_grenade_custom_motion:OnDestroy()
	if not IsServer() then
		return
	end
	self:GetParent():RemoveHorizontalMotionController(self)
	self:GetParent():RemoveVerticalMotionController(self)
	self:GetParent():EmitSound("Omniknight.StickyGrenade.Land")
	self:GetParent():AddNewModifier(
		self:GetCaster(),
		self:GetAbility(),
		"modifier_omniknight_holy_grenade_activated",
		{ duration = self.countdown }
	)
	GridNav:DestroyTreesAroundPoint(self:GetParent():GetAbsOrigin(), 100, true)
end

function modifier_omniknight_holy_grenade_custom_motion:UpdateHorizontalMotion(me, dt)
	if not IsServer() then
		return
	end
	self.flCurrentTimeHoriz = math.min(self.flCurrentTimeHoriz + dt, self.flPredictedTotalTime)
	local t = self.flCurrentTimeHoriz / self.flPredictedTotalTime
	local vStartToTarget = self.vLastKnownTargetPos - self.vStartPosition
	local vDesiredPos = self.vStartPosition + t * vStartToTarget
	local vOldPos = me:GetOrigin()
	local vToDesired = vDesiredPos - vOldPos
	vToDesired.z = 0.0
	local vDesiredVel = vToDesired / dt
	local vVelDif = vDesiredVel - self.vHorizontalVelocity
	local flVelDif = vVelDif:Length2D()
	vVelDif = vVelDif:Normalized()
	local flVelDelta = math.min(flVelDif, GRENADE_MAX_HORIZONTAL_ACCELERATION)
	self.vHorizontalVelocity = self.vHorizontalVelocity + vVelDif * flVelDelta * dt
	local vNewPos = vOldPos + self.vHorizontalVelocity * dt
	me:SetOrigin(vNewPos)
end

function modifier_omniknight_holy_grenade_custom_motion:UpdateVerticalMotion(me, dt)
	if not IsServer() then
		return
	end
	self.flCurrentTimeVert = self.flCurrentTimeVert + dt
	local bGoingDown = (-GRENADE_ACCELERATION_Z * self.flCurrentTimeVert + self.flInitialVelocityZ) < 0
	local vNewPos = me:GetOrigin()
	vNewPos.z = self.vStartPosition.z
		+ (-0.5 * GRENADE_ACCELERATION_Z * (self.flCurrentTimeVert * self.flCurrentTimeVert) + self.flInitialVelocityZ * self.flCurrentTimeVert)
	local flGroundHeight = GetGroundHeight(vNewPos, self:GetParent())
	local bLanded = false
	if vNewPos.z < flGroundHeight and bGoingDown == true then
		vNewPos.z = flGroundHeight
		bLanded = true
	end
	me:SetOrigin(vNewPos)
	if bLanded == true then
		self:GetParent():RemoveHorizontalMotionController(self)
		self:GetParent():RemoveVerticalMotionController(self)
		self:SetDuration(0.01, false)
	end
end

function modifier_omniknight_holy_grenade_custom_motion:OnHorizontalMotionInterrupted()
	if not IsServer() then
		return
	end
	self.bHorizontalMotionInterrupted = true
end

function modifier_omniknight_holy_grenade_custom_motion:OnVerticalMotionInterrupted()
	if not IsServer() then
		return
	end
	self:Destroy()
end

modifier_omniknight_holy_grenade_activated = class({})

function modifier_omniknight_holy_grenade_activated:IsHidden()
	return true
end

function modifier_omniknight_holy_grenade_activated:IsPurgable()
	return false
end

function modifier_omniknight_holy_grenade_activated:IsPurgeException()
	return false
end

function modifier_omniknight_holy_grenade_activated:OnCreated()
	if not IsServer() then
		return
	end
	self.explosion_radius = self:GetAbility():GetSpecialValueFor("explosion_radius")
	self.secondary_slow_duration = self:GetAbility():GetSpecialValueFor("secondary_slow_duration")
	self.secondary_slow = self:GetAbility():GetSpecialValueFor("secondary_slow")
end

function modifier_omniknight_holy_grenade_activated:OnDestroy()
	if not IsServer() then
		return
	end
	local origin = self:GetParent():GetAbsOrigin()
	local caster = self:GetCaster()
	local r = self.explosion_radius
	local ability = self:GetAbility()

	local particle_scale = 2.2
	if ability and not ability:IsNull() then
		local s = ability:GetSpecialValueFor("explosion_particle_radius_scale")
		if s and s > 0 then
			particle_scale = s
		end
	end
	local particle_r = r * particle_scale

	local particle_explosion = ParticleManager:CreateParticle(PARTICLE_EXPLOSION, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(particle_explosion, 0, origin)
	ParticleManager:SetParticleControl(particle_explosion, 1, Vector(particle_r, particle_r, particle_r))
	ParticleManager:ReleaseParticleIndex(particle_explosion)

	local particle_explosion_radius = ParticleManager:CreateParticle(PARTICLE_EXPLOSION_RADIUS, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(particle_explosion_radius, 0, origin)
	ParticleManager:SetParticleControl(particle_explosion_radius, 1, Vector(r, 0, 0))
	ParticleManager:ReleaseParticleIndex(particle_explosion_radius)

	EmitSoundOnLocationWithCaster(origin, "Hero_Techies.StickyBomb.Detonate", caster)
	EmitSoundOnLocationWithCaster(origin, "Hero_Techies.RemoteMine.Detonate", caster)
	local burst = ability and not ability:IsNull() and ability:GetBurstAmount(caster) or 0

	local allies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		origin,
		nil,
		self.explosion_radius,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)
	for _, ally in pairs(allies) do
		if ally and not ally:IsNull() and ally:IsAlive() and burst > 0 then
			ally:Heal(burst, ability)
		end
	end

	local enemies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		origin,
		nil,
		self.explosion_radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)
	for _, enemy in pairs(enemies) do
		if enemy and not enemy:IsNull() and enemy:IsAlive() then
			if self.secondary_slow > 0 and self.secondary_slow_duration > 0 then
				enemy:AddNewModifier(
					caster,
					ability,
					"modifier_omniknight_holy_grenade_slow_secondary",
					{ duration = self.secondary_slow_duration * (1 - enemy:GetStatusResistance()) }
				)
			end
			ApplyDamage({
				victim = enemy,
				attacker = caster,
				damage = burst,
				damage_type = DAMAGE_TYPE_PURE,
				ability = ability,
			})
		end
	end
	self:GetParent():AddNoDraw()
	self:GetParent():ForceKill(false)
end

modifier_omniknight_holy_grenade_slow_secondary = class({})

function modifier_omniknight_holy_grenade_slow_secondary:OnCreated()
	self.secondary_slow = self:GetAbility():GetSpecialValueFor("secondary_slow")
end

function modifier_omniknight_holy_grenade_slow_secondary:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
	}
end

function modifier_omniknight_holy_grenade_slow_secondary:GetModifierMoveSpeedBonus_Percentage()
	return self.secondary_slow
end

function modifier_omniknight_holy_grenade_slow_secondary:GetStatusEffectName()
	return "particles/status_fx/status_effect_brewmaster_thunder_clap.vpcf"
end

function modifier_omniknight_holy_grenade_slow_secondary:GetEffectName()
	return "particles/units/heroes/hero_brewmaster/brewmaster_thunder_clap_debuff.vpcf"
end

function modifier_omniknight_holy_grenade_slow_secondary:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_omniknight_holy_grenade_slow_secondary:StatusEffectPriority()
	return 3
end
