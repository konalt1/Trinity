require("abilities/chen/barrack/chen_barrack_gold")
require("abilities/chen/barrack/units/chen_barrack_unit")
require("abilities/chen/barrack/units/chen_barrack_hunter_focus")
require("abilities/chen/barrack/units/chen_barrack_heal")
require("abilities/chen/barrack/units/chen_barrack_brute_rally")

chen_barrack = class({})
chen_barrack_farmland = class({})
chen_barrack_summon_worker = class({})
chen_barrack_summon_hunter = class({})
chen_barrack_summon_healer = class({})
chen_barrack_summon_brute = class({})
chen_worker_gather = class({})
modifier_chen_barrack = class({})
modifier_chen_barrack_farmland = class({})
modifier_chen_barrack_producing = class({})
modifier_chen_barrack_producing_worker = class(modifier_chen_barrack_producing, {})
modifier_chen_barrack_producing_hunter = class(modifier_chen_barrack_producing, {})
modifier_chen_barrack_producing_healer = class(modifier_chen_barrack_producing, {})
modifier_chen_barrack_producing_brute = class(modifier_chen_barrack_producing, {})
modifier_chen_worker_gather_ai = class({})

local SCRIPT_PATH = "abilities/chen/chen_barrack"
local UNIT_SCRIPT_PATH = "abilities/chen/barrack/units/chen_barrack_unit"

LinkLuaModifier("modifier_chen_barrack", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_barrack_farmland", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_barrack_producing", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_barrack_producing_worker", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_barrack_producing_hunter", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_barrack_producing_healer", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_barrack_producing_brute", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_worker_gather_ai", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_barrack_unit", UNIT_SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_barrack_carrier", UNIT_SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_barrack_gold_display", UNIT_SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)

ChenBarrackGold.Init()
ChenBarrackGold.UNIT_GOLD_MODES = ChenBarrackGold.UNIT_GOLD_MODES or {}

local CHEN_BARRACK_UNIT = "npc_chen_barrack"
local CHEN_BARRACK_WORKER_UNIT = "npc_chen_barrack_worker"
local CHEN_BARRACK_HUNTER_UNIT = "npc_chen_barrack_hunter"
local CHEN_BARRACK_HEALER_UNIT = "npc_chen_barrack_healer"
local CHEN_BARRACK_BRUTE_UNIT = "npc_chen_barrack_brute"
local BARRACK_MODEL = "models/props_structures/good_barracks_melee001.vmdl"
local FARMLAND_BLOOM_PARTICLE = "particles/items8_fx/foragers_kit_tree_aura.vpcf"

local CHEN_BARRACK_PRODUCING_MODIFIERS = {
    [CHEN_BARRACK_WORKER_UNIT] = "modifier_chen_barrack_producing_worker",
    [CHEN_BARRACK_HUNTER_UNIT] = "modifier_chen_barrack_producing_hunter",
    [CHEN_BARRACK_HEALER_UNIT] = "modifier_chen_barrack_producing_healer",
    [CHEN_BARRACK_BRUTE_UNIT] = "modifier_chen_barrack_producing_brute",
}

ChenBarrackGold.UNIT_GOLD_MODES[CHEN_BARRACK_WORKER_UNIT] = "carrier"
ChenBarrackGold.UNIT_GOLD_MODES[CHEN_BARRACK_HUNTER_UNIT] = "shared_carrier"
ChenBarrackGold.UNIT_GOLD_MODES[CHEN_BARRACK_HEALER_UNIT] = "shared_carrier"
ChenBarrackGold.UNIT_GOLD_MODES[CHEN_BARRACK_BRUTE_UNIT] = "shared_carrier"
ChenBarrackGold.UNIT_GOLD_MODES["npc_chen_ancient_thunderhide"] = "shared_carrier"
ChenBarrackGold.UNIT_GOLD_MODES["npc_chen_ancient_black_dragon"] = "shared_carrier"

CHEN_BARRACK_REGISTRY = CHEN_BARRACK_REGISTRY or {}

local CHEN_BARRACK_DEBUG = false
local FARMLAND_DEBUG = false
local CHEN_GATHER_DEBUG = false

local function BarrackDebug(...)
    if not CHEN_BARRACK_DEBUG then
        return
    end

    local parts = { "[ChenBarrack]" }
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end

    print(table.concat(parts, " "))
end

local function FarmlandDebug(...)
    if not FARMLAND_DEBUG then
        return
    end

    local parts = { "[ChenFarmland]" }
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end

    print(table.concat(parts, " "))
end

local function GatherDebug(...)
    if not CHEN_GATHER_DEBUG then
        return
    end

    local parts = { "[ChenGather]" }
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end

    print(table.concat(parts, " "))
end

local function BarrackDescribeUnit(unit)
    if not unit or unit:IsNull() then
        return "null"
    end

    return string.format(
        "%s#%d alive=%s",
        unit:GetUnitName() or "?",
        unit:entindex(),
        tostring(unit:IsAlive())
    )
end

local function BarrackDescribeItem(item)
    if not item then
        return "nil"
    end

    return string.format(
        "unit=%s gold=%s time=%s spawn=%s lifetime=%s",
        tostring(item.unit_name),
        tostring(item.gold_cost),
        tostring(item.production_time),
        tostring(item.spawn_distance),
        tostring(item.summon_lifetime)
    )
end

local function IsValidBarrackEntity(entity)
    return entity and not entity:IsNull()
end

local function IsTreeStanding(tree)
    return tree and tree.IsStanding and tree:IsStanding()
end

local function GetTreePosition(tree)
    if not tree then
        return nil
    end
    if tree.GetAbsOrigin then
        return tree:GetAbsOrigin()
    end
    if tree.GetOrigin then
        return tree:GetOrigin()
    end
    return nil
end

local function DescribeTree(tree)
    if not tree then
        return "nil"
    end

    local key = "?"
    if tree.entindex then
        key = tostring(tree:entindex())
    end

    local position = GetTreePosition(tree)
    if not position then
        return "tree#" .. key .. " pos=nil"
    end

    return string.format("tree#%s pos=(%.0f,%.0f,%.0f)", key, position.x, position.y, position.z)
end

local function GetTreesAroundPoint(position, radius, fullCollision)
    local trees = nil
    if GridNav.GetAllTreesAroundPoint then
        trees = GridNav:GetAllTreesAroundPoint(position, radius, fullCollision)
    elseif GridNav.GetAllTreesInRadius then
        trees = GridNav:GetAllTreesInRadius(position, radius, fullCollision)
    elseif GridNav.GetAllTreesAround then
        trees = GridNav:GetAllTreesAround(position, radius, fullCollision)
    end
    return trees or {}
end

local function ResolveBarrackFromEntIndex(entindex)
    if not entindex then
        return nil
    end

    local ok, barrack = pcall(EntIndexToHScript, entindex)
    if ok and IsValidBarrackEntity(barrack) then
        return barrack
    end

    return nil
end

function chen_barrack:Precache(context)
    PrecacheResource("model", BARRACK_MODEL, context)
    PrecacheUnitByNameSync(CHEN_BARRACK_WORKER_UNIT, context)
    PrecacheUnitByNameSync(CHEN_BARRACK_HUNTER_UNIT, context)
    PrecacheUnitByNameSync(CHEN_BARRACK_HEALER_UNIT, context)
    PrecacheUnitByNameSync(CHEN_BARRACK_BRUTE_UNIT, context)
    if ChenWorkerBuild and ChenWorkerBuild.Precache then
        ChenWorkerBuild.Precache(context)
    end
    if ChenSubBarrack and ChenSubBarrack.Precache then
        ChenSubBarrack.Precache(context)
    end
end

function chen_barrack:Init()
    ChenBarrackGold.Init()
end

function ChenBarrackHasScepterUpgrade(hero)
    if not hero or hero:IsNull() then
        return false
    end
    if hero.HasScepter and hero:HasScepter() then
        return true
    end
    return hero:HasModifier("modifier_item_ultimate_scepter") or hero:HasModifier("modifier_item_ultimate_scepter_consumed")
end

local function HasScepterUpgrade(hero)
    return ChenBarrackHasScepterUpgrade(hero)
end

function IsChenBarrackUnit(unit)
    if not unit or unit:IsNull() then
        return false
    end

    return (unit:GetUnitName() or "") == CHEN_BARRACK_UNIT
end

function IsChenBarrackWorker(unit)
    if not unit or unit:IsNull() then
        return false
    end

    return (unit:GetUnitName() or "") == CHEN_BARRACK_WORKER_UNIT
end

function GetBarrackOwnerHero(unit)
    if not unit or unit:IsNull() then
        return nil
    end

    if unit.chen_barrack_owner_hero then
        local ok, dead = pcall(function() return unit.chen_barrack_owner_hero:IsNull() end)
        if ok and not dead then
            return unit.chen_barrack_owner_hero
        end
        unit.chen_barrack_owner_hero = nil
    end

    if unit.chen_barrack_owner_entindex then
        local ok, hero = pcall(EntIndexToHScript, unit.chen_barrack_owner_entindex)
        if ok and hero and not hero:IsNull() and hero:IsRealHero() then
            unit.chen_barrack_owner_hero = hero
            return hero
        end
    end

    local ownerIdx = CHEN_BARRACK_REGISTRY[unit:entindex()]
    if ownerIdx then
        local ok, hero = pcall(EntIndexToHScript, ownerIdx)
        if ok and hero and not hero:IsNull() and hero:IsRealHero() then
            unit.chen_barrack_owner_entindex = ownerIdx
            unit.chen_barrack_owner_hero = hero
            return hero
        end
    end

    local playerID = unit:GetPlayerOwnerID()
    if playerID and playerID >= 0 and PlayerResource then
        local hero = PlayerResource:GetSelectedHeroEntity(playerID)
        if hero and not hero:IsNull() and hero:IsRealHero() then
            return hero
        end
    end

    local ok4, owner = pcall(function() return unit:GetOwnerEntity() end)
    if ok4 and owner and not owner:IsNull() and owner:IsRealHero() then
        return owner
    end

    return nil
