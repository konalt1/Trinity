-- Spawns Mortimer from the map's existing Roshan pathway spawner.

require("map_modifications/Bosses/mortimer_level_scaling")

local SPAWN_INTERVAL = 360
local FIRST_SPAWN_TIME = 600
local BOSS_UNIT_NAME = "npc_mortimer_boss"
local VISION_DURATION = 5.0
local VISION_RADIUS = 800

function Spawn(entityKeyValues)
    thisEntity.spawnCount = 0
    thisEntity.firstSpawnPending = true
    thisEntity:AddNewModifier(thisEntity, nil, "modifier_invulnerable", {})

    Timers:CreateTimer(0.1, function()
        return SpawnBossLoop()
    end)
end

function SpawnBossLoop()
    if not thisEntity or not IsValidEntity(thisEntity) or not thisEntity:IsAlive() then
        print("[MortimerSpawner] Spawner is no longer valid; stopping.")
        return nil
    end

    local dotaTime = GameRules:GetDOTATime(false, false)
    if thisEntity.firstSpawnPending and dotaTime < FIRST_SPAWN_TIME then
        return math.max(0.25, FIRST_SPAWN_TIME - dotaTime)
    end

    local spawnPosition = thisEntity:GetAbsOrigin()
    local boss = CreateUnitByName(
        BOSS_UNIT_NAME,
        spawnPosition,
        true,
        nil,
        nil,
        DOTA_TEAM_NEUTRALS
    )

    if not boss then
        print("[MortimerSpawner] Failed to spawn Mortimer.")
        return SPAWN_INTERVAL
    end

    thisEntity.firstSpawnPending = false
    thisEntity.spawnCount = (thisEntity.spawnCount or 0) + 1

    boss.spawnNumber = thisEntity.spawnCount
    MortimerLevelScaling:ApplyToBoss(boss, boss.spawnNumber)
    boss.pathwayEnabled = true
    boss:RemoveModifierByName("modifier_invulnerable")
    boss:SetAngles(0, RandomFloat(0, 360), 0)

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

    print("[MortimerSpawner] Mortimer level " .. boss.spawnNumber .. " spawned at " .. tostring(spawnPosition))
    return SPAWN_INTERVAL
end
