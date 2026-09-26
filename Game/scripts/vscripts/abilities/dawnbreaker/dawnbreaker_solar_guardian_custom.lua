require("modifiers/modifier_generic_arc_lua")

LinkLuaModifier(
	"modifier_dawnbreaker_solar_guardian_custom_leap",
	"abilities/dawnbreaker/dawnbreaker_solar_guardian_custom",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_dawnbreaker_solar_guardian_custom_tracker",
	"abilities/dawnbreaker/dawnbreaker_solar_guardian_custom",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_dawnbreaker_solar_guardian_custom_tracker_active",
	"abilities/dawnbreaker/dawnbreaker_solar_guardian_custom",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_dawnbreaker_celestial_hammer_custom_nohammer",
	"abilities/dawnbreaker/dawnbreaker_celestial_hammer_custom",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier("modifier_generic_arc_lua", "modifiers/modifier_generic_arc_lua", LUA_MODIFIER_MOTION_BOTH)

dawnbreaker_solar_guardian_custom = class({})

local ULT_NAME = "dawnbreaker_solar_guardian_custom"
local RELEASE_NAME = "dawnbreaker_solar_guardian_release_custom"
local WORLD_EDGE_MARGIN = 128
local WORLD_EDGE_EPSILON = 8

local function Clamp(value, min_value, max_value)
	return math.max(min_value, math.min(max_value, value))
end

local function IsValidEntity(entity)
	return entity and not entity:IsNull()
end

local function GetSafeWorldBounds()
	return GetWorldMinX() + WORLD_EDGE_MARGIN,
		GetWorldMaxX() - WORLD_EDGE_MARGIN,
		GetWorldMinY() + WORLD_EDGE_MARGIN,
		GetWorldMaxY() - WORLD_EDGE_MARGIN
end

local function IsInsideWorldBounds(position)
	if not position then
		return false
	end

	local minX, maxX, minY, maxY = GetSafeWorldBounds()
	return position.x >= minX
		and position.x <= maxX
		and position.y >= minY
		and position.y <= maxY
end

local function ClampAlongRayToWorldBounds(origin, destination)
	local dest = Vector(destination.x, destination.y, destination.z or 0)
	if IsInsideWorldBounds(dest) then
		return GetGroundPosition(dest, nil), false
	end

	local minX, maxX, minY, maxY = GetSafeWorldBounds()
	local dx = dest.x - origin.x
	local dy = dest.y - origin.y
	local t = 1

	if dest.x > maxX and dx > 0 then
		t = math.min(t, (maxX - origin.x) / dx)
	end
	if dest.x < minX and dx < 0 then
		t = math.min(t, (minX - origin.x) / dx)
	end
	if dest.y > maxY and dy > 0 then
		t = math.min(t, (maxY - origin.y) / dy)
	end
	if dest.y < minY and dy < 0 then
		t = math.min(t, (minY - origin.y) / dy)
	end

	t = Clamp(t, 0, 1)
	local clamped = Vector(origin.x + dx * t, origin.y + dy * t, origin.z or 0)
	return GetGroundPosition(clamped, nil), true
end

local function SetGuardianRadiusControls(particle, origin, radius)
	ParticleManager:SetParticleControl(particle, 0, origin)
	ParticleManager:SetParticleControl(particle, 1, origin)
	ParticleManager:SetParticleControl(particle, 2, Vector(radius, radius, radius))
end

function dawnbreaker_solar_guardian_custom:Precache(context)
	if self:GetCaster() and self:GetCaster():IsIllusion() then
		return
	end

	PrecacheResource("particle", "particles/units/heroes/hero_dawnbreaker/dawnbreaker_solar_guardian.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_dawnbreaker/dawnbreaker_solar_guardian_landing.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_dawnbreaker/dawnbreaker_solar_guardian_aoe.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_techies/techies_blast_off_trail.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_dawnbreaker.vsndevts", context)
end

function dawnbreaker_solar_guardian_custom:GetCastRange(location, target)
	if IsClient() then
		return 0
	end
	return self:GetSpecialValueFor("max_range")
end

function dawnbreaker_solar_guardian_custom:OnUpgrade()
	if self:GetLevel() < 1 then
		self:RestoreCastLayout()
		return
	end

	local caster = self:GetCaster()
	local release = caster:FindAbilityByName(RELEASE_NAME)
	if not release then
		return
	end
	if release:GetLevel() < 1 then
		release:SetLevel(1)
	end
	if not self.tracker_active then
		release:SetActivated(false)
		self:RestoreCastLayout()
	end
end

function dawnbreaker_solar_guardian_custom:OnOwnerSpawned()
	if not IsServer() then
		return
	end

	if self.tracker_active then
		self:CancelTracker()
	end
	self.tracker_active = false
	self:RestoreCastLayout()
end

function dawnbreaker_solar_guardian_custom:RestoreCastLayout()
	if not IsServer() then
		return
	end
	if self.tracker_active then
		return
	end

	self:HideReleaseAbility()
	if self:IsHidden() then
		self:SetHidden(false)
	end
end

function dawnbreaker_solar_guardian_custom:GetLandingDistance(raw_distance)
	local min_range = self:GetSpecialValueFor("min_range")
	local max_range = self:GetSpecialValueFor("max_range")
	return Clamp(raw_distance, min_range, max_range)
end

function dawnbreaker_solar_guardian_custom:GetLandingRadius(distance)
	local min_range = self:GetSpecialValueFor("min_range")
	local max_range = self:GetSpecialValueFor("max_range")
	local min_radius = self:GetSpecialValueFor("min_radius")
	local max_radius = self:GetSpecialValueFor("max_radius")
	local grow = self:GetSpecialValueFor("radius_grow_multiplier")
	if grow < 1 then
		grow = 2.5
	end
	local t = 0
	if max_range > min_range then
		t = Clamp((distance - min_range) / (max_range - min_range) * grow, 0, 1)
	end
	local radius = min_radius + (max_radius - min_radius) * t
	if GetHeroBonusSpellAoE then
		radius = radius + GetHeroBonusSpellAoE(self:GetCaster())
	end
	return radius
end

function dawnbreaker_solar_guardian_custom:GetTrackerRadius(location)
	local origin = self.tracker_origin or self:GetCaster():GetAbsOrigin()
	local distance = self:GetLandingDistance((location - origin):Length2D())
	return self:GetLandingRadius(distance)
end

function dawnbreaker_solar_guardian_custom:GetTrackerWorldOrigin()
	if not self.tracker_active then
		return nil
	end
	if IsValidEntity(self.tracker_dummy) then
		return self.tracker_dummy:GetAbsOrigin()
	end
	return nil
end

function dawnbreaker_solar_guardian_custom:CastFilterResultLocation(location)
	if self:GetCaster():HasModifier("modifier_dawnbreaker_celestial_hammer_custom_nohammer") then
		return UF_FAIL_CUSTOM
	end
	return UF_SUCCESS
end

function dawnbreaker_solar_guardian_custom:GetCustomCastErrorLocation(location)
	if self:GetCaster():HasModifier("modifier_dawnbreaker_celestial_hammer_custom_nohammer") then
		return "#dota_hud_error_nohammer"
	end
	return ""
end

function dawnbreaker_solar_guardian_custom:OnSpellStart()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	local point = self:GetCursorPosition()
	if point == caster:GetAbsOrigin() then
		point = point + caster:GetForwardVector() * 100
	end

	local direction = point - caster:GetAbsOrigin()
	direction.z = 0
	if direction:Length2D() < 1 then
		direction = caster:GetForwardVector()
		direction.z = 0
	end
	direction = direction:Normalized()

	local speed = self:GetSpecialValueFor("tracker_speed")
	local max_range = self:GetSpecialValueFor("max_range")
	local velocity = direction * speed
	self.tracker_origin = caster:GetAbsOrigin()
	self.tracker_direction = direction
	self.tracker_active = true

	self.tracker_dummy = CreateModifierThinker(
		caster,
		self,
		"modifier_dawnbreaker_solar_guardian_custom_tracker",
		{
			dir_x = velocity.x,
			dir_y = velocity.y,
			origin_x = self.tracker_origin.x,
			origin_y = self.tracker_origin.y,
			origin_z = self.tracker_origin.z,
		},
		caster:GetAbsOrigin(),
		caster:GetTeamNumber(),
		false
	)

	self.tracker_projectile = ProjectileManager:CreateLinearProjectile({
		Ability = self,
		vSpawnOrigin = caster:GetAbsOrigin(),
		fDistance = max_range,
		fStartRadius = 0,
		fEndRadius = 0,
		Source = caster,
		bDrawsOnMinimap = true,
		bVisibleToEnemies = false,
		bHasFrontalCone = false,
		bReplaceExisting = false,
		iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_NONE,
		iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_NONE,
		iUnitTargetType = DOTA_UNIT_TARGET_NONE,
		fExpireTime = GameRules:GetGameTime() + (max_range / speed) + 2.0,
		bDeleteOnHit = false,
		vVelocity = Vector(velocity.x, velocity.y, 0),
		bProvidesVision = true,
		iVisionRadius = self:GetSpecialValueFor("tracker_vision"),
		iVisionTeamNumber = caster:GetTeamNumber(),
		ExtraData = {
			dummy = self.tracker_dummy:entindex(),
		},
	})

	self:ShowReleaseAbility()
	self:StartThrownHammer()
	caster:EmitSound("Hero_Dawnbreaker.Celestial_Hammer.Cast")
end

function dawnbreaker_solar_guardian_custom:OnProjectileThink_ExtraData(location, data)
	if not data.dummy then
		return
	end

	local dummy = EntIndexToHScript(data.dummy)
	local origin = self.tracker_origin or self:GetCaster():GetAbsOrigin()
	local clamped, hit_world_edge = ClampAlongRayToWorldBounds(origin, location)

	if IsValidEntity(dummy) then
		dummy:SetAbsOrigin(clamped)
		self:SyncThrownWeapon(dummy)
		local tracker = dummy:FindModifierByName("modifier_dawnbreaker_solar_guardian_custom_tracker")
		if tracker then
			tracker:UpdateMarkerVisuals()
		end
	end

	if not self:GetCaster():IsAlive() then
		self:CancelTracker()
		return
	end

	if hit_world_edge or (clamped - origin):Length2D() >= self:GetSpecialValueFor("max_range") - WORLD_EDGE_EPSILON then
		self:ConfirmTracker()
	end
end

function dawnbreaker_solar_guardian_custom:OnProjectileHit_ExtraData(target, location, data)
	if target then
		return false
	end
	self:ConfirmTracker()
	return true
end

function dawnbreaker_solar_guardian_custom:ShowReleaseAbility()
	local caster = self:GetCaster()
	local release = caster:FindAbilityByName(RELEASE_NAME)
	if not release then
		return
	end

	if release:GetLevel() < 1 then
		release:SetLevel(1)
	end
	release:SetActivated(true)
	if release:IsHidden() then
		caster:SwapAbilities(ULT_NAME, RELEASE_NAME, false, true)
	end
	if release:IsHidden() then
		release:SetHidden(false)
	end
	if IsServer() and not caster:HasModifier("modifier_dawnbreaker_solar_guardian_custom_tracker_active") then
		caster:AddNewModifier(caster, self, "modifier_dawnbreaker_solar_guardian_custom_tracker_active", {})
	end
end

function dawnbreaker_solar_guardian_custom:HideReleaseAbility()
	local caster = self:GetCaster()
	local release = caster:FindAbilityByName(RELEASE_NAME)
	if not release then
		return
	end

	if not release:IsHidden() then
		caster:SwapAbilities(RELEASE_NAME, ULT_NAME, false, true)
	end
	if not release:IsHidden() then
		release:SetHidden(true)
	end
	release:SetActivated(false)
	if IsServer() then
		caster:RemoveModifierByName("modifier_dawnbreaker_solar_guardian_custom_tracker_active")
	end
	if self:IsHidden() then
		self:SetHidden(false)
	end
end

function dawnbreaker_solar_guardian_custom:StopTrackerProjectile()
	if self.tracker_projectile then
		ProjectileManager:DestroyLinearProjectile(self.tracker_projectile)
		self.tracker_projectile = nil
	end
end

function dawnbreaker_solar_guardian_custom:StartThrownHammer()
	local caster = self:GetCaster()
	if not IsValidEntity(caster) then
		return
	end

	local hammer = caster:FindAbilityByName("dawnbreaker_celestial_hammer_custom")
	caster:AddNewModifier(caster, hammer or self, "modifier_dawnbreaker_celestial_hammer_custom_nohammer", {
		skip_hide_weapon = 1,
	})
	self:AttachWeaponToTracker()
end

function dawnbreaker_solar_guardian_custom:FinishThrownHammer()
	local caster = self:GetCaster()
	if IsValidEntity(caster) then
		caster:RemoveModifierByName("modifier_dawnbreaker_celestial_hammer_custom_nohammer")
	end
end

function dawnbreaker_solar_guardian_custom:AttachWeaponToTracker()
	if not IsValidEntity(self.tracker_dummy) then
		return
	end

	local caster = self:GetCaster()
	if not IsValidEntity(caster) or not caster.GetTogglableWearable then
		return
	end

	local weapon = caster:GetTogglableWearable(DOTA_LOADOUT_TYPE_WEAPON)
	if not weapon then
		return
	end

	self.thrown_weapon = weapon
	self:SyncThrownWeapon(self.tracker_dummy)
	weapon:FollowEntity(self.tracker_dummy, false)
end

function dawnbreaker_solar_guardian_custom:SyncThrownWeapon(dummy)
	if not IsValidEntity(dummy) then
		return
	end

	if self.tracker_direction then
		dummy:SetForwardVector(self.tracker_direction)
	end

	local weapon = self.thrown_weapon
	if not weapon or (weapon.IsNull and weapon:IsNull()) then
		return
	end

	weapon:SetAbsOrigin(dummy:GetAbsOrigin())
	if self.tracker_direction then
		local angles = VectorToAngles(self.tracker_direction)
		weapon:SetAbsAngles(angles.x, angles.y, angles.z)
	end
end

function dawnbreaker_solar_guardian_custom:RestoreThrownWeapon()
	local weapon = self.thrown_weapon
	self.thrown_weapon = nil
	if not weapon or (weapon.IsNull and weapon:IsNull()) then
		return
	end

	local caster = self:GetCaster()
	if not IsValidEntity(caster) then
		return
	end

	weapon:FollowEntity(caster, true)
	if weapon.RemoveEffects then
		weapon:RemoveEffects(EF_NODRAW)
	end
end

function dawnbreaker_solar_guardian_custom:DestroyTrackerDummy()
	self:RestoreThrownWeapon()
	if IsValidEntity(self.tracker_dummy) then
		local modifier = self.tracker_dummy:FindModifierByName("modifier_dawnbreaker_solar_guardian_custom_tracker")
		if modifier then
			modifier.skip_cancel = true
			modifier:Destroy()
		elseif not self.tracker_dummy:IsNull() then
			UTIL_Remove(self.tracker_dummy)
		end
	end
	self.tracker_dummy = nil
end

function dawnbreaker_solar_guardian_custom:CancelTracker()
	if not self.tracker_active then
		return
	end
	self.tracker_active = false
	self:StopTrackerProjectile()
	self:DestroyTrackerDummy()
	self:FinishThrownHammer()
	self:HideReleaseAbility()
end

function dawnbreaker_solar_guardian_custom:ConfirmTracker()
	if not self.tracker_active then
		return
	end
	self.tracker_active = false

	local caster = self:GetCaster()
	local origin = self.tracker_origin or caster:GetAbsOrigin()
	local location = origin
	if IsValidEntity(self.tracker_dummy) then
		location = self.tracker_dummy:GetAbsOrigin()
	end

	self:StopTrackerProjectile()
	self:DestroyTrackerDummy()
	self:FinishThrownHammer()
	self:HideReleaseAbility()

	if not caster:IsAlive() then
		return
	end

	location = ClampAlongRayToWorldBounds(origin, location)

	local hammer_offset = location - origin
	hammer_offset.z = 0
	local radius = self:GetLandingRadius(self:GetLandingDistance(hammer_offset:Length2D()))

	local leap_offset = location - caster:GetAbsOrigin()
	leap_offset.z = 0
	local distance = leap_offset:Length2D()
	local direction = self.tracker_direction
	if distance >= 1 then
		direction = leap_offset:Normalized()
	elseif not direction then
		direction = caster:GetForwardVector()
		direction.z = 0
		direction = direction:Normalized()
	end

	self:LeapTo(location, direction, distance, radius)
end

function dawnbreaker_solar_guardian_custom:LeapTo(destination, direction, distance, radius)
	local caster = self:GetCaster()
	local duration = self:GetSpecialValueFor("leap_duration")
	local height = self:GetSpecialValueFor("leap_height")

	caster:AddNewModifier(caster, self, "modifier_dawnbreaker_solar_guardian_custom_leap", {
		duration = duration,
		radius = radius,
	})

	local arc = caster:AddNewModifier(caster, self, "modifier_generic_arc_lua", {
		dir_x = direction.x,
		dir_y = direction.y,
		duration = duration,
		distance = distance,
		height = height,
		fix_end = false,
		isStun = 0,
		isForward = 1,
		activity = ACT_DOTA_CAST_ABILITY_4,
	})

	caster:EmitSound("Hero_Dawnbreaker.Solar_Guardian.Cast")
	caster:StartGesture(ACT_DOTA_CAST_ABILITY_4)

	if arc and arc.SetEndCallback then
		arc:SetEndCallback(function(interrupted)
			local leap = caster:FindModifierByName("modifier_dawnbreaker_solar_guardian_custom_leap")
			if leap then
				leap.interrupted = interrupted
				leap:Destroy()
			end
			caster:FadeGesture(ACT_DOTA_CAST_ABILITY_4)
		end)
	end
end

modifier_dawnbreaker_solar_guardian_custom_tracker_active = class({})

function modifier_dawnbreaker_solar_guardian_custom_tracker_active:IsHidden()
	return true
end

function modifier_dawnbreaker_solar_guardian_custom_tracker_active:IsPurgable()
	return false
end

function modifier_dawnbreaker_solar_guardian_custom_tracker_active:RemoveOnDeath()
	return true
end

dawnbreaker_solar_guardian_release_custom = class({})

function dawnbreaker_solar_guardian_release_custom:IsStealable()
	return false
end

function dawnbreaker_solar_guardian_release_custom:ProcsMagicStick()
	return false
end

function dawnbreaker_solar_guardian_release_custom:OnSpellStart()
	if not IsServer() then
		return
	end

	local ult = self:GetCaster():FindAbilityByName(ULT_NAME)
	if ult then
		ult:ConfirmTracker()
	end
end

modifier_dawnbreaker_solar_guardian_custom_tracker = class({})

function modifier_dawnbreaker_solar_guardian_custom_tracker:IsHidden()
	return true
end

function modifier_dawnbreaker_solar_guardian_custom_tracker:IsPurgable()
	return false
end

function modifier_dawnbreaker_solar_guardian_custom_tracker:OnCreated(kv)
	if not IsServer() then
		return
	end

	self.origin = Vector(kv.origin_x or 0, kv.origin_y or 0, kv.origin_z or 0)
	if self.origin:Length2D() < 1 then
		self.origin = self:GetParent():GetAbsOrigin()
	end

	local parent = self:GetParent()
	local velocity = Vector(kv.dir_x or 0, kv.dir_y or 0, 0)
	if velocity:Length2D() > 0 then
		parent:SetForwardVector(velocity:Normalized())
	end

	parent:EmitSound("Hero_Dawnbreaker.Celestial_Hammer.Projectile")
	self:StartIntervalThink(0.03)
	self:OnIntervalThink()
end

function modifier_dawnbreaker_solar_guardian_custom_tracker:DestroyMarker()
	if not self.marker then
		return
	end
	ParticleManager:DestroyParticle(self.marker, false)
	ParticleManager:ReleaseParticleIndex(self.marker)
	self.marker = nil
end

function modifier_dawnbreaker_solar_guardian_custom_tracker:GetRadiusForLocation(location)
	local ability = self:GetAbility()
	if not ability then
		return 0
	end

	local offset = location - self.origin
	offset.z = 0
	return ability:GetLandingRadius(ability:GetLandingDistance(offset:Length2D()))
end

function modifier_dawnbreaker_solar_guardian_custom_tracker:UpdateMarkerVisuals()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	local location = GetGroundPosition(parent:GetAbsOrigin(), parent)
	local radius = self:GetRadiusForLocation(location)
	local last_radius = self.marker_radius or 0
	if not self.marker or math.abs(radius - last_radius) >= 8 then
		self:DestroyMarker()
		local caster = self:GetCaster()
		self.marker = ParticleManager:CreateParticleForTeam(
			"particles/units/heroes/hero_dawnbreaker/dawnbreaker_solar_guardian_aoe.vpcf",
			PATTACH_WORLDORIGIN,
			parent,
			caster:GetTeamNumber()
		)
		self.marker_radius = radius
	end

	SetGuardianRadiusControls(self.marker, location, radius)
end

function modifier_dawnbreaker_solar_guardian_custom_tracker:OnIntervalThink()
	self:UpdateMarkerVisuals()
end

function modifier_dawnbreaker_solar_guardian_custom_tracker:OnDestroy()
	if not IsServer() then
		return
	end

	local ability = self:GetAbility()
	self:GetParent():StopSound("Hero_Dawnbreaker.Celestial_Hammer.Projectile")
	self:DestroyMarker()
	if ability and ability.RestoreThrownWeapon then
		ability:RestoreThrownWeapon()
	end
	if ability and ability.tracker_active and not self.skip_cancel then
		ability:CancelTracker()
	end
	UTIL_Remove(self:GetParent())
end

modifier_dawnbreaker_solar_guardian_custom_leap = class({})

function modifier_dawnbreaker_solar_guardian_custom_leap:IsHidden()
	return true
end

function modifier_dawnbreaker_solar_guardian_custom_leap:IsPurgable()
	return false
end

function modifier_dawnbreaker_solar_guardian_custom_leap:OnCreated(kv)
	if not IsServer() then
		return
	end
	self.radius = tonumber(kv.radius) or self:GetAbility():GetSpecialValueFor("min_radius")
	local parent = self:GetParent()
	local trail = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_techies/techies_blast_off_trail.vpcf",
		PATTACH_ABSORIGIN_FOLLOW,
		parent
	)
	ParticleManager:SetParticleControlEnt(
		trail,
		1,
		parent,
		PATTACH_POINT_FOLLOW,
		"attach_hitloc",
		parent:GetAbsOrigin(),
		true
	)
	self:AddParticle(trail, false, false, -1, false, false)
