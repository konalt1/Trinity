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
LinkLuaModifier("modifier_generic_arc_lua", "modifiers/modifier_generic_arc_lua", LUA_MODIFIER_MOTION_BOTH)

dawnbreaker_solar_guardian_custom = class({})

local ULT_NAME = "dawnbreaker_solar_guardian_custom"
local RELEASE_NAME = "dawnbreaker_solar_guardian_release_custom"

local function Clamp(value, min_value, max_value)
	return math.max(min_value, math.min(max_value, value))
end

local function IsValidEntity(entity)
	return entity and not entity:IsNull()
end

function dawnbreaker_solar_guardian_custom:Precache(context)
	if self:GetCaster() and self:GetCaster():IsIllusion() then
		return
	end

	PrecacheResource("particle", "particles/units/heroes/hero_dawnbreaker/dawnbreaker_solar_guardian.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_dawnbreaker/dawnbreaker_solar_guardian_landing.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_dawnbreaker/dawnbreaker_solar_guardian_aoe.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_dawnbreaker/dawnbreaker_celestial_hammer_projectile.vpcf", context)
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
	local t = 0
	if max_range > min_range then
		t = Clamp((distance - min_range) / (max_range - min_range), 0, 1)
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
	caster:EmitSound("Hero_Dawnbreaker.Celestial_Hammer.Cast")
end

function dawnbreaker_solar_guardian_custom:OnProjectileThink_ExtraData(location, data)
	if not data.dummy then
		return
	end

	local dummy = EntIndexToHScript(data.dummy)
	if IsValidEntity(dummy) then
		dummy:SetAbsOrigin(location)
		local tracker = dummy:FindModifierByName("modifier_dawnbreaker_solar_guardian_custom_tracker")
		if tracker then
			tracker:UpdateMarkerVisuals()
		end
	end

	if not self:GetCaster():IsAlive() then
		self:CancelTracker()
		return
	end

	local origin = self.tracker_origin or self:GetCaster():GetAbsOrigin()
	if (location - origin):Length2D() >= self:GetSpecialValueFor("max_range") - 8 then
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

function dawnbreaker_solar_guardian_custom:DestroyTrackerDummy()
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
	self:HideReleaseAbility()

	if not caster:IsAlive() then
		return
	end

	local offset = location - origin
	offset.z = 0
	local direction = self.tracker_direction
	if offset:Length2D() >= 1 then
		direction = offset:Normalized()
	elseif not direction then
		direction = caster:GetForwardVector()
		direction.z = 0
		direction = direction:Normalized()
	end

	local distance = self:GetLandingDistance(offset:Length2D())
	local destination = GetGroundPosition(origin + direction * distance, caster)
	local radius = self:GetLandingRadius(distance)
	self:LeapTo(destination, direction, distance, radius)
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
	local caster = self:GetCaster()
	local team = caster:GetTeamNumber()
	local velocity = Vector(kv.dir_x or 0, kv.dir_y or 0, 0)

	local trail = ParticleManager:CreateParticleForTeam(
		"particles/units/heroes/hero_dawnbreaker/dawnbreaker_celestial_hammer_projectile.vpcf",
		PATTACH_ABSORIGIN_FOLLOW,
		parent,
		team
	)
	ParticleManager:SetParticleControl(trail, 1, velocity)
	ParticleManager:SetParticleControl(trail, 4, Vector(1, 0, 0))
	self:AddParticle(trail, false, false, -1, false, false)

	self.marker = ParticleManager:CreateParticleForTeam(
		"particles/units/heroes/hero_dawnbreaker/dawnbreaker_solar_guardian_aoe.vpcf",
		PATTACH_WORLDORIGIN,
		nil,
		team
	)
	self:AddParticle(self.marker, false, false, -1, false, false)
	parent:EmitSound("Hero_Dawnbreaker.Celestial_Hammer.Projectile")
	self:StartIntervalThink(0.03)
	self:OnIntervalThink()
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
	if not IsServer() or not self.marker then
		return
	end

	local parent = self:GetParent()
	local location = GetGroundPosition(parent:GetAbsOrigin(), parent)
	local radius = self:GetRadiusForLocation(location)
	local radius_cp = Vector(radius, radius, radius)

	ParticleManager:SetParticleControl(self.marker, 0, location)
	ParticleManager:SetParticleControl(self.marker, 1, location)
	ParticleManager:SetParticleControl(self.marker, 2, radius_cp)
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
	self.radius = kv.radius or self:GetAbility():GetSpecialValueFor("min_radius")
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
	ParticleManager:SetParticleControl(landing, 0, origin)
	ParticleManager:SetParticleControl(landing, 1, origin)
	ParticleManager:SetParticleControl(landing, 2, Vector(radius, radius, radius))
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
