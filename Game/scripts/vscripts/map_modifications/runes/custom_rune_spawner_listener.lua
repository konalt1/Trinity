--[[
    Custom Rune Spawner Listener

    Спавн-политика:
    - 0:00  -> Bounty
    - 2:00  -> Water
    - До 4:59 -> Water
    - 5:00+ -> Random Powerup (первый фактический рандомный спавн на ближайшем тике)

    Спавн идёт на координатах самого юнита-слушателя.
]]

local THINK_INTERVAL = 0.25
local SPAWN_INTERVAL = 120
local FIRST_SPAWN_TIME = 0
local RANDOM_POWERUP_START_TIME = 300
local RUNE_SEARCH_RADIUS = 220

local state = {
    spawn_index = 0,
    next_spawn_time = FIRST_SPAWN_TIME,
}

local function IsValidRuneType(runeType)
    return runeType ~= nil
end

local function BuildPowerupPool()
    local pool = {}
    local candidates = {
        DOTA_RUNE_DOUBLEDAMAGE,
        DOTA_RUNE_HASTE,
        DOTA_RUNE_ILLUSION,
        DOTA_RUNE_INVISIBILITY,
        DOTA_RUNE_REGENERATION,
        DOTA_RUNE_ARCANE,
        DOTA_RUNE_SHIELD,
    }

    for _, runeType in ipairs(candidates) do
        if IsValidRuneType(runeType) then
            table.insert(pool, runeType)
        end
    end

    return pool
end

local POWERUP_POOL = BuildPowerupPool()

local function RemoveRunesAtPosition(position)
    local toRemove = {}
    local runeEntity = nil

    while true do
        runeEntity = Entities:FindByClassnameWithin(runeEntity, "dota_item_rune", position, RUNE_SEARCH_RADIUS)
        if not runeEntity then
            break
        end

        if IsValidEntity(runeEntity) then
            table.insert(toRemove, runeEntity)
        end
    end

    for _, rune in ipairs(toRemove) do
        UTIL_Remove(rune)
    end
end

local function GetRuneTypeForCurrentTick(spawnIndex, gameTime)
    if spawnIndex == 1 then
        return DOTA_RUNE_BOUNTY
    end

    if spawnIndex == 2 then
        return DOTA_RUNE_WATER
    end

    if gameTime < RANDOM_POWERUP_START_TIME then
        return DOTA_RUNE_WATER
    end

    if #POWERUP_POOL == 0 then
        return DOTA_RUNE_BOUNTY
    end

    return POWERUP_POOL[RandomInt(1, #POWERUP_POOL)]
end

local function PingAllPlayers(position)
    GameRules:ExecuteTeamPing(DOTA_TEAM_GOODGUYS, position.x, position.y, thisEntity, 0)
    GameRules:ExecuteTeamPing(DOTA_TEAM_BADGUYS, position.x, position.y, thisEntity, 0)
end

local function SpawnRunesNow()
    if not thisEntity or not IsValidEntity(thisEntity) then
        return
    end

    local gameTime = GameRules:GetDOTATime(false, false)
    state.spawn_index = state.spawn_index + 1
    local runeType = GetRuneTypeForCurrentTick(state.spawn_index, gameTime)
    local origin = thisEntity:GetAbsOrigin()
    RemoveRunesAtPosition(origin)
    CreateRune(origin, runeType)
    PingAllPlayers(origin)

    print(string.format("[CustomRuneSpawner] Спавн #%d, тип=%s, позиция=%s", state.spawn_index, tostring(runeType), tostring(origin)))
end

function CustomRuneSpawnerThink()
    if not thisEntity or not IsValidEntity(thisEntity) then
        return nil
    end

    -- Защита от любых внешних эффектов: если юнит каким-то образом убили,
    -- сразу поднимаем обратно и возвращаем неуязвимость.
    if not thisEntity:IsAlive() then
        thisEntity:RespawnUnit()
    end

    if not thisEntity:HasModifier("modifier_invulnerable") then
        thisEntity:AddNewModifier(thisEntity, nil, "modifier_invulnerable", {})
    end

    local gameTime = GameRules:GetDOTATime(false, false)
    if gameTime < 0 then
        return THINK_INTERVAL
    end

    if gameTime + 0.01 >= state.next_spawn_time then
        SpawnRunesNow()
        state.next_spawn_time = state.next_spawn_time + SPAWN_INTERVAL

        if state.next_spawn_time <= gameTime then
            state.next_spawn_time = gameTime + SPAWN_INTERVAL
        end
    end

    return THINK_INTERVAL
end

function Spawn(_)
    state.spawn_index = 0
    state.next_spawn_time = FIRST_SPAWN_TIME

    thisEntity:AddNewModifier(thisEntity, nil, "modifier_invulnerable", {})

    print("[CustomRuneSpawner] Инициализирован. Спавн на позиции слушателя.")
    thisEntity:SetContextThink("CustomRuneSpawnerThink", CustomRuneSpawnerThink, THINK_INTERVAL)
end

