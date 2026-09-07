require("map_modifications/Bosses/caravan/caravan_event")

local WAYPOINT_REACH_DISTANCE = 100
local CAST_RADIUS_PADDING = 200

local ABILITY_ROTATION = {
    "caravan_aghanim_spears",
    "caravan_aghanim_shards",
    "caravan_aghanim_laser",
}

local function IsUsable(ability)
    return ability and ability:GetLevel() > 0 and ability:IsFullyCastable()
end

local function GetCastRadius()
    local ability = thisEntity:FindAbilityByName("caravan_aghanim_shards")
    local orbit = 800
    if ability and ability.GetSpecialValueFor then
        local value = ability:GetSpecialValueFor("orbit_radius")
        if value and value > 0 then
            orbit = value
        end
    end
    return orbit + CAST_RADIUS_PADDING
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

local function IsRetreating()
    if CourierCaravan and CourierCaravan.IsAghanimRetreating then
        return CourierCaravan:IsAghanimRetreating(thisEntity)
    end

    return thisEntity.caravanRetreating == true
        or (thisEntity.caravanPack and thisEntity.caravanPack.retreating == true)
end

local function MaybeStartRetreat()
    if IsRetreating() then
        return
    end

    local pack = thisEntity.caravanPack
    if not pack or pack.escaping or not pack.couriers or #pack.couriers == 0 then
        return
    end

    if CourierCaravan:CountAliveCouriers(pack) == 0 then
        if CourierCaravan.RetreatDebug then
            CourierCaravan:RetreatDebug("AI poll: 0 alive couriers, starting retreat")
        end
        CourierCaravan:StartAghanimRetreat(pack)
    end
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
        local retreating = IsRetreating()
        if retreating then
            if index <= 1 then
                if CourierCaravan and CourierCaravan.RetreatDebug then
                    CourierCaravan:RetreatDebug("reached spawn waypoint, despawn")
                end
                FinishPathway()
                return nil
            end

            thisEntity.currentWaypointIndex = index - 1
            waypointPosition = path[thisEntity.currentWaypointIndex]
            if not waypointPosition then
                FinishPathway()
                return nil
            end
        elseif index >= #path then
            if #path >= 2 then
                FinishPathway()
                return nil
            end
            return 0.35
        else
            thisEntity.currentWaypointIndex = index + 1
            waypointPosition = path[thisEntity.currentWaypointIndex]
            if not waypointPosition then
                FinishPathway()
                return nil
            end
        end
    end

    thisEntity:MoveToPosition(waypointPosition)
    if IsRetreating() then
        if CourierCaravan then
            local now = GameRules:GetGameTime()
            local wp = thisEntity.currentWaypointIndex or 0
            local lastWp = thisEntity.caravanRetreatLogWp
            local lastTime = thisEntity.caravanRetreatLogTime or 0
            if lastWp ~= wp or (now - lastTime) >= 0.5 then
                thisEntity.caravanRetreatLogWp = wp
                thisEntity.caravanRetreatLogTime = now
                local speed = thisEntity.GetIdealSpeed and thisEntity:GetIdealSpeed() or thisEntity:GetBaseMoveSpeed()
                CourierCaravan:RetreatDebug(
                    "move wp=%d/%d dist=%.0f speed=%.0f dest=%.0f %.0f",
                    wp,
                    #path,
                    (thisEntity:GetAbsOrigin() - waypointPosition):Length2D(),
                    speed or 0,
                    waypointPosition.x,
                    waypointPosition.y
                )
            end
            CourierCaravan:DrawRetreatDebug(thisEntity, waypointPosition)
        end
        return 0.1
    end
    return 0.35
end

local function TryCastRotation()
    if IsRetreating() then
        return false
    end

    local now = GameRules:GetGameTime()
    if now < (thisEntity.caravanAbilityBusyUntil or 0) then
        return false
    end

    if now < (thisEntity.caravanNextCastTime or 0) then
        return false
    end

    local heroes = FindEnemyHeroes(GetCastRadius())
    if #heroes == 0 then
        return false
    end

    local index = thisEntity.caravanAbilityIndex or 1
    local abilityName = ABILITY_ROTATION[index]
    if abilityName == "caravan_aghanim_shards"
        and thisEntity:HasModifier("modifier_caravan_aghanim_shards")
    then
        thisEntity.caravanAbilityIndex = (index % #ABILITY_ROTATION) + 1
        return false
    end

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

    MaybeStartRetreat()

    if IsRetreating() then
        if thisEntity:IsChanneling() or thisEntity:GetCurrentActiveAbility() then
            thisEntity:Stop()
        end
        thisEntity.caravanAbilityBusyUntil = 0
        return MoveAlongPathway()
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
