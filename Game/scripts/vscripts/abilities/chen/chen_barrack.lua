chen_barrack = class({})
chen_barrack_summon = class({})
chen_barrack_centaur_t1 = class({})
chen_barrack_centaur_t2 = class({})
chen_barrack_centaur_t3 = class({})
chen_barrack_centaur_ancient = class({})
chen_barrack_satyr_t1 = class({})
chen_barrack_satyr_t2 = class({})
chen_barrack_satyr_t3 = class({})
chen_barrack_satyr_ancient = class({})
chen_barrack_troll_t1 = class({})
chen_barrack_troll_t2 = class({})
chen_barrack_troll_t3 = class({})
chen_barrack_troll_ancient = class({})
chen_barrack_wolf_t1 = class({})
chen_barrack_wolf_t2 = class({})
chen_barrack_wolf_t3 = class({})
chen_barrack_wolf_ancient = class({})
chen_barrack_golem_t1 = class({})
chen_barrack_golem_t2 = class({})
chen_barrack_golem_t3 = class({})
chen_barrack_golem_ancient = class({})
chen_barrack_harpy_t1 = class({})
chen_barrack_harpy_t2 = class({})
chen_barrack_harpy_t3 = class({})
chen_barrack_harpy_ancient = class({})
chen_barrack_furbolg_t1 = class({})
chen_barrack_furbolg_t2 = class({})
chen_barrack_furbolg_t3 = class({})
chen_barrack_furbolg_ancient = class({})
chen_barrack_frog_t1 = class({})
chen_barrack_frog_t2 = class({})
chen_barrack_frog_t3 = class({})
chen_barrack_frog_ancient = class({})
chen_barrack_dragon_t1 = class({})
chen_barrack_dragon_t2 = class({})
chen_barrack_dragon_t3 = class({})
chen_barrack_dragon_ancient = class({})
chen_barrack_bear_t1 = class({})
chen_barrack_bear_t2 = class({})
chen_barrack_bear_t3 = class({})
chen_barrack_bear_ancient = class({})
chen_barrack_self_destruct = class({})
modifier_chen_barrack = class({})
modifier_chen_barrack_producing = class({})

local BARRACK_MODEL = "models/props_structures/good_barracks_melee001.vmdl"

--- 10 семей крипов для барака Чена
--- Каждая семья имеет 4 уровня: т1, т2, т3, ancient (т4)
--- Уровень барака определяет доступные уровни крипов
--- Аганим открывает ancient уровень
local CHEN_BARRACK_FAMILIES = {
    { "satyr", { "npc_dota_neutral_satyr_trickster", "npc_dota_neutral_satyr_soulstealer", "npc_dota_neutral_satyr_hellcaller", "npc_dota_neutral_satyr_sentry" } },
    { "frog", { "npc_dota_neutral_pollywog", "npc_dota_neutral_frog", "npc_dota_neutral_frog_elder", "npc_chen_frog_ancient" } },
    { "troll", { "npc_dota_neutral_forest_troll_berserker", "npc_dota_neutral_ogre_magi", "npc_dota_neutral_ogre_mauler", "npc_dota_neutral_dark_troll_warlord" } },
    { "wolf", { "npc_dota_neutral_vhoul_assassin", "npc_dota_neutral_giant_wolf", "npc_dota_neutral_alpha_wolf", "npc_chen_wolf_thunder" } },
    { "centaur", { "npc_dota_neutral_kobold_foreman", "npc_dota_neutral_centaur_khan", "npc_dota_neutral_centaur_outrunner", "npc_dota_neutral_centaur_brute" } },
    { "golem", { "npc_dota_neutral_mud_golem_tiny", "npc_dota_neutral_mud_golem", "npc_dota_neutral_rock_golem", "npc_dota_neutral_mud_golem_shard" } },
    { "dragon", { "npc_dota_neutral_harpy_scout", "npc_dota_neutral_harpy_storm", "npc_dota_neutral_black_drake", "npc_dota_neutral_black_dragon" } },
    { "bear", { "npc_chen_bear_wander", "npc_dota_neutral_hellbear", "npc_dota_neutral_hellbear_smasher", "npc_chen_bear_torchbearer" } },
    { "furbolg", { "npc_chen_furbolg_treant", "npc_chen_furbolg_shroom", "npc_chen_furbolg_woodling", "npc_dota_neutral_warpine_raider" } },
    { "harpy", { "npc_dota_neutral_wildwing", "npc_chen_harpy_bird", "npc_dota_neutral_wildwing_ripper", "npc_chen_harpy_phoenix" } },
}