end

ChenBarrackGold.GetBarrackOwnerHero = GetBarrackOwnerHero
ChenBarrackGold.IsChenBarrackBuilding = IsChenBarrackUnit

local function FocusPlayerOnBarrack(playerID, barrack)
    if playerID == nil or playerID < 0 or not barrack or barrack:IsNull() then
        return
    end

    local pos = barrack:GetAbsOrigin()
    if PlayerResource.SetCameraTargetPositionTime then
        PlayerResource:SetCameraTargetPositionTime(playerID, pos, 0.35, 0, 0)
    elseif PlayerResource.SetCameraTargetPosition then
        PlayerResource:SetCameraTargetPosition(playerID, pos, 0.35)
    end

    Timers:CreateTimer(0, function()
        if PlayerResource.NewGameEvent then
            PlayerResource:NewGameEvent("dota_player_update_selected_unit", { player_id = playerID })
        end
        return nil
    end)
end

local function GetBarrackProductionScalingLevel(ownerHero)
    if not ownerHero or ownerHero:IsNull() then
        return 1
    end
    local ult = ownerHero:FindAbilityByName("chen_barrack")
    if not ult or ult:IsNull() then
        return 1
    end
    return math.max(1, ult:GetLevel())
end

local function GetBarrackSummonedUnitAbilityLevel(ownerHero)
    if HasScepterUpgrade(ownerHero) then
        return 4
    end
    return GetBarrackProductionScalingLevel(ownerHero)
end

local function GetBarrackSummonValue(summonAbility, ownerHero, key)
    if not summonAbility or summonAbility:IsNull() then
        return 0
    end
    local lv = GetBarrackProductionScalingLevel(ownerHero)
    local maxLv = summonAbility:GetMaxLevel()
    if maxLv and maxLv > 0 then
        lv = math.min(lv, maxLv)
    end
    return summonAbility:GetLevelSpecialValueFor(key, lv)
end

