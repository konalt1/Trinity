LinkLuaModifier(
    "modifier_caravan_aghanim_spear_dummy",
    "map_modifications/Bosses/caravan/caravan_aghanim_spears",
    LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
    "modifier_caravan_aghanim_spear_impale",
    "map_modifications/Bosses/caravan/caravan_aghanim_spears",
    LUA_MODIFIER_MOTION_HORIZONTAL
)

caravan_aghanim_spears = class({})

local SPEAR_MODEL = "models/heroes/mars/mars_spear.vmdl"
local SPEAR_UNIT = "npc_caravan_spear"
local SPEAR_HEIGHT = 80
local SPEAR_SCALE = 1.0
local SPEAR_CENTER_OFFSET = 0
local AIM_THINK = 0.03
local AIM_DEADZONE = 2
local FLY_THINK = 0.03
local TREE_RADIUS = 80
local BUILDING_RADIUS = 90
local CLIFF_STEP = 40
local DEBUG_AIM_DRAW = 0.12
local DEBUG_FLY_DRAW = 0.08

local function NormalizeYaw(yaw)
    yaw = tonumber(yaw) or 0
    while yaw > 180 do
        yaw = yaw - 360
    end
    while yaw < -180 do
        yaw = yaw + 360
    end
    return yaw
end

local function DirToYaw(direction)
    if not direction then
        return 0
    end

    return NormalizeYaw(math.deg(math.atan2(direction.y, direction.x)))
end

local function YawToDir(yaw)
    local rad = math.rad(yaw or 0)
    return Vector(math.cos(rad), math.sin(rad), 0)
end

local function VisualYaw(dummy)
    if not dummy or dummy.IsNull == nil or dummy:IsNull() then
        return 0, 0
    end

    local yaw = DirToYaw(dummy:GetForwardVector())
    return yaw, yaw
end

local function YawDelta(a, b)
    local delta = (a or 0) - (b or 0)
    while delta > 180 do
        delta = delta - 360
    end
    while delta < -180 do
        delta = delta + 360
    end
    return delta
end

local function StepYaw(current, desired, maxDegrees)
    current = current or 0
    desired = desired or 0
    maxDegrees = maxDegrees or 0

    local delta = desired - current
    while delta > 180 do
        delta = delta - 360
    end
    while delta < -180 do
        delta = delta + 360
    end

    if math.abs(delta) <= AIM_DEADZONE then
        return NormalizeYaw(current)
    end

    if math.abs(delta) <= maxDegrees then
        return NormalizeYaw(current + delta)
    end

    if delta > 0 then
        return NormalizeYaw(current + maxDegrees)
    end

    return NormalizeYaw(current - maxDegrees)
end

_G.CARAVAN_SPEAR_DEBUG_ENABLED = true

if IsServer() and not _G.CARAVAN_SPEAR_DEBUG_COMMAND_REGISTERED then
    -- Flag 0, not FCVAR_CHEAT: the client console otherwise prints
    -- "is not a recognized command" and never reaches the server.
    Convars:RegisterCommand("caravan_spear_debug", function(_, value)
        if value == nil or value == "" then
            _G.CARAVAN_SPEAR_DEBUG_ENABLED = not _G.CARAVAN_SPEAR_DEBUG_ENABLED
        else
            local normalized = string.lower(tostring(value))
            _G.CARAVAN_SPEAR_DEBUG_ENABLED = normalized == "1" or normalized == "true" or normalized == "on"
        end

        local state = _G.CARAVAN_SPEAR_DEBUG_ENABLED and "ON" or "OFF"
        print("[CaravanSpear] Debug " .. state .. " (yellow=slot, cyan=aim, green=flight, magenta=hit, red=pin)")
    end, "Toggle Aghanim spear debug: caravan_spear_debug [0|1]", 0)

    _G.CARAVAN_SPEAR_DEBUG_COMMAND_REGISTERED = true
end

local function IsValidUnit(unit)
    return unit and not unit:IsNull() and IsValidEntity(unit)
end

local function IsSpearDebug()
    return _G.CARAVAN_SPEAR_DEBUG_ENABLED == true
end

local function FormatVector(vector)
    if not vector then
        return "nil"
    end

    return string.format("(%.1f, %.1f, %.1f)", vector.x, vector.y, vector.z)
end

local function HeroName(hero)
    if not IsValidUnit(hero) then
        return "nil"
    end

    return string.format("%s[%d]", hero:GetUnitName(), hero:entindex())
