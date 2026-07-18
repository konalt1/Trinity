require("abilities/chen/barrack/units/chen_ancient_black_dragon_fire_puddle")
require("abilities/chen/barrack/units/chen_giant_courier_transport")

chen_sub_barrack_summon_giant_courier = class({})
chen_sub_barrack_summon_dragon = class({})

ChenSubBarrack = ChenSubBarrack or {}

local GIANT_COURIER_UNIT = "npc_chen_giant_courier"
local DRAGON_UNIT = "npc_chen_ancient_black_dragon"

local function IsValidEntity(entity)
    return entity and not entity:IsNull()
end

local function GetOwnerHero(unit)
    if GetBarrackOwnerHero then
        return GetBarrackOwnerHero(unit)
    end
    return nil
end

function ChenSubBarrack.GetHomeBarrack(subBarrack)
    if not IsValidEntity(subBarrack) then
        return nil
    end

    if subBarrack.chen_sub_barrack_home_entindex then
        local ok, barrack = pcall(EntIndexToHScript, subBarrack.chen_sub_barrack_home_entindex)
        if ok and IsValidEntity(barrack) and barrack:IsAlive() then
            return barrack
        end
    end

    local ownerHero = GetOwnerHero(subBarrack)
    if ownerHero and GetLivingBarrackForHero then
        return GetLivingBarrackForHero(ownerHero)
    end

    return nil
end

local function InitSubBarrackState(barrack)
    barrack.chen_production_queue = barrack.chen_production_queue or {}
    barrack.chen_active_productions = barrack.chen_active_productions or 0
end

local function GetQueuedCount(barrack)
    InitSubBarrackState(barrack)
    return #barrack.chen_production_queue + (barrack.chen_active_productions or 0)
end

local function CreateSummonUnit(item, spawnPosition, ownerHero, teamNumber)
    return CreateUnitByName(item.unit_name, spawnPosition, true, ownerHero, ownerHero, teamNumber)
end

local function CompleteSummon(subBarrack, item)
    local ownerHero = GetOwnerHero(subBarrack)
    local homeBarrack = ChenSubBarrack.GetHomeBarrack(subBarrack)
    if not ownerHero or not homeBarrack or not subBarrack:IsAlive() then
        if homeBarrack then
            ChenBarrackGold.Add(homeBarrack, item.gold_cost or 0, "sub_barrack_refund")
        end
        return
    end

    local spawnDistance = item.spawn_distance or 360
    local spawnPosition = subBarrack:GetAbsOrigin() + subBarrack:GetForwardVector() * spawnDistance + RandomVector(60)
    local summon = CreateSummonUnit(item, spawnPosition, ownerHero, ownerHero:GetTeamNumber())
    if not summon or summon:IsNull() then
        ChenBarrackGold.Add(homeBarrack, item.gold_cost or 0, "sub_barrack_refund")
        return
    end

    ChenBarrackGold.RegisterBarrackUnit(summon, homeBarrack, ownerHero, "shared_carrier")
    summon:SetOwner(ownerHero)
    summon:SetControllableByPlayer(ownerHero:GetPlayerOwnerID(), true)
    FindClearSpaceForUnit(summon, spawnPosition, true)
end

local function StartNextProduction(subBarrack)
    if not IsValidEntity(subBarrack) or not subBarrack:IsAlive() then
        return
    end

    InitSubBarrackState(subBarrack)
    local item = table.remove(subBarrack.chen_production_queue, 1)
    if not item then
        return
    end

    subBarrack.chen_active_productions = (subBarrack.chen_active_productions or 0) + 1
    subBarrack.chen_current_order = item

    local productionTime = math.max(0.1, tonumber(item.production_time) or 30)
    item.production_time = productionTime

    if ChenBarrackProduction then
        ChenBarrackProduction.EnsureModifier(subBarrack, item)
        ChenBarrackProduction.RecalculateTimers(subBarrack)
    end

    Timers:CreateTimer(productionTime, function()
        if not IsValidEntity(subBarrack) or not subBarrack:IsAlive() then
            if ChenBarrackProduction then
                ChenBarrackProduction.DestroyModifier(item)
            end
            subBarrack.chen_active_productions = math.max(0, (subBarrack.chen_active_productions or 1) - 1)
            subBarrack.chen_current_order = nil
            StartNextProduction(subBarrack)
            return nil
        end

        CompleteSummon(subBarrack, item)
        if ChenBarrackProduction then
            ChenBarrackProduction.DestroyModifier(item)
        end
        subBarrack.chen_active_productions = math.max(0, (subBarrack.chen_active_productions or 1) - 1)
        subBarrack.chen_current_order = nil
        StartNextProduction(subBarrack)
        return nil
    end)
end

local function QueueSummon(self, unitName)
    if not IsServer() then
        return
    end

    local subBarrack = self:GetCaster()
    local homeBarrack = ChenSubBarrack.GetHomeBarrack(subBarrack)
    if not homeBarrack or not homeBarrack:IsAlive() then
        return
    end

    if subBarrack:HasModifier("modifier_chen_building_construction") then
        return
    end

    ChenSubBarrack.EnsureSummonAbility(subBarrack)

    InitSubBarrackState(subBarrack)
    if GetQueuedCount(subBarrack) >= 5 then
        return
    end

    local goldCost = self:GetSpecialValueFor("gold_cost")
    if not ChenBarrackGold.Has(homeBarrack, goldCost) then
        return
    end
    if not ChenBarrackGold.Spend(homeBarrack, goldCost, "sub_barrack_summon") then
        return
    end

    local item = {
        unit_name = unitName,
        gold_cost = goldCost,
        production_time = self:GetSpecialValueFor("production_time"),
        spawn_distance = self:GetSpecialValueFor("spawn_distance"),
    }

    table.insert(subBarrack.chen_production_queue, item)
    EmitSoundOn("General.Buy", subBarrack)

    if (subBarrack.chen_active_productions or 0) > 0 and ChenBarrackProduction then
        ChenBarrackProduction.RecalculateTimers(subBarrack)
    elseif (subBarrack.chen_active_productions or 0) == 0 then
        StartNextProduction(subBarrack)
    end

    self:EndCooldown()