function ForEachBarrackOwnedByHero(hero, fn)
    if not hero or hero:IsNull() or not fn then
        return
    end

    local units = FindUnitsInRadius(
        hero:GetTeamNumber(),
        hero:GetAbsOrigin(),
        nil,
        FIND_UNITS_EVERYWHERE,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_ALL,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    for _, unit in pairs(units) do
        if IsChenBarrackUnit(unit) and unit.chen_barrack_owner_entindex == hero:entindex() then
            fn(unit)
        end
    end
end

local function CountQueuedWorkersForHero(hero)
    local count = 0
    ForEachBarrackOwnedByHero(hero, function(barrack)
        for _, item in ipairs(barrack.chen_production_queue or {}) do
            if item and item.is_worker then
                count = count + 1
            end
        end
        if barrack.chen_current_order and barrack.chen_current_order.is_worker then
            count = count + (barrack.chen_active_productions or 1)
        end
    end)
    return count
end

local function CountLivingWorkersForHero(hero)
    if not hero or hero:IsNull() then
        return 0
    end

    local count = 0
    local units = FindUnitsInRadius(
        hero:GetTeamNumber(),
        hero:GetAbsOrigin(),
        nil,
        FIND_UNITS_EVERYWHERE,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_ALL,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    for _, unit in pairs(units) do
        if IsChenBarrackWorker(unit) and unit:IsAlive() and GetBarrackOwnerHero(unit) == hero then
            count = count + 1
        end
    end

    return count
end

function GetLivingBarrackForHero(hero)
    if not hero or hero:IsNull() then
        return nil
    end

    local found
    ForEachBarrackOwnedByHero(hero, function(barrack)
        if barrack and not barrack:IsNull() and barrack:IsAlive() and not barrack.chen_is_destroyed then
            found = barrack
        end
    end)
    return found
end

local function LevelBarrackAbilities(barrack)
    if not barrack or barrack:IsNull() then
        return
    end

    local ownerHero = GetBarrackOwnerHero(barrack)
    local lv = math.max(1, GetBarrackProductionScalingLevel(ownerHero))
    for slot = 0, barrack:GetAbilityCount() - 1 do
        local ability = barrack:GetAbilityByIndex(slot)
        if ability and not ability:IsNull() then
            local maxLv = ability:GetMaxLevel()
            if maxLv and maxLv > 0 then
                ability:SetLevel(math.max(1, math.min(lv, maxLv)))
            end
            ability:SetActivated(true)
            ability:SetHidden(ability:GetAbilityName() == "chen_barrack_farmland")
        end
    end
end

local function DebugBarrackAbilities(barrack, label)
    if not CHEN_BARRACK_DEBUG or not barrack or barrack:IsNull() then
        return
    end

    for slot = 0, barrack:GetAbilityCount() - 1 do
        local ability = barrack:GetAbilityByIndex(slot)
        if ability and not ability:IsNull() then
            BarrackDebug(
                label,
                "slot",
                slot,
                ability:GetAbilityName(),
                "level",
                ability:GetLevel(),
                "activated",
                tostring(ability:IsActivated())
            )
        end
    end
end

local function InitBarrackState(barrack)
    barrack.chen_production_queue = barrack.chen_production_queue or {}
    barrack.chen_production_active = barrack.chen_production_active or false
    barrack.chen_is_destroyed = barrack.chen_is_destroyed or false
    barrack.chen_active_productions = barrack.chen_active_productions or 0
    barrack.chen_barrack_gold = barrack.chen_barrack_gold or 0
end

local function GetBarrackQueuedCount(barrack)
    InitBarrackState(barrack)
    return #barrack.chen_production_queue + (barrack.chen_active_productions or 0)
end

local function IsValidProductionModifier(modifier)
    if not modifier then
        return false
    end

    if modifier.IsNull then
        return not modifier:IsNull()
    end

    return true
end

local function GetProductionModifierName(unitName)
    return CHEN_BARRACK_PRODUCING_MODIFIERS[unitName] or "modifier_chen_barrack_producing"
end

local function AddProductionModifier(barrack, item, duration)
    if not barrack or barrack:IsNull() then
        return nil
    end

    local unitName = item and item.unit_name or ""
    local kv = {
        production_time = item and item.production_time or 0,
        unit_name = unitName,
    }

    if duration and duration > 0 then
        kv.duration = duration
    end

    return barrack:AddNewModifier(barrack, nil, GetProductionModifierName(unitName), kv)
end

local function SyncProductionModifierTimer(modifier, remaining)
    if not IsValidProductionModifier(modifier) then
        return
    end

    remaining = math.max(0.1, remaining)
    modifier.is_producing = true
    modifier:SetDuration(remaining, true)
    modifier:SetStackCount(math.max(1, math.ceil(remaining)))
end

local function PauseProductionModifierTimer(modifier)
    if not IsValidProductionModifier(modifier) then
        return
    end

    modifier.is_producing = false
    modifier:SetDuration(-1, true)
    modifier:SetStackCount(0)
end

local function EnsureProductionModifier(barrack, item)
    if IsValidProductionModifier(item.production_modifier) then
        return item.production_modifier
    end

    item.production_modifier = AddProductionModifier(barrack, item)
    return item.production_modifier
end

local function RecalculateBarrackProductionTimers(barrack)
    if not barrack or barrack:IsNull() then
        return
    end

    local now = GameRules:GetGameTime()
    local deadline = now

    local currentOrder = barrack.chen_current_order
    if currentOrder then
        local remaining = math.max(0.1, tonumber(currentOrder.production_time) or 10)
        if IsValidProductionModifier(currentOrder.production_modifier) then
            local modRemaining = currentOrder.production_modifier:GetRemainingTime()
            if modRemaining and modRemaining > 0 then
                remaining = modRemaining
            end
        end

        deadline = now + remaining
        currentOrder.spawn_at = deadline

        if IsValidProductionModifier(currentOrder.production_modifier) then
            SyncProductionModifierTimer(currentOrder.production_modifier, deadline - now)
        end
    end

    for _, item in ipairs(barrack.chen_production_queue or {}) do
        local productionTime = math.max(0.1, tonumber(item.production_time) or 10)
        deadline = deadline + productionTime
        item.spawn_at = deadline

        if IsValidProductionModifier(item.production_modifier) then
            PauseProductionModifierTimer(item.production_modifier)
        end
    end
end

local function DestroyProductionModifier(item)
    if item and IsValidProductionModifier(item.production_modifier) then
        item.production_modifier:Destroy()
    end

    if item then
        item.production_modifier = nil
    end
end

local function CreateProductUnit(item, spawnPosition, ownerHero, teamNumber)
    local unitName = item.unit_name
    if unitName and unitName ~= "" then
        BarrackDebug("CreateUnitByName", unitName, "team", teamNumber, "pos", tostring(spawnPosition))
        local unit = CreateUnitByName(unitName, spawnPosition, true, ownerHero, ownerHero, teamNumber)
        if not unit or unit:IsNull() then
            BarrackDebug("CreateUnitByName failed", unitName)
        end
        return unit
    end

    BarrackDebug("CreateProductUnit skipped: empty unit_name")
    return nil
end

local function LevelUnitAbilities(unit, ownerHero)
    if not unit or unit:IsNull() then
        return
    end

    local level = GetBarrackSummonedUnitAbilityLevel(ownerHero)
    for slot = 0, unit:GetAbilityCount() - 1 do
        local ability = unit:GetAbilityByIndex(slot)
        if ability and not ability:IsNull() then
            local maxLevel = ability:GetMaxLevel()
            if maxLevel and maxLevel > 0 then
                ability:SetLevel(math.min(level, maxLevel))
            end
        end
    end
end

local function CompleteProduction(barrack, item)
    BarrackDebug("CompleteProduction start", BarrackDescribeUnit(barrack), BarrackDescribeItem(item))

    if not barrack or barrack:IsNull() then
        BarrackDebug("CompleteProduction abort: barrack missing")
        return
    end
    if not barrack:IsAlive() then
        BarrackDebug("CompleteProduction abort: barrack dead")
        return
    end
    if barrack.chen_is_destroyed then
        BarrackDebug("CompleteProduction abort: barrack destroyed flag")
        return
    end

    local ownerHero = GetBarrackOwnerHero(barrack)
    if not ownerHero then
        BarrackDebug("CompleteProduction abort: owner hero missing")
        return
    end

    local playerID = ownerHero:GetPlayerOwnerID()
    local teamNumber = ownerHero:GetTeamNumber()
    local spawnDistance = item.spawn_distance or 400
    local spawnPosition = barrack:GetAbsOrigin() + barrack:GetForwardVector() * spawnDistance + RandomVector(80)
    local summon = CreateProductUnit(item, spawnPosition, ownerHero, teamNumber)

    if not summon then
        BarrackDebug("CompleteProduction refund", item.gold_cost or 0, "gold")
        ChenBarrackGold.Add(barrack, item.gold_cost or 0, "production_refund")
        return
    end

    ChenBarrackGold.RegisterBarrackUnit(
        summon,
        barrack,
        ownerHero,
        item.gold_mode or ChenBarrackGold.GetUnitGoldMode(item.unit_name)
    )

    summon:SetOwner(ownerHero)
    summon:SetControllableByPlayer(playerID, true)
    if summon.SetPlayerID then
        summon:SetPlayerID(playerID)
    end

    LevelUnitAbilities(summon, ownerHero)

    local summonLifetime = tonumber(item.summon_lifetime) or 60
    if summonLifetime > 0 then
        summon:AddNewModifier(ownerHero, ownerHero:FindAbilityByName("chen_barrack"), "modifier_kill", { duration = math.max(1, summonLifetime) })
    end

    if item.is_worker then
        ChenBarrackEnableWorkerGatherAutocast(summon)
        if ChenWorkerBuild and ChenWorkerBuild.ApplyScepterToWorker then
            ChenWorkerBuild.ApplyScepterToWorker(summon, ownerHero)
        end
        Timers:CreateTimer(0, function()
            if summon and not summon:IsNull() and summon:IsAlive() then
                ChenBarrackEnsureFarmlandBloom(barrack)
                ChenBarrackKickWorkerGather(summon)
            end
            return nil
        end)
    end

    if item.is_healer then
        ChenBarrackEnableHealerAutocast(summon)
    end

    if item.is_brute then
        ChenBarrackEnableBruteAutocast(summon)
    end

    local particle = ParticleManager:CreateParticle("particles/econ/events/ti6/kill_effect_creep_gold.vpcf", PATTACH_ABSORIGIN_FOLLOW, summon)
    ParticleManager:ReleaseParticleIndex(particle)

   
    FindClearSpaceForUnit(summon, spawnPosition, true)
    BarrackDebug("CompleteProduction success", BarrackDescribeUnit(summon), "lifetime", summonLifetime)
end

local StartNextProduction

StartNextProduction = function(barrack)
    BarrackDebug("StartNextProduction called", BarrackDescribeUnit(barrack))

    if not barrack or barrack:IsNull() then
        BarrackDebug("StartNextProduction abort: barrack missing")
        return
    end
    if not barrack:IsAlive() then
        BarrackDebug("StartNextProduction abort: barrack dead")
        return
    end
    if barrack.chen_is_destroyed then
        BarrackDebug("StartNextProduction abort: barrack destroyed flag")
        return
    end

    InitBarrackState(barrack)

    local item = table.remove(barrack.chen_production_queue, 1)
    if not item then
        BarrackDebug("StartNextProduction abort: queue empty")
        return
    end

    barrack.chen_active_productions = (barrack.chen_active_productions or 0) + 1
    barrack.chen_current_order = item

    local productionTime = math.max(0.1, tonumber(item.production_time) or 10)
    item.production_time = productionTime
    BarrackDebug(
        "Production started",
        BarrackDescribeItem(item),
        "queue_left",
        #barrack.chen_production_queue,
        "active",
        barrack.chen_active_productions
    )

    EnsureProductionModifier(barrack, item)
    RecalculateBarrackProductionTimers(barrack)

    Timers:CreateTimer(productionTime, function()
        BarrackDebug(
            "Production timer fired",
            "delay",
            productionTime,
            BarrackDescribeUnit(barrack),
            BarrackDescribeItem(item)
        )

        if not barrack or barrack:IsNull() then
            BarrackDebug("Timer abort: barrack missing")
            return nil
        end

        if not barrack:IsAlive() or barrack.chen_is_destroyed then
            BarrackDebug(
                "Timer abort: barrack unusable",
                "alive",
                tostring(barrack:IsAlive()),
                "destroyed",
                tostring(barrack.chen_is_destroyed)
            )
            DestroyProductionModifier(item)
            barrack.chen_active_productions = math.max(0, (barrack.chen_active_productions or 1) - 1)
            barrack.chen_current_order = nil
            StartNextProduction(barrack)
            return nil
        end

        CompleteProduction(barrack, item)
        DestroyProductionModifier(item)
        barrack.chen_active_productions = math.max(0, (barrack.chen_active_productions or 1) - 1)
        barrack.chen_current_order = nil
        BarrackDebug("Production finished", "queue_left", #barrack.chen_production_queue, "active", barrack.chen_active_productions)
        StartNextProduction(barrack)
        return nil
    end)
end

local function IsFirstWorkerFree(ownerHero)
    return CountLivingWorkersForHero(ownerHero) == 0 and CountQueuedWorkersForHero(ownerHero) == 0
end

local function GetWorkerGoldCost(ability, ownerHero)
    if IsFirstWorkerFree(ownerHero) then
        return 0
    end

    return GetBarrackSummonValue(ability, ownerHero, "gold_cost")
end

local function QueueBarrackWorker(self)
    if not IsServer() then
        return
    end

    local barrack = self:GetCaster()
    BarrackDebug("QueueBarrackWorker cast", BarrackDescribeUnit(barrack))

    repeat
        local ownerHero = GetBarrackOwnerHero(barrack)
        if not ownerHero then
            BarrackDebug("Worker queue abort: no owner hero")
            break
        end

        InitBarrackState(barrack)
        if GetBarrackQueuedCount(barrack) >= 5 then
            BarrackDebug("Worker queue abort: queue full")
            break
        end

        local goldCost = GetWorkerGoldCost(self, ownerHero)
        if not ChenBarrackGold.Has(barrack, goldCost) then
            BarrackDebug("Worker queue abort: not enough gold", "need", goldCost, "have", ChenBarrackGold.Get(barrack))
            break
        end

        if goldCost > 0 and not ChenBarrackGold.Spend(barrack, goldCost, "hire_worker") then
            BarrackDebug("Worker queue abort: spend failed", goldCost)
            break
        end

        local productionItem = {
            unit_name = CHEN_BARRACK_WORKER_UNIT,
            gold_cost = goldCost,
            production_time = GetBarrackSummonValue(self, ownerHero, "production_time"),
            spawn_distance = GetBarrackSummonValue(self, ownerHero, "spawn_distance"),
            summon_lifetime = 0,
            gold_mode = "carrier",
            is_worker = true,
        }

        table.insert(barrack.chen_production_queue, productionItem)
        BarrackDebug(
            "Worker queued",
            BarrackDescribeItem(productionItem),
            "queue_size",
            #barrack.chen_production_queue,
            "active",
            barrack.chen_active_productions or 0,
            "gold_left",
            ChenBarrackGold.Get(barrack)
        )

        if (barrack.chen_active_productions or 0) > 0 then
            EnsureProductionModifier(barrack, productionItem)
            RecalculateBarrackProductionTimers(barrack)
        end

        EmitSoundOn("General.Buy", barrack)
        if (barrack.chen_active_productions or 0) == 0 then
            StartNextProduction(barrack)
        end
    until true

    if self and not self:IsNull() then
        self:EndCooldown()
    end
end

local function BarrackWorkerCastFilter(self)
    if not IsServer() then
        return UF_SUCCESS
    end

    local barrack = self:GetCaster()
    local ownerHero = GetBarrackOwnerHero(barrack)
    if not ownerHero or ownerHero:IsNull() then
        return UF_FAIL_CUSTOM
    end

    InitBarrackState(barrack)
    if GetBarrackQueuedCount(barrack) >= 5 then
        return UF_FAIL_CUSTOM
    end

    if not ChenBarrackGold.Has(barrack, GetWorkerGoldCost(self, ownerHero)) then
        return UF_FAIL_CUSTOM
    end

    return UF_SUCCESS
end

local function BarrackWorkerCastError(self)
    if not IsServer() then
        return ""
    end

    local barrack = self:GetCaster()
    local ownerHero = GetBarrackOwnerHero(barrack)
    if not ownerHero or ownerHero:IsNull() then
        return "#dota_hud_error_chen_barrack_no_owner"
    end

    InitBarrackState(barrack)
    if GetBarrackQueuedCount(barrack) >= 5 then
        return "#dota_hud_error_chen_barrack_queue_full"
    end

    if not ChenBarrackGold.Has(barrack, GetWorkerGoldCost(self, ownerHero)) then
        return "#dota_hud_error_chen_barrack_not_enough_gold"
    end

    return ""
end

local function QueueBarrackHunter(self)
    if not IsServer() then
        return
    end

    local barrack = self:GetCaster()
    BarrackDebug("QueueBarrackHunter cast", BarrackDescribeUnit(barrack))

    repeat
        local ownerHero = GetBarrackOwnerHero(barrack)
        if not ownerHero then
            BarrackDebug("Hunter queue abort: no owner hero")
            break
        end

        InitBarrackState(barrack)
        if GetBarrackQueuedCount(barrack) >= 5 then
            BarrackDebug("Hunter queue abort: queue full")
            break
        end

        local goldCost = GetBarrackSummonValue(self, ownerHero, "gold_cost")
        if not ChenBarrackGold.Has(barrack, goldCost) then
            BarrackDebug("Hunter queue abort: not enough gold", "need", goldCost, "have", ChenBarrackGold.Get(barrack))
            break
        end

        if goldCost > 0 and not ChenBarrackGold.Spend(barrack, goldCost, "hire_hunter") then
            BarrackDebug("Hunter queue abort: spend failed", goldCost)
            break
        end

        local productionItem = {
            unit_name = CHEN_BARRACK_HUNTER_UNIT,
            gold_cost = goldCost,
            production_time = GetBarrackSummonValue(self, ownerHero, "production_time"),
            spawn_distance = GetBarrackSummonValue(self, ownerHero, "spawn_distance"),
            summon_lifetime = 0,
            gold_mode = "shared_carrier",
        }

        table.insert(barrack.chen_production_queue, productionItem)
        BarrackDebug(
            "Hunter queued",
            BarrackDescribeItem(productionItem),
            "queue_size",
            #barrack.chen_production_queue,
            "active",
            barrack.chen_active_productions or 0,
            "gold_left",
            ChenBarrackGold.Get(barrack)
        )

        if (barrack.chen_active_productions or 0) > 0 then
            EnsureProductionModifier(barrack, productionItem)
            RecalculateBarrackProductionTimers(barrack)
        end

        EmitSoundOn("General.Buy", barrack)
        if (barrack.chen_active_productions or 0) == 0 then
            StartNextProduction(barrack)
        end
    until true

    if self and not self:IsNull() then
        self:EndCooldown()
    end
end

local function BarrackHunterCastFilter(self)
    if not IsServer() then
        return UF_SUCCESS
    end

    local barrack = self:GetCaster()
    local ownerHero = GetBarrackOwnerHero(barrack)
    if not ownerHero or ownerHero:IsNull() then
        return UF_FAIL_CUSTOM
    end

    InitBarrackState(barrack)
    if GetBarrackQueuedCount(barrack) >= 5 then
        return UF_FAIL_CUSTOM
    end

    if not ChenBarrackGold.Has(barrack, GetBarrackSummonValue(self, ownerHero, "gold_cost")) then
        return UF_FAIL_CUSTOM
    end

    return UF_SUCCESS
end

local function BarrackHunterCastError(self)
    if not IsServer() then
        return ""
    end

    local barrack = self:GetCaster()
    local ownerHero = GetBarrackOwnerHero(barrack)
    if not ownerHero or ownerHero:IsNull() then
        return "#dota_hud_error_chen_barrack_no_owner"
    end

    InitBarrackState(barrack)
    if GetBarrackQueuedCount(barrack) >= 5 then
        return "#dota_hud_error_chen_barrack_queue_full"
    end

    if not ChenBarrackGold.Has(barrack, GetBarrackSummonValue(self, ownerHero, "gold_cost")) then
        return "#dota_hud_error_chen_barrack_not_enough_gold"
    end

    return ""
end

local function QueueBarrackHealer(self)
    if not IsServer() then
        return
    end

    local barrack = self:GetCaster()
    BarrackDebug("QueueBarrackHealer cast", BarrackDescribeUnit(barrack))

    repeat
        local ownerHero = GetBarrackOwnerHero(barrack)
        if not ownerHero then
            BarrackDebug("Healer queue abort: no owner hero")
            break
        end

        InitBarrackState(barrack)
        if GetBarrackQueuedCount(barrack) >= 5 then
            BarrackDebug("Healer queue abort: queue full")
            break
        end

        local goldCost = GetBarrackSummonValue(self, ownerHero, "gold_cost")
        if not ChenBarrackGold.Has(barrack, goldCost) then
            BarrackDebug("Healer queue abort: not enough gold", "need", goldCost, "have", ChenBarrackGold.Get(barrack))
            break
        end

        if goldCost > 0 and not ChenBarrackGold.Spend(barrack, goldCost, "hire_healer") then
            BarrackDebug("Healer queue abort: spend failed", goldCost)
            break
        end

        local productionItem = {
            unit_name = CHEN_BARRACK_HEALER_UNIT,
            gold_cost = goldCost,
            production_time = GetBarrackSummonValue(self, ownerHero, "production_time"),
            spawn_distance = GetBarrackSummonValue(self, ownerHero, "spawn_distance"),
            summon_lifetime = 0,
            gold_mode = "shared_carrier",
            is_healer = true,
        }

        table.insert(barrack.chen_production_queue, productionItem)
        BarrackDebug(
            "Healer queued",
            BarrackDescribeItem(productionItem),
            "queue_size",
            #barrack.chen_production_queue,
            "active",
            barrack.chen_active_productions or 0,
            "gold_left",
            ChenBarrackGold.Get(barrack)
        )

        if (barrack.chen_active_productions or 0) > 0 then
            EnsureProductionModifier(barrack, productionItem)
            RecalculateBarrackProductionTimers(barrack)
        end

        EmitSoundOn("General.Buy", barrack)
        if (barrack.chen_active_productions or 0) == 0 then
            StartNextProduction(barrack)
        end
    until true

    if self and not self:IsNull() then
        self:EndCooldown()
    end
end

local function BarrackHealerCastFilter(self)
    if not IsServer() then
        return UF_SUCCESS
    end

    local barrack = self:GetCaster()
    local ownerHero = GetBarrackOwnerHero(barrack)
    if not ownerHero or ownerHero:IsNull() then
        return UF_FAIL_CUSTOM
    end

    InitBarrackState(barrack)
    if GetBarrackQueuedCount(barrack) >= 5 then
        return UF_FAIL_CUSTOM
    end

    if not ChenBarrackGold.Has(barrack, GetBarrackSummonValue(self, ownerHero, "gold_cost")) then
        return UF_FAIL_CUSTOM
    end

    return UF_SUCCESS
end

local function BarrackHealerCastError(self)
    if not IsServer() then
        return ""
    end

    local barrack = self:GetCaster()
    local ownerHero = GetBarrackOwnerHero(barrack)
    if not ownerHero or ownerHero:IsNull() then
        return "#dota_hud_error_chen_barrack_no_owner"
    end

    InitBarrackState(barrack)
    if GetBarrackQueuedCount(barrack) >= 5 then
        return "#dota_hud_error_chen_barrack_queue_full"
    end

    if not ChenBarrackGold.Has(barrack, GetBarrackSummonValue(self, ownerHero, "gold_cost")) then
        return "#dota_hud_error_chen_barrack_not_enough_gold"
    end

    return ""
end

local function QueueBarrackBrute(self)
    if not IsServer() then
        return
    end

    local barrack = self:GetCaster()
    BarrackDebug("QueueBarrackBrute cast", BarrackDescribeUnit(barrack))

    repeat
        local ownerHero = GetBarrackOwnerHero(barrack)
        if not ownerHero then
            BarrackDebug("Brute queue abort: no owner hero")
            break
        end

        InitBarrackState(barrack)
        if GetBarrackQueuedCount(barrack) >= 5 then
            BarrackDebug("Brute queue abort: queue full")
            break
        end

        local goldCost = GetBarrackSummonValue(self, ownerHero, "gold_cost")
        if not ChenBarrackGold.Has(barrack, goldCost) then
            BarrackDebug("Brute queue abort: not enough gold", "need", goldCost, "have", ChenBarrackGold.Get(barrack))
            break
        end

        if goldCost > 0 and not ChenBarrackGold.Spend(barrack, goldCost, "hire_brute") then
            BarrackDebug("Brute queue abort: spend failed", goldCost)
            break
        end

        local productionItem = {
            unit_name = CHEN_BARRACK_BRUTE_UNIT,
            gold_cost = goldCost,
            production_time = GetBarrackSummonValue(self, ownerHero, "production_time"),
            spawn_distance = GetBarrackSummonValue(self, ownerHero, "spawn_distance"),
            summon_lifetime = 0,
            gold_mode = "shared_carrier",
            is_brute = true,
        }

        table.insert(barrack.chen_production_queue, productionItem)
        BarrackDebug(
            "Brute queued",
            BarrackDescribeItem(productionItem),
            "queue_size",
            #barrack.chen_production_queue,
            "active",
            barrack.chen_active_productions or 0,
            "gold_left",
            ChenBarrackGold.Get(barrack)
        )

        if (barrack.chen_active_productions or 0) > 0 then
            EnsureProductionModifier(barrack, productionItem)
            RecalculateBarrackProductionTimers(barrack)
        end

        EmitSoundOn("General.Buy", barrack)
        if (barrack.chen_active_productions or 0) == 0 then
            StartNextProduction(barrack)
        end
    until true

    if self and not self:IsNull() then
        self:EndCooldown()
    end
end

local function BarrackBruteCastFilter(self)
    if not IsServer() then
        return UF_SUCCESS
    end

    local barrack = self:GetCaster()
    local ownerHero = GetBarrackOwnerHero(barrack)
    if not ownerHero or ownerHero:IsNull() then
        return UF_FAIL_CUSTOM
    end

    InitBarrackState(barrack)
    if GetBarrackQueuedCount(barrack) >= 5 then
        return UF_FAIL_CUSTOM
    end

    if not ChenBarrackGold.Has(barrack, GetBarrackSummonValue(self, ownerHero, "gold_cost")) then
        return UF_FAIL_CUSTOM
    end

    return UF_SUCCESS
end

local function BarrackBruteCastError(self)
    if not IsServer() then
        return ""
    end

    local barrack = self:GetCaster()
    local ownerHero = GetBarrackOwnerHero(barrack)
    if not ownerHero or ownerHero:IsNull() then
        return "#dota_hud_error_chen_barrack_no_owner"
    end

    InitBarrackState(barrack)
    if GetBarrackQueuedCount(barrack) >= 5 then
        return "#dota_hud_error_chen_barrack_queue_full"
    end

    if not ChenBarrackGold.Has(barrack, GetBarrackSummonValue(self, ownerHero, "gold_cost")) then
        return "#dota_hud_error_chen_barrack_not_enough_gold"
    end

    return ""
end

function ChenBarrackSpendGold(barrack, amount, reason)
    return ChenBarrackGold.Spend(barrack, amount, reason or "building")
end

function ChenBarrackGrantUnitGold(unit, amount, source)
    return ChenBarrackGold.GrantUnitGold(unit, amount, source)
end

function chen_barrack_farmland:GetIntrinsicModifierName()
    return "modifier_chen_barrack_farmland"
end

function modifier_chen_barrack_farmland:IsHidden()
    return true
end

function modifier_chen_barrack_farmland:IsPurgable()
    return false
end

function modifier_chen_barrack_farmland:RemoveOnDeath()
    return true
end

function modifier_chen_barrack_farmland:OnCreated()
    if not IsServer() then
        return
    end

    self.blooms = {}
    self:GetParent().chen_farmland_blooms = self.blooms
    self:StartIntervalThink(self:GetFarmlandValue("think_interval", 0.25))
    FarmlandDebug("created", BarrackDescribeUnit(self:GetParent()), "interval", self:GetFarmlandValue("think_interval", 0.25))
end

function modifier_chen_barrack_farmland:OnRefresh()
    if not IsServer() then
        return
    end

    self:StartIntervalThink(self:GetFarmlandValue("think_interval", 0.25))
    FarmlandDebug("refreshed", BarrackDescribeUnit(self:GetParent()), "interval", self:GetFarmlandValue("think_interval", 0.25))
end

function modifier_chen_barrack_farmland:OnDestroy()
    if not IsServer() then
        return
    end

    for key in pairs(self.blooms or {}) do
        self:DestroyBloom(key)
    end

    local parent = self:GetParent()
    if IsValidBarrackEntity(parent) then
        parent.chen_farmland_blooms = nil
    end
    FarmlandDebug("destroyed", BarrackDescribeUnit(parent))
end

function modifier_chen_barrack_farmland:GetFarmlandValue(name, fallback)
    local ability = self:GetAbility()
    if ability and not ability:IsNull() then
        local value = ability:GetSpecialValueFor(name)
        if value and value > 0 then
            return value
        end
    end

    return fallback
end

function modifier_chen_barrack_farmland:GetActiveBloomCount()
    local count = 0
    for _ in pairs(self.blooms or {}) do
        count = count + 1
    end
    return count
end

function modifier_chen_barrack_farmland:CreateBloomParticle(position)
    local particle = ParticleManager:CreateParticle(FARMLAND_BLOOM_PARTICLE, PATTACH_CUSTOMORIGIN, nil)
    ParticleManager:SetParticleControl(particle, 0, position)
    return particle
end

function modifier_chen_barrack_farmland:DestroyBloom(key)
    if not self.blooms then
        return
    end

    local record = self.blooms[key]
    if not record then
        FarmlandDebug("destroy bloom skipped missing", "key", key)
        return
    end

    if record.particle then
        ParticleManager:DestroyParticle(record.particle, false)
        ParticleManager:ReleaseParticleIndex(record.particle)
    end

    self.blooms[key] = nil
    FarmlandDebug("destroy bloom", "key", key)
end

function modifier_chen_barrack_farmland:BloomTree(tree)
    if not IsTreeStanding(tree) then
        FarmlandDebug("bloom skipped tree not standing", DescribeTree(tree))
        return false
    end

    local position = GetTreePosition(tree)
    if not position then
        FarmlandDebug("bloom skipped tree no position", DescribeTree(tree))
        return false
    end

    local key = tree:entindex()
    local now = GameRules:GetGameTime()
    local duration = self:GetFarmlandValue("bloom_duration", 60)
    local existing = self.blooms[key]

    if existing then
        existing.expiresAt = now + duration
        existing.gathererEntindex = nil
        existing.gatherCompleteAt = nil
        FarmlandDebug("refresh bloom", DescribeTree(tree), "duration", duration, "expires", existing.expiresAt)
        return true
    end

    self.blooms[key] = {
        tree = tree,
        expiresAt = now + duration,
        gathererEntindex = nil,
        gatherCompleteAt = nil,
        particle = self:CreateBloomParticle(position),
    }

    local parent = self:GetParent()
    if IsValidBarrackEntity(parent) then
        parent.chen_farmland_blooms = self.blooms
    end

    FarmlandDebug("new bloom", DescribeTree(tree), "duration", duration, "expires", self.blooms[key].expiresAt)
    return true
end

function modifier_chen_barrack_farmland:BloomRandomTree()
    local parent = self:GetParent()
    if not IsValidBarrackEntity(parent) or not parent:IsAlive() then
        FarmlandDebug("random bloom skipped invalid barrack", BarrackDescribeUnit(parent))
        return false
    end

    local radius = self:GetFarmlandValue("bloom_radius", 800)
    FarmlandDebug("random bloom scan", BarrackDescribeUnit(parent), "radius", radius)
    local ok, trees = pcall(function()
        return GetTreesAroundPoint(parent:GetAbsOrigin(), radius, true)
    end)
    if not ok or not trees then
        FarmlandDebug("random bloom failed tree query", "ok", ok, "trees", trees)
        return false
    end

    local candidates = {}
    for _, tree in pairs(trees) do
        if IsTreeStanding(tree) and not self.blooms[tree:entindex()] then
            candidates[#candidates + 1] = tree
        end
    end

    if #candidates == 0 then
        FarmlandDebug("random bloom no candidates", "trees", #trees, "active", self:GetActiveBloomCount())
        return false
    end

    local pickedIndex = RandomInt(1, #candidates)
    FarmlandDebug("random bloom candidates", #candidates, "picked", pickedIndex, DescribeTree(candidates[pickedIndex]))
    return self:BloomTree(candidates[pickedIndex])
end

function modifier_chen_barrack_farmland:IsEligibleGatherer(unit)
    if not IsValidBarrackEntity(unit) or not unit:IsAlive() or not unit.chen_barrack_spawned then
        FarmlandDebug("gatherer rejected base", BarrackDescribeUnit(unit))
        return false
    end
    if IsChenBarrackUnit(unit) then
        FarmlandDebug("gatherer rejected barrack", BarrackDescribeUnit(unit))
        return false
    end

    local barrack = self:GetParent()
    local homeBarrack = ChenBarrackGold.GetHomeBarrack(unit)
    if IsValidBarrackEntity(homeBarrack) then
        local matches = homeBarrack == barrack
        if not matches then
            FarmlandDebug("gatherer rejected wrong home", BarrackDescribeUnit(unit), "home", BarrackDescribeUnit(homeBarrack), "barrack", BarrackDescribeUnit(barrack))
        end
        return matches
    end

    local matchesEntindex = unit.chen_home_barrack_entindex and barrack and unit.chen_home_barrack_entindex == barrack:entindex()
    if not matchesEntindex then
        FarmlandDebug("gatherer rejected no matching entindex", BarrackDescribeUnit(unit), "home_idx", unit.chen_home_barrack_entindex)
    end
    return matchesEntindex
end

function modifier_chen_barrack_farmland:FindGatherer(position)
    local parent = self:GetParent()
    if not IsValidBarrackEntity(parent) then
        FarmlandDebug("find gatherer skipped invalid parent")
        return nil
    end

    local triggerRadius = self:GetFarmlandValue("gather_trigger_radius", 120)
    FarmlandDebug("find gatherer scan", "pos", tostring(position), "radius", triggerRadius)
    local units = FindUnitsInRadius(
        parent:GetTeamNumber(),
        position,
        nil,
        triggerRadius,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_ALL,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_CLOSEST,
        false
    )

    for _, unit in pairs(units) do
        if self:IsEligibleGatherer(unit) then
            FarmlandDebug("find gatherer success", BarrackDescribeUnit(unit), "units", #units)
            return unit
        end
    end

    FarmlandDebug("find gatherer none", "units", #units)
    return nil
end

function modifier_chen_barrack_farmland:CollectBloom(key, record, gatherer)
    local parent = self:GetParent()
    if not IsValidBarrackEntity(parent) or not record or not IsValidBarrackEntity(gatherer) then
        FarmlandDebug("collect skipped invalid state", "key", key, "parent", BarrackDescribeUnit(parent))
        self:DestroyBloom(key)
        return
    end

    local gold = self:GetFarmlandValue("tree_gold", 25)
    if not gatherer:FindModifierByName("modifier_chen_barrack_carrier") then
        gatherer:AddNewModifier(gatherer, nil, "modifier_chen_barrack_carrier", {})
    end

    local carried = ChenBarrackGold.AddCarrierGold(gatherer, gold)
    FarmlandDebug("collect bloom carried", "key", key, "gold", gold, "gatherer", BarrackDescribeUnit(gatherer), "carried", carried, "barrack_gold", ChenBarrackGold.Get(parent))

    self:DestroyBloom(key)
    self:BloomRandomTree()
end

function modifier_chen_barrack_farmland:UpdateGather(key, record, now)
    if not record then
        FarmlandDebug("update gather skipped missing record", "key", key)
        return
    end

    local position = GetTreePosition(record.tree)
    if not position then
        FarmlandDebug("update gather skipped no tree position", "key", key, DescribeTree(record.tree))
        self:DestroyBloom(key)
        return
    end

    if record.gathererEntindex then
        local gatherer = ResolveBarrackFromEntIndex(record.gathererEntindex)
        if not self:IsEligibleGatherer(gatherer) then
            FarmlandDebug("gather cancelled invalid gatherer", "key", key, "gatherer_idx", record.gathererEntindex)
            record.gathererEntindex = nil
            record.gatherCompleteAt = nil
            return
        end

        if now >= (record.gatherCompleteAt or now) then
            FarmlandDebug("gather complete", "key", key, "gatherer", BarrackDescribeUnit(gatherer), "now", now)
            return gatherer
        end
        FarmlandDebug("gather pending", "key", key, "gatherer", BarrackDescribeUnit(gatherer), "complete_at", record.gatherCompleteAt, "now", now)
        return
    end

    local gatherer = self:FindGatherer(position)
    if gatherer then
        record.gathererEntindex = gatherer:entindex()
        record.gatherCompleteAt = now + self:GetFarmlandValue("gather_time", 4)
        FarmlandDebug("gather started", "key", key, "gatherer", BarrackDescribeUnit(gatherer), "complete_at", record.gatherCompleteAt)
        EmitSoundOnLocationWithCaster(position, "Hero_Furion.Sprout", gatherer)
    end
end

function modifier_chen_barrack_farmland:ExpireBloom(key, record)
    local parent = self:GetParent()
    if not IsValidBarrackEntity(parent) or not record then
        FarmlandDebug("expire skipped invalid state", "key", key, "parent", BarrackDescribeUnit(parent))
        self:DestroyBloom(key)
        return
    end

    local position = GetTreePosition(record.tree)
    self:DestroyBloom(key)
    if not position then
        FarmlandDebug("expire skipped no position", "key", key)
        return
    end

    local spreadRadius = self:GetFarmlandValue("spread_radius", 200)
    local bloomRadius = self:GetFarmlandValue("bloom_radius", 800)
    local ok, trees = pcall(function()
        return GetTreesAroundPoint(position, spreadRadius, true)
    end)
    if not ok or not trees then
        FarmlandDebug("expire spread query failed", "key", key, "ok", ok, "trees", trees)
        return
    end

    local barrackPosition = parent:GetAbsOrigin()
    local spreadCount = 0
    for _, tree in pairs(trees) do
        local treePosition = GetTreePosition(tree)
        if IsTreeStanding(tree) and treePosition and (treePosition - barrackPosition):Length2D() <= bloomRadius then
            if self:BloomTree(tree) then
                spreadCount = spreadCount + 1
            end
        end
    end
    FarmlandDebug("expire spread", "key", key, "trees", #trees, "spread", spreadCount, "spread_radius", spreadRadius, "bloom_radius", bloomRadius)
end

function modifier_chen_barrack_farmland:OnIntervalThink()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if not IsValidBarrackEntity(parent) or not parent:IsAlive() or parent.chen_is_destroyed then
        FarmlandDebug("tick destroying invalid barrack", BarrackDescribeUnit(parent), "destroyed", parent and parent.chen_is_destroyed)
        self:Destroy()
        return
    end

    local now = GameRules:GetGameTime()
    local expired = {}
    local collected = {}
    FarmlandDebug("tick", BarrackDescribeUnit(parent), "active", self:GetActiveBloomCount(), "time", now)

    for key, record in pairs(self.blooms or {}) do
        if not record or not IsTreeStanding(record.tree) then
            FarmlandDebug("tick mark destroy", "key", key, "standing", record and IsTreeStanding(record.tree))
            expired[#expired + 1] = { key = key, record = record, destroyOnly = true }
        elseif now >= (record.expiresAt or now) then
            FarmlandDebug("tick mark expired", "key", key, "expires", record.expiresAt, "now", now)
            expired[#expired + 1] = { key = key, record = record }
        else
            local gatherer = self:UpdateGather(key, record, now)
            if gatherer then
                collected[#collected + 1] = { key = key, record = record, gatherer = gatherer }
            end
        end
    end

    for _, item in ipairs(collected) do
        if self.blooms[item.key] == item.record then
            self:CollectBloom(item.key, item.record, item.gatherer)
        end
    end

    for _, item in ipairs(expired) do
        if self.blooms[item.key] == item.record then
            if item.destroyOnly then
                self:DestroyBloom(item.key)
            else
                self:ExpireBloom(item.key, item.record)
            end
        end
    end

    if self:GetActiveBloomCount() == 0 then
        FarmlandDebug("tick no active blooms, creating random")
        self:BloomRandomTree()
    end
end

local WORKER_GATHER_ABILITY = "chen_worker_gather"

local function GetFarmlandModifier(barrack)
    if not IsValidBarrackEntity(barrack) then
        return nil
    end

    return barrack:FindModifierByName("modifier_chen_barrack_farmland")
end

function ChenBarrackGetFarmlandBlooms(barrack)
    if not IsValidBarrackEntity(barrack) then
        return nil
    end

    if barrack.chen_farmland_blooms then
        return barrack.chen_farmland_blooms
    end

    local farmlandModifier = GetFarmlandModifier(barrack)
    if farmlandModifier and farmlandModifier.blooms then
        barrack.chen_farmland_blooms = farmlandModifier.blooms
        return farmlandModifier.blooms
    end

    return nil
end

function ChenBarrackEnsureFarmlandBloom(barrack)
    local farmlandModifier = GetFarmlandModifier(barrack)
    if not farmlandModifier then
        return false
    end

    if farmlandModifier:GetActiveBloomCount() > 0 then
        return true
    end

    return farmlandModifier:BloomRandomTree()
end

-- Создаёт ещё один цветок, даже если активные уже есть (нужно, когда все известные
-- рабочему деревья оказались недостижимы и он их временно пропускает).
function ChenBarrackForceNewBloom(barrack)
    local farmlandModifier = GetFarmlandModifier(barrack)
    if not farmlandModifier then
        return false
    end

    return farmlandModifier:BloomRandomTree()
end

function ChenBarrackEnableWorkerGatherAutocast(worker)
    if not IsValidBarrackEntity(worker) then
        return
    end

    local ability = worker:FindAbilityByName(WORKER_GATHER_ABILITY)
    if ability and not ability:IsNull() and not ability:GetAutoCastState() then
        ability:ToggleAutoCast()
    end
end

local function CancelWorkerGatherClaim(worker)
    if not IsValidBarrackEntity(worker) then
        return
    end

    local workerIndex = worker:entindex()
    local blooms = ChenBarrackGetFarmlandBlooms(ChenBarrackGold.GetHomeBarrack(worker))
    if not blooms then
        return
    end

    for _, record in pairs(blooms) do
        if record and record.gathererEntindex == workerIndex then
            record.gathererEntindex = nil
            record.gatherCompleteAt = nil
        end
    end
end

local function GetWorkerGatherPauseDuration(worker)
    local duration = 15
    local ability = worker and worker:FindAbilityByName(WORKER_GATHER_ABILITY)
    if ability and not ability:IsNull() then
        local specialValue = ability:GetSpecialValueFor("manual_pause_duration")
        if specialValue and specialValue > 0 then
            duration = specialValue
        end
    end
    return duration
end

local function RefreshWorkerGatherPause(worker)
    if not IsValidBarrackEntity(worker) or not worker:IsAlive() then
        return
    end

    worker.chen_worker_gather_paused_until = GameRules:GetGameTime() + GetWorkerGatherPauseDuration(worker)
    worker.chen_worker_gather_target_key = nil
    CancelWorkerGatherClaim(worker)

    local aiModifier = worker:FindModifierByName("modifier_chen_worker_gather_ai")
    if aiModifier then
        aiModifier.waitingBloomKey = nil
        aiModifier.lastMoveTarget = nil
        aiModifier.targetBloomKey = nil
        aiModifier.progressDist = nil
    end
end

function chen_worker_gather:GetIntrinsicModifierName()
    return "modifier_chen_worker_gather_ai"
end

function chen_worker_gather:OnToggle()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    if caster and not caster:IsNull() and not self:GetAutoCastState() then
        caster.chen_worker_gather_target_key = nil
        local aiModifier = caster:FindModifierByName("modifier_chen_worker_gather_ai")
        if aiModifier then
            aiModifier.waitingBloomKey = nil
            aiModifier.lastMoveTarget = nil
            aiModifier.targetBloomKey = nil
            aiModifier.progressDist = nil
        end
    end
end

function modifier_chen_worker_gather_ai:IsHidden()
    return true
end

function modifier_chen_worker_gather_ai:IsPurgable()
    return false
end

function modifier_chen_worker_gather_ai:GetGatherValue(name, fallback)
    local ability = self:GetAbility()
    if ability and not ability:IsNull() then
        local value = ability:GetSpecialValueFor(name)
        if value and value > 0 then
            return value
        end
    end

    return fallback
end

function modifier_chen_worker_gather_ai:SetDebugState(state)
    self.debugState = state
end

function modifier_chen_worker_gather_ai:MaybeLogStatus(now)
    if not CHEN_GATHER_DEBUG then
        return
    end
    if self.lastStatusLog and (now - self.lastStatusLog) < 5 then
        return
    end
    self.lastStatusLog = now

    local parent = self:GetParent()
    local barrack = self:GetHomeBarrack()
    local blooms = barrack and ChenBarrackGetFarmlandBlooms(barrack)
    local bloomCount = 0
    if blooms then
        for _ in pairs(blooms) do
            bloomCount = bloomCount + 1
        end
    end

    GatherDebug(
        BarrackDescribeUnit(parent),
        "state",
        self.debugState or "nil",
        "autocast",
        tostring(self:IsAutocastActive()),
        "paused",
        tostring(self:IsPaused(now)),
        "carried",
        ChenBarrackGold.GetCarriedGold(parent),
        "home",
        barrack and "ok" or "none",
        "blooms",
        bloomCount,
        "pos",
        string.format("%.0f,%.0f", parent:GetAbsOrigin().x, parent:GetAbsOrigin().y)
    )
end

function modifier_chen_worker_gather_ai:OnCreated()
    if not IsServer() then
        return
    end

    self.waitingBloomKey = nil
    self.lastMoveTarget = nil
    self.targetBloomKey = nil
    self.progressDist = nil
    self.skipBlooms = {}
    self:StartIntervalThink(self:GetGatherValue("think_interval", 0.5))
end

function modifier_chen_worker_gather_ai:OnRefresh()
    if not IsServer() then
        return
    end

    self:StartIntervalThink(self:GetGatherValue("think_interval", 0.5))
end

function modifier_chen_worker_gather_ai:IsAutocastActive()
    local ability = self:GetAbility()
    return ability and not ability:IsNull() and ability:GetAutoCastState()
end

function modifier_chen_worker_gather_ai:IsPaused(now)
    local parent = self:GetParent()
    return parent.chen_worker_gather_paused_until and now < parent.chen_worker_gather_paused_until
end

function modifier_chen_worker_gather_ai:GetHomeBarrack()
    local barrack = ChenBarrackGold.GetHomeBarrack(self:GetParent())
    if IsValidBarrackEntity(barrack) and barrack:IsAlive() and not barrack.chen_is_destroyed then
        return barrack
    end
    return nil
end

function modifier_chen_worker_gather_ai:FindNearestBloom(barrack, now)
    local parent = self:GetParent()
    local blooms = ChenBarrackGetFarmlandBlooms(barrack)
    if not blooms then
        return nil
    end

    local farmlandModifier = GetFarmlandModifier(barrack)
    local workerIndex = parent:entindex()
    local parentPosition = parent:GetAbsOrigin()
    local bestKey, bestRecord, bestDistance

    for key, record in pairs(blooms) do
        if record and not (self.skipBlooms and self.skipBlooms[key]) then
            local skip = false
            if record.gathererEntindex and record.gathererEntindex ~= workerIndex then
                local claimer = ResolveBarrackFromEntIndex(record.gathererEntindex)
                if farmlandModifier and farmlandModifier:IsEligibleGatherer(claimer) then
                    skip = true
                else
                    record.gathererEntindex = nil
                    record.gatherCompleteAt = nil
                end
            end

            if not skip then
                local treePosition = GetTreePosition(record.tree)
                if treePosition and IsTreeStanding(record.tree) and now < (record.expiresAt or now) then
                    local distance = (treePosition - parentPosition):Length2D()
                    if not bestDistance or distance < bestDistance then
                        bestDistance = distance
                        bestKey = key
                        bestRecord = record
                    end
                end
            end
        end
    end

    return bestKey, bestRecord
end

function modifier_chen_worker_gather_ai:IssueMoveTo(position)
    if not position then
        return
    end

    local parent = self:GetParent()
    if self.lastMoveTarget and (self.lastMoveTarget - position):Length2D() < 16 then
        return
    end

    parent.chen_worker_ai_order = true
    ExecuteOrderFromTable({
        UnitIndex = parent:entindex(),
        OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
        Position = position,
        Queue = false,
    })
    parent.chen_worker_ai_order = nil
    self.lastMoveTarget = position
end

function modifier_chen_worker_gather_ai:IssueStop()
    local parent = self:GetParent()
    parent.chen_worker_ai_order = true
    ExecuteOrderFromTable({
        UnitIndex = parent:entindex(),
        OrderType = DOTA_UNIT_ORDER_STOP,
        Queue = false,
    })
    parent.chen_worker_ai_order = nil
    self.lastMoveTarget = nil
end

function modifier_chen_worker_gather_ai:TickDeliverGold(barrack)
    local parent = self:GetParent()
    local homePosition = barrack:GetAbsOrigin()
    local homeRadius = self:GetGatherValue("home_arrive_radius", 240)

    self.waitingBloomKey = nil
    parent.chen_worker_gather_target_key = nil

    if (parent:GetAbsOrigin() - homePosition):Length2D() <= homeRadius then
        self:SetDebugState("deposit", "gold", ChenBarrackGold.GetCarriedGold(parent))
        ChenBarrackGold.DepositCarrierGold(parent)
        self.lastMoveTarget = nil
        self:TickGatherGold(barrack, GameRules:GetGameTime())
        return
    end

    self:SetDebugState("returning_home", "carried", ChenBarrackGold.GetCarriedGold(parent))
    self:IssueMoveTo(homePosition)
end

function modifier_chen_worker_gather_ai:GetBloomRecord(barrack, key)
    local blooms = ChenBarrackGetFarmlandBlooms(barrack)
    return blooms and blooms[key] or nil
end

function modifier_chen_worker_gather_ai:CleanupSkips(now)
    if not self.skipBlooms then
        return
    end
    for k, expireAt in pairs(self.skipBlooms) do
        if now >= expireAt then
            self.skipBlooms[k] = nil
        end
    end
end

-- Цель ещё пригодна: дерево стоит, цветок не истёк, не в списке пропуска и не
-- застолблён другим рабочим.
function modifier_chen_worker_gather_ai:IsTargetUsable(barrack, key, record, now)
    if not key or not record then
        return false
    end
    if self.skipBlooms and self.skipBlooms[key] then
        return false
    end
    if not IsTreeStanding(record.tree) or not GetTreePosition(record.tree) then
        return false
    end
    if now >= (record.expiresAt or now) then
        return false
    end
    if record.gathererEntindex and record.gathererEntindex ~= self:GetParent():entindex() then
        local farmlandModifier = GetFarmlandModifier(barrack)
        local claimer = ResolveBarrackFromEntIndex(record.gathererEntindex)
        if farmlandModifier and farmlandModifier:IsEligibleGatherer(claimer) then
            return false
        end
    end
    return true
end

function modifier_chen_worker_gather_ai:TickGatherGold(barrack, now)
    local parent = self:GetParent()
    local treeRadius = self:GetGatherValue("tree_arrive_radius", 110)

    self:CleanupSkips(now)

    -- Держимся за уже выбранную цель, пока она пригодна (анти-трешинг). Новую
    -- выбираем только если прежней нет/она невалидна.
    local key = self.targetBloomKey
    local record = key and self:GetBloomRecord(barrack, key) or nil
    if not self:IsTargetUsable(barrack, key, record, now) then
        key, record = self:FindNearestBloom(barrack, now)
        self.targetBloomKey = key
        self.progressDist = nil
        self.progressTime = now
    end

    if not key or not record then
        self:SetDebugState("no_bloom")
        self.waitingBloomKey = nil
        self.targetBloomKey = nil
        parent.chen_worker_gather_target_key = nil
        -- Все известные деревья недостижимы/отсутствуют — форсим новое (с троттлом).
        if not self.lastForceBloom or (now - self.lastForceBloom) >= self:GetGatherValue("force_bloom_interval", 1.0) then
            self.lastForceBloom = now
            ChenBarrackForceNewBloom(barrack)
        end
        return
    end

    parent.chen_worker_gather_target_key = key
    local treePosition = GetTreePosition(record.tree)
    local distToTree = (parent:GetAbsOrigin() - treePosition):Length2D()

    if distToTree <= treeRadius then
        if self.waitingBloomKey ~= key then
            self.waitingBloomKey = key
            self:IssueStop()
        end
        self:SetDebugState("waiting_at_tree:" .. tostring(key))
        return
    end

    -- Детект застревания: требуем стабильного приближения к дереву. Если прогресса
    -- нет дольше stuck_time — помечаем дерево недостижимым и берём другое.
    local stuckTime = self:GetGatherValue("stuck_time", 2.5)
    if self.progressDist == nil or distToTree < (self.progressDist - 8) then
        self.progressDist = distToTree
        self.progressTime = now
    elseif (now - (self.progressTime or now)) >= stuckTime then
        self.skipBlooms = self.skipBlooms or {}
        self.skipBlooms[key] = now + self:GetGatherValue("skip_duration", 15)
        self.targetBloomKey = nil
        self.waitingBloomKey = nil
        self.progressDist = nil
        self:SetDebugState("skip_unreachable:" .. tostring(key))
        return
    end

    self.waitingBloomKey = nil
    self:SetDebugState("moving_to_tree:" .. tostring(key))

    -- Не подходим в упор к стволу (его клетка и плотные рощи рядом часто
    -- заблокированы — путь не строится). Целимся на радиус сбора со стороны
    -- рабочего: точка дальше от дерева почти всегда на проходимой земле, а барак
    -- всё равно подбирает крипа в пределах gather_trigger_radius.
    local moveTarget = treePosition
    local toWorker = parent:GetAbsOrigin() - treePosition
    if distToTree > 1 then
        local approach = math.min(distToTree, treeRadius * 0.9)
        moveTarget = treePosition + toWorker:Normalized() * approach
    end

    self:IssueMoveTo(moveTarget)
end

function modifier_chen_worker_gather_ai:RunGatherTick()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if not IsValidBarrackEntity(parent) or not parent:IsAlive() then
        return
    end

    local now = GameRules:GetGameTime()
    self:MaybeLogStatus(now)

    if not self:IsAutocastActive() then
        self:SetDebugState("autocast_off")
        return
    end
    if self:IsPaused(now) then
        self:SetDebugState("paused", "until", parent.chen_worker_gather_paused_until)
        return
    end
    if ChenWorkerBuild and ChenWorkerBuild.IsGatherBlocked and ChenWorkerBuild.IsGatherBlocked(parent) then
        self:SetDebugState("building")
        return
    end

    local barrack = self:GetHomeBarrack()
    if not barrack then
        self:SetDebugState("no_home_barrack")
        return
    end

    if ChenBarrackGold.GetCarriedGold(parent) > 0 then
        self:TickDeliverGold(barrack)
        return
    end

    self:TickGatherGold(barrack, now)
end

function modifier_chen_worker_gather_ai:OnIntervalThink()
    self:RunGatherTick()
end

function ChenBarrackKickWorkerGather(worker)
    if not IsValidBarrackEntity(worker) or not worker:IsAlive() then
        return
    end

    local aiModifier = worker:FindModifierByName("modifier_chen_worker_gather_ai")
    if aiModifier and aiModifier.RunGatherTick then
        GatherDebug("kick", BarrackDescribeUnit(worker))
        aiModifier:RunGatherTick()
    end
end

local function IsWorkerPauseOrder(orderType)
    return orderType == DOTA_UNIT_ORDER_MOVE_TO_POSITION
        or orderType == DOTA_UNIT_ORDER_MOVE_TO_TARGET
        or orderType == DOTA_UNIT_ORDER_MOVE_TO_DIRECTION
        or orderType == DOTA_UNIT_ORDER_ATTACK_MOVE
        or orderType == DOTA_UNIT_ORDER_ATTACK_TARGET
end

function ChenBarrackWorkerHandleOrder(data)
    if not IsServer() or not data or not IsWorkerPauseOrder(data.order_type) then
        return true
    end

    if data.issuer_player_id_const == nil or data.issuer_player_id_const < 0 then
        return true
    end

    for _, unitIndex in pairs(data.units or {}) do
        local index = tonumber(unitIndex)
        local unit = index and EntIndexToHScript(index) or nil
        if IsChenBarrackWorker(unit) and unit:IsAlive() and not unit.chen_worker_ai_order then
            RefreshWorkerGatherPause(unit)
        end
    end

    return true
end

function chen_barrack:OnUpgrade()
    if not IsServer() then
        return
    end

    local hero = self:GetCaster()
    if not hero or hero:IsNull() then
        return
    end

    ForEachBarrackOwnedByHero(hero, function(b)
        LevelBarrackAbilities(b)
    end)
end

function chen_barrack:OnSpellStart()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    if not caster or caster:IsNull() then
        return
    end

    local existingBarrack = GetLivingBarrackForHero(caster)
    if existingBarrack then
        FocusPlayerOnBarrack(caster:GetPlayerOwnerID(), existingBarrack)
        self:EndCooldown()
        caster:GiveMana(self:GetManaCost(self:GetLevel()))
        return
    end

    local point = self:GetCursorPosition()
    local forward = caster:GetForwardVector()
    local playerID = caster:GetPlayerOwnerID()
    local teamNumber = caster:GetTeamNumber()
    local barrackHealth = self:GetSpecialValueFor("minimum_barrack_health")

    local barrack = CreateUnitByName(CHEN_BARRACK_UNIT, point, true, caster, caster, teamNumber)
    if not barrack then
        return
    end

    barrack.chen_barrack_owner_entindex = caster:entindex()
    barrack.chen_barrack_owner_hero = caster
    barrack.chen_barrack_created_time = GameRules:GetGameTime()
    barrack.chen_barrack_gold = 0

    CHEN_BARRACK_REGISTRY[barrack:entindex()] = caster:entindex()

    barrack:SetOwner(caster)
    barrack:SetControllableByPlayer(playerID, true)
    if barrack.SetPlayerID then
        barrack:SetPlayerID(playerID)
    end
    barrack:SetForwardVector(forward)
    barrack:SetMoveCapability(DOTA_UNIT_CAP_MOVE_NONE)
    barrack:AddNewModifier(caster, self, "modifier_chen_barrack", {})

    barrack:SetBaseMaxHealth(barrackHealth)
    barrack:SetMaxHealth(barrackHealth)
    barrack:SetHealth(barrackHealth)

    barrack:SetModel(BARRACK_MODEL)
    barrack:SetOriginalModel(BARRACK_MODEL)

    FindClearSpaceForUnit(barrack, point, false)
    LevelBarrackAbilities(barrack)
    ChenBarrackGold.SyncDisplay(barrack)
    BarrackDebug("Barrack spawned", BarrackDescribeUnit(barrack), "owner", BarrackDescribeUnit(caster))

    Timers:CreateTimer(0.1, function()
        LevelBarrackAbilities(barrack)
        DebugBarrackAbilities(barrack, "Barrack abilities ready")
        return nil
    end)

    Timers:CreateTimer(0.5, function()
        LevelBarrackAbilities(barrack)
        DebugBarrackAbilities(barrack, "Barrack abilities recheck")
        return nil
    end)

    -- Стартовый рабочий при создании барака. Бесплатен только если у Чена ещё нет
    -- живых рабочих под контролем; дистанция спавна — штатная (из способности).
    Timers:CreateTimer(0.3, function()
        if not barrack or barrack:IsNull() or not barrack:IsAlive() or barrack.chen_is_destroyed then
            return nil
        end

        if not IsFirstWorkerFree(caster) then
            return nil
        end

        local spawnDistance = 360
        local summonAbility = barrack:FindAbilityByName("chen_barrack_summon_worker")
        if summonAbility and not summonAbility:IsNull() then
            local value = GetBarrackSummonValue(summonAbility, caster, "spawn_distance")
            if value and value > 0 then
                spawnDistance = value
            end
        end

        CompleteProduction(barrack, {
            unit_name = CHEN_BARRACK_WORKER_UNIT,
            gold_cost = 0,
            production_time = 0,
            spawn_distance = spawnDistance,
            summon_lifetime = 0,
            gold_mode = "carrier",
            is_worker = true,
        })
        return nil
    end)

    EmitSoundOn("Hero_Chen.HolyPersuasionEnemy", barrack)
end

function chen_barrack_summon_worker:CastFilterResult()
    return BarrackWorkerCastFilter(self)
end

function chen_barrack_summon_worker:GetCustomCastError()
    return BarrackWorkerCastError(self)
end

function chen_barrack_summon_worker:OnSpellStart()
    QueueBarrackWorker(self)
end

function chen_barrack_summon_hunter:CastFilterResult()
    return BarrackHunterCastFilter(self)
end

function chen_barrack_summon_hunter:GetCustomCastError()
    return BarrackHunterCastError(self)
end

function chen_barrack_summon_hunter:OnSpellStart()
    QueueBarrackHunter(self)
end

function chen_barrack_summon_healer:CastFilterResult()
    return BarrackHealerCastFilter(self)
end

function chen_barrack_summon_healer:GetCustomCastError()
    return BarrackHealerCastError(self)
end

function chen_barrack_summon_healer:OnSpellStart()
    QueueBarrackHealer(self)
end

function chen_barrack_summon_brute:CastFilterResult()
    return BarrackBruteCastFilter(self)
end

function chen_barrack_summon_brute:GetCustomCastError()
    return BarrackBruteCastError(self)
end

function chen_barrack_summon_brute:OnSpellStart()
    QueueBarrackBrute(self)
end

function modifier_chen_barrack:IsHidden()
    return true
end

function modifier_chen_barrack:IsPurgable()
    return false
end

function modifier_chen_barrack_producing:OnCreated(kv)
    if kv then
        if kv.unit_name and kv.unit_name ~= "" then
            self.unit_name = kv.unit_name
        end
        if kv.duration and kv.duration > 0 then
            self.is_producing = true
            self:SetStackCount(math.max(1, math.ceil(kv.duration)))
        else
            self.is_producing = false
            self:SetStackCount(0)
        end
    end

    if IsServer() then
        self:StartIntervalThink(0.25)
    end
end

function modifier_chen_barrack_producing:OnIntervalThink()
    if not IsServer() or not self.is_producing then
        return
    end

    local remaining = self:GetRemainingTime()
    if remaining and remaining > 0 then
        self:SetStackCount(math.max(1, math.ceil(remaining)))
    end
end

function modifier_chen_barrack_producing:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_TOOLTIP,
    }
end

function modifier_chen_barrack_producing:OnTooltip()
    if IsServer() and not self.is_producing then
        return 0
    end

    local remaining = self:GetRemainingTime()
    if remaining and remaining > 0 then
        return math.ceil(remaining)
    end

    return 0
end

function modifier_chen_barrack_producing:IsHidden()
    return false
end

function modifier_chen_barrack_producing:IsPurgable()
    return false
end

function modifier_chen_barrack_producing:IsStackable()
    return true
end

function modifier_chen_barrack_producing:GetAttributes()
    return MODIFIER_ATTRIBUTE_MULTIPLE
end
