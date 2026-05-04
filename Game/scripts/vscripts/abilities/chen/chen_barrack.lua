LinkLuaModifier("modifier_chen_barrack", "abilities/chen/chen_barrack", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_barrack_producing", "abilities/chen/chen_barrack", LUA_MODIFIER_MOTION_NONE)

chen_barrack = class({})
chen_barrack_summon_melee = class({})
chen_barrack_summon_ranged = class({})
chen_barrack_summon_siege = class({})
chen_barrack_self_destruct = class({})
modifier_chen_barrack = class({})
modifier_chen_barrack_producing = class({})

local BARRACK_MODEL = "models/props_structures/good_barracks_melee001.vmdl"

local function GetTalentValue(hero, talentName, valueName, fallback)
    if not hero or hero:IsNull() then
        return fallback or 0
    end

    local talent = hero:FindAbilityByName(talentName)
    if not talent or talent:IsNull() or talent:GetLevel() <= 0 then
        return fallback or 0
    end

    local value = 0
    if valueName then
        value = talent:GetSpecialValueFor(valueName)
    end
    if value == 0 then
        value = talent:GetSpecialValueFor("value")
    end

    return value or fallback or 0
end

local function HasScepterUpgrade(hero)
    if not hero or hero:IsNull() then
        return false
    end
    if hero.HasScepter and hero:HasScepter() then
        return true
    end
    return hero:HasModifier("modifier_item_ultimate_scepter") or hero:HasModifier("modifier_item_ultimate_scepter_consumed")
end

local CHEN_BARRACK_FAMILIES = {
    { "centaur", { "npc_dota_neutral_centaur_outrunner", "npc_dota_neutral_centaur_khan", "npc_dota_neutral_centaur_khan" } },
    { "dark_troll", { "npc_dota_neutral_dark_troll", "npc_dota_neutral_dark_troll_warlord", "npc_dota_neutral_dark_troll_warlord" } },
    { "forest_troll", { "npc_dota_neutral_forest_troll_berserker", "npc_dota_neutral_forest_troll_high_priest", "npc_dota_neutral_forest_troll_high_priest" } },
    { "satyr", { "npc_dota_neutral_satyr_trickster", "npc_dota_neutral_satyr_soulstealer", "npc_dota_neutral_satyr_hellcaller" } },
    { "harpy", { "npc_dota_neutral_harpy_scout", "npc_dota_neutral_harpy_storm", "npc_dota_neutral_harpy_storm" } },
    { "kobold", { "npc_dota_neutral_kobold", "npc_dota_neutral_kobold_tunneler", "npc_dota_neutral_kobold_taskmaster" } },
    { "ogre", { "npc_dota_neutral_ogre_mauler", "npc_dota_neutral_ogre_magi", "npc_dota_neutral_ogre_magi" } },
    { "wildkin", { "npc_dota_neutral_wildkin", "npc_dota_neutral_enraged_wildkin", "npc_dota_neutral_enraged_wildkin" } },
    { "wolf", { "npc_dota_neutral_giant_wolf", "npc_dota_neutral_alpha_wolf", "npc_dota_neutral_alpha_wolf" } },
    { "polar_furbolg", { "npc_dota_neutral_polar_furbolg_champion", "npc_dota_neutral_polar_furbolg_ursa_warrior", "npc_dota_neutral_polar_furbolg_ursa_warrior" } },
}

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

    if not unit:IsCreep() or unit:IsHero() or unit:IsAncient() or unit:IsBuilding() then
        return false
    end

    if IsChenBarrackUnit(unit) then
        return false
    end

    if unit:GetTeamNumber() ~= caster:GetTeamNumber() then
        return false
    end

    return true
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

local function GiveGoldToHero(hero, gold)
    if not hero or hero:IsNull() or gold <= 0 then
        return
    end

    hero:ModifyGold(gold, true, DOTA_ModifyGold_Unspecified)
    local player = hero:GetPlayerOwner()
    if player then
        SendOverheadEventMessage(player, OVERHEAD_ALERT_GOLD, hero, gold, nil)
    end
end

local function SpendGold(hero, goldCost)
    if goldCost <= 0 then
        return
    end

    hero:ModifyGold(-goldCost, false, DOTA_ModifyGold_Unspecified)
end

local function LevelUnitAbilities(unit)
    local count = 6
    if unit and unit.GetAbilityCount then
        count = unit:GetAbilityCount()
    end

    for slot = 0, count - 1 do
        local ability = unit:GetAbilityByIndex(slot)
        if ability and not ability:IsNull() and ability:GetLevel() == 0 then
            ability:SetLevel(1)
        end
    end
end

local function LevelBarrackAbilities(barrack)
    local count = 6
    if barrack and barrack.GetAbilityCount then
        count = barrack:GetAbilityCount()
    end

    for slot = 0, count - 1 do
        local ability = barrack:GetAbilityByIndex(slot)
        if ability and ability:GetLevel() == 0 then
            ability:SetLevel(1)
        end
    end
end

local function GetBarrackModel(teamNumber)
    return BARRACK_MODEL
end

local function GetLaneFamilyUnit(variant)
    local units = {
        "npc_chen_barrack_melee",
        "npc_chen_barrack_ranged",
        "npc_chen_barrack_siege",
    }

    return units[variant]
end

local function GetFamilyUnitName(sourceUnitName, variant, fallbackUnitName)
    if not sourceUnitName or sourceUnitName == "" then
        return fallbackUnitName
    end

    if string.find(sourceUnitName, "lane", 1, true) or string.find(sourceUnitName, "creep", 1, true) or string.find(sourceUnitName, "siege", 1, true) then
        return GetLaneFamilyUnit(variant) or fallbackUnitName
    end

    for _, family in ipairs(CHEN_BARRACK_FAMILIES) do
        if string.find(sourceUnitName, family[1], 1, true) then
            return family[2][variant] or sourceUnitName
        end
    end

    return sourceUnitName
end

local function InitBarrackState(barrack)
    barrack.chen_production_queue = barrack.chen_production_queue or {}
    barrack.chen_reserved_gold = barrack.chen_reserved_gold or 0
    barrack.chen_production_active = barrack.chen_production_active or false
    barrack.chen_is_destroyed = barrack.chen_is_destroyed or false
end

local function GetBarrackQueuedCount(barrack)
    InitBarrackState(barrack)

    local count = #barrack.chen_production_queue
    if barrack.chen_production_active then
        count = count + 1
    end

    return count
end

local function CreateProductUnit(item, spawnPosition, ownerHero, teamNumber)
    local candidates = {
        item.unit_name,
        item.source_unit_name,
        item.fallback_unit_name,
    }

    for _, unitName in ipairs(candidates) do
        if unitName and unitName ~= "" then
            local summon = CreateUnitByName(unitName, spawnPosition, true, ownerHero, ownerHero, teamNumber)
            if summon then
                return summon
            end
        end
    end

    return nil
end

local function CompleteProduction(barrack, item)
    if not barrack or barrack:IsNull() or not barrack:IsAlive() or barrack.chen_is_destroyed then
        return
    end

    local ownerHero = GetBarrackOwnerHero(barrack)
    if not ownerHero then
        return
    end

    local playerID = ownerHero:GetPlayerOwnerID()
    local teamNumber = ownerHero:GetTeamNumber()
    local spawnDistance = item.spawn_distance or 200
    local spawnPosition = barrack:GetAbsOrigin() + barrack:GetForwardVector() * spawnDistance + RandomVector(80)
    local summon = CreateProductUnit(item, spawnPosition, ownerHero, teamNumber)

    if not summon then
        GiveGoldToHero(ownerHero, item.gold_cost or 0)
        barrack.chen_reserved_gold = math.max(0, (barrack.chen_reserved_gold or 0) - (item.gold_cost or 0))
        return
    end

    summon:SetOwner(ownerHero)
    summon:SetControllableByPlayer(playerID, true)
    if summon.SetPlayerID then
        summon:SetPlayerID(playerID)
    end
    summon.chen_barrack_spawned = true
    summon.chen_owner_entindex = ownerHero:entindex()
    LevelUnitAbilities(summon)
    FindClearSpaceForUnit(summon, spawnPosition, true)
    summon:Stop()

    barrack.chen_reserved_gold = math.max(0, (barrack.chen_reserved_gold or 0) - (item.gold_cost or 0))
    EmitSoundOn("Hero_Chen.TeleportLoop", summon)
end

local StartNextProduction

StartNextProduction = function(barrack)
    if not barrack or barrack:IsNull() or not barrack:IsAlive() or barrack.chen_is_destroyed then
        return
    end

    InitBarrackState(barrack)

    if barrack.chen_production_active then
        return
    end

    local item = table.remove(barrack.chen_production_queue, 1)
    if not item then
        return
    end

    barrack.chen_production_active = true
    barrack.chen_current_order = item

    -- Apply production debuff with proper duration
    local productionTime = tonumber(item.production_time) or 10
    barrack:AddNewModifier(barrack, nil, "modifier_chen_barrack_producing", { duration = productionTime, production_time = productionTime })

    Timers:CreateTimer(item.production_time or 1, function()
        if barrack and not barrack:IsNull() and barrack:IsAlive() and not barrack.chen_is_destroyed then
            CompleteProduction(barrack, item)
            barrack.chen_production_active = false
            barrack.chen_current_order = nil
            StartNextProduction(barrack)
        end
    end)
end

local function QueueBarrackUnit(self, variant, fallbackUnitName)
    if not IsServer() then
        return
    end

    local barrack = self:GetCaster()
    local ownerHero = GetBarrackOwnerHero(barrack)
    if not ownerHero then
        return
    end

    local goldCost = self:GetSpecialValueFor("gold_cost")
    goldCost = math.max(0, goldCost - GetTalentValue(ownerHero, "special_bonus_unique_custom_chen_8", "gold_cost_reduction", 0))

    if not HasEnoughGold(ownerHero, goldCost) then
        return
    end

    InitBarrackState(barrack)

    local queueLimit = 5

    if GetBarrackQueuedCount(barrack) >= queueLimit then
        return
    end

    local sourceUnitName = barrack.chen_source_unit_name or fallbackUnitName
    local unitName = GetFamilyUnitName(sourceUnitName, variant, fallbackUnitName)

    local productionTime = self:GetSpecialValueFor("production_time")
    productionTime = math.max(1, productionTime - GetTalentValue(ownerHero, "special_bonus_unique_custom_chen_8", "production_time_reduction", 0))

    SpendGold(ownerHero, goldCost)
    barrack.chen_reserved_gold = (barrack.chen_reserved_gold or 0) + goldCost

    table.insert(barrack.chen_production_queue, {
        unit_name = unitName,
        source_unit_name = sourceUnitName,
        fallback_unit_name = fallbackUnitName,
        gold_cost = goldCost,
        production_time = productionTime,
        spawn_distance = self:GetSpecialValueFor("spawn_distance"),
    })

    EmitSoundOn("General.Buy", barrack)
    StartNextProduction(barrack)
end

local function BarrackSummonCastFilter(self)
    local barrack = self:GetCaster()
    local ownerHero = GetBarrackOwnerHero(barrack)
    local goldCost = self:GetSpecialValueFor("gold_cost")

    if not ownerHero or ownerHero:IsNull() then
        return UF_FAIL_CUSTOM
    end

    InitBarrackState(barrack)
    if GetBarrackQueuedCount(barrack) >= 5 then
        return UF_FAIL_CUSTOM
    end

    goldCost = math.max(0, goldCost - GetTalentValue(ownerHero, "special_bonus_unique_custom_chen_8", "gold_cost_reduction", 0))

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

    InitBarrackState(self:GetCaster())
    if GetBarrackQueuedCount(self:GetCaster()) >= 5 then
        return "#dota_hud_error_chen_barrack_queue_full"
    end

    local goldCost = math.max(0, self:GetSpecialValueFor("gold_cost") - GetTalentValue(ownerHero, "special_bonus_unique_custom_chen_8", "gold_cost_reduction", 0))

    if not HasEnoughGold(ownerHero, goldCost) then
        return "#dota_hud_error_not_enough_gold"
    end

    return ""
end

local function RefundReservedGold(barrack)
    InitBarrackState(barrack)

    local gold = math.floor(barrack.chen_reserved_gold or 0)
    if gold <= 0 then
        return
    end

    barrack.chen_reserved_gold = 0

    local ownerHero = GetBarrackOwnerHero(barrack)
    if not ownerHero then
        return
    end

    local recipients = {}
    local maxPlayers = DOTA_MAX_PLAYERS or 24
    for playerID = 0, maxPlayers - 1 do
        if PlayerResource:IsValidPlayerID(playerID) and PlayerResource:GetTeam(playerID) == ownerHero:GetTeamNumber() then
            local hero = PlayerResource:GetSelectedHeroEntity(playerID)
            if hero and not hero:IsNull() then
                table.insert(recipients, hero)
            end
        end
    end

    if #recipients == 0 then
        GiveGoldToHero(ownerHero, gold)
        return
    end

    local share = math.floor(gold / #recipients)
    local remainder = gold - share * #recipients

    for index, hero in ipairs(recipients) do
        local amount = share
        if index == 1 then
            amount = amount + remainder
        end
        GiveGoldToHero(hero, amount)
    end
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

    -- Find existing barracks owned by this Chen
    local teamNumber = caster:GetTeamNumber()
    local units = FindUnitsInRadius(
        teamNumber,
        caster:GetAbsOrigin(),
        nil,
        FIND_UNITS_EVERYWHERE,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_ALL,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    local existingBarracks = {}
    for _, unit in pairs(units) do
        if unit and not unit:IsNull() and unit:IsAlive() and unit:GetUnitName() == "npc_chen_barrack" then
            if unit.chen_barrack_owner_entindex == caster:entindex() then
                table.insert(existingBarracks, unit)
            end
        end
    end

    table.sort(existingBarracks, function(a, b)
        return (a.chen_barrack_created_time or 0) < (b.chen_barrack_created_time or 0)
    end)

    local maxBarracks = self:GetSpecialValueFor("max_barracks")
    if maxBarracks <= 0 then
        maxBarracks = 1
    end
    if HasScepterUpgrade(caster) then
        local scepterMaxBarracks = self:GetSpecialValueFor("scepter_max_barracks")
        if scepterMaxBarracks <= 0 then
            scepterMaxBarracks = 2
        end
        maxBarracks = scepterMaxBarracks
    end

    while #existingBarracks >= maxBarracks do
        local oldest = table.remove(existingBarracks, 1)
        if oldest and not oldest:IsNull() then
            oldest.chen_is_destroyed = true
            RefundReservedGold(oldest)
            oldest:Kill(nil, oldest)
        end
    end

    local origin = target:GetAbsOrigin()
    local forward = target:GetForwardVector()
    local playerID = caster:GetPlayerOwnerID()
    local targetMaxHealth = math.max(target:GetMaxHealth(), target:GetHealth())
    local targetUnitName = target:GetUnitName()
    local bonusHealth = self:GetSpecialValueFor("bonus_health")
    local minimumBarrackHealth = self:GetSpecialValueFor("minimum_barrack_health")

    target.chen_skip_bounty_share = true
    UTIL_Remove(target)

    local barrack = CreateUnitByName("npc_chen_barrack", origin, true, caster, caster, teamNumber)
    if not barrack then
        return
    end

    barrack.chen_barrack_owner_entindex = caster:entindex()
    barrack.chen_barrack_created_time = GameRules:GetGameTime()
    barrack.chen_source_unit_name = targetUnitName
    barrack:SetOwner(caster)
    barrack:SetControllableByPlayer(playerID, true)
    if barrack.SetPlayerID then
        barrack:SetPlayerID(playerID)
    end
    barrack:SetForwardVector(forward)
    barrack:SetMoveCapability(DOTA_UNIT_CAP_MOVE_NONE)

    local barrackMaxHealth = math.max(minimumBarrackHealth, targetMaxHealth + bonusHealth)
    barrackMaxHealth = barrackMaxHealth + GetTalentValue(caster, "special_bonus_unique_custom_chen_7", "barrack_health", 0)

    barrack:SetBaseMaxHealth(barrackMaxHealth)
    barrack:SetMaxHealth(barrackMaxHealth)
    barrack:SetHealth(barrackMaxHealth)

    local model = GetBarrackModel(teamNumber)
    barrack:SetModel(model)
    barrack:SetOriginalModel(model)

    InitBarrackState(barrack)
    LevelBarrackAbilities(barrack)
    barrack:AddNewModifier(caster, self, "modifier_chen_barrack", {})

    -- Level the self-destruct ability
    local selfDestruct = barrack:FindAbilityByName("chen_barrack_self_destruct")
    if selfDestruct and selfDestruct:GetLevel() == 0 then
        selfDestruct:SetLevel(1)
    end

    -- Building construction effect
    local constructionParticle = ParticleManager:CreateParticle("particles/econ/events/ti6/hero_transform_dust.vpcf", PATTACH_ABSORIGIN, barrack)
    ParticleManager:SetParticleControl(constructionParticle, 0, barrack:GetAbsOrigin())
    ParticleManager:SetParticleControl(constructionParticle, 1, Vector(200, 200, 200))
    ParticleManager:ReleaseParticleIndex(constructionParticle)

    -- Light beam effect
    local beamParticle = ParticleManager:CreateParticle("particles/items_fx/aegis_respawn.vpcf", PATTACH_ABSORIGIN, barrack)
    ParticleManager:SetParticleControl(beamParticle, 0, barrack:GetAbsOrigin())
    ParticleManager:SetParticleControl(beamParticle, 1, barrack:GetAbsOrigin() + Vector(0, 0, 500))
    ParticleManager:ReleaseParticleIndex(beamParticle)

    EmitSoundOn("Hero_Chen.HolyPersuasionEnemy", barrack)
end

function chen_barrack_summon_melee:CastFilterResult()
    return BarrackSummonCastFilter(self)
end

function chen_barrack_summon_melee:GetCustomCastError()
    return BarrackSummonCastError(self)
end

function chen_barrack_summon_melee:OnSpellStart()
    QueueBarrackUnit(self, 1, "npc_chen_barrack_melee")
end

function chen_barrack_summon_ranged:CastFilterResult()
    return BarrackSummonCastFilter(self)
end

function chen_barrack_summon_ranged:GetCustomCastError()
    return BarrackSummonCastError(self)
end

function chen_barrack_summon_ranged:OnSpellStart()
    QueueBarrackUnit(self, 2, "npc_chen_barrack_ranged")
end

function chen_barrack_summon_siege:CastFilterResult()
    return BarrackSummonCastFilter(self)
end

function chen_barrack_summon_siege:GetCustomCastError()
    return BarrackSummonCastError(self)
end

function chen_barrack_summon_siege:OnSpellStart()
    QueueBarrackUnit(self, 3, "npc_chen_barrack_siege")
end

function chen_barrack_self_destruct:CastFilterResult()
    local barrack = self:GetCaster()
    if not IsChenBarrackUnit(barrack) then
        return UF_FAIL_CUSTOM
    end

    if not barrack:IsAlive() then
        return UF_FAIL_CUSTOM
    end

    return UF_SUCCESS
end

function chen_barrack_self_destruct:GetCustomCastError()
    local barrack = self:GetCaster()
    if not IsChenBarrackUnit(barrack) then
        return "#dota_hud_error_chen_barrack_self_destruct_invalid_target"
    end

    if not barrack:IsAlive() then
        return "#dota_hud_error_chen_barrack_self_destruct_dead"
    end

    return ""
end

function chen_barrack_self_destruct:OnSpellStart()
    if not IsServer() then
        return
    end

    local barrack = self:GetCaster()
    if not IsChenBarrackUnit(barrack) or not barrack:IsAlive() then
        return
    end

    -- Explosion effect
    local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_techies/techies_remote_mines_detonate.vpcf", PATTACH_ABSORIGIN, barrack)
    ParticleManager:SetParticleControl(particle, 0, barrack:GetAbsOrigin())
    ParticleManager:ReleaseParticleIndex(particle)

    EmitSoundOn("Hero_Techies.RemoteMine.Detonate", barrack)

    -- Mark as destroyed and refund gold
    barrack.chen_is_destroyed = true
    RefundReservedGold(barrack)

    -- Deal damage in area
    local radius = self:GetSpecialValueFor("radius")
    local damage = self:GetSpecialValueFor("damage")
    local units = FindUnitsInRadius(
        barrack:GetTeamNumber(),
        barrack:GetAbsOrigin(),
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    for _, unit in pairs(units) do
        if unit and not unit:IsNull() and unit:IsAlive() then
            ApplyDamage({
                victim = unit,
                attacker = barrack,
                damage = damage,
                damage_type = DAMAGE_TYPE_MAGICAL,
                ability = self,
            })
        end
    end

    -- Destroy the barrack
    barrack:Kill(self, barrack)
end

function modifier_chen_barrack:IsHidden()
    return true
end

function modifier_chen_barrack:IsPurgable()
    return false
end

function modifier_chen_barrack:RemoveOnDeath()
    return true
end

function modifier_chen_barrack:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_DEATH,
    }
end

function modifier_chen_barrack:OnDeath(params)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if not params.unit or params.unit ~= parent then
        return
    end

    parent.chen_is_destroyed = true
    RefundReservedGold(parent)
end

-- Production debuff modifier
modifier_chen_barrack_producing = class({})

function modifier_chen_barrack_producing:IsHidden()
    return false
end

function modifier_chen_barrack_producing:IsDebuff()
    return false
end

function modifier_chen_barrack_producing:IsPurgable()
    return false
end

function modifier_chen_barrack_producing:GetEffectName()
    return "particles/econ/events/ti6/hero_transform_dust.vpcf"
end

function modifier_chen_barrack_producing:GetEffectAttachType()
    return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_chen_barrack_producing:OnCreated(kv)
    if IsServer() then
        local parent = self:GetParent()
        EmitSoundOn("Building.Construction", parent)
    end

    -- Set duration from kv if provided (both server and client)
    if kv and kv.production_time then
        local duration = tonumber(kv.production_time) or 10
        self:SetDuration(duration, false)
    end
end

function modifier_chen_barrack_producing:OnDestroy()
    if IsServer() then
        local parent = self:GetParent()
        EmitSoundOn("Building.Complete", parent)
    end
end
