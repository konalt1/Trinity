LinkLuaModifier(
	"modifier_antimage_dodge_trinity",
	"abilities/antimage/antimage_dodge_trinity",
	LUA_MODIFIER_MOTION_NONE
)

local PARTICLE_TRAIL = "particles/units/heroes/hero_void_spirit/astral_step/void_spirit_astral_step.vpcf"
local PARTICLE_IMPACT = "particles/units/heroes/hero_void_spirit/astral_step/void_spirit_astral_step_impact.vpcf"
local SOUND_FILE_AM = "soundevents/game_sounds_heroes/game_sounds_antimage.vsndevts"
local SOUND_FILE_VOID = "soundevents/game_sounds_heroes/game_sounds_void_spirit.vsndevts"
local DASH_DURATION = 0.14

local function IsValidHandle(handle)
	return handle and (not handle.IsNull or not handle:IsNull())
end

local function EaseOutCubic(t)
	local u = 1 - t
	return 1 - u * u * u
end

antimage_dodge_trinity = class({})

function antimage_dodge_trinity:Precache(context)
	if self:GetCaster() and self:GetCaster():IsIllusion() then
		return
	end

	PrecacheResource("soundfile", SOUND_FILE_AM, context)
	PrecacheResource("soundfile", SOUND_FILE_VOID, context)
	PrecacheResource("particle", PARTICLE_TRAIL, context)
	PrecacheResource("particle", PARTICLE_IMPACT, context)
end

function antimage_dodge_trinity:GetCastRange(_, _)
	return self:GetSpecialValueFor("range")
end

function antimage_dodge_trinity:OnSpellStart()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	if not IsValidHandle(caster) then
		return
	end

	local origin = caster:GetAbsOrigin()
	local cursor = self:GetCursorPosition()
	local offset = cursor - origin
	offset.z = 0

	local direction
	if offset:Length2D() < 0.01 then
		direction = caster:GetForwardVector()
		direction.z = 0
		if direction:Length2D() < 0.01 then
			direction = Vector(1, 0, 0)
		else
			direction = direction:Normalized()
		end
	else
		direction = offset:Normalized()
	end

	local max_range = self:GetSpecialValueFor("range")
	local distance = math.min(max_range, offset:Length2D())
	local destination = GetGroundPosition(origin + direction * distance, caster)
	local duration = DASH_DURATION

	local trail = ParticleManager:CreateParticle(PARTICLE_TRAIL, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(trail, 0, origin)
	ParticleManager:SetParticleControl(trail, 1, destination)
	ParticleManager:ReleaseParticleIndex(trail)

	caster:EmitSound("Hero_Antimage.Blink_out")
	ProjectileManager:ProjectileDodge(caster)

	if caster.InterruptMotionControllers then
		caster:InterruptMotionControllers(true)
	end

	caster:FaceTowards(destination)
	caster:StartGesture(ACT_DOTA_CAST_ABILITY_2)

	caster:AddNewModifier(caster, self, "modifier_antimage_dodge_trinity", {
		duration = duration,
		origin_x = origin.x,
		origin_y = origin.y,
		origin_z = origin.z,
		dest_x = destination.x,
		dest_y = destination.y,
		dest_z = destination.z,
	})
end

modifier_antimage_dodge_trinity = class({})

function modifier_antimage_dodge_trinity:IsHidden()
	return true
end

function modifier_antimage_dodge_trinity:IsPurgable()
	return false
end

function modifier_antimage_dodge_trinity:GetAttributes()
	return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end

function modifier_antimage_dodge_trinity:OnCreated(kv)
	kv = kv or {}
	self.origin = Vector(tonumber(kv.origin_x) or 0, tonumber(kv.origin_y) or 0, tonumber(kv.origin_z) or 0)
	self.destination = Vector(tonumber(kv.dest_x) or 0, tonumber(kv.dest_y) or 0, tonumber(kv.dest_z) or 0)

	if not IsServer() then
		return
	end

	self:StartIntervalThink(1 / 120)
	self:OnIntervalThink()
end

function modifier_antimage_dodge_trinity:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_DISABLE_TURNING,
		MODIFIER_PROPERTY_OVERRIDE_ANIMATION,
	}
end

function modifier_antimage_dodge_trinity:GetModifierDisableTurning()
	return 1
end

function modifier_antimage_dodge_trinity:GetOverrideAnimation()
	return ACT_DOTA_RUN
end

function modifier_antimage_dodge_trinity:CheckState()
	return {
		[MODIFIER_STATE_COMMAND_RESTRICTED] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_FLYING_FOR_PATHING_PURPOSES_ONLY] = true,
	}
end

function modifier_antimage_dodge_trinity:OnIntervalThink()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if not IsValidHandle(parent) then
		self:Destroy()
		return
	end

	local duration = math.max(0.05, self:GetDuration())
	local t = math.min(1, math.max(0, self:GetElapsedTime() / duration))
	local eased = EaseOutCubic(t)
	local origin = self.origin or parent:GetAbsOrigin()
	local dest = self.destination or origin
	local pos = origin + (dest - origin) * eased
	pos.z = GetGroundHeight(pos, parent)
	parent:SetAbsOrigin(pos)
end

function modifier_antimage_dodge_trinity:OnDestroy()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if not IsValidHandle(parent) then
		return
	end

	local dest = self.destination or parent:GetAbsOrigin()
	dest = GetGroundPosition(dest, parent)
	parent:SetAbsOrigin(dest)

	if not parent:IsAlive() then
		return
	end

	FindClearSpaceForUnit(parent, dest, false)

	local impact = ParticleManager:CreateParticle(PARTICLE_IMPACT, PATTACH_ABSORIGIN_FOLLOW, parent)
	ParticleManager:ReleaseParticleIndex(impact)

	parent:EmitSound("Hero_Antimage.Blink_in")
end
