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

    local slot = thisEntity.caravanSlotIndex or 1
    local dest = CourierCaravan:GetFollowPosition(aghanim, slot)
    local dist = (thisEntity:GetAbsOrigin() - dest):Length2D()
    CourierCaravan:UpdateCatchUp(thisEntity, dist)

    local leash = CourierCaravan.LEASH_RADIUS or 1100
    local origin = thisEntity:GetAbsOrigin()
    local lastPos = thisEntity.caravanStuckPos
    local moved = lastPos and (origin - lastPos):Length2D() or 999
    thisEntity.caravanStuckPos = origin
    if dist > 180 and moved < 8 then
        thisEntity.caravanStuckThinks = (thisEntity.caravanStuckThinks or 0) + 1
    else
        thisEntity.caravanStuckThinks = 0
    end

    if dist > leash or (thisEntity.caravanStuckThinks or 0) >= 6 then
        print(string.format(
            "[CourierCaravan] Unstuck %s slot=%s dist=%.0f stuck=%s",
            thisEntity:GetUnitName(),
            tostring(slot),
            dist,
            tostring(thisEntity.caravanStuckThinks)
        ))
        CourierCaravan:PlaceCourier(thisEntity, dest)
        thisEntity.caravanStuckThinks = 0
        thisEntity.caravanStuckPos = dest
        return 0.15
    end

    if CourierCaravan:IsFleeing(thisEntity) then
        if dist >= (CourierCaravan.SLOT_MAX_OFFSET or 700) then
            MoveTo(dest)
            return 0.15
        end

        local fleePosition = CourierCaravan:GetFleePosition(thisEntity)
        if fleePosition then
            MoveTo(fleePosition)
            return 0.15
        end
    end

    if CourierCaravan:IsAghanimStationary(aghanim) and dist <= FOLLOW_IDLE_RANGE then
        HoldIdle()
        return 0.3
    end

    MoveTo(dest)
    return 0.2
end