-- Маппинг правильных имен юнитов для каждой семьи
local CHEN_BARRACK_FAMILY_TARGETS = {
    satyr = { "npc_dota_neutral_satyr_trickster", "npc_dota_neutral_satyr_soulstealer", "npc_dota_neutral_satyr_hellcaller", "npc_dota_neutral_satyr_sentry" },
    frog = { "npc_dota_neutral_pollywog", "npc_dota_neutral_frog", "npc_dota_neutral_frog_elder", "npc_chen_frog_ancient" },
    troll = { "npc_dota_neutral_forest_troll_berserker", "npc_dota_neutral_ogre_magi", "npc_dota_neutral_ogre_mauler", "npc_dota_neutral_dark_troll_warlord" },
    wolf = { "npc_dota_neutral_vhoul_assassin", "npc_dota_neutral_giant_wolf", "npc_dota_neutral_alpha_wolf", "npc_chen_wolf_thunder" },
    centaur = { "npc_dota_neutral_kobold_foreman", "npc_dota_neutral_centaur_khan", "npc_dota_neutral_centaur_outrunner", "npc_dota_neutral_centaur_brute" },
    golem = { "npc_dota_neutral_mud_golem_tiny", "npc_dota_neutral_mud_golem", "npc_dota_neutral_rock_golem", "npc_dota_neutral_mud_golem_shard" },
    dragon = { "npc_dota_neutral_harpy_scout", "npc_dota_neutral_harpy_storm", "npc_dota_neutral_black_drake", "npc_dota_neutral_black_dragon" },
    bear = { "npc_chen_bear_wander", "npc_dota_neutral_hellbear", "npc_dota_neutral_hellbear_smasher", "npc_chen_bear_torchbearer" },
    furbolg = { "npc_chen_furbolg_treant", "npc_chen_furbolg_shroom", "npc_chen_furbolg_woodling", "npc_dota_neutral_warpine_raider" },
    harpy = { "npc_dota_neutral_wildwing", "npc_chen_harpy_bird", "npc_dota_neutral_wildwing_ripper", "npc_chen_harpy_phoenix" },
}

