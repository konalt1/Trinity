LinkLuaModifier(
    "modifier_tinker_march_of_the_machines_custom_thinker",
    "abilities/tinker/tinker_march_of_the_machines_custom",
    LUA_MODIFIER_MOTION_NONE
)

tinker_march_of_the_machines_custom = class({})

_G.TINKER_MARCH_DEBUG_ENABLED = _G.TINKER_MARCH_DEBUG_ENABLED or false

if IsServer() and not _G.TINKER_MARCH_DEBUG_COMMAND_REGISTERED then
    Convars:RegisterCommand("tinker_march_debug", function(_, value)
        if value == nil or value == "" then
            _G.TINKER_MARCH_DEBUG_ENABLED = not _G.TINKER_MARCH_DEBUG_ENABLED
        else
            local normalized = string.lower(tostring(value))
            _G.TINKER_MARCH_DEBUG_ENABLED = normalized == "1" or normalized == "true" or normalized == "on"
        end

        local state = _G.TINKER_MARCH_DEBUG_ENABLED and "ON" or "OFF"
        print("[TinkerMarch] Debug " .. state .. " (yellow=caster, cyan=cursor, magenta=spawn, orange=spawn line, green=travel)")
    end, "Toggle March of the Machines debug: tinker_march_debug [0|1]", FCVAR_CHEAT)

    _G.TINKER_MARCH_DEBUG_COMMAND_REGISTERED = true
end

local function IsValidUnit(unit)
    return unit and not unit:IsNull()
end

local function FormatVector(vector)
    if not vector then
        return "nil"
    end

    return string.format("(%.1f, %.1f, %.1f)", vector.x, vector.y, vector.z)
end

local function ResolveMarchGeometry(ability, caster)
    local origin = caster:GetAbsOrigin()
    local cursor = ability:GetCursorPosition()
    local facing = caster:GetForwardVector()
    local delta = cursor - origin
    delta.z = 0

    local cursor_dist = delta:Length2D()
    local used_facing_fallback = cursor_dist < 1
    local direction

    if used_facing_fallback then
        direction = Vector(facing.x, facing.y, 0)
        if direction:Length2D() < 0.01 then
            direction = Vector(0, 1, 0)
        else
            direction = direction:Normalized()
        end
    else
        direction = delta:Normalized()
    end

    local behind = ability:GetSpecialValueFor("spawn_behind_distance")
    local spawn_origin = GetGroundPosition(origin - direction * behind, nil)
    local right = Vector(-direction.y, direction.x, 0)

    return {
        caster_origin = origin,
        cursor = cursor,
        cursor_dist = cursor_dist,
        facing = facing,
        used_facing_fallback = used_facing_fallback,
        direction = direction,
        spawn_origin = spawn_origin,
        right = right,
        behind = behind,
        spawn_area = ability:GetSpecialValueFor("spawn_area"),
        distance = ability:GetSpecialValueFor("distance"),
        duration = ability:GetSpecialValueFor("duration"),
        speed = ability:GetSpecialValueFor("speed"),
    }
end

