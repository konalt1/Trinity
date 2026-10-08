-- Общий маршрут pathway-боссов: Мортимер, его finale-актёр и Primal Beast.
-- Точки берутся только на игровом поле (как у каравана). Roshan_pathway_final на текущей
-- карте лежит за полем: босс не мог до неё дойти, оставался жив у края карты и навсегда
-- занимал слот спавнера, поэтому следующие ивенты не выходили.

require("map_modifications/Bosses/caravan/caravan_event")

BossPathway = BossPathway or {}

local REACH_DISTANCE = 100
-- Страховка от недостижимых точек: если босс на маршруте 10 сек не приблизился к точке
-- хотя бы на 50, точка считается пройденной.
local STALL_TIME = 10
local STALL_PROGRESS = 50
-- Перерыв в вызовах дольше этого (бой, каст, пауза) сбрасывает отсчёт.
local STALL_RESET_GAP = 1.5

function BossPathway:BuildPath(origin)
    if CourierCaravan and CourierCaravan.GetMortimerPath then
        return CourierCaravan.GetMortimerPath(origin)
    end

    print("[BossPathway] CourierCaravan.GetMortimerPath is missing; empty route.")
    return {}
end

function BossPathway:Init(unit, path, index)
    unit.pathwayPoints = path or self:BuildPath(unit:GetAbsOrigin())
    unit.currentWaypointIndex = index or 1
    unit.pathwayStall = nil
end

function BossPathway:HasPath(unit)
    return unit.pathwayPoints ~= nil and #unit.pathwayPoints > 0
end

local function IsStalled(unit, index, distance, now)
    local stall = unit.pathwayStall
    local blocked = unit:IsRooted() or unit:IsStunned()

    if blocked or not stall or stall.index ~= index or now - stall.lastTick > STALL_RESET_GAP then
        unit.pathwayStall = { index = index, best = distance, since = now, lastTick = now }
        return false
    end

    stall.lastTick = now
    if distance < stall.best - STALL_PROGRESS then
        stall.best = distance
        stall.since = now
        return false
    end

    if now - stall.since >= STALL_TIME then
        print(string.format(
            "[BossPathway] %s stuck %.0f from waypoint %d for %.0fs; skipping it",
            unit:GetUnitName(),
            distance,
            index,
            STALL_TIME
        ))
        return true
    end

    return false
end

-- Позиция текущей точки маршрута или nil, если маршрут пройден.
function BossPathway:GetTarget(unit)
    if not unit.pathwayPoints then
        self:Init(unit)
    end

    local points = unit.pathwayPoints
    local now = GameRules:GetGameTime()

    while true do
        local index = unit.currentWaypointIndex or 1
        local target = points[index]
        if not target then
            return nil
        end

        local distance = (unit:GetAbsOrigin() - target):Length2D()
        if distance >= REACH_DISTANCE and not IsStalled(unit, index, distance, now) then
            return target
        end

        unit.currentWaypointIndex = index + 1
        unit.pathwayStall = nil
    end
end