end

local function SummonCastFilter(self)
    if not IsServer() then
        return UF_SUCCESS
    end

    local subBarrack = self:GetCaster()
    if subBarrack:HasModifier("modifier_chen_building_construction") then
        return UF_FAIL_CUSTOM
    end

    local homeBarrack = ChenSubBarrack.GetHomeBarrack(subBarrack)
    if not homeBarrack or not homeBarrack:IsAlive() then
        return UF_FAIL_CUSTOM
    end

    InitSubBarrackState(subBarrack)
    if GetQueuedCount(subBarrack) >= 5 then
        return UF_FAIL_CUSTOM
    end

    if not ChenBarrackGold.Has(homeBarrack, self:GetSpecialValueFor("gold_cost")) then
        return UF_FAIL_CUSTOM
    end

    return UF_SUCCESS
end

local function SummonCastError(self)
    if not IsServer() then
        return ""
    end

    local subBarrack = self:GetCaster()
    if subBarrack:HasModifier("modifier_chen_building_construction") then
        return "#dota_hud_error_chen_sub_barrack_under_construction"
    end

    local homeBarrack = ChenSubBarrack.GetHomeBarrack(subBarrack)
    if not homeBarrack or not homeBarrack:IsAlive() then
        return "#dota_hud_error_chen_barrack_no_owner"
    end

    InitSubBarrackState(subBarrack)
    if GetQueuedCount(subBarrack) >= 5 then
        return "#dota_hud_error_chen_barrack_queue_full"
    end

    if not ChenBarrackGold.Has(homeBarrack, self:GetSpecialValueFor("gold_cost")) then
        return "#dota_hud_error_chen_barrack_not_enough_gold"
    end

    return ""
end

function ChenSubBarrack.DisableProduction(subBarrack)
    if not IsValidEntity(subBarrack) then
        return
    end

    for slot = 0, subBarrack:GetAbilityCount() - 1 do
        local ability = subBarrack:GetAbilityByIndex(slot)
        if ability and not ability:IsNull() then
            ability:SetActivated(false)
        end
    end
end

local SUB_BARRACK_SUMMON_ABILITIES = {
    courier = "chen_sub_barrack_summon_giant_courier",
    dragon = "chen_sub_barrack_summon_dragon",
}

function ChenSubBarrack.EnsureSummonAbility(subBarrack)
    if not IsValidEntity(subBarrack) then
        return nil
    end

    local abilityName = SUB_BARRACK_SUMMON_ABILITIES[subBarrack.chen_sub_barrack_type or ""]
    if not abilityName then
        for slot = 0, subBarrack:GetAbilityCount() - 1 do
            local ability = subBarrack:GetAbilityByIndex(slot)
            if ability and not ability:IsNull() then
                return ability
            end
        end
        return nil
    end

    local ability = subBarrack:FindAbilityByName(abilityName)
    if not ability or ability:IsNull() then
        ability = subBarrack:AddAbility(abilityName)
    end

    if ability and not ability:IsNull() then
        ability:SetHidden(false)
        ability:SetLevel(1)
        ability:SetActivated(true)
    end

    return ability
end

function ChenSubBarrack.EnableProduction(subBarrack)
    if not IsValidEntity(subBarrack) then
        return
    end

    ChenSubBarrack.EnsureSummonAbility(subBarrack)

    for slot = 0, subBarrack:GetAbilityCount() - 1 do
        local ability = subBarrack:GetAbilityByIndex(slot)
        if ability and not ability:IsNull() then
            ability:SetHidden(false)
            ability:SetActivated(true)
            if ability:GetLevel() < 1 then
                ability:SetLevel(1)
            end
        end
    end
end

function chen_sub_barrack_summon_giant_courier:CastFilterResult()
    return SummonCastFilter(self)
end

function chen_sub_barrack_summon_giant_courier:GetCustomCastError()
    return SummonCastError(self)
end

function chen_sub_barrack_summon_giant_courier:OnSpellStart()
    QueueSummon(self, GIANT_COURIER_UNIT)
end

function chen_sub_barrack_summon_dragon:CastFilterResult()
    return SummonCastFilter(self)
end

function chen_sub_barrack_summon_dragon:GetCustomCastError()
    return SummonCastError(self)
end

function chen_sub_barrack_summon_dragon:OnSpellStart()
    QueueSummon(self, DRAGON_UNIT)
end

function ChenSubBarrack.Precache(context)
    PrecacheResource("model", "models/courier/baby_rosh/babyroshan_ti9_flying.vmdl", context)
    PrecacheResource("model", "models/creeps/neutral_creeps/n_creep_black_dragon/n_creep_black_dragon.vmdl", context)
    PrecacheResource("particle", "particles/neutral_fx/black_dragon_attack.vpcf", context)
    PrecacheResource("particle", "particles/units/neutral/black_dragon/black_dragon_fireball.vpcf", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_creeps.vsndevts", context)
    PrecacheUnitByNameSync(GIANT_COURIER_UNIT, context)
    PrecacheUnitByNameSync(DRAGON_UNIT, context)
end

function chen_sub_barrack_summon_giant_courier:Precache(context)
    ChenSubBarrack.Precache(context)
end

function chen_sub_barrack_summon_dragon:Precache(context)
    ChenSubBarrack.Precache(context)
end