local function DrawMarchDebug(geometry, thinker_origin, kv_direction)
    local duration = (geometry.duration or 6) + (geometry.distance / math.max(1, geometry.speed)) + 1
    local half = geometry.spawn_area * 0.5
    local spawn_left = GetGroundPosition(geometry.spawn_origin - geometry.right * half, nil)
    local spawn_right = GetGroundPosition(geometry.spawn_origin + geometry.right * half, nil)
    local travel = geometry.direction * geometry.distance
    local end_center = GetGroundPosition(geometry.spawn_origin + travel, nil)
    local end_left = GetGroundPosition(spawn_left + travel, nil)
    local end_right = GetGroundPosition(spawn_right + travel, nil)

    DebugDrawCircle(geometry.caster_origin, Vector(255, 220, 80), 255, 40, false, duration)
    DebugDrawCircle(geometry.cursor, Vector(80, 220, 255), 255, 48, false, duration)
    DebugDrawCircle(geometry.spawn_origin, Vector(255, 80, 220), 255, 48, false, duration)

    DebugDrawLine(geometry.caster_origin, geometry.cursor, 80, 160, 255, false, duration)
    DebugDrawLine(geometry.caster_origin, geometry.spawn_origin, 255, 80, 80, false, duration)
    DebugDrawLine(spawn_left, spawn_right, 255, 160, 40, false, duration)
    DebugDrawLine(geometry.spawn_origin, end_center, 80, 255, 120, false, duration)
    DebugDrawLine(spawn_left, end_left, 80, 255, 120, false, duration)
    DebugDrawLine(spawn_right, end_right, 80, 255, 120, false, duration)
    DebugDrawLine(end_left, end_right, 80, 255, 120, false, duration)

    if thinker_origin then
        DebugDrawCircle(thinker_origin, Vector(255, 255, 255), 255, 24, false, duration)
    end

    if kv_direction then
        local kv_end = GetGroundPosition(geometry.spawn_origin + kv_direction * 400, nil)
        DebugDrawLine(geometry.spawn_origin, kv_end, 255, 255, 255, false, duration)
    end
end