-- Маппинг существующих нейтральных крипов в правильные семьи (для создания барака из любых крипов)
-- Основано на таблице кемпов:
-- Лагерь кобольдов -> Барак Кентавров
-- Лагерь холмовых троллей -> Барак Троллей
-- Лагерь воулов-убийц -> барак волков
-- Лагерь призраков -> барак сатиров
-- Лагерь гарпий -> барак драконов
-- Лагерь кентавров -> барак кентавров
-- Лагерь волков -> барак волков
-- Лагерь сатиров -> барак сатиров
-- Лагерь огров -> барак тролей
-- Лагерь големов -> барак големов
-- Крупный лагерь сатиров -> барак сатиров
-- Лагерь медведемонов -> барак медведей
-- Лагерь дикокрылов -> барак пернатых
-- Лагерь троллей -> лагерь троллей
-- Лагерь сосновых налётчиков -> барак шишек
-- Лагерь драконов -> барак драконов
-- Крупный лагерь големов -> барак големов
-- Лагерь ящериц -> барак волков
-- Промёрзший лагерь -> барак тролей
local NEUTRAL_TO_FAMILY = {
    -- Кобольды -> Кентавры
    ["npc_dota_neutral_kobold"] = "centaur",
    ["npc_dota_neutral_kobold_foreman"] = "centaur",
    ["npc_dota_neutral_kobold_taskmaster"] = "centaur",
    ["npc_dota_neutral_kobold_soldier"] = "centaur",
    ["npc_dota_neutral_kobold_tunneler"] = "centaur",
    -- Холмовые тролли -> Тролли
    ["npc_dota_neutral_forest_troll_berserker"] = "troll",
    ["npc_dota_neutral_forest_troll_high_priest"] = "troll",
    -- Воулы-убийцы -> Волки
    ["npc_dota_neutral_vhoul_assassin"] = "wolf",
    ["npc_dota_neutral_gnoll_assassin"] = "wolf",
    -- Призраки -> Сатиры
    ["npc_dota_neutral_ghost"] = "satyr",
    ["npc_dota_neutral_ghost_frost"] = "satyr",
    ["npc_dota_neutral_ghost_mage"] = "satyr",
    -- Гарпии -> Драконы
    ["npc_dota_neutral_harpy_scout"] = "dragon",
    ["npc_dota_neutral_harpy_storm"] = "dragon",
    ["npc_dota_neutral_harpy"] = "dragon",
    -- Кентавры -> Кентавры
    ["npc_dota_neutral_centaur_khan"] = "centaur",
    ["npc_dota_neutral_centaur_outrunner"] = "centaur",
    ["npc_dota_neutral_centaur_brute"] = "centaur",
    -- Волки -> Волки
    ["npc_dota_neutral_giant_wolf"] = "wolf",
    ["npc_dota_neutral_alpha_wolf"] = "wolf",
    ["npc_dota_neutral_ghost_wolf"] = "wolf",
    -- Сатиры -> Сатиры
    ["npc_dota_neutral_satyr_trickster"] = "satyr",
    ["npc_dota_neutral_satyr_soulstealer"] = "satyr",
    ["npc_dota_neutral_satyr_hellcaller"] = "satyr",
    ["npc_dota_neutral_prowler_shaman"] = "satyr",
    ["npc_dota_neutral_satyr_sentry"] = "satyr",
    -- Огры -> Тролли
    ["npc_dota_neutral_ogre_magi"] = "troll",
    ["npc_dota_neutral_ogre_mauler"] = "troll",
    ["npc_dota_neutral_ogre_bruiser"] = "troll",
    -- Големы -> Големы
    ["npc_dota_neutral_mud_golem"] = "golem",
    ["npc_dota_neutral_mud_golem_tiny"] = "golem",
    ["npc_dota_neutral_rock_golem"] = "golem",
    ["npc_dota_neutral_granite_golem"] = "golem",
    -- Медведемоны -> Медведи
    ["npc_dota_neutral_hellbear"] = "bear",
    ["npc_dota_neutral_hellbear_smasher"] = "bear",
    ["npc_dota_neutral_polar_furbolg"] = "bear",
    ["npc_dota_neutral_polar_furbolg_champion"] = "bear",
    ["npc_dota_neutral_polar_furbolg_ursa_warrior"] = "bear",
    -- Дикокрылы -> Пернатые
    ["npc_dota_neutral_wildwing"] = "harpy",
    ["npc_dota_neutral_wildwing_ripper"] = "harpy",
    ["npc_dota_neutral_big_wildwing"] = "harpy",
    ["npc_dota_neutral_enraged_wildkin"] = "harpy",
    ["npc_dota_neutral_wildkin"] = "harpy",
    -- Тролли -> Тролли
    ["npc_dota_neutral_dark_troll"] = "troll",
    ["npc_dota_neutral_dark_troll_warlord"] = "troll",
    -- Сосновые налётчики -> Шишки
    ["npc_dota_neutral_treant"] = "furbolg",
    ["npc_dota_neutral_treant_small"] = "furbolg",
    ["npc_dota_neutral_prowler_acolyte"] = "furbolg",
    ["npc_dota_neutral_prowler_shaman"] = "furbolg",
    ["npc_dota_neutral_warpine_raider"] = "furbolg",
    ["npc_dota_neutral_polar_furbolg_ursa_warrior"] = "bear",
    -- Драконы -> Драконы
    ["npc_dota_neutral_black_drake"] = "dragon",
    ["npc_dota_neutral_black_dragon"] = "dragon",
    ["npc_dota_neutral_elder_dragon"] = "dragon",
    -- Ящерицы -> Волки
    ["npc_dota_neutral_dragon_spawn"] = "wolf",
    ["npc_dota_neutral_dragon_spawn_elder"] = "wolf",
    ["npc_dota_neutral_dragon_spawn_jungle"] = "wolf",
    -- Промёрзший лагерь -> Тролли
    ["npc_dota_neutral_frost_bear"] = "troll",
    ["npc_dota_neutral_frost_bear_spawn"] = "troll",
    ["npc_dota_neutral_frost_bear_leader"] = "troll",
    -- Кастомные юниты Чена
    ["npc_chen_frog_ancient"] = "frog",
    ["npc_chen_wolf_thunder"] = "wolf",
    ["npc_chen_bear_wander"] = "bear",
    ["npc_chen_bear_torchbearer"] = "bear",
    ["npc_chen_furbolg_treant"] = "furbolg",
    ["npc_chen_furbolg_woodling"] = "furbolg",
    ["npc_chen_furbolg_shroom"] = "furbolg",
    ["npc_chen_furbolg_shroom_ancient"] = "furbolg",
    ["npc_chen_harpy_bird"] = "harpy",
    ["npc_chen_harpy_phoenix"] = "harpy",
    -- Лягухи
    ["npc_dota_neutral_pollywog"] = "frog",
    ["npc_dota_neutral_frog"] = "frog",
    ["npc_dota_neutral_frog_elder"] = "frog",
}

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

local function IsChenBarrackUnit(unit)
    if not unit or unit:IsNull() then
        return false
    end

    local unitName = unit:GetUnitName() or ""
    return string.find(unitName, "npc_chen_barrack", 1, true) == 1
end

local function IsChenTamedCreep(unit, caster)
    if not unit or unit:IsNull() then
        return false
    end

    if not unit:IsAlive() then
        return false
    end

    if unit:GetTeamNumber() ~= caster:GetTeamNumber() then
        return false
    end

    if unit:GetPlayerOwnerID() ~= caster:GetPlayerOwnerID() then
        return false
    end

    -- Если крип не герой и не здание - считаем валидной целью
    if not unit:IsHero() and not unit:IsBuilding() then
        return true
    end

    return false
