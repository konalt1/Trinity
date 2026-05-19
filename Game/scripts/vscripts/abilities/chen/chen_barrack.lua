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
modifier_chen_barrack = class({})
modifier_chen_barrack_producing = class({})

-- Регистрируем Lua-модификаторы, иначе движок их не найдёт
LinkLuaModifier("modifier_chen_barrack", "abilities/chen/chen_barrack", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_barrack_producing", "abilities/chen/chen_barrack", LUA_MODIFIER_MOTION_NONE)

local CHEN_BARRACK_PRODUCING_MODIFIER = "modifier_chen_barrack_producing"
-- Маппинг семьи к юниту барака
local FAMILY_TO_BARRACK_UNIT = {
    satyr = "npc_chen_barrack_satyr",
    frog = "npc_chen_barrack_frog",
    troll = "npc_chen_barrack_troll",
    wolf = "npc_chen_barrack_wolf",
    centaur = "npc_chen_barrack_centaur",
    golem = "npc_chen_barrack_golem",
    dragon = "npc_chen_barrack_dragon",
    bear = "npc_chen_barrack_bear",
    furbolg = "npc_chen_barrack_furbolg",
    harpy = "npc_chen_barrack_harpy",
}

local BARRACK_MODEL = "models/props_structures/good_barracks_melee001.vmdl"

function chen_barrack:Precache(context)
    PrecacheResource("model", BARRACK_MODEL, context)
end

--- 10 семей крипов для барака Чена
--- Каждая семья имеет 4 уровня: т1, т2, т3, ancient (т4)
--- Уровень барака определяет доступные уровни крипов
--- Аганим открывает ancient уровень
local CHEN_BARRACK_FAMILIES = {
    { "satyr", { "npc_dota_neutral_satyr_trickster", "npc_dota_neutral_satyr_soulstealer", "npc_dota_neutral_satyr_hellcaller", "npc_dota_neutral_prowler_acolyte"} },
    { "frog", { "npc_dota_neutral_pollywog", "npc_dota_neutral_frog", "npc_dota_neutral_frog_elder", "npc_chen_frog_ancient" } },
    { "troll", { "npc_dota_neutral_forest_troll_berserker", "npc_dota_neutral_ogre_magi", "npc_dota_neutral_ogre_mauler", "npc_dota_neutral_ice_shaman" } },
    { "wolf", { "npc_dota_neutral_gnoll_assassin", "npc_dota_neutral_alpha_wolf", "npc_dota_neutral_giant_wolf", "npc_dota_neutral_big_thunder_lizard" } },
    { "centaur", { "npc_dota_neutral_kobold", "npc_dota_neutral_centaur_outrunner", "npc_dota_neutral_centaur_khan", "npc_chen_centaur_warruner" } },
    { "golem", { "npc_dota_neutral_mud_golem_split", "npc_dota_neutral_mud_golem", "npc_dota_neutral_rock_golem", "npc_dota_neutral_granite_golem" } },
    { "dragon", { "npc_dota_neutral_harpy_scout", "npc_dota_neutral_harpy_storm", "npc_dota_neutral_black_drake", "npc_dota_neutral_black_dragon" } },
    { "bear", { "npc_chen_bear_wander", "npc_dota_neutral_polar_furbolg_champion", "npc_dota_neutral_polar_furbolg_ursa_warrior", "npc_chen_bear_torchbearer" } },
    { "furbolg", { "npc_dota_furion_treant", "npc_chen_furbolg_shroom", "npc_dota_neutral_warpine_raider", "npc_chen_furbolg_treant" } },
    { "harpy", { "npc_dota_neutral_wildkin", "npc_chen_harpy_bird", "npc_dota_neutral_enraged_wildkin", "npc_chen_harpy_phoenix" } },
}

-- Маппинг правильных имен юнитов для каждой семьи
local CHEN_BARRACK_FAMILY_TARGETS = {
    satyr = { "npc_dota_neutral_satyr_trickster", "npc_dota_neutral_satyr_soulstealer", "npc_dota_neutral_satyr_hellcaller", "npc_dota_neutral_prowler_acolyte" },
    frog = { "npc_dota_neutral_pollywog", "npc_dota_neutral_frog", "npc_dota_neutral_frog_elder", "npc_chen_frog_ancient" },
    troll = { "npc_dota_neutral_forest_troll_berserker", "npc_dota_neutral_ogre_magi", "npc_dota_neutral_ogre_mauler", "npc_dota_neutral_ice_shaman" },
    wolf = { "npc_dota_neutral_gnoll_assassin", "npc_dota_neutral_alpha_wolf", "npc_dota_neutral_giant_wolf", "npc_dota_neutral_big_thunder_lizard" },
    centaur = { "npc_dota_neutral_kobold", "npc_dota_neutral_centaur_outrunner", "npc_dota_neutral_centaur_khan", "npc_chen_centaur_warruner" },
    golem = { "npc_dota_neutral_mud_golem_split", "npc_dota_neutral_mud_golem", "npc_dota_neutral_rock_golem", "npc_dota_neutral_granite_golem" },
    dragon = { "npc_dota_neutral_harpy_scout", "npc_dota_neutral_harpy_storm", "npc_dota_neutral_black_drake", "npc_dota_neutral_black_dragon" },
    bear = { "npc_chen_bear_wander", "npc_dota_neutral_polar_furbolg_champion", "npc_dota_neutral_polar_furbolg_ursa_warrior", "npc_chen_bear_torchbearer" },
    furbolg = { "npc_dota_furion_treant", "npc_chen_furbolg_shroom", "npc_dota_neutral_warpine_raider", "npc_chen_furbolg_treant" },
    harpy = { "npc_dota_neutral_wildkin", "npc_chen_harpy_bird", "npc_dota_neutral_enraged_wildkin", "npc_chen_harpy_phoenix" },
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

    local ok, alive = pcall(function() return unit:IsAlive() end)
    if not ok or not alive then
        return false
    end

    -- Герои и здания — не крипы
    if unit:IsHero() or unit:IsBuilding() then
        return false
    end

    -- Должен быть союзным (KV уже фильтрует DOTA_UNIT_TARGET_TEAM_FRIENDLY,
    -- но дополнительная проверка не помешает)
    if unit:GetTeamNumber() ~= caster:GetTeamNumber() then
        return false
    end

    -- Всё — цель валидна. Строгая проверка владения делается в OnSpellStart.
    return true
end

-- Глобальный реестр: [entindex барака] -> entindex героя-владельца
CHEN_BARRACK_REGISTRY = CHEN_BARRACK_REGISTRY or {}

local function GetBarrackOwnerHero(unit)
    if not unit or unit:IsNull() then
        return nil
    end

    local dbg = "[GetBarrackOwnerHero] eid=" .. unit:entindex() .. " "

    -- Way 0: прямая ссылка
    if unit.chen_barrack_owner_hero then
        local ok, dead = pcall(function() return unit.chen_barrack_owner_hero:IsNull() end)
        if ok and not dead then
            return unit.chen_barrack_owner_hero
        end
        unit.chen_barrack_owner_hero = nil
        print(dbg .. "Way0 FAIL (ok=" .. tostring(ok) .. " dead=" .. tostring(dead) .. ")")
    else
        print(dbg .. "Way0 SKIP (no field)")
    end

    -- Way 1: entindex
    if unit.chen_barrack_owner_entindex then
        local ok, hero = pcall(EntIndexToHScript, unit.chen_barrack_owner_entindex)
        if ok and hero and not hero:IsNull() and hero:IsRealHero() then
            unit.chen_barrack_owner_hero = hero
            return hero
        end
        print(dbg .. "Way1 FAIL entindex=" .. tostring(unit.chen_barrack_owner_entindex))
    else
        print(dbg .. "Way1 SKIP (no entindex field)")
    end

    -- Way 2: глобальный реестр
    local barrackIdx = unit:entindex()
    local ownerIdx = CHEN_BARRACK_REGISTRY and CHEN_BARRACK_REGISTRY[barrackIdx]
    if ownerIdx then
        local ok, hero = pcall(EntIndexToHScript, ownerIdx)
        if ok and hero and not hero:IsNull() and hero:IsRealHero() then
            unit.chen_barrack_owner_entindex = ownerIdx
            unit.chen_barrack_owner_hero = hero
            return hero
        end
        print(dbg .. "Way2 FAIL ownerIdx=" .. tostring(ownerIdx))
    else
        print(dbg .. "Way2 SKIP (not in registry)")
    end

    -- Way 3: GetPlayerOwnerID
    local playerID = unit:GetPlayerOwnerID()
    print(dbg .. "Way3 playerID=" .. tostring(playerID))
    if playerID and playerID >= 0 and PlayerResource then
        local hero = PlayerResource:GetSelectedHeroEntity(playerID)
        if hero and not hero:IsNull() and hero:IsRealHero() then
            return hero
        end
        print(dbg .. "Way3 FAIL hero=" .. tostring(hero))
    end

    -- Way 4: GetOwnerEntity
    local ok4, owner = pcall(function() return unit:GetOwnerEntity() end)
    if ok4 and owner and not owner:IsNull() and owner:IsRealHero() then
        return owner
    end
    print(dbg .. "Way4 FAIL, returning nil")

    return nil
end

--- Уровень ульты chen_barrack: определяет ступень цены/времени в AbilityValues способностей производства.
local function GetBarrackProductionScalingLevel(ownerHero)
    if not ownerHero or ownerHero:IsNull() then
        return 1
    end
    local ult = ownerHero:FindAbilityByName("chen_barrack")
    if not ult or ult:IsNull() then
        return 1
    end
    local n = ult:GetLevel()
    if n < 1 then
        n = 1
    end
    return n
end

local function GetBarrackSummonedUnitAbilityLevel(ownerHero)
    if HasScepterUpgrade(ownerHero) then
        return 4
    end

    return GetBarrackProductionScalingLevel(ownerHero)
end

--- Читает gold_cost / production_time / spawn_distance для «ступени» ульты (без опоры на уровень способности на юните).
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

local function ForEachBarrackOwnedByHero(hero, fn)
    if not hero or hero:IsNull() or not fn then
        return
    end
    local teamNumber = hero:GetTeamNumber()
    local units = FindUnitsInRadius(
        teamNumber,
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
        if unit and not unit:IsNull() and unit:IsAlive() then
            local unitName = unit:GetUnitName()
            for _, barrackUnitName in pairs(FAMILY_TO_BARRACK_UNIT) do
                if unitName == barrackUnitName then
                    if unit.chen_barrack_owner_entindex == hero:entindex() then
                        fn(unit)
                    end
                    break
                end
            end
        end
    end
end

local function HasEnoughGold(hero, goldCost)
    if not hero or hero:IsNull() then
        return false
    end

    local playerID = hero:GetPlayerOwnerID()
    if playerID == nil or playerID < 0 then
        return false
    end

    if not PlayerResource then return false end
    return PlayerResource:GetGold(playerID) >= goldCost
end

local function GetBarrackGoldReason()
    return DOTA_ModifyGold_PurchaseItem or DOTA_ModifyGold_Unspecified or 0
end

local function GetPlayerGoldPart(playerID, methodName)
    if not PlayerResource or not PlayerResource[methodName] then
        return 0
    end

    local ok, value = pcall(function()
        return PlayerResource[methodName](PlayerResource, playerID)
    end)

    if not ok then
        return 0
    end

    return math.max(0, tonumber(value) or 0)
end

local function ModifyPlayerGold(playerID, goldAmount, reliable)
    if not PlayerResource or not PlayerResource.ModifyGold then
        return false
    end

    local ok = pcall(function()
        PlayerResource:ModifyGold(playerID, goldAmount, reliable, GetBarrackGoldReason())
    end)

    return ok
end

local function SpendGold(hero, goldCost)
    goldCost = math.floor(tonumber(goldCost) or 0)
    if goldCost <= 0 or not hero or hero:IsNull() then
        return
    end

    local playerID = hero:GetPlayerOwnerID()
    if playerID == nil or playerID < 0 then
        hero:ModifyGold(-goldCost, false, GetBarrackGoldReason())
        return
    end

    if PlayerResource and PlayerResource.SpendGold then
        local ok = pcall(function()
            PlayerResource:SpendGold(playerID, goldCost, GetBarrackGoldReason())
        end)
        if ok then
            return
        end
    end

    local remainingCost = goldCost
    local unreliableGold = GetPlayerGoldPart(playerID, "GetUnreliableGold")
    local unreliableSpend = math.min(unreliableGold, remainingCost)

    if unreliableSpend > 0 and ModifyPlayerGold(playerID, -unreliableSpend, false) then
        remainingCost = remainingCost - unreliableSpend
    end

    if remainingCost > 0 and ModifyPlayerGold(playerID, -remainingCost, true) then
        return
    end

    if remainingCost > 0 then
        hero:ModifyGold(-remainingCost, true, GetBarrackGoldReason())
    end
end

local function GiveGoldToHero(hero, goldAmount)
    goldAmount = math.floor(tonumber(goldAmount) or 0)
    if not hero or hero:IsNull() or goldAmount <= 0 then
        return
    end

    local playerID = hero:GetPlayerOwnerID()
    if playerID ~= nil and playerID >= 0 and ModifyPlayerGold(playerID, goldAmount, false) then
        return
    end

    hero:ModifyGold(goldAmount, false, GetBarrackGoldReason())
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
    if not barrack or barrack:IsNull() then
        return
    end
    local ownerHero = GetBarrackOwnerHero(barrack)
    local lv = GetBarrackProductionScalingLevel(ownerHero)
    for slot = 0, 15 do
        local ability = barrack:GetAbilityByIndex(slot)
        if ability and not ability:IsNull() then
            local maxLv = ability:GetMaxLevel()
            if maxLv and maxLv > 0 then
                ability:SetLevel(math.min(lv, maxLv))
            end
        end
    end
end

local function GetBarrackModel(teamNumber)
    return BARRACK_MODEL
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
end

local function GetFamilyUnitName(familyName, variant)
    if not familyName or familyName == "" then
        return nil
    end

    -- Ищем по имени семьи в CHEN_BARRACK_FAMILY_TARGETS
    local unitNames = CHEN_BARRACK_FAMILY_TARGETS[familyName]
    if unitNames and unitNames[variant] then
        return unitNames[variant]
    end

    -- Fallback: ищем в CHEN_BARRACK_FAMILIES
    for _, family in ipairs(CHEN_BARRACK_FAMILIES) do
        if family[1] == familyName and family[2][variant] then
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

local function IsValidProductionModifier(modifier)
    if not modifier then
        return false
    end

    if modifier.IsNull then
        return not modifier:IsNull()
    end

    return true
end

local function AddProductionModifier(barrack, item, duration)
    if not barrack or barrack:IsNull() then
        return nil
    end

    local kv = {
        production_time = item and item.production_time or duration or 0,
    }

    if duration and duration > 0 then
        kv.duration = duration
    end

    local modifier = barrack:AddNewModifier(barrack, nil, CHEN_BARRACK_PRODUCING_MODIFIER, kv)
    if modifier and duration and duration > 0 then
        modifier:SetDuration(duration, true)
    end

    return modifier
end

local function AddQueuedProductionModifier(barrack, item)
    if IsValidProductionModifier(item.production_modifier) then
        return item.production_modifier
    end

    item.production_modifier = AddProductionModifier(barrack, item, nil)
    return item.production_modifier
end

local function StartProductionModifier(barrack, item, productionTime)
    if IsValidProductionModifier(item.production_modifier) then
        item.production_modifier:SetDuration(productionTime, true)
        return item.production_modifier
    end

    item.production_modifier = AddProductionModifier(barrack, item, productionTime)
    return item.production_modifier
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

local function LevelUnitAbilities(unit, ownerHero)
    if not unit or unit:IsNull() then
        return
    end

    local level = GetBarrackSummonedUnitAbilityLevel(ownerHero)

    for slot = 0, 7 do
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
    if not barrack or barrack:IsNull() or not barrack:IsAlive() or barrack.chen_is_destroyed then
        return
    end

    local ownerHero = GetBarrackOwnerHero(barrack)
    if not ownerHero then
        return
    end

    local playerID = ownerHero:GetPlayerOwnerID()
    local teamNumber = ownerHero:GetTeamNumber()
    local spawnDistance = item.spawn_distance or 400
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
    LevelUnitAbilities(summon, ownerHero)

    local summonLifetime = math.max(1, tonumber(item.summon_lifetime) or 60)
    summon:AddNewModifier(ownerHero, ownerHero:FindAbilityByName("chen_barrack"), "modifier_kill", { duration = summonLifetime })

    -- Add production visual effects
    local particle = ParticleManager:CreateParticle("particles/econ/events/ti6/kill_effect_creep_gold.vpcf", PATTACH_ABSORIGIN_FOLLOW, summon)
    ParticleManager:ReleaseParticleIndex(particle)

    -- Play spawn sound
    EmitSoundOn("DOTA_Item.Hand_Of_Midas", barrack)
    FindClearSpaceForUnit(summon, spawnPosition, true)

    barrack.chen_reserved_gold = math.max(0, (barrack.chen_reserved_gold or 0) - (item.gold_cost or 0))
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
    StartProductionModifier(barrack, item, productionTime)

    Timers:CreateTimer(item.production_time or 1, function()
        if barrack and not barrack:IsNull() and barrack:IsAlive() and not barrack.chen_is_destroyed then
            CompleteProduction(barrack, item)
            DestroyProductionModifier(item)
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

    repeat
        local barrack = self:GetCaster()
        local ownerHero = GetBarrackOwnerHero(barrack)
        if not ownerHero then
            break
        end

        local abilityName = self:GetAbilityName()
        local variant = GetAbilityVariant(abilityName)

        if not ownerHero:FindAbilityByName("chen_barrack") then
            break
        end
        if variant == 4 and not HasScepterUpgrade(ownerHero) then
            break
        end

        local goldCost = GetBarrackSummonValue(self, ownerHero, "gold_cost")

        if not HasEnoughGold(ownerHero, goldCost) then
            break
        end

        InitBarrackState(barrack)

        local queueLimit = 5
        if GetBarrackQueuedCount(barrack) >= queueLimit then
            break
        end

        local sourceUnitName = barrack.chen_source_unit_name
        local familyName = barrack.chen_family_name
        local unitName = GetFamilyUnitName(familyName, variant)

        if not unitName then
            CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(ownerHero:GetPlayerOwnerID()), "show_custom_error", { message = "#dota_hud_error_chen_barrack_no_unit_in_family" })
            break
        end

        local productionTime = GetBarrackSummonValue(self, ownerHero, "production_time")

        SpendGold(ownerHero, goldCost)
        barrack.chen_reserved_gold = (barrack.chen_reserved_gold or 0) + goldCost

        local productionItem = {
            unit_name = unitName,
            source_unit_name = sourceUnitName,
            gold_cost = goldCost,
            production_time = productionTime,
            spawn_distance = GetBarrackSummonValue(self, ownerHero, "spawn_distance"),
            summon_lifetime = GetBarrackSummonValue(self, ownerHero, "summon_lifetime"),
        }

        table.insert(barrack.chen_production_queue, productionItem)

        if (barrack.chen_active_productions or 0) > 0 then
            AddQueuedProductionModifier(barrack, productionItem)
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

local function BarrackSummonCastFilter(self)
    if not IsServer() then
        return UF_SUCCESS
    end

    local barrack = self:GetCaster()
    local ownerHero = GetBarrackOwnerHero(barrack)
    if not ownerHero or ownerHero:IsNull() then
        return UF_FAIL_CUSTOM
    end

    local abilityName = self:GetAbilityName()
    local variant = GetAbilityVariant(abilityName)

    local ult = ownerHero:FindAbilityByName("chen_barrack")
    if not ult then return UF_FAIL_CUSTOM end

    if variant == 4 and not HasScepterUpgrade(ownerHero) then
        return UF_FAIL_CUSTOM
    end

    local sourceUnitName = barrack.chen_source_unit_name
    local familyName = barrack.chen_family_name
    local unitName = GetFamilyUnitName(familyName, variant)
    if not unitName then
        return UF_FAIL_CUSTOM
    end

    InitBarrackState(barrack)
    if GetBarrackQueuedCount(barrack) >= 5 then
        return UF_FAIL_CUSTOM
    end

    local goldCost = GetBarrackSummonValue(self, ownerHero, "gold_cost")

    if not HasEnoughGold(ownerHero, goldCost) then
        return UF_FAIL_CUSTOM
    end

    return UF_SUCCESS
end

local function BarrackSummonCastError(self)
    if not IsServer() then
        return ""
    end

    local barrack = self:GetCaster()
    local ownerHero = GetBarrackOwnerHero(barrack)
    if not ownerHero or ownerHero:IsNull() then
        return "#dota_hud_error_chen_barrack_no_owner"
    end

    local abilityName = self:GetAbilityName()
    local variant = GetAbilityVariant(abilityName)

    local ult = ownerHero:FindAbilityByName("chen_barrack")
    if not ult then return "#dota_hud_error_internal" end

    if variant == 4 and not HasScepterUpgrade(ownerHero) then
        return "#dota_hud_error_chen_barrack_need_scepter"
    end

    local sourceUnitName = barrack.chen_source_unit_name
    local familyName = barrack.chen_family_name
    local unitName = GetFamilyUnitName(familyName, variant)
    if not unitName then
        return "#dota_hud_error_chen_barrack_no_unit_in_family"
    end

    InitBarrackState(barrack)
    if GetBarrackQueuedCount(barrack) >= 5 then
        return "#dota_hud_error_chen_barrack_queue_full"
    end

    local goldCost = GetBarrackSummonValue(self, ownerHero, "gold_cost")

    if not HasEnoughGold(ownerHero, goldCost) then
        return "#dota_hud_error_not_enough_gold"
    end

    return ""
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

function chen_barrack:CastFilterResultTarget(target)
    -- KV уже фильтрует по DOTA_UNIT_TARGET_TEAM_FRIENDLY + BASIC
    -- Проверяем только что это не герой и не здание
    if not target or target:IsNull() then return UF_FAIL_CUSTOM end
    if target:IsHero() or target:IsBuilding() then return UF_FAIL_CUSTOM end
    return UF_SUCCESS
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
        if unit and not unit:IsNull() and unit:IsAlive() then
            local unitName = unit:GetUnitName()
            -- Проверяем все юниты бараков
            for _, barrackUnitName in pairs(FAMILY_TO_BARRACK_UNIT) do
                if unitName == barrackUnitName then
                    if unit.chen_barrack_owner_entindex == caster:entindex() then
                        table.insert(existingBarracks, unit)
                    end
                    break
                end
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

    -- Спавним соответствующий юнит барака для семьи
    local barrackUnitName = FAMILY_TO_BARRACK_UNIT[familyName] or "npc_chen_barrack"
    local barrack = CreateUnitByName(barrackUnitName, origin, true, caster, caster, teamNumber)
    if not barrack then
        return
    end

    barrack.chen_barrack_owner_entindex = caster:entindex()
    barrack.chen_barrack_owner_hero = caster  -- прямая ссылка для надёжного поиска
    barrack.chen_barrack_created_time = GameRules:GetGameTime()
    barrack.chen_source_unit_name = targetName
    barrack.chen_family_name = familyName

    -- Регистрируем в глобальном реестре (надёжный fallback)
    CHEN_BARRACK_REGISTRY = CHEN_BARRACK_REGISTRY or {}
    CHEN_BARRACK_REGISTRY[barrack:entindex()] = caster:entindex()
    print("[Chen Barrack] Registered barrack " .. barrack:entindex() .. " -> owner " .. caster:entindex())

    barrack:SetOwner(caster)
    barrack:SetControllableByPlayer(playerID, true)
    if barrack.SetPlayerID then
        barrack:SetPlayerID(playerID)
    end
    barrack:SetForwardVector(forward)
    barrack:SetMoveCapability(DOTA_UNIT_CAP_MOVE_NONE)
    barrack:AddNewModifier(caster, nil, "modifier_chen_barrack", {})

    -- Способности уже заданы в KV, не нужно выдавать их вручную
    -- GrantFamilyAbilities(barrack, familyName, caster)

    local barrackMaxHealth = math.max(minimumBarrackHealth, targetMaxHealth + bonusHealth)
    barrack:SetBaseMaxHealth(barrackMaxHealth)
    barrack:SetMaxHealth(barrackMaxHealth)
    barrack:SetHealth(barrackMaxHealth)

    barrack:SetModel(BARRACK_MODEL)
    barrack:SetOriginalModel(BARRACK_MODEL)

    LevelBarrackAbilities(barrack)

    -- Задержка для правильной инициализации способностей
    Timers:CreateTimer(0.1, function()
        print("[Chen Barrack] Activating abilities for barrack")
        for slot = 0, 4 do
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

function modifier_chen_barrack_producing:GetAttributes()
    return MODIFIER_ATTRIBUTE_MULTIPLE
end

function modifier_chen_barrack_producing:GetTexture()
    return "chen_holy_persuasion"
end
