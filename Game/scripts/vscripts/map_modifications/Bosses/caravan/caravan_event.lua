CourierCaravan = CourierCaravan or {}

require("map_modifications/Bosses/caravan/caravan_assets")
require("map_modifications/Bosses/caravan/caravan_loot")

LinkLuaModifier(
    "modifier_caravan_aghanim_leash",
    "map_modifications/Bosses/caravan/caravan_modifiers",
    LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
    "modifier_caravan_courier",
    "map_modifications/Bosses/caravan/caravan_modifiers",
    LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
    "modifier_caravan_global_vision",
    "map_modifications/Bosses/caravan/caravan_modifiers",
    LUA_MODIFIER_MOTION_NONE
)

local AGHANIM_NAME = "npc_caravan_aghanim"
local MORTIMER_NAME = "npc_mortimer_boss"
local MORTIMER_FINALE_NAME = "npc_mortimer_boss_finale"
local VISION_DURATION = 5.0
local VISION_RADIUS = 800
local FOLLOW_RADIUS = 420
local LEASH_RADIUS = 700
local FLEE_DURATION = 2.5
local FLEE_DISTANCE = 450
local CAST_PAUSE = 2.0
local DEBUG_VISION_RADIUS = 800
local DEBUG_VISION_DURATION = 5

local SLOT_BUSY_NAMES = {
    [MORTIMER_NAME] = true,
    [MORTIMER_FINALE_NAME] = true,
    [AGHANIM_NAME] = true,
}

local MORTIMER_WAYPOINTS = {
    "Roshan_pathway",
    "Roshan_pathway_2",
    "Roshan_pathway_final",
}

-- new2 overview is ~±6720. Roshan_pathway_final at (-8309, 8312) is a leftover off the map.
local PLAYABLE_HALF = 7000
local CARAVAN_SPAWN = Vector(-6017, 6017, 0)

local function OriginOnMap(origin)
    return origin ~= nil
        and math.abs(origin.x) <= PLAYABLE_HALF
        and math.abs(origin.y) <= PLAYABLE_HALF
end

local function CollectNamed(name)
    local list = {}
    local seen = {}

    local function add(entity)
        if not entity or (entity.IsNull and entity:IsNull()) then
            return
        end
        local id = entity.entindex and entity:entindex() or tostring(entity)
        if seen[id] then
            return
        end
        seen[id] = true
        table.insert(list, entity)
    end

    for _, entity in ipairs(Entities:FindAllByName(name) or {}) do
        add(entity)
    end
    add(Entities:FindByName(nil, name))

    return list
end

local function PickClosestOnMap(name, nearOrigin)
    local best, bestDist = nil, math.huge

    for _, entity in ipairs(CollectNamed(name)) do
        local origin = entity:GetAbsOrigin()
        if OriginOnMap(origin) then
            local dist = (origin - nearOrigin):Length2D()
            if dist < bestDist then
                best, bestDist = entity, dist
            end
        else
            print(string.format(
                "[CourierCaravan] Skip off-map %s (%.0f %.0f %.0f)",
                name,
                origin.x,
                origin.y,
                origin.z
            ))
        end
    end

    return best
end

local function GroundOrigin(entity)
    local origin = entity:GetAbsOrigin()
    if GetGroundPosition then
        origin = GetGroundPosition(origin, nil)
    end
    return origin
end

function CourierCaravan.GetMortimerPath(spawnerOrigin)
    local points = {}
    local near = spawnerOrigin or Vector(0, 0, 128)

    for _, name in ipairs(MORTIMER_WAYPOINTS) do
        local entity = PickClosestOnMap(name, near)
        if entity then
            local origin = GroundOrigin(entity)
            table.insert(points, origin)
            near = origin
            print(string.format(
                "[CourierCaravan] On-map waypoint %s -> (%.0f %.0f %.0f)",
                name,
                origin.x,
                origin.y,
                origin.z
            ))
        end
    end

    return points
end