end

local function SpearLabel(dummy)
    if not dummy then
        return "?"
    end

    return tostring(dummy.spearIndex or dummy:entindex())
end

local function DebugLog(message)
    if IsSpearDebug() then
        print("[CaravanSpear] " .. message)
    end
end

local function Ground(pos)
    return GetGroundPosition(pos, nil)
end

local function DrawCorridor(origin, direction, range, width, duration)
    local startPos = Ground(origin)
    local travel = direction * range
    local endPos = Ground(origin + travel)
    local right = Vector(-direction.y, direction.x, 0)
    local half = width
    local startLeft = Ground(origin - right * half)
    local startRight = Ground(origin + right * half)
    local endLeft = Ground(origin + travel - right * half)
    local endRight = Ground(origin + travel + right * half)

    DebugDrawCircle(startPos, Vector(255, 220, 80), 255, 28, false, duration)
    DebugDrawCircle(endPos, Vector(80, 255, 120), 255, 28, false, duration)
    DebugDrawCircle(startPos, Vector(80, 255, 120), 255, width, false, duration)
    DebugDrawLine(startPos, endPos, 80, 255, 120, false, duration)
    DebugDrawLine(startLeft, endLeft, 80, 255, 120, false, duration)
    DebugDrawLine(startRight, endRight, 80, 255, 120, false, duration)
    DebugDrawLine(startLeft, startRight, 255, 160, 40, false, duration)
    DebugDrawLine(endLeft, endRight, 255, 160, 40, false, duration)
end

local function Assets()
    if not CaravanAssets then
        require("map_modifications/Bosses/caravan/caravan_assets")
    end
    return CaravanAssets
end

