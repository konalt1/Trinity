require("map_modifications/Bosses/caravan/caravan_event")

local WAYPOINT_REACH_DISTANCE = 100
local CAST_RADIUS = 1800

local ABILITY_ROTATION = {
    "caravan_aghanim_spears",
}

local function IsUsable(ability)
    return ability and ability:GetLevel() > 0 and ability:IsFullyCastable()
end

local function FindEnemyHeroes(radius)
    local enemies = FindUnitsInRadius(
        thisEntity:GetTeamNumber(),
        thisEntity:GetAbsOrigin(),
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        FIND_CLOSEST,
        false
    )

    local heroes = {}
    for _, enemy in ipairs(enemies) do
        if enemy and not enemy:IsNull() and enemy:IsAlive() and enemy:IsRealHero() then
            table.insert(heroes, enemy)
        end
    end
    return heroes
end

local function FinishPathway()
    if CourierCaravan and thisEntity.caravanPack then
        CourierCaravan:DespawnPack(thisEntity.caravanPack)
    else
        UTIL_Remove(thisEntity)
    end
end

local function MoveAlongPathway()
    if not thisEntity.pathwayEnabled then
        return 0.35
    end

    local path = thisEntity.caravanPath
    if not path or #path == 0 then
        return 0.35
    end

    local index = thisEntity.currentWaypointIndex or 1
    local waypointPosition = path[index]
    if not waypointPosition then
        return 0.35
    end

    if (thisEntity:GetAbsOrigin() - waypointPosition):Length2D() < WAYPOINT_REACH_DISTANCE then
        if index >= #path then
            if #path >= 2 then
                FinishPathway()
                return nil
            end
            return 0.35
        end

        thisEntity.currentWaypointIndex = index + 1
        waypointPosition = path[thisEntity.currentWaypointIndex]
        if not waypointPosition then
            FinishPathway()
            return nil
        end
    end

    thisEntity:MoveToPosition(waypointPosition)
    return 0.35
end

local function TryCastRotation()
    local now = GameRules:GetGameTime()
    if now < (thisEntity.caravanAbilityBusyUntil or 0) then
        return false
    end

    if now < (thisEntity.caravanNextCastTime or 0) then
        return false
    end

    local heroes = FindEnemyHeroes(CAST_RADIUS)
    if #heroes == 0 then
        return false
    end

    local index = thisEntity.caravanAbilityIndex or 1
    local abilityName = ABILITY_ROTATION[index]
    local ability = abilityName and thisEntity:FindAbilityByName(abilityName) or nil
    if not IsUsable(ability) then
        thisEntity.caravanAbilityIndex = (index % #ABILITY_ROTATION) + 1
        return false
    end

    thisEntity:Stop()
    thisEntity:CastAbilityNoTarget(ability, -1)
    thisEntity.caravanAbilityIndex = (index % #ABILITY_ROTATION) + 1
    return true
end

function Spawn(entityKeyValues)
    if not IsServer() or not thisEntity or not IsValidEntity(thisEntity) then
        return
    end

    thisEntity.currentWaypointIndex = thisEntity.currentWaypointIndex or 1
    thisEntity.caravanAbilityIndex = thisEntity.caravanAbilityIndex or 1
    thisEntity.caravanNextCastTime = thisEntity.caravanNextCastTime or (GameRules:GetGameTime() + 2)
    thisEntity:StartGesture(ACT_DOTA_SPAWN)
    thisEntity:SetContextThink("CaravanAghanimBehavior", CaravanAghanimBehavior, 0.25)
end

function CaravanAghanimBehavior()
    if not thisEntity or not IsValidEntity(thisEntity) or not thisEntity:IsAlive() then
        return nil
    end

    if GameRules:IsGamePaused() then
        return 0.25
    end

    if thisEntity:IsChanneling() or thisEntity:GetCurrentActiveAbility() then
        return 0.1
    end

    if GameRules:GetGameTime() < (thisEntity.caravanAbilityBusyUntil or 0) then
        return 0.1
    end

    if TryCastRotation() then
        return 0.2
    end

    return MoveAlongPathway()
end
