require("modifiers/modifier_generic_arc_lua")
require("map_modifications/Bosses/mortimer_level_scaling")

LinkLuaModifier(
    "modifier_mortimer_gobble_up_swallowed",
    "map_modifications/Bosses/mortimer_gobble_up",
    LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
    "modifier_mortimer_gobble_up_caster",
    "map_modifications/Bosses/mortimer_gobble_up",
    LUA_MODIFIER_MOTION_NONE
)

mortimer_gobble_up = class({})

local RANDOM_POINT_ATTEMPTS = 64
local WORLD_EDGE_MARGIN = 512
local GOBBLE_IGNORED_UNITS = {
    ["npc_guardian_good"] = true,
    ["npc_guardian_bad"] = true,
}

local function IsValidLivingUnit(unit)
    return unit and not unit:IsNull() and unit:IsAlive()
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

local function IsValidLandingPosition(position)
    if not position or not GridNav or not IsInsideWorldBounds(position) then
        return false
    end
    if GridNav.IsTraversable and not GridNav:IsTraversable(position) then
        return false
    end
    if GridNav.IsBlocked and GridNav:IsBlocked(position) then
        return false
    end

    return true
end

local function GetRandomThroneDirection(origin)
    local thrones = {}
    local throne = Entities:FindByClassname(nil, "npc_dota_fort")

    while throne do
        if IsValidEntity(throne) then
            thrones[#thrones + 1] = throne
        end
        throne = Entities:FindByClassname(throne, "npc_dota_fort")
    end

    if #thrones > 0 then
        local targetThrone = thrones[RandomInt(1, #thrones)]
        local direction = targetThrone:GetAbsOrigin() - origin
        direction.z = 0
        if direction:Length2D() > 0 then
            return direction:Normalized()
        end
    end

    local angle = RandomFloat(0, math.pi * 2)
    return Vector(math.cos(angle), math.sin(angle), 0)
end

function mortimer_gobble_up:Precache(context)
    PrecacheResource("particle", "particles/ui_mouseactions/range_finder_aoe.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_snapfire/snapfire_flaming_creep.vpcf", context)
end

function mortimer_gobble_up:GetBehavior()
    return DOTA_ABILITY_BEHAVIOR_NO_TARGET + DOTA_ABILITY_BEHAVIOR_AOE
end

function mortimer_gobble_up:GetAOERadius()
    return self:GetSpecialValueFor("effect_radius")
end

function mortimer_gobble_up:GetCastRange(location, target)
    return 0
end

function mortimer_gobble_up:GetCastAnimation()
    return ACT_DOTA_CAST_ABILITY_1
end

function mortimer_gobble_up:IsSequenceActive()
    return self.sequenceActive == true
end

function mortimer_gobble_up:IsValidGobbleTarget(target)
    local caster = self:GetCaster()
    return IsValidLivingUnit(target)
        and target ~= caster
        and caster:CanEntityBeSeenByMyTeam(target)
        and not GOBBLE_IGNORED_UNITS[target:GetUnitName()]
        and not target:IsAncient()
        and not target:HasModifier("modifier_mortimer_gobble_up_swallowed")
        and target:GetUnitName() ~= "npc_mortimer_boss_finale"
end

function mortimer_gobble_up:CreateWarningCircle(position, radius, duration)
    local particle = ParticleManager:CreateParticle(
        "particles/ui_mouseactions/range_finder_aoe.vpcf",
        PATTACH_WORLDORIGIN,
        self:GetCaster()
    )
    ParticleManager:SetParticleControl(particle, 0, position)
    ParticleManager:SetParticleControl(particle, 1, Vector(radius, radius, radius))
    ParticleManager:SetParticleControl(particle, 2, position)
    ParticleManager:SetParticleControl(particle, 3, Vector(255, 0, 0))

    Timers:CreateTimer(duration, function()
        ParticleManager:DestroyParticle(particle, false)
        ParticleManager:ReleaseParticleIndex(particle)
    end)
end

function mortimer_gobble_up:FindTargets(position, radius)
    local caster = self:GetCaster()
    local nearbyUnits = FindUnitsInRadius(
        caster:GetTeamNumber(),
        position,
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_BOTH,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        FIND_ANY_ORDER,
        false
    )
    local targets = {}

    for _, unit in ipairs(nearbyUnits) do
        if self:IsValidGobbleTarget(unit) then
            targets[#targets + 1] = unit
        end
    end

    return targets
end

function mortimer_gobble_up:GetThroneDirectedSpitPosition()
    local caster = self:GetCaster()
    local origin = caster:GetAbsOrigin()
    local minDistance = self:GetSpecialValueFor("spit_min_distance")
    local maxDistance = MortimerLevelScaling:GetGobbleSpitMaxDistance(self)
    local direction = GetRandomThroneDirection(origin)

    for _ = 1, RANDOM_POINT_ATTEMPTS do
        local distance = RandomFloat(minDistance, maxDistance)
        local candidate = GetGroundPosition(origin + direction * distance, caster)

        if IsValidLandingPosition(candidate) then
            return candidate
        end
    end

    return GetGroundPosition(origin, caster)
end

function mortimer_gobble_up:OnSpellStart()
    if not IsServer() or self:IsSequenceActive() then
        return
    end

    local caster = self:GetCaster()
    local origin = caster:GetAbsOrigin()
    local forward = caster:GetForwardVector()
    forward.z = 0
    if forward:Length2D() > 0 then
        forward = forward:Normalized()
    else
        forward = Vector(1, 0, 0)
    end

    local offset = self:GetSpecialValueFor("effect_offset")
    local position = GetGroundPosition(origin + forward * offset, caster)
    local radius = self:GetSpecialValueFor("effect_radius")
    local warningDuration = self:GetSpecialValueFor("warning_duration")

    self.sequenceActive = true
    self.swallowedUnits = {}
    self:CreateWarningCircle(position, radius, warningDuration)

    Timers:CreateTimer(warningDuration, function()
        if not IsValidLivingUnit(caster) then
            self.sequenceActive = false
            return
        end

        self:SwallowTargets(self:FindTargets(position, radius))
    end)
end

function mortimer_gobble_up:SwallowTargets(targets)
    local caster = self:GetCaster()
    local spitDelay = self:GetSpecialValueFor("spit_delay")

    for _, target in ipairs(targets) do
        if self:IsValidGobbleTarget(target) then
            target:Interrupt()
            target:Stop()
            target:AddNewModifier(caster, self, "modifier_mortimer_gobble_up_swallowed", {
                duration = spitDelay + 1,
            })
            self.swallowedUnits[#self.swallowedUnits + 1] = target
        end
    end

    if #self.swallowedUnits == 0 then
        self.sequenceActive = false
        return
    end

    caster:EmitSound("Hero_Snapfire.GobbleUp.Cast")
    caster:AddNewModifier(caster, self, "modifier_mortimer_gobble_up_caster", {
        duration = spitDelay,
    })

    Timers:CreateTimer(spitDelay, function()
        self:SpitAllUnits()
    end)
end

function mortimer_gobble_up:ReleaseUnit(target, position)
    if not IsValidLivingUnit(target) then
        return
    end

    local swallowed = target:FindModifierByName("modifier_mortimer_gobble_up_swallowed")
    if swallowed then
        swallowed.wasSpat = true
        swallowed:Destroy()
    else
        target:RemoveNoDraw()
    end

    FindClearSpaceForUnit(target, position, true)
end

function mortimer_gobble_up:SpitUnit(target, position)
    local caster = self:GetCaster()
    if not IsValidLivingUnit(target) then
        return
    end

    position = GetGroundPosition(position, caster)
    if not IsValidLandingPosition(position) then
        position = self:GetThroneDirectedSpitPosition()
    end

    local origin = caster:GetAbsOrigin()
    local direction = position - origin
    direction.z = 0
    local distance = direction:Length2D()
    if distance < 1 then
        self:ReleaseUnit(target, origin)
        return
    end
    direction = direction:Normalized()
    caster:SetForwardVector(direction)

    local swallowed = target:FindModifierByName("modifier_mortimer_gobble_up_swallowed")
    if swallowed then
        swallowed.wasSpat = true
        swallowed:Destroy()
    end

    target:EmitSound("Hero_Snapfire.SpitOut.Projectile")
    target:EmitSound("Hero_Snapfire.MortimerGrunt")
    FindClearSpaceForUnit(target, origin + direction * 80, false)

    local speed = self:GetSpecialValueFor("spit_speed")
    local arc = target:AddNewModifier(caster, self, "modifier_generic_arc_lua", {
        target_x = position.x,
        target_y = position.y,
        distance = distance,
        speed = speed,
        height = math.min(1200, math.max(300, distance * 0.12)),
        fix_end = false,
        isStun = 1,
        activity = ACT_DOTA_FLAIL,
    })

    if not arc then
        FindClearSpaceForUnit(target, position, true)
        return
    end

    local particle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_snapfire/snapfire_flaming_creep.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        target
    )
    ParticleManager:SetParticleControlEnt(
        particle,
        3,
        target,
        PATTACH_POINT_FOLLOW,
        "attach_hitloc",
        target:GetAbsOrigin(),
        true
    )
    ParticleManager:SetParticleControlEnt(
        particle,
        5,
        target,
        PATTACH_POINT_FOLLOW,
        "attach_hitloc",
        target:GetAbsOrigin(),
        true
    )
    arc:AddParticle(particle, false, false, -1, false, false)

    arc:SetEndCallback(function()
        if IsValidLivingUnit(target) then
            GridNav:DestroyTreesAroundPoint(position, 200, true)
            FindClearSpaceForUnit(target, position, true)
        end
    end)
end

function mortimer_gobble_up:SpitAllUnits()
    local caster = self:GetCaster()
    local units = self.swallowedUnits or {}
    self.swallowedUnits = {}

    if caster and not caster:IsNull() then
        caster:RemoveModifierByName("modifier_mortimer_gobble_up_caster")
    end

    if IsValidLivingUnit(caster) then
        local spitPosition = self:GetThroneDirectedSpitPosition()
        for _, target in ipairs(units) do
            self:SpitUnit(target, spitPosition)
        end
    else
        for _, target in ipairs(units) do
            if IsValidLivingUnit(target) then
                self:ReleaseUnit(target, target:GetAbsOrigin())
            end
        end
    end

    self.sequenceActive = false
end

modifier_mortimer_gobble_up_swallowed = class({})

function modifier_mortimer_gobble_up_swallowed:IsHidden()
    return true
end

function modifier_mortimer_gobble_up_swallowed:IsPurgable()
    return false
end

function modifier_mortimer_gobble_up_swallowed:CheckState()
    return {
        [MODIFIER_STATE_INVULNERABLE] = true,
        [MODIFIER_STATE_OUT_OF_GAME] = true,
        [MODIFIER_STATE_NO_HEALTH_BAR] = true,
        [MODIFIER_STATE_NO_UNIT_COLLISION] = true,
        [MODIFIER_STATE_STUNNED] = true,
        [MODIFIER_STATE_UNSELECTABLE] = true,
        [MODIFIER_STATE_COMMAND_RESTRICTED] = true,
    }
end

function modifier_mortimer_gobble_up_swallowed:OnCreated()
    if not IsServer() then
        return
    end

    self:GetParent():AddNoDraw()
    self:StartIntervalThink(FrameTime())
end

function modifier_mortimer_gobble_up_swallowed:OnIntervalThink()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    local parent = self:GetParent()
    if not IsValidLivingUnit(caster) or not IsValidLivingUnit(parent) then
        self:Destroy()
        return
    end

    parent:SetAbsOrigin(caster:GetAbsOrigin())
end

function modifier_mortimer_gobble_up_swallowed:OnDestroy()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    parent:RemoveNoDraw()
    if not self.wasSpat and IsValidLivingUnit(parent) then
        FindClearSpaceForUnit(parent, parent:GetAbsOrigin(), true)
    end
end

modifier_mortimer_gobble_up_caster = class({})

function modifier_mortimer_gobble_up_caster:IsHidden()
    return false
end

function modifier_mortimer_gobble_up_caster:IsPurgable()
    return false
end

function modifier_mortimer_gobble_up_caster:GetEffectName()
    return "particles/units/heroes/hero_life_stealer/life_stealer_infested_unit_icon.vpcf"
end

function modifier_mortimer_gobble_up_caster:GetEffectAttachType()
    return PATTACH_OVERHEAD_FOLLOW
end
