-- Shared pathway slot: Caravan, Mortimer and Primal Beast.

require("map_modifications/Bosses/mortimer_level_scaling")
require("map_modifications/Bosses/caravan/caravan_event")
require("map_modifications/Bosses/primal_beast/primal_beast_boss")

-- First event at 7:00 after horn, then every 7 minutes.
-- Wave comes from the clock, not from how often this boss already spawned.
local SPAWN_INTERVAL = 420
local FIRST_SPAWN_TIME = 420
local MAX_WAVE = 5
local BOSS_TYPES = {
    "caravan",
    "mortimer",
    "primal_beast",
}
local BOSS_UNIT_NAME = "npc_mortimer_boss"
local PRIMAL_BEAST_NAME = "npc_primal_beast_boss"
local VISION_DURATION = 5.0
local VISION_RADIUS = 800

local function GetWave(dotaTime)
    local wave = math.floor((tonumber(dotaTime) or 0) / SPAWN_INTERVAL)
    if wave < 1 then
        wave = 1
    end
    return math.min(MAX_WAVE, wave)
end

local function PickBossType()
    return BOSS_TYPES[RandomInt(1, #BOSS_TYPES)]
end

function Spawn(entityKeyValues)
    thisEntity.nextSpawnTime = FIRST_SPAWN_TIME
    thisEntity:AddNewModifier(thisEntity, nil, "modifier_invulnerable", {})

    Timers:CreateTimer(0.1, function()
        return SpawnBossLoop()
    end)
end

local function AnnounceBoss(boss, spawnPosition, token, sound)
    FireGameEvent("draw_game_event", {
        color = "#a1e4ff",
        duration = 3,
        sound_event = "_game_events.template_sound_event",
        text_token = token,
    })

    AddFOWViewer(DOTA_TEAM_GOODGUYS, spawnPosition, VISION_RADIUS, VISION_DURATION, false)
    AddFOWViewer(DOTA_TEAM_BADGUYS, spawnPosition, VISION_RADIUS, VISION_DURATION, false)
    GameRules:ExecuteTeamPing(DOTA_TEAM_GOODGUYS, spawnPosition.x, spawnPosition.y, boss, 0)
    GameRules:ExecuteTeamPing(DOTA_TEAM_BADGUYS, spawnPosition.x, spawnPosition.y, boss, 0)
    if sound then
        EmitSoundOn(sound, boss)
    end
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
    AnnounceBoss(boss, spawnPosition, "#mortimer_spawn", "Hero_Snapfire.MortimerGrunt")
    print("[PathwaySpawner] Mortimer level " .. level .. " spawned at " .. tostring(spawnPosition))
    return true
end

local function SpawnPrimalBeast(spawnPosition, level)
    local boss = CreateUnitByName(
        PRIMAL_BEAST_NAME,
        spawnPosition,
        true,
        nil,
        nil,
        DOTA_TEAM_NEUTRALS
    )

    if not boss then
        print("[PathwaySpawner] Failed to spawn Primal Beast.")
        return false
    end

    if PrimalBeastBoss then
        PrimalBeastBoss:PrepareHostile(boss, level, true)
    else
        boss.spawnNumber = level
        boss.pathwayEnabled = true
        boss:RemoveModifierByName("modifier_invulnerable")
    end
    boss:SetAngles(0, RandomFloat(0, 360), 0)
    AnnounceBoss(boss, spawnPosition, "#primal_beast_spawn", "Hero_PrimalBeast.Attack")
    print("[PathwaySpawner] Primal Beast level " .. level .. " spawned at " .. tostring(spawnPosition))
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
    local nextSpawn = thisEntity.nextSpawnTime or FIRST_SPAWN_TIME
    if dotaTime < nextSpawn then
        return 0.5
    end

    if CourierCaravan.IsPathwaySlotBusy() then
        return 1.0
    end

    local wave = GetWave(dotaTime)
    local bossType = PickBossType()
    local spawnPosition = thisEntity:GetAbsOrigin()
    local spawned = false

    if bossType == "caravan" then
        local aghanim = CourierCaravan:SpawnAt(spawnPosition, wave, true)
        spawned = aghanim ~= nil
        if spawned then
            local origin = aghanim:GetAbsOrigin()
            print(string.format(
                "[PathwaySpawner] Caravan stage %d wave %d at (%.0f %.0f %.0f) dota=%.1f",
                aghanim.caravanStage or wave,
                wave,
                origin.x,
                origin.y,
                origin.z,
                dotaTime
            ))
        else
            print("[PathwaySpawner] Failed to spawn caravan.")
        end
    elseif bossType == "mortimer" then
        spawned = SpawnMortimer(spawnPosition, wave)
    else
        spawned = SpawnPrimalBeast(spawnPosition, wave)
    end

    if not spawned then
        return 1.0
    end

    thisEntity.nextSpawnTime = math.floor(dotaTime / SPAWN_INTERVAL) * SPAWN_INTERVAL + SPAWN_INTERVAL
    return 0.5
end