end

local function GetBarrackOwnerHero(unit)
    if not unit or unit:IsNull() then
        return nil
    end

    -- Сначала пробуем GetOwnerEntity
    local owner = unit.GetOwnerEntity and unit:GetOwnerEntity()
    if owner and not owner:IsNull() and owner:IsRealHero() then
        return owner
    end

    -- Если не сработало, пробуем через PlayerOwnerID найти героя
    local playerID = unit:GetPlayerOwnerID()
    if playerID and playerID >= 0 then
        local hero = PlayerResource:GetSelectedHeroEntity(playerID)
        if hero and not hero:IsNull() and hero:IsRealHero() then
            return hero
        end
    end

    -- Фоллбек через entindex если он есть
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

local function GiveGoldToHero(hero, goldAmount)
    if not hero or hero:IsNull() or goldAmount <= 0 then
        return
    end

    hero:ModifyGold(goldAmount, false, DOTA_ModifyGold_Unspecified)
end

local function RefundReservedGold(barrack)
    if not barrack or barrack:IsNull() then
        return
    end

    local reservedGold = barrack.chen_reserved_gold or 0
    if reservedGold > 0 then
        local ownerHero = GetBarrackOwnerHero(barrack)
        if ownerHero then
            GiveGoldToHero(ownerHero, reservedGold)
        end
        barrack.chen_reserved_gold = 0
    end
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
    return "models/props_structures/good_barracks_melee001.vmdl"
end

--- Маппинг способностей для каждой семьи и уровня
local FAMILY_ABILITIES = {
    satyr = {
        "chen_barrack_satyr_t1",
        "chen_barrack_satyr_t2",
        "chen_barrack_satyr_t3",
        "chen_barrack_satyr_ancient"
    },
    frog = {
        "chen_barrack_frog_t1",
        "chen_barrack_frog_t2",
        "chen_barrack_frog_t3",
        "chen_barrack_frog_ancient"
    },
    troll = {
        "chen_barrack_troll_t1",
        "chen_barrack_troll_t2",
        "chen_barrack_troll_t3",
        "chen_barrack_troll_ancient"
    },
    wolf = {
        "chen_barrack_wolf_t1",
        "chen_barrack_wolf_t2",
        "chen_barrack_wolf_t3",
        "chen_barrack_wolf_ancient"
    },
    centaur = {
        "chen_barrack_centaur_t1",
        "chen_barrack_centaur_t2",
        "chen_barrack_centaur_t3",
        "chen_barrack_centaur_ancient"
    },
    golem = {
        "chen_barrack_golem_t1",
        "chen_barrack_golem_t2",
        "chen_barrack_golem_t3",
        "chen_barrack_golem_ancient"
    },
    dragon = {
        "chen_barrack_dragon_t1",
        "chen_barrack_dragon_t2",
        "chen_barrack_dragon_t3",
        "chen_barrack_dragon_ancient"
    },
    bear = {
        "chen_barrack_bear_t1",
        "chen_barrack_bear_t2",
        "chen_barrack_bear_t3",
        "chen_barrack_bear_ancient"
    },
    furbolg = {
        "chen_barrack_furbolg_t1",
        "chen_barrack_furbolg_t2",
        "chen_barrack_furbolg_t3",
        "chen_barrack_furbolg_ancient"
    },
    harpy = {
        "chen_barrack_harpy_t1",
        "chen_barrack_harpy_t2",
        "chen_barrack_harpy_t3",
        "chen_barrack_harpy_ancient"
    }
}

local function GetFamilyName(sourceUnitName)
    if not sourceUnitName or sourceUnitName == "" then
        print("[Chen Barrack GetFamilyName] Empty unit name")
        return nil
    end

    local sourceUnitNameLower = sourceUnitName:lower()
    print("[Chen Barrack GetFamilyName] Looking up: " .. sourceUnitNameLower)

    -- Сначала ищем точное совпадение в маппинге нейтральных крипов
    if NEUTRAL_TO_FAMILY[sourceUnitName] then
        print("[Chen Barrack GetFamilyName] Found in NEUTRAL_TO_FAMILY (exact): " .. sourceUnitName .. " -> " .. NEUTRAL_TO_FAMILY[sourceUnitName])
        return NEUTRAL_TO_FAMILY[sourceUnitName]
    end

    if NEUTRAL_TO_FAMILY[sourceUnitNameLower] then
        print("[Chen Barrack GetFamilyName] Found in NEUTRAL_TO_FAMILY (lower): " .. sourceUnitNameLower .. " -> " .. NEUTRAL_TO_FAMILY[sourceUnitNameLower])
        return NEUTRAL_TO_FAMILY[sourceUnitNameLower]
    end

    -- Сначала ищем точное совпадение в таблице целей семей
    for familyName, unitNames in pairs(CHEN_BARRACK_FAMILY_TARGETS) do
        for _, unitName in ipairs(unitNames) do
            if sourceUnitNameLower == unitName:lower() then
                return familyName
            end
        end
    end

    -- Если точного совпадения нет, ищем по подстроке (fallback)
    for _, family in ipairs(CHEN_BARRACK_FAMILIES) do
        if string.find(sourceUnitNameLower, family[1], 1, true) then
            return family[1]
        end
    end

    return nil
