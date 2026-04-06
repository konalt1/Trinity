chen_barrack = class({})
chen_barrack_summon_melee = class({})
chen_barrack_summon_ranged = class({})
chen_barrack_summon_siege = class({})

local BARRACK_MODEL = "models/props_structures/good_barracks_melee001.vmdl"

local function IsChenBarrackUnit(unit)
    if not unit or unit:IsNull() then
        return false
    end

    local unitName = unit:GetUnitName() or ""
    return string.find(unitName, "npc_chen_barrack", 1, true) == 1
end

local function IsChenTamedCreep(unit, caster)
    if not unit or unit:IsNull() or not unit:IsAlive() then
        return false
    end

    if not unit:IsCreep() or unit:IsHero() or unit:IsAncient() then
        return false
    end

    if IsChenBarrackUnit(unit) then
        return false
    end

    if unit:GetTeamNumber() ~= caster:GetTeamNumber() then
        return false
    end

    if unit:GetPlayerOwnerID() ~= caster:GetPlayerOwnerID() then
        return false
    end

    return unit:GetOwnerEntity() == caster
end

local function GetBarrackOwnerHero(unit)
    if not unit or unit:IsNull() then
        return nil
    end

    local owner = unit:GetOwnerEntity()
    if owner and not owner:IsNull() and owner:IsRealHero() then
        return owner
    end

    if unit.chen_barrack_owner_entindex then
        local ownerFromIndex = EntIndexToHScript(unit.chen_barrack_owner_entindex)
        if ownerFromIndex and not ownerFromIndex:IsNull() and ownerFromIndex:IsRealHero() then
            return ownerFromIndex
        end
    end

    return nil
end

local function HasEnoughGold(hero, goldCost)
    if not hero or hero:IsNull() then
        return false
    end

    local playerID = hero:GetPlayerOwnerID()
    if playerID == nil or playerID < 0 then
        return false
    end

    return PlayerResource:GetGold(playerID) >= goldCost
end

local function SpendGold(hero, goldCost)
    if goldCost <= 0 then
        return
    end

    hero:ModifyGold(-goldCost, false, DOTA_ModifyGold_Unspecified)
end

local function LevelBarrackAbilities(barrack)
    for slot = 0, 5 do
        local ability = barrack:GetAbilityByIndex(slot)
        if ability and ability:GetLevel() == 0 then
            ability:SetLevel(1)
        end
    end
end

local function GetBarrackModel(teamNumber)
    return BARRACK_MODEL
end

local function BarrackSummonCastFilter(self)
    local barrack = self:GetCaster()
    local ownerHero = GetBarrackOwnerHero(barrack)
    local goldCost = self:GetSpecialValueFor("gold_cost")

    if not ownerHero or ownerHero:IsNull() then
        return UF_FAIL_CUSTOM
    end

    if not HasEnoughGold(ownerHero, goldCost) then
        return UF_FAIL_CUSTOM
    end

    return UF_SUCCESS
end

local function BarrackSummonCastError(self)
    local ownerHero = GetBarrackOwnerHero(self:GetCaster())
    if not ownerHero or ownerHero:IsNull() then
        return "#dota_hud_error_chen_barrack_no_owner"
    end

    if not HasEnoughGold(ownerHero, self:GetSpecialValueFor("gold_cost")) then
        return "#dota_hud_error_not_enough_gold"
    end

    return ""
end

local function SpawnBarrackUnit(self, unitName)
    if not IsServer() then
        return
    end

    local barrack = self:GetCaster()
    local ownerHero = GetBarrackOwnerHero(barrack)
    if not ownerHero then
        return
    end

    local goldCost = self:GetSpecialValueFor("gold_cost")
    if not HasEnoughGold(ownerHero, goldCost) then
        return
    end

    SpendGold(ownerHero, goldCost)

    local playerID = ownerHero:GetPlayerOwnerID()
    local spawnDistance = self:GetSpecialValueFor("spawn_distance")
    local spawnPosition = barrack:GetAbsOrigin() + barrack:GetForwardVector() * spawnDistance + RandomVector(75)
    local summon = CreateUnitByName(unitName, spawnPosition, true, ownerHero, ownerHero, ownerHero:GetTeamNumber())
    if not summon then
        return
    end

    summon:SetOwner(ownerHero)
    summon:SetControllableByPlayer(playerID, true)
    FindClearSpaceForUnit(summon, spawnPosition, true)

    EmitSoundOn("Hero_Chen.TeleportLoop", summon)
end

function chen_barrack:CastFilterResultTarget(target)
    if IsChenTamedCreep(target, self:GetCaster()) then
        return UF_SUCCESS
    end

    return UF_FAIL_CUSTOM
end

function chen_barrack:GetCustomCastErrorTarget(target)
    return "#dota_hud_error_chen_barrack_invalid_target"
end

function chen_barrack:OnSpellStart()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    local target = self:GetCursorTarget()
    if not IsChenTamedCreep(target, caster) then
        return
    end

    local origin = target:GetAbsOrigin()
    local forward = target:GetForwardVector()
    local playerID = caster:GetPlayerOwnerID()
    local teamNumber = caster:GetTeamNumber()
    local targetMaxHealth = math.max(target:GetMaxHealth(), target:GetHealth())
    local bonusHealth = self:GetSpecialValueFor("bonus_health")
    local minimumBarrackHealth = self:GetSpecialValueFor("minimum_barrack_health")

    if target:IsAlive() then
        target:ForceKill(false)
    end
    UTIL_Remove(target)

    local barrack = CreateUnitByName("npc_chen_barrack", origin, true, caster, caster, teamNumber)
    if not barrack then
        return
    end

    barrack.chen_barrack_owner_entindex = caster:entindex()
    barrack:SetOwner(caster)
    barrack:SetControllableByPlayer(playerID, true)
    barrack:SetForwardVector(forward)
    barrack:SetMoveCapability(DOTA_UNIT_CAP_MOVE_NONE)

    local barrackMaxHealth = math.max(minimumBarrackHealth, targetMaxHealth + bonusHealth)
    barrack:SetBaseMaxHealth(barrackMaxHealth)
    barrack:SetMaxHealth(barrackMaxHealth)
    barrack:SetHealth(barrackMaxHealth)

    local model = GetBarrackModel(teamNumber)
    barrack:SetModel(model)
    barrack:SetOriginalModel(model)

    LevelBarrackAbilities(barrack)

    EmitSoundOn("Hero_Chen.HolyPersuasionEnemy", barrack)
end

function chen_barrack_summon_melee:CastFilterResult()
    return BarrackSummonCastFilter(self)
end

function chen_barrack_summon_melee:GetCustomCastError()
    return BarrackSummonCastError(self)
end

function chen_barrack_summon_melee:OnSpellStart()
    SpawnBarrackUnit(self, "npc_chen_barrack_melee")
end

function chen_barrack_summon_ranged:CastFilterResult()
    return BarrackSummonCastFilter(self)
end

function chen_barrack_summon_ranged:GetCustomCastError()
    return BarrackSummonCastError(self)
end

function chen_barrack_summon_ranged:OnSpellStart()
    SpawnBarrackUnit(self, "npc_chen_barrack_ranged")
end

function chen_barrack_summon_siege:CastFilterResult()
    return BarrackSummonCastFilter(self)
end

function chen_barrack_summon_siege:GetCustomCastError()
    return BarrackSummonCastError(self)
end

function chen_barrack_summon_siege:OnSpellStart()
    SpawnBarrackUnit(self, "npc_chen_barrack_siege")
end