function tinker_march_of_the_machines_custom:Precache(context)
    PrecacheResource("particle", "particles/units/heroes/hero_tinker/tinker_machine.vpcf", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_tinker.vsndevts", context)
end

function tinker_march_of_the_machines_custom:GetAOERadius()
    return self:GetSpecialValueFor("spawn_area")
end

function tinker_march_of_the_machines_custom:GetMindScaledDamage()
    local caster = self:GetCaster()
    local base = self:GetSpecialValueFor("damage")
    local multiplier = self:GetSpecialValueFor("mind_power_multiplier")
    local mind_power = GetHeroMindPower and (GetHeroMindPower(caster) or 0) or 0
    return math.max(0, base + mind_power * multiplier)
end

function tinker_march_of_the_machines_custom:OnSpellStart()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    local geometry = ResolveMarchGeometry(self, caster)
    self._march_debug_geometry = geometry

    if _G.TINKER_MARCH_DEBUG_ENABLED then
        print(string.format(
            "[TinkerMarch] cast caster=%s cursor=%s dist=%.1f facing=%s fallback=%s dir=%s spawn=%s behind=%.0f",
            FormatVector(geometry.caster_origin),
            FormatVector(geometry.cursor),
            geometry.cursor_dist,
            FormatVector(geometry.facing),
            tostring(geometry.used_facing_fallback),
            FormatVector(geometry.direction),
            FormatVector(geometry.spawn_origin),
            geometry.behind
        ))
        DrawMarchDebug(geometry)
    end

    CreateModifierThinker(
        caster,
        self,
        "modifier_tinker_march_of_the_machines_custom_thinker",
        {
            duration = geometry.duration,
            dir_x = geometry.direction.x,
            dir_y = geometry.direction.y,
        },
        geometry.spawn_origin,
        caster:GetTeamNumber(),
        false
    )

    caster:EmitSound("Hero_Tinker.March_of_the_Machines.Cast")
end

function tinker_march_of_the_machines_custom:OnProjectileHit(target, location)
    if not IsServer() then
        return true
    end

    local explode_origin = location
    if IsValidUnit(target) then
        explode_origin = target:GetAbsOrigin()
    end

    if explode_origin then
        self:DetonateRobot(explode_origin)
    end

    return true
end

function tinker_march_of_the_machines_custom:DetonateRobot(origin)
    local caster = self:GetCaster()
    if not IsValidUnit(caster) then
        return
    end

    local damage = self:GetMindScaledDamage()
    local units = FindUnitsInRadius(
        caster:GetTeamNumber(),
        origin,
        nil,
        self:GetSpecialValueFor("radius"),
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    for _, unit in ipairs(units) do
        ApplyDamage({
            attacker = caster,
            victim = unit,
            damage = damage,
            damage_type = self:GetAbilityDamageType(),
            ability = self,
        })
    end
end

modifier_tinker_march_of_the_machines_custom_thinker = class({})

function modifier_tinker_march_of_the_machines_custom_thinker:IsHidden()
    return true
end

function modifier_tinker_march_of_the_machines_custom_thinker:IsPurgable()
    return false
end

function modifier_tinker_march_of_the_machines_custom_thinker:OnCreated(kv)
    if not IsServer() then
        return
    end

    local ability = self:GetAbility()
    if not ability or ability:IsNull() then
        self:Destroy()
        return
    end

    local kv_x = tonumber(kv and kv.dir_x) or 0
    local kv_y = tonumber(kv and kv.dir_y) or 0
    local direction = Vector(kv_x, kv_y, 0)
    if direction:Length2D() < 0.01 then
        direction = Vector(0, 1, 0)
    else
        direction = direction:Normalized()
    end

    self.direction = direction
    self.right = Vector(-direction.y, direction.x, 0)
    self.origin = self:GetParent():GetAbsOrigin()
    self.spawn_area = ability:GetSpecialValueFor("spawn_area")
    self.distance = ability:GetSpecialValueFor("distance")
    self.speed = ability:GetSpecialValueFor("speed")
    self.collision_radius = ability:GetSpecialValueFor("collision_radius")
    self.machines_per_sec = math.max(1, ability:GetSpecialValueFor("machines_per_sec"))

    if _G.TINKER_MARCH_DEBUG_ENABLED then
        local geometry = ability._march_debug_geometry
        local expected = geometry and geometry.direction
        local mismatch = expected and (expected - direction):Length2D() > 0.05
        print(string.format(
            "[TinkerMarch] thinker origin=%s kv_dir=(%.3f, %.3f) used_dir=%s expected_dir=%s mismatch=%s kv_fallback=%s",
            FormatVector(self.origin),
            kv_x,
            kv_y,
            FormatVector(direction),
            expected and FormatVector(expected) or "nil",
            tostring(mismatch == true),
            tostring(kv_x == 0 and kv_y == 0)
        ))

        if geometry then
            DrawMarchDebug(geometry, self.origin, direction)
        end
    end

    self:GetParent():EmitSound("Hero_Tinker.March_of_the_Machines")
    self:StartIntervalThink(1 / self.machines_per_sec)
    self:OnIntervalThink()
end

function modifier_tinker_march_of_the_machines_custom_thinker:OnIntervalThink()
    if not IsServer() then
        return
    end

    local ability = self:GetAbility()
    local caster = self:GetCaster()
    if not ability or ability:IsNull() or not IsValidUnit(caster) then
        self:Destroy()
        return
    end

    local offset = (RandomFloat(0, 1) - 0.5) * self.spawn_area
    local spawn_origin = GetGroundPosition(self.origin + self.right * offset, nil)

    ProjectileManager:CreateLinearProjectile({
        Ability = ability,
        EffectName = "particles/units/heroes/hero_tinker/tinker_machine.vpcf",
        vSpawnOrigin = spawn_origin,
        fDistance = self.distance,
        fStartRadius = self.collision_radius,
        fEndRadius = self.collision_radius,
        Source = caster,
        bHasFrontalCone = false,
        bReplaceExisting = false,
        iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
        iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_NONE,
        iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        bDeleteOnHit = true,
        vVelocity = self.direction * self.speed,
        bProvidesVision = false,
        fExpireTime = GameRules:GetGameTime() + self.distance / self.speed + 0.1,
    })
end

function modifier_tinker_march_of_the_machines_custom_thinker:OnDestroy()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if IsValidUnit(parent) then
        parent:StopSound("Hero_Tinker.March_of_the_Machines")
    end
end