function caravan_aghanim_spears:Precache(context)
    local assets = Assets()
    PrecacheResource("model", SPEAR_MODEL, context)
    PrecacheUnitByNameSync(SPEAR_UNIT, context)
    PrecacheResource("particle", assets.PARTICLE.spear_burst, context)
    PrecacheResource("particle", assets.PARTICLE.spear_ground, context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_mars.vsndevts", context)
end

function caravan_aghanim_spears:OnSpellStart()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    self:SyncStageLevel()

    local heroes = self:FindHeroes(caster:GetAbsOrigin())
    DebugLog(string.format(
        "cast stage=%s level=%s heroes=%d origin=%s radius=%.0f",
        tostring(caster.caravanStage or 1),
        tostring(self:GetLevel()),
        #heroes,
        FormatVector(caster:GetAbsOrigin()),
        self:GetSpecialValueFor("search_radius")
    ))
    if #heroes == 0 then
        DebugLog("abort: no heroes")
        if CourierCaravan and CourierCaravan.FinishAghanimCast then
            CourierCaravan:FinishAghanimCast(caster)
        end
        return
    end

    local launchDelay = self:GetSpecialValueFor("launch_delay")
    if CourierCaravan and CourierCaravan.MarkAghanimBusy then
        CourierCaravan:MarkAghanimBusy(caster, launchDelay + 0.35)
    end

    caster:StartGesture(ACT_DOTA_ATTACK)

    local origin = caster:GetAbsOrigin()
    local forward = self:FlatDirection(origin, origin + caster:GetForwardVector(), Vector(1, 0, 0))
    local spearCount = math.max(1, self:GetSpecialValueFor("spear_count"))
    local orbit = self:GetSpecialValueFor("orbit_radius")
    local spears = {}
    local aimYaw = {}

    for i = 1, spearCount do
        local dir = RotatePosition(Vector(0, 0, 0), QAngle(0, (i - 1) * (360 / spearCount), 0), forward)
        local slot = GetGroundPosition(origin + dir * orbit, nil)
        spears[i] = self:SpawnSpearDummy(slot, dir)
        aimYaw[i] = DirToYaw(dir)
        if spears[i] then
            spears[i].spearIndex = i
            spears[i].spearSlot = slot
            DebugLog(string.format("spawn #%d slot=%s orbit=%.0f yaw=%.1f", i, FormatVector(slot), orbit, aimYaw[i]))
        else
            DebugLog(string.format("spawn #%d failed", i))
        end
    end

    self:AimSpears(spears, aimYaw)

    local elapsed = 0
    Timers:CreateTimer(AIM_THINK, function()
        if not IsValidUnit(caster) then
            self:DestroySpears(spears)
            return nil
        end

        elapsed = elapsed + AIM_THINK
        if elapsed >= launchDelay then
            self:AimSpears(spears, aimYaw)
            self:LaunchSpears(spears, aimYaw)
            if CourierCaravan and CourierCaravan.FinishAghanimCast then
                CourierCaravan:FinishAghanimCast(caster)
            end
            return nil
        end

        self:AimSpears(spears, aimYaw)
        return AIM_THINK
    end)
end

function caravan_aghanim_spears:SyncStageLevel()
    local caster = self:GetCaster()
    local stage = caster and caster.caravanStage or self:GetLevel()
    stage = math.min(3, math.max(1, math.floor(tonumber(stage) or 1)))
    if self:GetLevel() ~= stage then
        self:SetLevel(stage)
    end
end

function caravan_aghanim_spears:DestroyFx(fx, immediate)
    if not fx then
        return
    end

    ParticleManager:DestroyParticle(fx, immediate == true)
    ParticleManager:ReleaseParticleIndex(fx)
end

function caravan_aghanim_spears:DestroyTelegraph(dummy)
    if not dummy then
        return
    end

    self:DestroyFx(dummy.spearTelegraph, false)
    self:DestroyFx(dummy.spearGround, false)
    dummy.spearTelegraph = nil
    dummy.spearGround = nil
end

function caravan_aghanim_spears:PlayImpact(target)
    local origin
    if IsValidUnit(target) then
        origin = target:GetAbsOrigin()
    elseif target then
        origin = target
    else
        return
    end

    local fx = ParticleManager:CreateParticle(Assets().PARTICLE.spear_burst, PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(fx, 0, origin)
    ParticleManager:ReleaseParticleIndex(fx)
end

function caravan_aghanim_spears:PlaceTelegraph(dummy)
    if not IsValidUnit(dummy) then
        return
    end

    self:DestroyTelegraph(dummy)

    local slot = self:SlotOf(dummy)
    local loc = GetGroundPosition(slot, dummy)
    local assets = Assets()
    local fx = ParticleManager:CreateParticle(assets.PARTICLE.spear_ground, PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(fx, 0, loc)

    dummy.spearGround = fx
    DebugLog(string.format("telegraph #%s at=%s fx=%s", SpearLabel(dummy), FormatVector(loc), tostring(fx)))
end

function caravan_aghanim_spears:FlatDirection(from, to, fallback)
    local direction = to - from
    direction.z = 0
    if direction:Length2D() < 0.01 then
        if fallback then
            fallback = Vector(fallback.x, fallback.y, 0)
            if fallback:Length2D() >= 0.01 then
                return fallback:Normalized()
            end
        end
        return Vector(1, 0, 0)
    end

    return direction:Normalized()
end

function caravan_aghanim_spears:SpearPosition(origin, dummy)
    local ground = GetGroundPosition(origin, dummy)
    return Vector(ground.x, ground.y, ground.z + SPEAR_HEIGHT)
end

function caravan_aghanim_spears:SlotOf(dummy)
    if dummy and dummy.spearSlot then
        return dummy.spearSlot
    end
    if IsValidUnit(dummy) then
        return dummy:GetAbsOrigin()
    end
    return Vector(0, 0, 0)
end

function caravan_aghanim_spears:PlaceDummyOnSlot(dummy, direction, move)
    if not IsValidUnit(dummy) then
        return
    end

    local facing = self:FlatDirection(Vector(0, 0, 0), direction, Vector(1, 0, 0))
    if move ~= false then
        local slot = dummy.spearSlot or dummy:GetAbsOrigin()
        dummy:SetAbsOrigin(self:SpearPosition(slot - facing * SPEAR_CENTER_OFFSET, dummy))
    end
    self:ApplyYaw(dummy, DirToYaw(facing))
end

function caravan_aghanim_spears:ApplyYaw(dummy, yaw)
    if not IsValidUnit(dummy) then
        return
    end

    dummy.logicYaw = NormalizeYaw(yaw)
    dummy:SetAbsAngles(0, dummy.logicYaw, 0)
end

function caravan_aghanim_spears:OrientDummy(dummy, direction)
    self:ApplyYaw(dummy, DirToYaw(direction))
end

function caravan_aghanim_spears:SpawnSpearDummy(origin, direction)
    local caster = self:GetCaster()
    local dummy = CreateUnitByName(SPEAR_UNIT, origin, false, nil, nil, caster:GetTeamNumber())
    if not IsValidUnit(dummy) then
        return nil
    end

    dummy.spearSlot = origin
    dummy:SetModel(SPEAR_MODEL)
    dummy:SetOriginalModel(SPEAR_MODEL)
    dummy:SetMoveCapability(DOTA_UNIT_CAP_MOVE_FLY)
    dummy:AddNewModifier(caster, self, "modifier_caravan_aghanim_spear_dummy", {})
    dummy:AddNewModifier(caster, self, "modifier_phased", {})
    self:PlaceDummyOnSlot(dummy, direction)
    Timers:CreateTimer(0, function()
        if not IsValidUnit(dummy) then
            return nil
        end

        self:PlaceTelegraph(dummy)
        return nil
    end)

    return dummy
end

function caravan_aghanim_spears:DestroySpears(spears)
    if not spears then
        return
    end

    for i, dummy in pairs(spears) do
        if IsValidUnit(dummy) then
            self:DestroyTelegraph(dummy)
            dummy.spearRemoved = true
            UTIL_Remove(dummy)
        end
        spears[i] = nil
    end
end

function caravan_aghanim_spears:FindHeroes(position)
    local caster = self:GetCaster()
    local radius = self:GetSpecialValueFor("search_radius")
    local heroes = {}

    for i = 0, HeroList:GetHeroCount() - 1 do
        local hero = HeroList:GetHero(i)
        if IsValidUnit(hero)
            and hero:IsRealHero()
            and hero:IsAlive()
            and hero:GetTeamNumber() ~= caster:GetTeamNumber()
            and (hero:GetAbsOrigin() - position):Length2D() <= radius
        then
            table.insert(heroes, hero)
        end
    end

    table.sort(heroes, function(a, b)
        return (a:GetAbsOrigin() - position):Length2D() < (b:GetAbsOrigin() - position):Length2D()
    end)

    return heroes
end

function caravan_aghanim_spears:AssignTargets(spears)
    local caster = self:GetCaster()
    local heroes = self:FindHeroes(caster:GetAbsOrigin())
    local claimed = {}
    local targets = {}

    for i, dummy in ipairs(spears) do
        if IsValidUnit(dummy) then
            local best, bestDist = nil, math.huge
            for _, hero in ipairs(heroes) do
                if not claimed[hero:entindex()] then
                    local dist = (hero:GetAbsOrigin() - self:SlotOf(dummy)):Length2D()
                    if dist < bestDist then
                        best = hero
                        bestDist = dist
                    end
                end
            end

            if best then
                claimed[best:entindex()] = true
                targets[i] = best
            end
        end
    end

    for i, dummy in ipairs(spears) do
        if IsValidUnit(dummy) and not targets[i] and #heroes > 0 then
            local best, bestDist = nil, math.huge
            for _, hero in ipairs(heroes) do
                local dist = (hero:GetAbsOrigin() - self:SlotOf(dummy)):Length2D()
                if dist < bestDist then
                    best = hero
                    bestDist = dist
                end
            end
            targets[i] = best
        end
    end

    return targets
end

function caravan_aghanim_spears:AimSpears(spears, aimYaw)
    aimYaw = aimYaw or {}
    local targets = self:AssignTargets(spears)
    local rate = self:GetSpecialValueFor("spear_turn_rate")
    if rate <= 0 then
        rate = 120
    end
    local maxDeg = rate * AIM_THINK
    for i, dummy in ipairs(spears) do
        local hero = targets[i]
        if IsValidUnit(dummy) and IsValidUnit(hero) then
            local from = self:SlotOf(dummy)
            local toHero = hero:GetAbsOrigin() - from
            toHero.z = 0
            if toHero:Length2D() < 1 then
                DebugLog(string.format("aim #%s skip: hero on slot", SpearLabel(dummy)))
            else
                local wantYaw = DirToYaw(toHero)
                local nextYaw = StepYaw(aimYaw[i] or wantYaw, wantYaw, maxDeg)
                aimYaw[i] = nextYaw
                dummy.spearAimTarget = hero
                self:ApplyYaw(dummy, nextYaw)
                aimYaw.logAccum = (aimYaw.logAccum or 0) + AIM_THINK
                if aimYaw.logAccum >= 0.1 then
                    aimYaw.logAccum = 0
                    DebugLog(string.format(
                        "aim #%s from=%s hero=%s want=%.1f yaw=%.1f",
                        SpearLabel(dummy),
                        FormatVector(from),
                        FormatVector(hero:GetAbsOrigin()),
                        wantYaw,
                        nextYaw
                    ))
                end
                if IsSpearDebug() then
                    local origin = Ground(from)
                    DebugDrawLine(origin, origin + YawToDir(nextYaw) * 260, 80, 255, 80, false, 0.08)
                    DebugDrawLine(origin, Ground(hero:GetAbsOrigin()), 80, 180, 255, false, 0.08)
                end
            end
        end
    end
end

function caravan_aghanim_spears:LaunchSpears(spears, aimYaw)
    aimYaw = aimYaw or {}
    local caster = self:GetCaster()
    local targets = self:AssignTargets(spears)

    for i, dummy in ipairs(spears) do
        if IsValidUnit(dummy) then
            local hero = targets[i]
            local direction = YawToDir(aimYaw[i] or 0)
            self:PlaceDummyOnSlot(dummy, direction)
            self:DestroyTelegraph(dummy)

            local range = self:GetSpecialValueFor("spear_range")
            local width = self:GetSpecialValueFor("spear_width")
            DebugLog(string.format(
                "launch #%s target=%s fly=%.1f dir=%s",
                SpearLabel(dummy),
                HeroName(hero),
                DirToYaw(direction),
                FormatVector(direction)
            ))
            if IsSpearDebug() then
                DrawCorridor(dummy:GetAbsOrigin(), direction, range, width, range / math.max(self:GetSpecialValueFor("spear_speed"), 1) + 1.2)
            end

            local modifier = dummy:FindModifierByName("modifier_caravan_aghanim_spear_dummy")
            if modifier and modifier.Launch then
                modifier:Launch(direction)
            end
        end
    end

    if IsValidUnit(caster) then
        caster:EmitSound("Hero_Mars.Spear.Cast")
    end
end

function caravan_aghanim_spears:ApplySpearDamage(target)
    local caster = self:GetCaster()
    if not IsValidUnit(caster) or not IsValidUnit(target) then
        return
    end

    ApplyDamage({
        attacker = caster,
        victim = target,
        damage = self:GetSpecialValueFor("damage"),
        damage_type = target:IsMagicImmune() and DAMAGE_TYPE_PURE or DAMAGE_TYPE_MAGICAL,
        ability = self,
    })
end

modifier_caravan_aghanim_spear_dummy = class({})

function modifier_caravan_aghanim_spear_dummy:IsHidden()
    return true
end

function modifier_caravan_aghanim_spear_dummy:IsPurgable()
    return false
end

function modifier_caravan_aghanim_spear_dummy:GetAttributes()
    return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end

function modifier_caravan_aghanim_spear_dummy:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_IGNORE_CAST_ANGLE,
    }
end

function modifier_caravan_aghanim_spear_dummy:GetModifierIgnoreCastAngle()
    return 1
end

function modifier_caravan_aghanim_spear_dummy:CheckState()
    local flying = self.phase == "fly"
    return {
        [MODIFIER_STATE_INVULNERABLE] = true,
        [MODIFIER_STATE_UNSELECTABLE] = true,
        [MODIFIER_STATE_NOT_ON_MINIMAP] = true,
        [MODIFIER_STATE_NO_HEALTH_BAR] = true,
        [MODIFIER_STATE_NO_UNIT_COLLISION] = true,
        [MODIFIER_STATE_ATTACK_IMMUNE] = true,
        [MODIFIER_STATE_MAGIC_IMMUNE] = true,
        [MODIFIER_STATE_NO_TEAM_MOVE_TO] = true,
        [MODIFIER_STATE_NO_TEAM_SELECT] = true,
        [MODIFIER_STATE_DISARMED] = true,
        [MODIFIER_STATE_COMMAND_RESTRICTED] = true,
        [MODIFIER_STATE_FLYING] = flying,
        [MODIFIER_STATE_ROOTED] = not flying,
    }
end

function modifier_caravan_aghanim_spear_dummy:SetLogicYaw(yaw)
    local ability = self:GetAbility()
    if ability and ability.ApplyYaw then
        ability:ApplyYaw(self:GetParent(), yaw)
    end
end

function modifier_caravan_aghanim_spear_dummy:OnCreated()
    if not IsServer() then
        return
    end

    self.phase = "aim"
    self.logicYaw = 0
    self.dir = Vector(1, 0, 0)
    self.traveled = 0
    self.victim = nil
end

function modifier_caravan_aghanim_spear_dummy:OnDestroy()
    if not IsServer() then
        return
    end

    self:ReleaseVictim(false)
    local parent = self:GetParent()
    local ability = self:GetAbility()
    if ability and ability.DestroyTelegraph then
        ability:DestroyTelegraph(parent)
    end
    if not IsValidUnit(parent) or parent.spearRemoved then
        return
    end

    parent.spearRemoved = true
    parent:StopSound("Hero_Mars.Spear.Cast")
    Timers:CreateTimer(0, function()
        if IsValidUnit(parent) then
            UTIL_Remove(parent)
        end
        return nil
    end)
end

function modifier_caravan_aghanim_spear_dummy:Launch(direction)
    local ability = self:GetAbility()
    if not ability then
        self:Destroy()
        return
    end

    self.phase = "fly"
    self.dir = ability:FlatDirection(Vector(0, 0, 0), direction, Vector(1, 0, 0))
    self.speed = ability:GetSpecialValueFor("spear_speed")
    self.range = ability:GetSpecialValueFor("spear_range")
    self.width = ability:GetSpecialValueFor("spear_width")
    self.vision = ability:GetSpecialValueFor("spear_vision")
    self.stun = ability:GetSpecialValueFor("stun_duration")
    self.linger = ability:GetSpecialValueFor("activity_duration")
    self.traveled = 0
    self.victim = nil
    self.hitUnits = {}

    local parent = self:GetParent()
    if IsValidUnit(parent) then
        parent.flyPos = parent:GetAbsOrigin()
        parent:SetDayTimeVisionRange(self.vision)
        parent:SetNightTimeVisionRange(self.vision)
        ability:OrientDummy(parent, self.dir)
        parent:EmitSound("Hero_Mars.Spear.Cast")
        DebugLog(string.format(
            "flystart #%s pos=%s dir=%s yaw=%.1f",
            SpearLabel(parent),
            FormatVector(parent.flyPos),
            FormatVector(self.dir),
            parent.logicYaw or DirToYaw(self.dir)
        ))
    end

    self:StartIntervalThink(FLY_THINK)
end

function modifier_caravan_aghanim_spear_dummy:OnIntervalThink()
    if not IsServer() or self.phase ~= "fly" then
        return
    end

    local parent = self:GetParent()
    local ability = self:GetAbility()
    if not IsValidUnit(parent) or not ability then
        self:Destroy()
        return
    end

    local step = self.speed * FLY_THINK
    local from = parent.flyPos or parent:GetAbsOrigin()
    local nextPos = from + self.dir * step
    local obstacle = self:GetObstacleKind(nextPos)
    if obstacle then
        self:Stick(true, obstacle)
        return
    end

    nextPos = ability:SpearPosition(nextPos)
    parent.flyPos = nextPos
    parent:SetAbsOrigin(nextPos)
    self.traveled = self.traveled + step
    AddFOWViewer(parent:GetTeamNumber(), nextPos, self.vision, 0.2, false)

    if IsSpearDebug() then
        local ground = Ground(nextPos)
        DebugDrawCircle(ground, Vector(80, 255, 120), 255, 16, false, DEBUG_FLY_DRAW)
        DebugDrawCircle(ground, Vector(80, 255, 120), 255, self.width, false, DEBUG_FLY_DRAW)
        DebugDrawLine(ground, Ground(nextPos + self.dir * 80), 80, 255, 120, false, DEBUG_FLY_DRAW)
    end

    if not self.victim then
        local hero = self:FindHitHero(nextPos)
        if hero then
            if hero:HasModifier("modifier_caravan_aghanim_spear_impale") then
                self:MarkHit(hero)
                ability:ApplySpearDamage(hero)
                hero:EmitSound("Hero_Mars.Spear.Target")
                DebugLog(string.format("graze #%s %s dist=%.0f", SpearLabel(parent), HeroName(hero), (hero:GetAbsOrigin() - nextPos):Length2D()))
                if IsSpearDebug() then
                    DebugDrawCircle(Ground(hero:GetAbsOrigin()), Vector(255, 80, 220), 255, 48, false, 1.2)
                end
            else
                self:Impale(hero)
            end
        end
    end

    if self.traveled >= self.range then
        self:Stick(false, "range")
    end
end

function modifier_caravan_aghanim_spear_dummy:MarkHit(hero)
    if IsValidUnit(hero) then
        self.hitUnits = self.hitUnits or {}
        self.hitUnits[hero:entindex()] = true
    end
end

function modifier_caravan_aghanim_spear_dummy:FindHitHero(position)
    local caster = self:GetCaster()
    if not IsValidUnit(caster) then
        return nil
    end

    local closest, closestDist = nil, self.width
    for i = 0, HeroList:GetHeroCount() - 1 do
        local hero = HeroList:GetHero(i)
        if IsValidUnit(hero)
            and hero:IsRealHero()
            and hero:IsAlive()
            and hero:GetTeamNumber() ~= caster:GetTeamNumber()
            and not (self.hitUnits and self.hitUnits[hero:entindex()])
        then
            local dist = (hero:GetAbsOrigin() - position):Length2D()
            if dist <= closestDist then
                closest = hero
                closestDist = dist
            end
        end
    end

    return closest
end

function modifier_caravan_aghanim_spear_dummy:GetObstacleKind(pos)
    local parent = self:GetParent()
    if GridNav:IsNearbyTree(pos, TREE_RADIUS, false) then
        return "tree"
    end

    local nextGround = GetGroundHeight(pos, parent)
    local currentGround = GetGroundHeight(parent.flyPos or parent:GetAbsOrigin(), parent)
    if nextGround - currentGround > CLIFF_STEP then
        return "cliff"
    end

    local caster = self:GetCaster()
    local team = caster and caster:GetTeamNumber() or parent:GetTeamNumber()
    local buildings = FindUnitsInRadius(
        team,
        pos,
        nil,
        BUILDING_RADIUS,
        DOTA_UNIT_TARGET_TEAM_BOTH,
        DOTA_UNIT_TARGET_BUILDING,
        DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        FIND_ANY_ORDER,
        false
    )
    if #buildings > 0 then
        return "building"
    end

    return nil
end

function modifier_caravan_aghanim_spear_dummy:CheckObstacle(pos)
    return self:GetObstacleKind(pos) ~= nil
end

function modifier_caravan_aghanim_spear_dummy:Impale(hero)
    local caster = self:GetCaster()
    local ability = self:GetAbility()
    local parent = self:GetParent()
    if not IsValidUnit(hero) or not ability then
        return
    end

    self.victim = hero
    self:MarkHit(hero)
    ability:ApplySpearDamage(hero)
    hero:EmitSound("Hero_Mars.Spear.Target")
    DebugLog(string.format(
        "impale #%s %s at=%s traveled=%.0f immune=%s invis=%s",
        SpearLabel(parent),
        HeroName(hero),
        FormatVector(hero:GetAbsOrigin()),
        self.traveled or 0,
        tostring(hero:IsMagicImmune()),
        tostring(hero:IsInvisible())
    ))
    if IsSpearDebug() then
        DebugDrawCircle(Ground(hero:GetAbsOrigin()), Vector(255, 80, 220), 255, 56, false, 1.5)
        DebugDrawText(hero:GetAbsOrigin() + Vector(0, 0, 80), "impale #" .. SpearLabel(parent), false, 1.5)
    end

    ability:PlayImpact(hero)

    hero:AddNewModifier(caster, ability, "modifier_caravan_aghanim_spear_impale", {
        dummy = parent:entindex(),
        dir_x = self.dir.x,
        dir_y = self.dir.y,
    })
end

function modifier_caravan_aghanim_spear_dummy:ReleaseVictim(pinned)
    local victim = self.victim
    self.victim = nil
    if not IsValidUnit(victim) then
        return
    end

    local impale = victim:FindModifierByName("modifier_caravan_aghanim_spear_impale")
    if not impale then
        return
    end

    if pinned then
        impale:Pin(self.stun)
    else
        impale:Destroy()
    end
end

function modifier_caravan_aghanim_spear_dummy:Stick(hitObstacle, kind)
    self.phase = "stuck"
    self:StartIntervalThink(-1)

    local parent = self:GetParent()
    local pos = Vector(0, 0, 0)
    if IsValidUnit(parent) then
        pos = parent.flyPos or parent:GetAbsOrigin()
    end
    if IsValidUnit(parent) then
        parent:StopSound("Hero_Mars.Spear.Cast")
    end

    if hitObstacle and self.victim then
        DebugLog(string.format(
            "pin #%s victim=%s obstacle=%s at=%s traveled=%.0f stun=%.2f",
            SpearLabel(parent),
            HeroName(self.victim),
            tostring(kind or "obstacle"),
            FormatVector(pos),
            self.traveled or 0,
            self.stun or 0
        ))
        if IsSpearDebug() then
            DebugDrawCircle(Ground(pos), Vector(255, 60, 60), 255, 64, false, self.stun or 1.6)
            DebugDrawText(pos + Vector(0, 0, 80), "pin #" .. SpearLabel(parent) .. " " .. tostring(kind or "obstacle"), false, self.stun or 1.6)
        end
        if IsValidUnit(self.victim) then
            self.victim:EmitSound("Hero_Mars.Spear.Root")
            local ability = self:GetAbility()
            if ability and ability.PlayImpact then
                ability:PlayImpact(self.victim)
            end
        end
        self:ReleaseVictim(true)
        self:SetDuration(self.stun, true)
        return
    end

    if hitObstacle then
        DebugLog(string.format(
            "stick #%s obstacle=%s at=%s traveled=%.0f linger=%.2f",
            SpearLabel(parent),
            tostring(kind or "obstacle"),
            FormatVector(pos),
            self.traveled or 0,
            self.linger or 0
        ))
        if IsSpearDebug() then
            DebugDrawCircle(Ground(pos), Vector(255, 60, 60), 255, 48, false, self.linger or 1.7)
            DebugDrawText(pos + Vector(0, 0, 80), "stick #" .. SpearLabel(parent) .. " " .. tostring(kind or "obstacle"), false, self.linger or 1.7)
        end
    else
        DebugLog(string.format(
            "end #%s victim=%s at=%s traveled=%.0f",
            SpearLabel(parent),
            HeroName(self.victim),
            FormatVector(pos),
            self.traveled or 0
        ))
    end

    self:ReleaseVictim(false)
    if hitObstacle then
        self:SetDuration(self.linger, true)
    else
        self:Destroy()
    end
end

modifier_caravan_aghanim_spear_impale = class({})

function modifier_caravan_aghanim_spear_impale:IsHidden()
    return true
end

function modifier_caravan_aghanim_spear_impale:IsDebuff()
    return true
end

function modifier_caravan_aghanim_spear_impale:IsPurgable()
    return false
end

function modifier_caravan_aghanim_spear_impale:GetAttributes()
    return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end

function modifier_caravan_aghanim_spear_impale:OnCreated(kv)
    if not IsServer() then
        return
    end

    kv = kv or {}
    self.dummy = EntIndexToHScript(tonumber(kv.dummy) or -1)
    self.dir = Vector(tonumber(kv.dir_x) or 1, tonumber(kv.dir_y) or 0, 0)
    if self.dir:Length2D() < 0.01 then
        self.dir = Vector(1, 0, 0)
    end
    self.dir = self.dir:Normalized()
    self.pinned = false

    if self:ApplyHorizontalMotionController() == false then
        self:StartIntervalThink(FLY_THINK)
    end
end

function modifier_caravan_aghanim_spear_impale:OnDestroy()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if IsValidUnit(parent) then
        parent:RemoveHorizontalMotionController(self)
        FindClearSpaceForUnit(parent, parent:GetAbsOrigin(), false)
    end
end

function modifier_caravan_aghanim_spear_impale:CheckState()
    return {
        [MODIFIER_STATE_STUNNED] = true,
    }
end

function modifier_caravan_aghanim_spear_impale:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_OVERRIDE_ANIMATION,
    }
end

function modifier_caravan_aghanim_spear_impale:GetOverrideAnimation()
    return ACT_DOTA_FLAIL
end

function modifier_caravan_aghanim_spear_impale:Pin(duration)
    self.pinned = true
    self:StartIntervalThink(-1)
    if duration and duration > 0 then
        self:SetDuration(duration, true)
    end
end

function modifier_caravan_aghanim_spear_impale:FollowDummy()
    if self.pinned then
        return
    end

    local parent = self:GetParent()
    if not IsValidUnit(parent) then
        self:Destroy()
        return
    end

    if not IsValidUnit(self.dummy) then
        self:Destroy()
        return
    end

    local pos = self.dummy.flyPos or self.dummy:GetAbsOrigin()
    pos.z = GetGroundHeight(pos, parent)
    parent:SetAbsOrigin(pos)
end

function modifier_caravan_aghanim_spear_impale:UpdateHorizontalMotion(me, dt)
    self:FollowDummy()
end

function modifier_caravan_aghanim_spear_impale:OnHorizontalMotionInterrupted()
    if IsServer() and not self.pinned then
        self:Destroy()
    end
end

function modifier_caravan_aghanim_spear_impale:OnIntervalThink()
    self:FollowDummy()
end