function CourierCaravan.GetReversePath(endOrigin)
    local forward = CourierCaravan.GetMortimerPath(endOrigin)
    local spawn = CARAVAN_SPAWN
    if GetGroundPosition then
        spawn = GetGroundPosition(spawn, nil)
    end

    local points = { spawn }
    for i = #forward, 1, -1 do
        local origin = forward[i]
        if (origin - spawn):Length2D() > 150 then
            table.insert(points, origin)
        end
    end

    if endOrigin then
        local last = points[#points]
        if not last or (last - endOrigin):Length2D() > 200 then
            table.insert(points, endOrigin)
        end
    end

    return points
end

local function IsAlive(unit)
    return unit and not unit:IsNull() and IsValidEntity(unit) and unit:IsAlive()
end

local function ParsePosition(x, y, z)
    if x and y and z then
        return Vector(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 128)
    end

    local hero = PlayerResource:GetSelectedHeroEntity(0)
    if hero then
        return hero:GetAbsOrigin() + hero:GetForwardVector() * 350
    end

    return Vector(0, 0, 128)
end

local function Announce(unit, token)
    if not IsAlive(unit) then
        return
    end

    local spawnPosition = unit:GetAbsOrigin()
    FireGameEvent("draw_game_event", {
        color = "#c9a6ff",
        duration = 3,
        sound_event = "_game_events.template_sound_event",
        text_token = token,
    })
    AddFOWViewer(DOTA_TEAM_GOODGUYS, spawnPosition, VISION_RADIUS, VISION_DURATION, false)
    AddFOWViewer(DOTA_TEAM_BADGUYS, spawnPosition, VISION_RADIUS, VISION_DURATION, false)
    GameRules:ExecuteTeamPing(DOTA_TEAM_GOODGUYS, spawnPosition.x, spawnPosition.y, unit, 0)
    GameRules:ExecuteTeamPing(DOTA_TEAM_BADGUYS, spawnPosition.x, spawnPosition.y, unit, 0)
end

local function ApplyHits(unit, hits)
    if not IsAlive(unit) or not hits then
        return
    end

    hits = math.max(1, math.floor(tonumber(hits) or 1))
    unit:SetBaseMaxHealth(hits)
    unit:SetMaxHealth(hits)
    unit:SetHealth(hits)
end

local function LaunchWorldItem(itemName, origin, autoUse)
    local item = CreateItem(itemName, nil, nil)
    if not item then
        print("[CourierCaravan] Failed to create item " .. tostring(itemName))
        return
    end

    item:SetPurchaseTime(0)
    local drop = CreateItemOnPositionForLaunch(origin, item)
    local dest = origin + RandomVector(RandomFloat(60, 120))
    item:LaunchLootInitialHeight(autoUse == true, 0, 150, 0.5, dest)
    if drop and drop.SetAbsOrigin then
        -- Launch already moves the drop; keep a reference so GC does not eat it.
    end
end

function CourierCaravan.IsPathwaySlotBusy()
    local creatures = Entities:FindAllByClassname("npc_dota_creature") or {}
    for _, unit in ipairs(creatures) do
        if IsAlive(unit) and SLOT_BUSY_NAMES[unit:GetUnitName()] then
            return true
        end
    end

    return false
end

function CourierCaravan:GetFollowSlotCount(aghanim)
    local pack = aghanim and aghanim.caravanPack
    if pack and pack.couriers and #pack.couriers > 0 then
        return #pack.couriers
    end
    return (CaravanLoot and CaravanLoot.PICK_COUNT) or 10
end

function CourierCaravan:GetFollowAngleStep(aghanim)
    return 360 / math.max(self:GetFollowSlotCount(aghanim), 1)
end

function CourierCaravan:IsAghanimStationary(aghanim)
    if not IsAlive(aghanim) then
        return true
    end

    if aghanim:IsChanneling() then
        return true
    end

    if aghanim.GetCurrentActiveAbility and aghanim:GetCurrentActiveAbility() then
        return true
    end

    if GameRules:GetGameTime() < (aghanim.caravanAbilityBusyUntil or 0) then
        return true
    end

    if aghanim.IsMoving then
        return not aghanim:IsMoving()
    end

    return true
end

function CourierCaravan:GetFollowPosition(aghanim, slotIndex)
    if not IsAlive(aghanim) then
        return Vector(0, 0, 0)
    end

    local pack = aghanim.caravanPack
    local forward
    if self:IsAghanimStationary(aghanim) then
        forward = (pack and pack.followForward) or aghanim:GetForwardVector()
        if pack and not pack.followForward then
            pack.followForward = forward
        end
    else
        forward = aghanim:GetForwardVector()
        if pack then
            pack.followForward = forward
        end
    end

    local rotated = RotatePosition(
        Vector(0, 0, 0),
        QAngle(0, (slotIndex - 1) * self:GetFollowAngleStep(aghanim), 0),
        forward
    )
    return aghanim:GetAbsOrigin() + rotated * FOLLOW_RADIUS
end

function CourierCaravan:OnCourierDamaged(courier, attacker)
    if not IsAlive(courier) or not IsAlive(attacker) then
        return
    end

    local pack = courier.caravanPack
    if not pack or pack.escaping then
        return
    end

    pack.fleeUntil = GameRules:GetGameTime() + FLEE_DURATION
    pack.fleeFrom = attacker:GetAbsOrigin()
end

function CourierCaravan:GetFleePosition(courier)
    local pack = courier and courier.caravanPack
    if not pack or not pack.fleeFrom then
        return nil
    end

    local origin = courier:GetAbsOrigin()
    local away = origin - pack.fleeFrom
    away.z = 0
    if away:Length2D() < 1 then
        away = courier:GetForwardVector()
        away.z = 0
    end

    return origin + away:Normalized() * FLEE_DISTANCE
end

function CourierCaravan:IsFleeing(courier)
    local pack = courier and courier.caravanPack
    if not pack or pack.escaping then
        return false
    end

    return GameRules:GetGameTime() < (pack.fleeUntil or 0)
end

function CourierCaravan:DropCourierLoot(courier)
    if not courier or courier:IsNull() or courier.caravanEscaping then
        return
    end

    local id = courier.caravanId
    local stage = courier.caravanStage or 1
    local data = CaravanLoot:GetStageData(id, stage)
    if not data then
        return
    end

    local origin = courier:GetAbsOrigin()
    for _, entry in ipairs(data.items) do
        local count = entry.count or 1
        for _ = 1, count do
            LaunchWorldItem(entry.name, origin, false)
        end
    end

    local bagCount = data.gold_bags or 1
    for _ = 1, bagCount do
        local bag = CreateItem("item_caravan_gold_bag", nil, nil)
        if bag then
            bag:SetPurchaseTime(0)
            bag:SetCurrentCharges(CaravanLoot.GOLD_PER_BAG)
            CreateItemOnPositionForLaunch(origin, bag)
            bag:LaunchLootInitialHeight(true, 0, 150, 0.5, origin + RandomVector(RandomFloat(50, 110)))
        end
    end
end

function CourierCaravan:OnEntityKilled(unit)
    if not unit or unit:IsNull() then
        return
    end

    if unit.caravanId and not unit.caravanEscaping then
        self:DropCourierLoot(unit)
    end
end

function CourierCaravan:MarkAghanimBusy(caster, duration)
    if not caster or caster:IsNull() then
        return
    end

    caster.caravanAbilityBusyUntil = GameRules:GetGameTime() + (duration or 0)
end

function CourierCaravan:FinishAghanimCast(caster)
    if not caster or caster:IsNull() then
        return
    end

    caster.caravanAbilityBusyUntil = 0
    caster.caravanNextCastTime = GameRules:GetGameTime() + CAST_PAUSE
end

function CourierCaravan:DespawnPack(pack)
    if not pack then
        return
    end

    pack.escaping = true
    for _, courier in ipairs(pack.couriers or {}) do
        if courier and not courier:IsNull() then
            courier.caravanEscaping = true
            UTIL_Remove(courier)
        end
    end

    if pack.aghanim and not pack.aghanim:IsNull() then
        UTIL_Remove(pack.aghanim)
    end
end

function CourierCaravan:SpawnAt(position, stage, pathwayEnabled)
    if not IsServer() then
        return nil
    end

    stage = CaravanLoot:ClampStage(stage)
    local fallback = position or Vector(0, 0, 128)
    local path = nil
    if pathwayEnabled then
        path = self.GetReversePath(fallback)
        if path[1] then
            position = path[1]
        else
            position = fallback
        end
    else
        position = fallback
    end

    local aghanim = CreateUnitByName(AGHANIM_NAME, position, true, nil, nil, DOTA_TEAM_NEUTRALS)
    if not aghanim then
        print("[CourierCaravan] Failed to spawn Aghanim")
        return nil
    end

    FindClearSpaceForUnit(aghanim, position, true)
    aghanim:SetAbsOrigin(GetGroundPosition(aghanim:GetAbsOrigin(), aghanim))
    aghanim:SetBaseMoveSpeed(160)
    position = aghanim:GetAbsOrigin()

    aghanim:AddNewModifier(aghanim, nil, "modifier_invulnerable", {})
    aghanim:AddNewModifier(aghanim, nil, "modifier_phased", {})
    aghanim:AddNewModifier(aghanim, nil, "modifier_caravan_global_vision", {})
    aghanim:SetAngles(0, RandomFloat(0, 360), 0)

    local pack = {
        aghanim = aghanim,
        couriers = {},
        stage = stage,
        pathwayEnabled = pathwayEnabled == true,
        escaping = false,
        fleeUntil = 0,
        fleeFrom = nil,
    }

    aghanim.caravanPack = pack
    aghanim.caravanStage = stage
    aghanim.pathwayEnabled = pack.pathwayEnabled
    aghanim.caravanPath = path
    aghanim.currentWaypointIndex = 1
    aghanim.caravanAbilityIndex = 1
    aghanim.caravanNextCastTime = GameRules:GetGameTime() + 1
    aghanim.caravanAbilityBusyUntil = 0
    pack.followForward = aghanim:GetForwardVector()

    local abilities = {
        aghanim:FindAbilityByName("caravan_aghanim_laser"),
        aghanim:FindAbilityByName("caravan_aghanim_shards"),
        aghanim:FindAbilityByName("caravan_aghanim_spears"),
    }
    for _, ability in ipairs(abilities) do
        if ability then
            ability:SetLevel(1)
            ability:SetActivated(true)
            ability:SetHidden(false)
        end
    end

    local picked = CaravanLoot:PickRandomIds(CaravanLoot.PICK_COUNT)
    local angleStep = self:GetFollowAngleStep(aghanim)
    for slot, id in ipairs(picked) do
        local def = CaravanLoot:GetCourier(id)
        local data = CaravanLoot:GetStageData(id, stage)
        if def and data then
            local offset = RotatePosition(Vector(0, 0, 0), QAngle(0, (slot - 1) * angleStep, 0), Vector(FOLLOW_RADIUS, 0, 0))
            local spawnPos = position + offset
            local courier = CreateUnitByName(def.unit_name, spawnPos, true, nil, nil, DOTA_TEAM_NEUTRALS)
            if courier then
                courier.caravanId = id
                courier.caravanStage = stage
                courier.caravanPack = pack
                courier.caravanAghanim = aghanim
                courier.caravanSlotIndex = slot
                courier.pathwayEnabled = pack.pathwayEnabled
                ApplyHits(courier, data.hits)
                courier:AddNewModifier(courier, nil, "modifier_caravan_courier", { hits = data.hits })
                courier:AddNewModifier(courier, nil, "modifier_caravan_aghanim_leash", { radius = LEASH_RADIUS })
                table.insert(pack.couriers, courier)
            else
                print("[CourierCaravan] Failed to spawn courier " .. tostring(id))
            end
        end
    end

    Announce(aghanim, "#caravan_spawn")
    print("[CourierCaravan] Stage " .. stage .. " spawned with " .. tostring(#pack.couriers) .. " couriers, path points " .. tostring(path and #path or 0))
    return aghanim
end

local function RegisterDebugCommands()
    if _G.COURIER_CARAVAN_COMMANDS_REGISTERED then
        return
    end
    _G.COURIER_CARAVAN_COMMANDS_REGISTERED = true

    -- Flag 0, not FCVAR_CHEAT: the client console otherwise prints
    -- "is not a recognized command" and never reaches the server.
    Convars:RegisterCommand("spawn_caravan", function(_, x, y, z)
        if not IsServer() then
            return
        end

        local position = ParsePosition(x, y, z)
        local aghanim = CourierCaravan:SpawnAt(position, 1, false)
        if aghanim then
            AddFOWViewer(DOTA_TEAM_GOODGUYS, position, DEBUG_VISION_RADIUS, DEBUG_VISION_DURATION, false)
            AddFOWViewer(DOTA_TEAM_BADGUYS, position, DEBUG_VISION_RADIUS, DEBUG_VISION_DURATION, false)
        end
    end, "Spawn courier caravan: spawn_caravan [x y z]", 0)

    Convars:RegisterCommand("spawn_caravan_stage", function(_, stage, x, y, z)
        if not IsServer() then
            return
        end

        local position = ParsePosition(x, y, z)
        local aghanim = CourierCaravan:SpawnAt(position, stage, false)
        if aghanim then
            AddFOWViewer(DOTA_TEAM_GOODGUYS, position, DEBUG_VISION_RADIUS, DEBUG_VISION_DURATION, false)
            AddFOWViewer(DOTA_TEAM_BADGUYS, position, DEBUG_VISION_RADIUS, DEBUG_VISION_DURATION, false)
        end
    end, "Spawn courier caravan at stage: spawn_caravan_stage N [x y z]", 0)
end

function CourierCaravan:Init()
    RegisterDebugCommands()
end

RegisterDebugCommands()

return CourierCaravan
