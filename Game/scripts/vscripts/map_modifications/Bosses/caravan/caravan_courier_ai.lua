require("map_modifications/Bosses/caravan/caravan_event")

local FOLLOW_IDLE_RANGE = 55
local FOLLOW_DEST_REISSUE = 40

function Spawn(entityKeyValues)
    if not IsServer() or not thisEntity or not IsValidEntity(thisEntity) then
        return
    end

    thisEntity:SetContextThink("CaravanCourierBehavior", CaravanCourierBehavior, 0.2)
end

local function HoldIdle()
    if thisEntity.caravanFollowMoving then
        thisEntity:Stop()
        thisEntity.caravanFollowMoving = false
        thisEntity.caravanLastFollowDest = nil
    end
end

local function MoveTo(dest)
    local last = thisEntity.caravanLastFollowDest
    if thisEntity.caravanFollowMoving and last and (last - dest):Length2D() < FOLLOW_DEST_REISSUE then
        return
    end

    thisEntity.caravanFollowMoving = true
    thisEntity.caravanLastFollowDest = dest
    thisEntity:MoveToPosition(dest)
end

function CaravanCourierBehavior()
    if not thisEntity or not IsValidEntity(thisEntity) or not thisEntity:IsAlive() then
        return nil
    end

    if GameRules:IsGamePaused() then
        return 0.25
    end

    local aghanim = thisEntity.caravanAghanim
    if not aghanim or aghanim:IsNull() or not aghanim:IsAlive() then
        thisEntity.caravanEscaping = true
        UTIL_Remove(thisEntity)
        return nil
    end

    if thisEntity.caravanLeashPull then
        MoveTo(aghanim:GetAbsOrigin())
        return 0.15
    end

    if CourierCaravan:IsFleeing(thisEntity) then
        local fleePosition = CourierCaravan:GetFleePosition(thisEntity)
        if fleePosition then
            MoveTo(fleePosition)
            return 0.15
        end
    end

    local slot = thisEntity.caravanSlotIndex or 1
    local dest = CourierCaravan:GetFollowPosition(aghanim, slot)
    local dist = (thisEntity:GetAbsOrigin() - dest):Length2D()

    if CourierCaravan:IsAghanimStationary(aghanim) and dist <= FOLLOW_IDLE_RANGE then
        HoldIdle()
        return 0.3
    end

    MoveTo(dest)
    return 0.2
end