end

function modifier_dawnbreaker_solar_guardian_custom_leap:OnDestroy()
	if not IsServer() then
		return
	end
	if self.interrupted then
		return
	end

	local ability = self:GetAbility()
	local caster = self:GetCaster()
	caster:FadeGesture(ACT_DOTA_CAST_ABILITY_4)
	caster:StartGesture(ACT_DOTA_OVERRIDE_ABILITY_4)
	local origin = GetGroundPosition(caster:GetAbsOrigin(), caster)
	local radius = self.radius
	if ability and ability.GetTrackerRadius then
		radius = ability:GetTrackerRadius(origin)
	end
	local damage = ability:GetSpecialValueFor("damage")
	local stun = ability:GetSpecialValueFor("stun_duration")

	FindClearSpaceForUnit(caster, origin, true)
	GridNav:DestroyTreesAroundPoint(origin, radius, true)
	caster:EmitSound("Hero_Dawnbreaker.Solar_Guardian.Impact")

	local landing = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_dawnbreaker/dawnbreaker_solar_guardian_landing.vpcf",
		PATTACH_WORLDORIGIN,
		caster
	)
	SetGuardianRadiusControls(landing, origin, radius)
	ParticleManager:ReleaseParticleIndex(landing)

	local enemies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		origin,
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)
	for _, enemy in ipairs(enemies) do
		if not enemy:IsInvulnerable() then
			ApplyDamage({
				victim = enemy,
				attacker = caster,
				damage = damage,
				damage_type = ability:GetAbilityDamageType(),
				ability = ability,
			})
			if not enemy:IsMagicImmune() then
				enemy:AddNewModifier(caster, ability, "modifier_stunned", {
					duration = stun * (1 - enemy:GetStatusResistance()),
				})
			end
		end
	end
end

function modifier_dawnbreaker_solar_guardian_custom_leap:CheckState()
	return {
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_STUNNED] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_FLYING_FOR_PATHING_PURPOSES_ONLY] = true,
	}
end

function modifier_dawnbreaker_solar_guardian_custom_leap:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_OVERRIDE_ANIMATION,
	}
end

function modifier_dawnbreaker_solar_guardian_custom_leap:GetOverrideAnimation()
	return ACT_DOTA_CAST_ABILITY_4
end
