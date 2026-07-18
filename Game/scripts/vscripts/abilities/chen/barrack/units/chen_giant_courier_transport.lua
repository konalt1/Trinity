chen_giant_courier_transport_load = class({})
chen_giant_courier_transport_unload = class({})
modifier_chen_giant_courier_transport = class({})
modifier_chen_giant_courier_passenger = class({})

local SCRIPT_PATH = "abilities/chen/barrack/units/chen_giant_courier_transport"
local PASSENGER_MODIFIER = "modifier_chen_giant_courier_passenger"

LinkLuaModifier("modifier_chen_giant_courier_transport", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier(PASSENGER_MODIFIER, SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)

local function IsValidEntity(entity)
    return entity and not entity:IsNull()
end

local function GetOwnerPlayerID(unit)
    if not IsValidEntity(unit) then
        return -1
    end
    if unit.GetPlayerOwnerID then
        local playerID = unit:GetPlayerOwnerID()
        if playerID and playerID >= 0 then
            return playerID
        end
    end
    local owner = unit.GetOwner and unit:GetOwner() or nil
    if IsValidEntity(owner) and owner.GetPlayerOwnerID then
        local playerID = owner:GetPlayerOwnerID()
        if playerID and playerID >= 0 then
            return playerID
        end
    end
    return -1
end

local function HasSameOwner(carrier, unit)
    local carrierPlayerID = GetOwnerPlayerID(carrier)
    local unitPlayerID = GetOwnerPlayerID(unit)
    if carrierPlayerID >= 0 and unitPlayerID >= 0 then
        return carrierPlayerID == unitPlayerID
    end
    return carrier:GetOwner() == unit:GetOwner()
end

local function GetPassengerCount(carrier)
    if not carrier.chen_giant_courier_passengers then
        return 0
    end

    local count = 0
    for _, passenger in ipairs(carrier.chen_giant_courier_passengers) do
        if IsValidEntity(passenger) and passenger:IsAlive() and passenger:HasModifier(PASSENGER_MODIFIER) then
            count = count + 1
        end
    end
    return count
end

local function PrunePassengerList(carrier)
    if not carrier.chen_giant_courier_passengers then
        carrier.chen_giant_courier_passengers = {}
        return
    end

    local alivePassengers = {}
    for _, passenger in ipairs(carrier.chen_giant_courier_passengers) do
        if IsValidEntity(passenger) and passenger:IsAlive() and passenger:HasModifier(PASSENGER_MODIFIER) then
            alivePassengers[#alivePassengers + 1] = passenger
        end
    end
    carrier.chen_giant_courier_passengers = alivePassengers
end

local function IsValidPassenger(carrier, unit)
    if not IsValidEntity(carrier) or not IsValidEntity(unit) then
        return false
    end
    if unit == carrier or not unit:IsAlive() then
        return false
    end
    if unit:IsHero() or unit:IsBuilding() or unit:IsIllusion() or unit:IsCourier() then
        return false
    end
    if unit:HasModifier(PASSENGER_MODIFIER) then
        return false
    end
    if unit.IsControllableByAnyPlayer and not unit:IsControllableByAnyPlayer() then
        return false
    end
    if unit:GetTeamNumber() ~= carrier:GetTeamNumber() then
        return false
    end
    return HasSameOwner(carrier, unit)
end

local function GetUnloadPosition(carrier, index, total)
    local origin = carrier:GetAbsOrigin()
    local radius = 120 + math.min(index, total) * 18
    local angle = (index - 1) * (2 * math.pi / math.max(total, 1))
    return origin + Vector(math.cos(angle) * radius, math.sin(angle) * radius, 0)
end

local function UnloadPassenger(carrier, passenger, index, total)
    if not IsValidEntity(passenger) then
        return
    end

    passenger.chen_giant_courier_carrier = nil
    passenger:RemoveNoDraw()
    passenger:RemoveModifierByName(PASSENGER_MODIFIER)

    if passenger:IsAlive() and IsValidEntity(carrier) then
        local position = GetUnloadPosition(carrier, index, total)
        FindClearSpaceForUnit(passenger, position, true)
        passenger:Stop()
    end
end

local function UnloadAllPassengers(carrier)
    if not IsValidEntity(carrier) then
        return
    end

    PrunePassengerList(carrier)
    local passengers = carrier.chen_giant_courier_passengers or {}
    local total = #passengers

    for index, passenger in ipairs(passengers) do
        UnloadPassenger(carrier, passenger, index, total)
    end

    carrier.chen_giant_courier_passengers = {}
end

local function KillAllPassengers(carrier)
    if not IsValidEntity(carrier) then
        return
    end

    PrunePassengerList(carrier)
    for _, passenger in ipairs(carrier.chen_giant_courier_passengers or {}) do
        if IsValidEntity(passenger) and passenger:IsAlive() then
            passenger.chen_giant_courier_dying_inside = true
            passenger.chen_giant_courier_carrier = nil
            passenger:RemoveNoDraw()
            passenger:RemoveModifierByName(PASSENGER_MODIFIER)
            passenger:ForceKill(false)
            passenger.chen_giant_courier_dying_inside = nil
        end
    end

    carrier.chen_giant_courier_passengers = {}
end

function chen_giant_courier_transport_load:GetIntrinsicModifierName()
    return "modifier_chen_giant_courier_transport"
end

function chen_giant_courier_transport_load:CastFilterResult()
    if not IsServer() then
        return UF_SUCCESS
    end

    local carrier = self:GetCaster()
    if GetPassengerCount(carrier) >= self:GetSpecialValueFor("max_passengers") then
        return UF_FAIL_CUSTOM
    end
    return UF_SUCCESS
end

function chen_giant_courier_transport_load:GetCustomCastError()
    return "#dota_hud_error_chen_giant_courier_full"
end

function chen_giant_courier_transport_load:OnSpellStart()
    if not IsServer() then
        return
    end

    local carrier = self:GetCaster()
    local maxPassengers = self:GetSpecialValueFor("max_passengers")
    local loadRadius = self:GetSpecialValueFor("load_radius")

    carrier.chen_giant_courier_passengers = carrier.chen_giant_courier_passengers or {}
    PrunePassengerList(carrier)

    local units = FindUnitsInRadius(
        carrier:GetTeamNumber(),
        carrier:GetAbsOrigin(),
        nil,
        loadRadius,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_CLOSEST,
        false
    )

    for _, unit in ipairs(units) do
        if #carrier.chen_giant_courier_passengers >= maxPassengers then
            break
        end
        if IsValidPassenger(carrier, unit) then
            unit.chen_giant_courier_carrier = carrier:entindex()
            unit:AddNewModifier(carrier, self, PASSENGER_MODIFIER, {})
            unit:AddNoDraw()
            unit:Interrupt()
            unit:Stop()
            carrier.chen_giant_courier_passengers[#carrier.chen_giant_courier_passengers + 1] = unit
        end
    end
end

function chen_giant_courier_transport_unload:CastFilterResult()
    if not IsServer() then
        return UF_SUCCESS
    end

    if GetPassengerCount(self:GetCaster()) <= 0 then
        return UF_FAIL_CUSTOM
    end
    return UF_SUCCESS
end

function chen_giant_courier_transport_unload:GetCustomCastError()
    return "#dota_hud_error_chen_giant_courier_empty"
end

function chen_giant_courier_transport_unload:OnSpellStart()
    if not IsServer() then
        return
    end

    UnloadAllPassengers(self:GetCaster())
end

function modifier_chen_giant_courier_transport:IsHidden()
    return true
end

function modifier_chen_giant_courier_transport:IsPurgable()
    return false
end

function modifier_chen_giant_courier_transport:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_DEATH,
    }
end

function modifier_chen_giant_courier_transport:OnDeath(event)
    if not IsServer() then
        return
    end
    if event.unit == self:GetParent() then
        KillAllPassengers(self:GetParent())
    end
end

function modifier_chen_giant_courier_transport:OnDestroy()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if not IsValidEntity(parent) or not parent:IsAlive() then
        KillAllPassengers(parent)
    end
end

function modifier_chen_giant_courier_passenger:IsHidden()
    return true
end

function modifier_chen_giant_courier_passenger:IsPurgable()
    return false
end

function modifier_chen_giant_courier_passenger:CheckState()
    return {
        [MODIFIER_STATE_OUT_OF_GAME] = true,
        [MODIFIER_STATE_INVULNERABLE] = true,
        [MODIFIER_STATE_NO_HEALTH_BAR] = true,
        [MODIFIER_STATE_NO_UNIT_COLLISION] = true,
        [MODIFIER_STATE_STUNNED] = true,
        [MODIFIER_STATE_UNSELECTABLE] = true,
        [MODIFIER_STATE_COMMAND_RESTRICTED] = true,
    }
end

function modifier_chen_giant_courier_passenger:OnDestroy()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if parent.chen_giant_courier_dying_inside then
        return
    end

    parent:RemoveNoDraw()
    parent.chen_giant_courier_carrier = nil
end
