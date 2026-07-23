ChenBuildingPlacement = ChenBuildingPlacement or {}

ChenBuildingPlacement.ERROR_KEY = "#dota_hud_error_chen_building_too_close"

local CHEN_BUILDING_UNITS = {
    npc_chen_barrack = true,
    npc_chen_building_tower = true,
    npc_chen_building_courier_barrack = true,
    npc_chen_building_dragon_barrack = true,
}

local function IsValidEntity(entity)
    return entity and not entity:IsNull()
end

local function IsBuildingEntity(entity)
    if entity.IsBuilding and entity:IsBuilding() then
        return true
    end

    return entity.GetUnitName and CHEN_BUILDING_UNITS[entity:GetUnitName()] == true
end

function ChenBuildingPlacement.FindNearbyBuilding(position, radius, excludedEntity)
    if not position or not Entities or not Entities.FindAllInSphere then
        return nil
    end

    radius = math.max(0, tonumber(radius) or 0)
    local nearbyEntities = Entities:FindAllInSphere(position, radius)
    for _, entity in pairs(nearbyEntities or {}) do
        if entity ~= excludedEntity
            and IsValidEntity(entity)
            and IsBuildingEntity(entity)
            and (not entity.IsAlive or entity:IsAlive()) then
            return entity
        end
    end

    return nil
end

function ChenBuildingPlacement.IsPositionClear(position, radius, excludedEntity)
    return ChenBuildingPlacement.FindNearbyBuilding(position, radius, excludedEntity) == nil
end

function ChenBuildingPlacement.IsLandingPositionClear(position, radius, excludedEntity)
    if not position or not ChenBuildingPlacement.IsPositionClear(position, radius, excludedEntity) then
        return false
    end

    if GridNav then
        if GridNav.IsTraversable and not GridNav:IsTraversable(position) then
            return false
        end
        if GridNav.IsBlocked and GridNav:IsBlocked(position) then
            return false
        end
        if GridNav.GetAllTreesAroundPoint then
            local trees = GridNav:GetAllTreesAroundPoint(position, 160, true)
            if trees and #trees > 0 then
                return false
            end
        end
    end

    return true
end

function ChenBuildingPlacement.NotifyError(caster, errorKey)
    if not IsServer() or not IsValidEntity(caster) then
        return
    end

    local playerID = caster:GetPlayerOwnerID()
    if playerID == nil or playerID < 0 then
        return
    end

    local player = PlayerResource:GetPlayer(playerID)
    if player then
        CustomGameEventManager:Send_ServerToPlayer(player, "dota_hud_error_message", {
            message = errorKey or ChenBuildingPlacement.ERROR_KEY,
            reason = 80,
            sequenceNumber = 0,
        })
    end
end

return ChenBuildingPlacement
