LinkLuaModifier("modifier_techies_sticky_bomb_custom", "abilities/techies/techies_sticky_bomb", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_techies_sticky_bomb_custom_motion", "abilities/techies/techies_sticky_bomb", LUA_MODIFIER_MOTION_BOTH)
LinkLuaModifier("modifier_techies_sticky_bomb_activated", "abilities/techies/techies_sticky_bomb", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_techies_sticky_bomb_slow_secondary", "abilities/techies/techies_sticky_bomb", LUA_MODIFIER_MOTION_NONE)

techies_sticky_bomb = class({})

local STICKY_BOMB_UNIT_NAME = "npc_dota_omniknight_sticky_grenade"

function techies_sticky_bomb:Precache(context)
	PrecacheResource("model", "models/heroes/sniper/concussive_grenade.vmdl", context)
end

function techies_sticky_bomb:GetAOERadius()
	return self:GetSpecialValueFor("radius")
end

function techies_sticky_bomb:OnSpellStart()
	if not IsServer() then
		return
	end
	self:ThrowBomb(self:GetCursorPosition())
end

function techies_sticky_bomb:ThrowBomb(point)
	local grenade = CreateUnitByName(
		STICKY_BOMB_UNIT_NAME,
		self:GetCaster():GetAbsOrigin(),
		false,
		nil,
		nil,
		self:GetCaster():GetTeamNumber()
	)
	if grenade then
		grenade:EmitSound("Hero_Techies.StickyBomb.Cast")
		grenade:AddNewModifier(self:GetCaster(), self, "modifier_techies_sticky_bomb_custom", {})
		grenade:AddNewModifier(
			self:GetCaster(),
			self,
			"modifier_techies_sticky_bomb_custom_motion",
			{ vLocX = point.x, vLocY = point.y, vLocZ = point.z }
		)
		grenade:AddNewModifier(self:GetCaster(), self, "modifier_kill", { duration = 10 })
	end
end

modifier_techies_sticky_bomb_custom = class({})

function modifier_techies_sticky_bomb_custom:IsHidden()
	return true
end

function modifier_techies_sticky_bomb_custom:IsPurgable()
	return false
end

function modifier_techies_sticky_bomb_custom:RemoveOnDeath()
	return false
end

function modifier_techies_sticky_bomb_custom:IsPurgeException()
	return false
end

function modifier_techies_sticky_bomb_custom:CheckState()
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

local TECHIES_MINIMUM_HEIGHT_ABOVE_LOWEST = 0
local TECHIES_MINIMUM_HEIGHT_ABOVE_HIGHEST = 600
local TECHIES_ACCELERATION_Z = 4000
local TECHIES_MAX_HORIZONTAL_ACCELERATION = 2000

modifier_techies_sticky_bomb_custom_motion = class({})

function modifier_techies_sticky_bomb_custom_motion:IsHidden()
	return true
end

function modifier_techies_sticky_bomb_custom_motion:IsPurgable()
	return false
end

function modifier_techies_sticky_bomb_custom_motion:IsPurgeException()
	return false
end

function modifier_techies_sticky_bomb_custom_motion:RemoveOnDeath()
	return false
end

function modifier_techies_sticky_bomb_custom_motion:OnCreated(kv)
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
	local flDesiredHeight = TECHIES_MINIMUM_HEIGHT_ABOVE_LOWEST * duration * duration
	local flLowZ = math.min(self.vLastKnownTargetPos.z, self.vStartPosition.z)
	local flHighZ = math.max(self.vLastKnownTargetPos.z, self.vStartPosition.z)
	local flArcTopZ = math.max(flLowZ + flDesiredHeight, flHighZ + TECHIES_MINIMUM_HEIGHT_ABOVE_HIGHEST)
	local flArcDeltaZ = flArcTopZ - self.vStartPosition.z
	self.flInitialVelocityZ = math.sqrt(2.0 * flArcDeltaZ * TECHIES_ACCELERATION_Z)
	local flDeltaZ = self.vLastKnownTargetPos.z - self.vStartPosition.z
	local flSqrtDet = math.sqrt(
		math.max(0, (self.flInitialVelocityZ * self.flInitialVelocityZ) - 2.0 * TECHIES_ACCELERATION_Z * flDeltaZ)
	)
	self.flPredictedTotalTime = math.max(
		(self.flInitialVelocityZ + flSqrtDet) / TECHIES_ACCELERATION_Z,
		(self.flInitialVelocityZ - flSqrtDet) / TECHIES_ACCELERATION_Z
	)
	self.vHorizontalVelocity = (self.vLastKnownTargetPos - self.vStartPosition) / self.flPredictedTotalTime
	self.vHorizontalVelocity.z = 0.0
end

function modifier_techies_sticky_bomb_custom_motion:OnDestroy()
	if not IsServer() then
		return
	end
	self:GetParent():RemoveHorizontalMotionController(self)
	self:GetParent():RemoveVerticalMotionController(self)
	self:GetParent():EmitSound("Hero_Techies.StickyBomb.Plant")
	self:GetParent():EmitSound("Ability.TossImpact")
	self:GetParent():AddNewModifier(
		self:GetCaster(),
		self:GetAbility(),
		"modifier_techies_sticky_bomb_activated",
		{ duration = self.countdown }
	)
	GridNav:DestroyTreesAroundPoint(self:GetParent():GetAbsOrigin(), 100, true)
end

function modifier_techies_sticky_bomb_custom_motion:UpdateHorizontalMotion(me, dt)
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
	local flVelDelta = math.min(flVelDif, TECHIES_MAX_HORIZONTAL_ACCELERATION)
	self.vHorizontalVelocity = self.vHorizontalVelocity + vVelDif * flVelDelta * dt
	local vNewPos = vOldPos + self.vHorizontalVelocity * dt
	me:SetOrigin(vNewPos)
end

function modifier_techies_sticky_bomb_custom_motion:UpdateVerticalMotion(me, dt)
	if not IsServer() then
		return
	end
	self.flCurrentTimeVert = self.flCurrentTimeVert + dt
	local bGoingDown = (-TECHIES_ACCELERATION_Z * self.flCurrentTimeVert + self.flInitialVelocityZ) < 0
	local vNewPos = me:GetOrigin()
	vNewPos.z = self.vStartPosition.z
		+ (-0.5 * TECHIES_ACCELERATION_Z * (self.flCurrentTimeVert * self.flCurrentTimeVert) + self.flInitialVelocityZ * self.flCurrentTimeVert)
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

function modifier_techies_sticky_bomb_custom_motion:OnHorizontalMotionInterrupted()
	if not IsServer() then
		return
	end
	self.bHorizontalMotionInterrupted = true
end

function modifier_techies_sticky_bomb_custom_motion:OnVerticalMotionInterrupted()
	if not IsServer() then
		return
	end
	self:Destroy()
end

modifier_techies_sticky_bomb_activated = class({})

function modifier_techies_sticky_bomb_activated:IsHidden()
	return true
end

function modifier_techies_sticky_bomb_activated:IsPurgable()
	return false
end

function modifier_techies_sticky_bomb_activated:IsPurgeException()
	return false
end

function modifier_techies_sticky_bomb_activated:OnCreated()
	if not IsServer() then
		return
	end
	self.explosion_radius = self:GetAbility():GetSpecialValueFor("explosion_radius")
	self.secondary_slow_duration = self:GetAbility():GetSpecialValueFor("secondary_slow_duration")
	self.damage = self:GetAbility():GetSpecialValueFor("damage")
	self.bonus_damage_creep_pct = self:GetAbility():GetSpecialValueFor("bonus_damage_creep_pct")
end

function modifier_techies_sticky_bomb_activated:OnDestroy()
	if not IsServer() then
		return
	end
	self:GetParent():EmitSound("Hero_Techies.StickyBomb.Detonate")
	local particle = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_techies/techies_remote_cart_explode.vpcf",
		PATTACH_WORLDORIGIN,
		nil
	)
	ParticleManager:SetParticleControl(particle, 0, self:GetParent():GetAbsOrigin())
	ParticleManager:SetParticleControl(particle, 1, Vector(self.explosion_radius, self.explosion_radius, self.explosion_radius))
	ParticleManager:ReleaseParticleIndex(particle)
	local units = FindUnitsInRadius(
		self:GetCaster():GetTeamNumber(),
		self:GetParent():GetAbsOrigin(),
		nil,
		self.explosion_radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)
	for _, hero in pairs(units) do
		hero:AddNewModifier(
			self:GetCaster(),
			self:GetAbility(),
			"modifier_techies_sticky_bomb_slow_secondary",
			{ duration = self.secondary_slow_duration * (1 - hero:GetStatusResistance()) }
		)
		local dmg = self.damage
		if hero:IsCreep() then
			dmg = dmg * (self.bonus_damage_creep_pct / 100)
		end
		ApplyDamage({
			victim = hero,
			attacker = self:GetCaster(),
			damage = dmg,
			damage_type = self:GetAbility():GetAbilityDamageType(),
			ability = self:GetAbility(),
		})
	end
	self:GetParent():AddNoDraw()
	self:GetParent():ForceKill(false)
end

modifier_techies_sticky_bomb_slow_secondary = class({})

function modifier_techies_sticky_bomb_slow_secondary:OnCreated()
	self.secondary_slow = self:GetAbility():GetSpecialValueFor("secondary_slow")
end

function modifier_techies_sticky_bomb_slow_secondary:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
	}
end

function modifier_techies_sticky_bomb_slow_secondary:GetModifierMoveSpeedBonus_Percentage()
	return self.secondary_slow
end

function modifier_techies_sticky_bomb_slow_secondary:GetStatusEffectName()
	return "particles/status_fx/status_effect_brewmaster_thunder_clap.vpcf"
end

function modifier_techies_sticky_bomb_slow_secondary:GetEffectName()
	return "particles/units/heroes/hero_brewmaster/brewmaster_thunder_clap_debuff.vpcf"
end

function modifier_techies_sticky_bomb_slow_secondary:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_techies_sticky_bomb_slow_secondary:StatusEffectPriority()
	return 3
end