end

local function GrantFamilyAbilities(barrack, familyName, ownerHero)
    if not barrack or barrack:IsNull() or not familyName then
        return
    end

    local abilities = FAMILY_ABILITIES[familyName]
    if not abilities then
        return
    end

    local ult = ownerHero:FindAbilityByName("chen_barrack")
    local ultLevel = ult and ult:GetLevel() or 1
    local hasScepter = HasScepterUpgrade(ownerHero)

    -- Выдаем способности семье на брак
    for i, abilityName in ipairs(abilities) do
        local ability = barrack:FindAbilityByName(abilityName)
        if not ability then
            barrack:AddAbility(abilityName)
            ability = barrack:FindAbilityByName(abilityName)
        end

        if ability then
            ability:SetLevel(1)
            ability:SetHidden(false)
            ability:SetActivated(true)
            print("[Chen Barrack] Added ability: " .. abilityName .. " to barrack")
        else
            print("[Chen Barrack] Failed to add ability: " .. abilityName)
        end
    end

    -- Добавляем способность самоуничтожения
    local destructAbility = barrack:FindAbilityByName("chen_barrack_self_destruct")
    if not destructAbility then
        barrack:AddAbility("chen_barrack_self_destruct")
        destructAbility = barrack:FindAbilityByName("chen_barrack_self_destruct")
    end
    if destructAbility then
        destructAbility:SetLevel(1)
        destructAbility:SetHidden(false)
        destructAbility:SetActivated(true)
    end
end

local function GetFamilyUnitName(sourceUnitName, variant)
    if not sourceUnitName or sourceUnitName == "" then
        return nil
    end

    local sourceUnitNameLower = sourceUnitName:lower()

    -- Сначала ищем точное совпадение в CHEN_BARRACK_FAMILY_TARGETS
    for familyName, unitNames in pairs(CHEN_BARRACK_FAMILY_TARGETS) do
        for i, unitName in ipairs(unitNames) do
            if i == variant and sourceUnitNameLower == unitName:lower() then
                return unitName
            end
        end
    end

    -- Если точного совпадения нет, ищем по имени семьи в CHEN_BARRACK_FAMILY_TARGETS
    for familyName, unitNames in pairs(CHEN_BARRACK_FAMILY_TARGETS) do
        if sourceUnitNameLower:find(familyName, 1, true) then
            return unitNames[variant]
        end
    end

    -- Fallback: ищем в CHEN_BARRACK_FAMILIES
    for _, family in ipairs(CHEN_BARRACK_FAMILIES) do
        if string.find(sourceUnitNameLower, family[1], 1, true) then
            return family[2][variant]
        end
    end

    return nil
end

local function InitBarrackState(barrack)
    barrack.chen_production_queue = barrack.chen_production_queue or {}
    barrack.chen_reserved_gold = barrack.chen_reserved_gold or 0
    barrack.chen_production_active = barrack.chen_production_active or false
    barrack.chen_is_destroyed = barrack.chen_is_destroyed or false
    barrack.chen_active_productions = barrack.chen_active_productions or 0
end

local function GetBarrackQueuedCount(barrack)
    InitBarrackState(barrack)

    local count = #barrack.chen_production_queue
    count = count + (barrack.chen_active_productions or 0)

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

local function LevelUnitAbilities(unit)
    if not unit or unit:IsNull() then
        return
    end

    for slot = 0, 15 do
        local ability = unit:GetAbilityByIndex(slot)
        if ability and ability:GetLevel() == 0 then
            ability:SetLevel(1)
        end
    end
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

    -- Add production visual effects
    local particle = ParticleManager:CreateParticle("particles/econ/events/ti6/kill_effect_creep_gold.vpcf", PATTACH_ABSORIGIN_FOLLOW, summon)
    ParticleManager:ReleaseParticleIndex(particle)

    -- Play spawn sound
    EmitSoundOn("DOTA_Item.Hand_Of_Midas", barrack)
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

    local item = table.remove(barrack.chen_production_queue, 1)
    if not item then
        return
    end

    barrack.chen_active_productions = (barrack.chen_active_productions or 0) + 1
    barrack.chen_current_order = item

    local productionTime = tonumber(item.production_time) or 10
    barrack:AddNewModifier(barrack, nil, "modifier_chen_barrack_producing", { duration = productionTime, production_time = productionTime })

    Timers:CreateTimer(item.production_time or 1, function()
        if barrack and not barrack:IsNull() and barrack:IsAlive() and not barrack.chen_is_destroyed then
            CompleteProduction(barrack, item)
            barrack.chen_active_productions = math.max(0, (barrack.chen_active_productions or 1) - 1)
            barrack.chen_current_order = nil
            StartNextProduction(barrack)
        end
    end)
