-- Shared pathway slot: Courier Caravan and Mortimer alternate.

require("map_modifications/Bosses/mortimer_level_scaling")
require("map_modifications/Bosses/caravan/caravan_event")

-- Debug first spawn: 1:00 after horn. Production target is 10:00 (600).
local SPAWN_INTERVAL = 300
local FIRST_SPAWN_TIME = 60
local BOSS_UNIT_NAME = "npc_mortimer_boss"
local VISION_DURATION = 5.0
local VISION_RADIUS = 800

function Spawn(entityKeyValues)
    thisEntity.eventIndex = 0
    thisEntity.caravanStage = 0
    thisEntity.mortimerLevel = 0
    thisEntity.firstSpawnPending = true
    thisEntity:AddNewModifier(thisEntity, nil, "modifier_invulnerable", {})

    Timers:CreateTimer(0.1, function()
        return SpawnBossLoop()
    end)
end

local function AnnounceMortimer(boss, spawnPosition)
    FireGameEvent("draw_game_event", {
        color = "#a1e4ff",
        duration = 3,
        sound_event = "_game_events.template_sound_event",
        text_token = "#mortimer_spawn",
    })

    AddFOWViewer(DOTA_TEAM_GOODGUYS, spawnPosition, VISION_RADIUS, VISION_DURATION, false)
    AddFOWViewer(DOTA_TEAM_BADGUYS, spawnPosition, VISION_RADIUS, VISION_DURATION, false)
    GameRules:ExecuteTeamPing(DOTA_TEAM_GOODGUYS, spawnPosition.x, spawnPosition.y, boss, 0)
    GameRules:ExecuteTeamPing(DOTA_TEAM_BADGUYS, spawnPosition.x, spawnPosition.y, boss, 0)
    EmitSoundOn("Hero_Snapfire.MortimerGrunt", boss)
end

local function SpawnMortimer(spawnPosition, level)
    local boss = CreateUnitByName(
        BOSS_UNIT_NAME,
        spawnPosition,
        true,
        nil,
        nil,
        DOTA_TEAM_NEUTRALS
    )

    if not boss then
        print("[PathwaySpawner] Failed to spawn Mortimer.")
        return false
    end

    boss.spawnNumber = level
    MortimerLevelScaling:ApplyToBoss(boss, level)
    boss.pathwayEnabled = true
    boss:RemoveModifierByName("modifier_invulnerable")
    boss:SetAngles(0, RandomFloat(0, 360), 0)
    AnnounceMortimer(boss, spawnPosition)
    print("[PathwaySpawner] Mortimer level " .. level .. " spawned at " .. tostring(spawnPosition))
    return true
end

function SpawnBossLoop()
    if not thisEntity or not IsValidEntity(thisEntity) or not thisEntity:IsAlive() then
        print("[PathwaySpawner] Spawner is no longer valid; stopping.")
        return nil
    end

    if GameRules:State_Get() < DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
        return 0.5
    end

    local dotaTime = GameRules:GetDOTATime(false, false)
    if dotaTime < FIRST_SPAWN_TIME then
        return 0.5
    end

    if CourierCaravan.IsPathwaySlotBusy() then
        return 1.0
    end

    local spawnPosition = thisEntity:GetAbsOrigin()
    thisEntity.eventIndex = (thisEntity.eventIndex or 0) + 1

    local spawned = false
    if thisEntity.eventIndex % 2 == 1 then
        thisEntity.caravanStage = math.min(3, (thisEntity.caravanStage or 0) + 1)
        local aghanim = CourierCaravan:SpawnAt(spawnPosition, thisEntity.caravanStage, true)
        spawned = aghanim ~= nil
        if not spawned then
            thisEntity.eventIndex = thisEntity.eventIndex - 1
            thisEntity.caravanStage = math.max(0, thisEntity.caravanStage - 1)
            print("[PathwaySpawner] Failed to spawn caravan.")
            return 1.0
        end
        local origin = aghanim:GetAbsOrigin()
        print(string.format(
            "[PathwaySpawner] Caravan stage %d at (%.0f %.0f %.0f) dota=%.1f",
            thisEntity.caravanStage,
            origin.x,
            origin.y,
            origin.z,
            dotaTime
        ))
    else
        thisEntity.mortimerLevel = (thisEntity.mortimerLevel or 0) + 1
        spawned = SpawnMortimer(spawnPosition, thisEntity.mortimerLevel)
        if not spawned then
            thisEntity.eventIndex = thisEntity.eventIndex - 1
            thisEntity.mortimerLevel = math.max(0, thisEntity.mortimerLevel - 1)
            return 1.0
        end
    end

    thisEntity.firstSpawnPending = false
    return SPAWN_INTERVAL
end