end

local function GetAbilityVariant(abilityName)
    -- Определяем вариант (1-4) из названия способности
    if string.find(abilityName, "_t1") then
        return 1
    elseif string.find(abilityName, "_t2") then
        return 2
    elseif string.find(abilityName, "_t3") then
        return 3
    elseif string.find(abilityName, "_ancient") then
        return 4
    end
    return 1
end

local function QueueBarrackUnit(self)
    if not IsServer() then
        return
    end

    local barrack = self:GetCaster()
    local ownerHero = GetBarrackOwnerHero(barrack)
    if not ownerHero then
        return
    end

    local abilityName = self:GetAbilityName()
    local variant = GetAbilityVariant(abilityName)

    local ult = ownerHero:FindAbilityByName("chen_barrack")
    if not ult then return end
    
    local ultLevel = ult:GetLevel()
    if variant > ultLevel and not (variant == 4 and HasScepterUpgrade(ownerHero)) then
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

    local sourceUnitName = barrack.chen_source_unit_name
    local unitName = GetFamilyUnitName(sourceUnitName, variant)

    if not unitName then
        CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(ownerHero:GetPlayerOwnerID()), "show_custom_error", { message = "#dota_hud_error_chen_barrack_no_unit_in_family" })
        return
    end

    local productionTime = self:GetSpecialValueFor("production_time")
    productionTime = math.max(1, productionTime - GetTalentValue(ownerHero, "special_bonus_unique_custom_chen_8", "production_time_reduction", 0))

    SpendGold(ownerHero, goldCost)
    barrack.chen_reserved_gold = (barrack.chen_reserved_gold or 0) + goldCost

    table.insert(barrack.chen_production_queue, {
        unit_name = unitName,
        source_unit_name = sourceUnitName,
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
    if not ownerHero or ownerHero:IsNull() then
        return UF_FAIL_CUSTOM
    end

    local abilityName = self:GetAbilityName()
    local variant = GetAbilityVariant(abilityName)

    local ult = ownerHero:FindAbilityByName("chen_barrack")
    if not ult then return UF_FAIL_CUSTOM end
    
    local ultLevel = ult:GetLevel()
    if variant > ultLevel then
        if variant == 4 then
            if not HasScepterUpgrade(ownerHero) then
                return UF_FAIL_CUSTOM
            end
        else
            return UF_FAIL_CUSTOM
        end
    end

    local sourceUnitName = barrack.chen_source_unit_name
    local unitName = GetFamilyUnitName(sourceUnitName, variant)
    if not unitName then
        return UF_FAIL_CUSTOM
    end

    InitBarrackState(barrack)
    if GetBarrackQueuedCount(barrack) >= 5 then
        return UF_FAIL_CUSTOM
    end

    local goldCost = self:GetSpecialValueFor("gold_cost")
    goldCost = math.max(0, goldCost - GetTalentValue(ownerHero, "special_bonus_unique_custom_chen_8", "gold_cost_reduction", 0))

    if not HasEnoughGold(ownerHero, goldCost) then
        return UF_FAIL_CUSTOM
    end

    return UF_SUCCESS
end

local function BarrackSummonCastError(self)
    local barrack = self:GetCaster()
    local ownerHero = GetBarrackOwnerHero(barrack)
    if not ownerHero or ownerHero:IsNull() then
        return "#dota_hud_error_chen_barrack_no_owner"
    end

    local abilityName = self:GetAbilityName()
    local variant = GetAbilityVariant(abilityName)

    local ult = ownerHero:FindAbilityByName("chen_barrack")
    if not ult then return "#dota_hud_error_internal" end
    
    local ultLevel = ult:GetLevel()
    if variant > ultLevel then
        if variant == 4 then
            if not HasScepterUpgrade(ownerHero) then
                return "#dota_hud_error_chen_barrack_need_scepter"
            end
        else
            return "#dota_hud_error_chen_barrack_low_level"
        end
    end

    local sourceUnitName = barrack.chen_source_unit_name
    local unitName = GetFamilyUnitName(sourceUnitName, variant)
    if not unitName then
        return "#dota_hud_error_chen_barrack_no_unit_in_family"
    end

    InitBarrackState(barrack)
    if GetBarrackQueuedCount(barrack) >= 5 then
        return "#dota_hud_error_chen_barrack_queue_full"
    end

    local goldCost = math.max(0, self:GetSpecialValueFor("gold_cost") - GetTalentValue(ownerHero, "special_bonus_unique_custom_chen_8", "gold_cost_reduction", 0))

    if not HasEnoughGold(ownerHero, goldCost) then
        return "#dota_hud_error_not_enough_gold"
    end

    return ""
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

    print("[Chen Barrack] OnSpellStart called")

    local caster = self:GetCaster()
    local target = self:GetCursorTarget()
    
    print("[Chen Barrack] Caster: " .. (caster and caster:GetUnitName() or "nil"))
    print("[Chen Barrack] Target: " .. (target and target:GetUnitName() or "nil"))
    
    if not IsChenTamedCreep(target, caster) then
        print("[Chen Barrack] Target is not a tamed creep")
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
    if HasScepterUpgrade(caster) then
        maxBarracks = maxBarracks + self:GetSpecialValueFor("scepter_bonus_barracks")
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
    local teamNumber = caster:GetTeamNumber()
    local targetMaxHealth = math.max(target:GetMaxHealth(), target:GetHealth())
    local bonusHealth = self:GetSpecialValueFor("bonus_health")
    local minimumBarrackHealth = self:GetSpecialValueFor("minimum_barrack_health")

    -- Determine family from target unit name
    local targetName = target:GetUnitName() or ""
    local familyName = GetFamilyName(targetName)
    
    print("[Chen Barrack] GetFamilyName returned: " .. (familyName or "nil") .. " for unit: " .. targetName)

    -- Fallback: если крип не найден в таблице, используем satyr как дефолт
    if not familyName then
        print("[Chen Barrack] Family not found for unit: " .. targetName .. ", using satyr as fallback")
        familyName = "satyr"
    end

    print("[Chen Barrack] Unit: " .. targetName .. ", Family: " .. familyName)

    if target:IsAlive() then
        target:ForceKill(false)
    end
    UTIL_Remove(target)

    local barrack = CreateUnitByName("npc_chen_barrack", origin, true, caster, caster, teamNumber)
    if not barrack then
        return
    end

    barrack.chen_barrack_owner_entindex = caster:entindex()
    barrack.chen_barrack_created_time = GameRules:GetGameTime()
    barrack.chen_source_unit_name = targetName
    barrack.chen_family_name = familyName
    barrack:SetOwner(caster)
    barrack:SetControllableByPlayer(playerID, true)
    barrack:SetForwardVector(forward)
    barrack:SetMoveCapability(DOTA_UNIT_CAP_MOVE_NONE)
    barrack:AddNewModifier(caster, nil, "modifier_chen_barrack", {})

    -- Выдаем способности семьи
    GrantFamilyAbilities(barrack, familyName, caster)

    local barrackMaxHealth = math.max(minimumBarrackHealth, targetMaxHealth + bonusHealth)
    barrack:SetBaseMaxHealth(barrackMaxHealth)
    barrack:SetMaxHealth(barrackMaxHealth)
    barrack:SetHealth(barrackMaxHealth)

    local model = GetBarrackModel(teamNumber)
    barrack:SetModel(model)
    barrack:SetOriginalModel(model)

    LevelBarrackAbilities(barrack)

    -- Задержка для правильной инициализации способностей
    Timers:CreateTimer(0.1, function()
        print("[Chen Barrack] Activating abilities for barrack")
        for slot = 0, 15 do
            local ability = barrack:GetAbilityByIndex(slot)
            if ability then
                ability:SetActivated(true)
                ability:SetHidden(false)
                print("[Chen Barrack] Activated ability at slot " .. slot .. ": " .. ability:GetAbilityName())
            end
        end
    end)

    EmitSoundOn("Hero_Chen.HolyPersuasionEnemy", barrack)
end

function chen_barrack_summon:CastFilterResult()
    return BarrackSummonCastFilter(self)
end

function chen_barrack_summon:GetCustomCastError()
    return BarrackSummonCastError(self)
end

function chen_barrack_summon:OnSpellStart()
    QueueBarrackUnit(self)
end

-- Generic OnSpellStart for all barrack summon abilities
function chen_barrack_centaur_t1:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_centaur_t2:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_centaur_t3:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_centaur_ancient:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_satyr_t1:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_satyr_t2:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_satyr_t3:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_satyr_ancient:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_troll_t1:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_troll_t2:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_troll_t3:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_troll_ancient:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_wolf_t1:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_wolf_t2:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_wolf_t3:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_wolf_ancient:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_golem_t1:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_golem_t2:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_golem_t3:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_golem_ancient:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_harpy_t1:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_harpy_t2:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_harpy_t3:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_harpy_ancient:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_furbolg_t1:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_furbolg_t2:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_furbolg_t3:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_furbolg_ancient:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_frog_t1:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_frog_t2:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_frog_t3:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_frog_ancient:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_dragon_t1:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_dragon_t2:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_dragon_t3:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_dragon_ancient:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_bear_t1:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_bear_t2:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_bear_t3:OnSpellStart() QueueBarrackUnit(self) end
function chen_barrack_bear_ancient:OnSpellStart() QueueBarrackUnit(self) end

-- Generic CastFilterResult for all barrack summon abilities
function chen_barrack_centaur_t1:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_centaur_t2:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_centaur_t3:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_centaur_ancient:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_satyr_t1:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_satyr_t2:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_satyr_t3:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_satyr_ancient:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_troll_t1:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_troll_t2:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_troll_t3:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_troll_ancient:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_wolf_t1:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_wolf_t2:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_wolf_t3:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_wolf_ancient:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_golem_t1:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_golem_t2:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_golem_t3:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_golem_ancient:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_harpy_t1:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_harpy_t2:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_harpy_t3:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_harpy_ancient:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_furbolg_t1:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_furbolg_t2:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_furbolg_t3:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_furbolg_ancient:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_frog_t1:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_frog_t2:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_frog_t3:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_frog_ancient:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_dragon_t1:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_dragon_t2:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_dragon_t3:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_dragon_ancient:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_bear_t1:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_bear_t2:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_bear_t3:CastFilterResult() return BarrackSummonCastFilter(self) end
function chen_barrack_bear_ancient:CastFilterResult() return BarrackSummonCastFilter(self) end

-- Generic GetCustomCastError for all barrack summon abilities
function chen_barrack_centaur_t1:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_centaur_t2:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_centaur_t3:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_centaur_ancient:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_satyr_t1:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_satyr_t2:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_satyr_t3:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_satyr_ancient:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_troll_t1:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_troll_t2:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_troll_t3:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_troll_ancient:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_wolf_t1:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_wolf_t2:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_wolf_t3:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_wolf_ancient:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_golem_t1:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_golem_t2:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_golem_t3:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_golem_ancient:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_harpy_t1:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_harpy_t2:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_harpy_t3:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_harpy_ancient:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_furbolg_t1:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_furbolg_t2:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_furbolg_t3:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_furbolg_ancient:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_frog_t1:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_frog_t2:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_frog_t3:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_frog_ancient:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_dragon_t1:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_dragon_t2:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_dragon_t3:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_dragon_ancient:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_bear_t1:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_bear_t2:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_bear_t3:GetCustomCastError() return BarrackSummonCastError(self) end
function chen_barrack_bear_ancient:GetCustomCastError() return BarrackSummonCastError(self) end

-- Self destruct ability
function chen_barrack_self_destruct:OnSpellStart()
    if not IsServer() then
        return
    end

    local barrack = self:GetCaster()
    if not barrack or barrack:IsNull() then
        return
    end

    -- Refund reserved gold
    RefundReservedGold(barrack)

    -- Mark as destroyed to prevent production
    barrack.chen_is_destroyed = true

    -- Create explosion effect
    local radius = self:GetSpecialValueFor("radius")
    local damage = self:GetSpecialValueFor("damage")

    local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_techies/techies_remote_mines_detonate.vpcf", PATTACH_ABSORIGIN, barrack)
    ParticleManager:SetParticleControl(particle, 0, barrack:GetAbsOrigin())
    ParticleManager:SetParticleControl(particle, 1, Vector(radius, 0, 0))
    ParticleManager:ReleaseParticleIndex(particle)

    EmitSoundOn("Hero_Techies.RemoteMine.Detonate", barrack)

    -- Deal damage to enemies
    local teamNumber = barrack:GetTeamNumber()
    local enemies = FindUnitsInRadius(
        teamNumber,
        barrack:GetAbsOrigin(),
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_ALL,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    for _, enemy in pairs(enemies) do
        if enemy and not enemy:IsNull() and enemy:IsAlive() then
            ApplyDamage({
                victim = enemy,
                attacker = barrack,
                damage = damage,
                damage_type = DAMAGE_TYPE_MAGICAL,
                ability = self
            })
        end
    end

    -- Kill the barrack
    barrack:Kill(nil, barrack)
end

-- Modifiers
function modifier_chen_barrack:IsHidden()
    return true
end

function modifier_chen_barrack:IsPurgable()
    return false
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

function modifier_chen_barrack_producing:GetTexture()
    return "chen_holy_persuasion"
end
