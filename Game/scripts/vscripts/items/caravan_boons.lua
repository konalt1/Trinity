-- Буны каравана Аганима.
-- Предмет применяется один раз на союзного героя или себя, затем исчезает.
-- Эффект держится до конца матча. Одинаковые буны увеличивают один и тот же модификатор.
-- Числа должны совпадать с AbilityValues в npc_items_custom.txt.
--
-- Какие буны несут курьеры на каждой стадии — CaravanLoot.BOONS (caravan_loot.lua), по 4 на стадию.
-- Особые буны:
--   item_boon_aghanim       — эффект Aghanim's Scepter (ванильный modifier_item_ultimate_scepter_consumed);
--   item_boon_aegis         — ванильный modifier_aegis на duration сек. (60);
--   буны с выбором способности (CHOICE ниже) — бун тратится сразу, цель получает видимый
--   modifier_<бун>_pending, а игрок, управляющий целью, выбирает способность в окне boon_charges:
--     item_boon_twin_charges — способность копит 2 заряда, заряд восстанавливается за КД × 1,5;
--     item_boon_vampirism    — урон способности лечит героя;
--     item_boon_quickening   — применение способности ускоряет героя;
--     item_boon_lens         — дальность применения способности +250;
--     item_boon_daedalus     — урон способности с шансом 30% увеличен на 150%;
--     item_boon_greaves      — применение способности даёт герою обычное развеивание;
--     item_boon_octarine     — перезарядка способности на 15% короче;
--     item_boon_venomancer   — дебаффы способности на врагах длятся в 2 раза дольше
--                              (CaravanBoons.ModifierGainedFilter из GameMode:ModifierGainedFilter);
--     item_boon_kaya         — все коэффициенты Силы магии способности ×1,5
--                              (OVERRIDE_ABILITY_SPECIAL на ключи *mind_power*);
--     item_boon_holy_locket  — лечение способности (себя и союзников) +15%
--                              (CaravanBoons.HealingFilter из GameMode:HealingFilter).

-- Правила подсказки Силы магии нужны буну Кайи, чтобы не трогать пересчитываемые подсказкой значения.
if not CustomAbilityTooltips then
    pcall(require, "game_managers/custom_ability_tooltips")
end

local BOONS = {
    -- Стат-буны. Стадия 1 лута: сила (пояс) +6, ловкость (ботинки эльфов) +6, интеллект (роба) +6, корона +4 ко всем.
    -- Перчатки, тапочки, мантия и обруч в лут не входят, оставлены предметами.
    item_boon_gauntlets = { texture = "item_boon_gauntlets", values = { bonus_strength = 3 } },
    item_boon_slippers = { texture = "item_boon_slippers", values = { bonus_agility = 3 } },
    item_boon_mantle = { texture = "item_boon_mantle", values = { bonus_intellect = 3 } },
    item_boon_circlet = { texture = "item_boon_circlet", values = { bonus_all_stats = 2 } },
    item_boon_belt_of_strength = { texture = "item_boon_belt_of_strength", values = { bonus_strength = 6 } },
    item_boon_boots_of_elves = { texture = "item_boon_boots_of_elves", values = { bonus_agility = 6 } },
    item_boon_robe = { texture = "item_boon_robe", values = { bonus_intellect = 6 } },
    item_boon_crown = { texture = "item_boon_crown", values = { bonus_all_stats = 4 } },

    -- Бывшая стадия 1 (в лут не входят, оставлены предметами)
    item_boon_vitality = { texture = "item_boon_vitality", values = { bonus_health = 80 } },
    item_boon_clarity = { texture = "item_boon_clarity", values = { bonus_mana_regen = 1 } },
    item_boon_swiftness = { texture = "item_boon_swiftness", values = { bonus_movement_speed = 12 } },

    -- Стадия 2 (14:00)
    item_boon_might = { texture = "item_boon_might", values = { bonus_damage = 10 } },
    item_boon_bulwark = { texture = "item_boon_bulwark", values = { bonus_armor = 3 } },
    item_boon_warding = { texture = "item_boon_warding", values = { bonus_magic_resistance = 8 } },
    item_boon_tenacity = { texture = "item_boon_tenacity", values = { bonus_status_resistance = 8 } },

    -- Стадия 3 (21:00)
    item_boon_fury = { texture = "item_boon_fury", values = { bonus_attack_speed = 30 } },
    item_boon_reach = { texture = "item_boon_reach", values = { bonus_cast_range = 125 } },
    item_boon_vampirism = {
        texture = "item_boon_vampirism",
        kind = "choice",
        values = { lifesteal_hero_pct = 25, lifesteal_creep_pct = 5 },
    },
    item_boon_quickening = {
        texture = "item_boon_quickening",
        kind = "choice",
        values = { move_speed_pct = 30, duration = 3 },
    },

    -- Стадия 4 (28:00)
    item_boon_twin_charges = { texture = "item_boon_twin_charges", kind = "choice" },
    item_boon_haste = { texture = "item_boon_haste", values = { cooldown_reduction = 10 } },
    item_boon_renewal = { texture = "item_boon_renewal", values = { bonus_health_regen = 7, bonus_mana_regen = 2.5 } },
    item_boon_aegis = { texture = "item_boon_aegis", kind = "aegis", values = { duration = 60 } },

    -- Стадия 5 (35:00+)
    item_boon_aghanim = { texture = "item_boon_aghanim", kind = "scepter" },
    item_boon_titan = { texture = "item_boon_titan", values = { bonus_all_stats = 10 } },
    item_boon_resilience = { texture = "item_boon_resilience", values = { damage_reduction = 8 } },
    item_boon_colossus = { texture = "item_boon_colossus", values = { bonus_health = 350, bonus_mana = 350 } },

    -- С выбором способности: линза — стадия 3 (вместо дальности), Дедалус — стадия 4 (вместо обновления).
    item_boon_lens = { texture = "item_boon_lens", kind = "choice", values = { cast_range = 250 } },
    item_boon_daedalus = { texture = "item_boon_daedalus", kind = "choice", values = { crit_chance = 30, crit_bonus_pct = 150 } },
    -- Гривсы — стадия 3 вместо ярости.
    item_boon_greaves = { texture = "item_boon_greaves", kind = "choice" },
    item_boon_octarine = { texture = "item_boon_octarine", kind = "choice", values = { cooldown_reduction_pct = 15 } },
    -- Веномансер — стадия 3 вместо ускорения.
    item_boon_venomancer = { texture = "item_boon_venomancer", kind = "choice", values = { debuff_duration_pct = 100 } },
    -- Холи локет — стадия 2 вместо оберега.
    item_boon_holy_locket = { texture = "item_boon_holy_locket", kind = "choice", values = { heal_amp_pct = 15 } },
    -- Кайя — пул 4 вместо спешки.
    item_boon_kaya = { texture = "item_boon_kaya", kind = "choice", values = { mind_power_coefficient_pct = 50 } },
}

-- Ключ AbilityValues → свойство модификатора, имя функции и знак.
local VALUE_PROPERTIES = {
    bonus_strength = { "MODIFIER_PROPERTY_STATS_STRENGTH_BONUS", "GetModifierBonusStats_Strength" },
    bonus_agility = { "MODIFIER_PROPERTY_STATS_AGILITY_BONUS", "GetModifierBonusStats_Agility" },
    bonus_intellect = { "MODIFIER_PROPERTY_STATS_INTELLECT_BONUS", "GetModifierBonusStats_Intellect" },
    bonus_health = { "MODIFIER_PROPERTY_HEALTH_BONUS", "GetModifierHealthBonus" },
    bonus_mana = { "MODIFIER_PROPERTY_MANA_BONUS", "GetModifierManaBonus" },
    bonus_mana_regen = { "MODIFIER_PROPERTY_MANA_REGEN_CONSTANT", "GetModifierConstantManaRegen" },
    bonus_health_regen = { "MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT", "GetModifierConstantHealthRegen" },
    bonus_movement_speed = { "MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT", "GetModifierMoveSpeedBonus_Constant" },
    bonus_damage = { "MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE", "GetModifierPreAttack_BonusDamage" },
    bonus_armor = { "MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS", "GetModifierPhysicalArmorBonus" },
    bonus_magic_resistance = { "MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS", "GetModifierMagicalResistanceBonus" },
    bonus_attack_speed = { "MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT", "GetModifierAttackSpeedBonus_Constant" },
    -- 4-е поле true: значение считается по способности (params.ability), ульте и «Дай пять» — 0.
    bonus_cast_range = { "MODIFIER_PROPERTY_CAST_RANGE_BONUS_STACKING", "GetModifierCastRangeBonusStacking", 1, true },
    bonus_status_resistance = { "MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING", "GetModifierStatusResistanceStacking" },
    cooldown_reduction = { "MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE", "GetModifierPercentageCooldown", 1, true },
    damage_reduction = { "MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE", "GetModifierIncomingDamage_Percentage", -1 },
}

local TWIN = {
    item = "item_boon_twin_charges",
    modifier = "modifier_item_boon_twin_charges",
    max_charges = 2,
    cooldown_multiplier = 1.5, -- КД способности +50%: столько восстанавливается один заряд
    think = 0.05,
    cast_credit_time = 20, -- сколько ждать перезарядку, которая стартует не в момент каста (канал, отпускание)
}

-- События окна выбора способности (Content/panorama/layout/custom_game/boon_charges/).
local CHOICE_EVENTS = {
    open = "trinity_boon_charges_open",
    pick = "trinity_boon_charges_pick",
    result = "trinity_boon_charges_result",
    request = "trinity_boon_charges_request", -- клиент после загрузки: показать невыбранный бун снова
}

-- Порядок, в котором окно предлагает невыбранные буны героя.
local CHOICE_ORDER = {
    "item_boon_twin_charges",
    "item_boon_vampirism",
    "item_boon_quickening",
    "item_boon_lens",
    "item_boon_daedalus",
    "item_boon_greaves",
    "item_boon_octarine",
    "item_boon_venomancer",
    "item_boon_holy_locket",
    "item_boon_kaya",
}

-- Видимый модификатор «бун получен, способность не выбрана»: стаки — сколько таких бунов ждут выбора.
local function PendingModifierName(itemName)
    return "modifier_" .. itemName .. "_pending"
end

local SCEPTER_MODIFIER = "modifier_item_ultimate_scepter_consumed"
local AEGIS_MODIFIER = "modifier_aegis"
-- Свой Аегис: ванильный modifier_aegis без предмета-источника движок может не создать.
local TRINITY_AEGIS_MODIFIER = "modifier_trinity_aegis"
local AEGIS_REINCARNATE_TIME = 5
local QUICKENING_HASTE_MODIFIER = "modifier_item_boon_quickening_haste"

local ERROR_HERO_ONLY = "#dota_hud_error_caravan_boon_hero_only"
local ERROR_HAS_SCEPTER = "#dota_hud_error_caravan_boon_has_scepter"
local ERROR_HAS_AEGIS = "#dota_hud_error_caravan_boon_has_aegis"
local ERROR_NO_ABILITY = "#dota_hud_error_caravan_boon_no_ability"

local function Publish(name, value)
    _G[name] = value
    if getfenv then
        local env = getfenv(1)
        if env then
            env[name] = value
        end
    end
end

local function HasFlag(value, flag)
    value = tonumber(value) or 0
    flag = tonumber(flag) or 0
    if flag <= 0 then
        return false
    end
    return math.floor(value / flag) % 2 == 1
end

local function SafeCall(object, method, ...)
    if not object or not object[method] then
        return nil
    end
    local ok, result = pcall(object[method], object, ...)
    if ok then
        return result
    end
    return nil
end

-- ---------------------------------------------------------------- способности, на которые буны не действуют
-- Ультимейты (по AbilityType), «Дай пять» и способности, которые подменяют ульту или появляются
-- только на время её действия. Их не предлагают окна выбора, на них не действуют и общие буны
-- (спешка −КД, досягаемость +дальность).

local BOON_EXCLUDED_ABILITIES = {
    high_five_custom = true,
    dawnbreaker_solar_guardian_release_custom = true, -- R на время полёта молота Solar Guardian
}
local BOON_EXCLUDED_PREFIXES = {
    "largo_song_", -- песни Amphibian Rhapsody в Q/W/E на время ульты
}

local function IsBoonExcludedAbility(ability)
    if not ability or (ability.IsNull and ability:IsNull()) then
        return false
    end
    local name = SafeCall(ability, "GetAbilityName") or ""
    if BOON_EXCLUDED_ABILITIES[name] then
        return true
    end
    for _, prefix in ipairs(BOON_EXCLUDED_PREFIXES) do
        if string.find(name, prefix, 1, true) == 1 then
            return true
        end
    end
    -- Тип из движка; на случай, если константа или метод в этой VM другие, — ещё и строка из KV.
    local ultimateType = ABILITY_TYPE_ULTIMATE or DOTA_ABILITY_TYPE_ULTIMATE or 1
    if SafeCall(ability, "GetAbilityType") == ultimateType then
        return true
    end
    local kv = SafeCall(ability, "GetAbilityKeyValues")
    if type(kv) ~= "table" and name ~= "" and type(GetAbilityKeyValuesByName) == "function" then
        local ok, byName = pcall(GetAbilityKeyValuesByName, name)
        kv = ok and byName or nil
    end
    local kvType = type(kv) == "table" and kv.AbilityType or nil
    return kvType == "DOTA_ABILITY_TYPE_ULTIMATE" or kvType == "ABILITY_TYPE_ULTIMATE"
end

-- ---------------------------------------------------------------- выбор способности: какие подходят

local function FindChoiceModifier(hero, modifierName, ability)
    if not hero or hero:IsNull() or not ability then
        return nil
    end
    local list = hero:FindAllModifiersByName(modifierName) or {}
    for _, modifier in ipairs(list) do
        if modifier:GetAbility() == ability then
            return modifier
        end
    end
    return nil
end

local function HasNativeCharges(ability)
    local maxLevel = math.max(1, SafeCall(ability, "GetMaxLevel") or 1)
    for level = 0, maxLevel do
        local charges = SafeCall(ability, "GetMaxAbilityCharges", level)
        if charges and charges > 0 then
            return true
        end
    end
    return false
end

local function HasCooldown(ability)
    local maxLevel = math.max(1, SafeCall(ability, "GetMaxLevel") or 1)
    for level = 0, maxLevel - 1 do
        local cooldown = SafeCall(ability, "GetCooldown", level)
        if cooldown and cooldown > 0 then
            return true
        end
    end
    return false
end

-- Своя видимая способность героя: не предмет, не талант, не ультимейт, не «Дай пять».
local function IsHeroAbility(hero, ability)
    if not ability or ability:IsNull() then
        return false
    end
    if ability:IsItem() or ability:IsHidden() then
        return false
    end
    if SafeCall(ability, "GetCaster") ~= hero then
        return false
    end
    local name = ability:GetAbilityName() or ""
    if name == "" or string.find(name, "special_bonus_", 1, true) == 1 or name == "generic_hidden" then
        return false
    end
    -- Буны улучшают только не ультимативные способности (и не «Дай пять»).
    if IsBoonExcludedAbility(ability) then
        return false
    end
    local behavior = SafeCall(ability, "GetBehaviorInt") or SafeCall(ability, "GetBehavior") or 0
    return not HasFlag(behavior, DOTA_ABILITY_BEHAVIOR_HIDDEN)
end

-- Применяемая способность с перезарядкой: не пассивная и не toggle.
local function IsCastableWithCooldown(hero, ability)
    if not IsHeroAbility(hero, ability) then
        return false
    end
    local behavior = SafeCall(ability, "GetBehaviorInt") or SafeCall(ability, "GetBehavior") or 0
    if HasFlag(behavior, DOTA_ABILITY_BEHAVIOR_PASSIVE) or HasFlag(behavior, DOTA_ABILITY_BEHAVIOR_TOGGLE) then
        return false
    end
    return HasCooldown(ability)
end

-- Способность, у которой есть цель или точка и дальность применения > 0: ей есть что увеличивать.
local function IsTargetedWithRange(hero, ability)
    if not IsHeroAbility(hero, ability) then
        return false
    end
    local behavior = SafeCall(ability, "GetBehaviorInt") or SafeCall(ability, "GetBehavior") or 0
    if HasFlag(behavior, DOTA_ABILITY_BEHAVIOR_PASSIVE) or HasFlag(behavior, DOTA_ABILITY_BEHAVIOR_TOGGLE) then
        return false
    end
    if not HasFlag(behavior, DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) and not HasFlag(behavior, DOTA_ABILITY_BEHAVIOR_POINT) then
        return false
    end
    local origin = SafeCall(hero, "GetAbsOrigin")
    local range = SafeCall(ability, "GetCastRange", origin, nil) or 0
    return range > 0
end

-- ---------------------------------------------------------------- коэффициенты Силы магии
-- Коэффициент — любое значение AbilityValues с «mind_power» в имени, кроме флага affected_by_mind_power,
-- базовой Силы магии героя (base_mind_power) и значений, которые подсказка Силы магии сама пересчитывает
-- (цели правил CustomAbilityTooltips.MIND_POWER_RULES, например mind_power_damage_bonus у Flame Guard).
local MIND_POWER_EXCLUDED_KEYS = { affected_by_mind_power = true, base_mind_power = true }

local function IsMindPowerCoefficientKey(abilityName, key)
    if type(key) ~= "string" or not string.find(key, "mind_power", 1, true) or MIND_POWER_EXCLUDED_KEYS[key] then
        return false
    end
    local rules = CustomAbilityTooltips and CustomAbilityTooltips.MIND_POWER_RULES
    local abilityRules = rules and rules[abilityName]
    if abilityRules and abilityRules[key] ~= nil then
        return false
    end
    return true
end

local function MindPowerCoefficientKeys(ability)
    local keys = {}
    local name = ability and ability:GetAbilityName()
    if not name or type(GetAbilityKeyValuesByName) ~= "function" then
        return keys
    end
    local ok, kv = pcall(GetAbilityKeyValuesByName, name)
    local values = ok and type(kv) == "table" and kv.AbilityValues or nil
    if type(values) ~= "table" then
        return keys
    end
    for key in pairs(values) do
        if IsMindPowerCoefficientKey(name, key) then
            table.insert(keys, key)
        end
    end
    table.sort(keys)
    return keys
end

local function HasMindPowerCoefficient(hero, ability)
    return IsHeroAbility(hero, ability) and #MindPowerCoefficientKeys(ability) > 0
end

-- Буны с выбором способности: модификатор вешается на цель с ability = выбранная способность.
local CHOICE = {
    item_boon_twin_charges = {
        modifier = TWIN.modifier,
        eligible = function(hero, ability)
            return IsCastableWithCooldown(hero, ability) and not HasNativeCharges(ability)
        end,
    },
    item_boon_vampirism = {
        modifier = "modifier_item_boon_vampirism",
        -- Пассивные тоже: урон бывает и от пассивок.
        eligible = IsHeroAbility,
    },
    item_boon_quickening = {
        modifier = "modifier_item_boon_quickening",
        eligible = IsCastableWithCooldown,
    },
    item_boon_lens = {
        modifier = "modifier_item_boon_lens",
        eligible = IsTargetedWithRange,
    },
    item_boon_greaves = {
        modifier = "modifier_item_boon_greaves",
        -- Только с перезарядкой: она и ограничивает частоту развеивания.
        eligible = IsCastableWithCooldown,
    },
    item_boon_octarine = {
        modifier = "modifier_item_boon_octarine",
        eligible = IsCastableWithCooldown,
    },
    item_boon_kaya = {
        modifier = "modifier_item_boon_kaya",
        -- Только способности с коэффициентом Силы магии.
        eligible = HasMindPowerCoefficient,
    },
    item_boon_holy_locket = {
        modifier = "modifier_item_boon_holy_locket",
        -- Пассивные тоже: лечение бывает и от пассивок.
        eligible = IsHeroAbility,
    },
    item_boon_venomancer = {
        modifier = "modifier_item_boon_venomancer",
        -- Пассивные тоже: дебаффы бывают и от пассивок.
        eligible = IsHeroAbility,
    },
    item_boon_daedalus = {
        modifier = "modifier_item_boon_daedalus",
        -- Пассивные тоже: урон бывает и от пассивок.
        eligible = IsHeroAbility,
    },
}

-- Группы способностей, которые бун с выбором улучшает целиком: в окне — одна кнопка (первая способность
-- группы), модификатор вешается на каждую способность группы. Разрывы Shadow Fiend — три способности
-- с отдельными перезарядками, бун должен касаться всех трёх.
local CHOICE_GROUPS = {
    { "nevermore_shadowraze1_trinity", "nevermore_shadowraze2_trinity", "nevermore_shadowraze3_trinity" },
    { "nevermore_shadowraze1", "nevermore_shadowraze2", "nevermore_shadowraze3" },
}
local CHOICE_GROUP_OF = {}
for _, group in ipairs(CHOICE_GROUPS) do
    for _, name in ipairs(group) do
        CHOICE_GROUP_OF[name] = group
    end
end

-- Способности героя из группы ability (сама ability всегда первой); без группы — только она.
local function ChoiceGroupAbilities(hero, ability)
    local list = { ability }
    local group = ability and CHOICE_GROUP_OF[SafeCall(ability, "GetAbilityName") or ""]
    if not group or not hero or hero:IsNull() then
        return list
    end
    for _, name in ipairs(group) do
        local other = hero:FindAbilityByName(name)
        if other and other ~= ability and not other:IsNull() then
            table.insert(list, other)
        end
    end
    return list
end

-- Ключ группы, чтобы в окне была одна кнопка на группу.
local function ChoiceGroupKey(ability)
    local name = SafeCall(ability, "GetAbilityName") or ""
    local group = CHOICE_GROUP_OF[name]
    return group and group[1] or nil
end

local function IsChoiceEligible(itemName, hero, ability)
    local choice = CHOICE[itemName]
    if not choice or not choice.eligible(hero, ability) then
        return false
    end
    -- Бун на группе уже есть, если он висит хоть на одной её способности.
    for _, member in ipairs(ChoiceGroupAbilities(hero, ability)) do
        if FindChoiceModifier(hero, choice.modifier, member) ~= nil then
            return false
        end
    end
    return true
end

local function ChoiceCandidates(itemName, hero)
    local list = {}
    if not hero or hero:IsNull() or not CHOICE[itemName] then
        return list
    end
    local seenGroups = {}
    local count = hero:GetAbilityCount() or 0
    for index = 0, count - 1 do
        local ability = hero:GetAbilityByIndex(index)
        if IsChoiceEligible(itemName, hero, ability) then
            local key = ChoiceGroupKey(ability)
            if not key or not seenGroups[key] then
                if key then
                    seenGroups[key] = true
                end
                table.insert(list, ability)
            end
        end
    end
    return list
end

-- ---------------------------------------------------------------- предметы

-- Метод юнита, если он есть в этой VM. Фильтр каста идёт и на клиенте, а у клиентского юнита
-- нет части серверных методов (IsAlive и др.): без проверки — Script Runtime Error на каждый тик.
local function UnitCheck(unit, method, default)
    local fn = unit and unit[method]
    if type(fn) ~= "function" then
        return default
    end
    local ok, result = pcall(fn, unit)
    if not ok then
        return default
    end
    return result
end

local function IsValidBoonTarget(caster, target)
    if not caster or not target then
        return false
    end
    if UnitCheck(caster, "IsNull", false) or UnitCheck(target, "IsNull", false) then
        return false
    end
    if caster.caravanId then
        return false
    end
    if not UnitCheck(target, "IsRealHero", true) or UnitCheck(target, "IsIllusion", false) then
        return false
    end
    if not UnitCheck(target, "IsAlive", true) then
        return false
    end
    return UnitCheck(target, "GetTeamNumber", -1) == UnitCheck(caster, "GetTeamNumber", -2)
end

local function TargetHasModifier(target, name)
    if not target or type(target.HasModifier) ~= "function" then
        return false
    end
    local ok, result = pcall(target.HasModifier, target, name)
    return ok and result == true
end

-- Сколько таких бунов цель уже получила, но ещё не выбрала способность (только сервер).
local function PendingCount(target, itemName)
    if not target or type(target.FindModifierByName) ~= "function" then
        return 0
    end
    local pending = target:FindModifierByName(PendingModifierName(itemName))
    return pending and pending:GetStackCount() or 0
end

local function BoonLog(text)
    if IsServer() then
        print("[CaravanBoon] " .. text)
    end
end

local function UnitLabel(unit)
    if not unit then
        return "nil"
    end
    local name = UnitCheck(unit, "GetUnitName", "?")
    local index = UnitCheck(unit, "entindex", -1)
    return tostring(name) .. "#" .. tostring(index)
end

local function ItemCastFilter(self, target)
    self.boonError = ERROR_HERO_ONLY
    if self.caravanDisplay or self.trinityBoonConsumed then
        return UF_FAIL_CUSTOM
    end
    local caster = self:GetCaster()
    if not IsValidBoonTarget(caster, target) then
        BoonLog("filter: invalid target " .. UnitLabel(target) .. " for " .. tostring(self.boonName) .. " caster " .. UnitLabel(caster))
        return UF_FAIL_CUSTOM
    end

    local kind = self.boonDef.kind
    if kind == "scepter" and TargetHasModifier(target, SCEPTER_MODIFIER) then
        self.boonError = ERROR_HAS_SCEPTER
        return UF_FAIL_CUSTOM
    end
    if kind == "aegis" and (TargetHasModifier(target, AEGIS_MODIFIER) or TargetHasModifier(target, TRINITY_AEGIS_MODIFIER)) then
        self.boonError = ERROR_HAS_AEGIS
        return UF_FAIL_CUSTOM
    end
    if kind == "choice" and IsServer() and #ChoiceCandidates(self.boonName, target) <= PendingCount(target, self.boonName) then
        self.boonError = ERROR_NO_ABILITY
        return UF_FAIL_CUSTOM
    end

    return UnitFilter(
        target,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_NOT_ILLUSIONS + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        caster:GetTeamNumber()
    )
end

local function ItemCastError(self)
    return self.boonError or ERROR_HERO_ONLY
end

local function ApplyStatBoon(caster, target, def)
    local modifier = target:FindModifierByName(def.modifier)
    if modifier then
        modifier:IncrementStackCount()
    else
        -- Способность не передаём: иначе удаление предмета снимет модификатор.
        modifier = target:AddNewModifier(caster, nil, def.modifier, {})
        if not modifier then
            print("[CaravanBoon] Failed to apply " .. def.modifier)
            return false
        end
    end
    if target.CalculateStatBonus then
        target:CalculateStatBonus(true)
    end
    BoonLog("applied " .. def.modifier .. " x" .. tostring(modifier:GetStackCount()) .. " to " .. UnitLabel(target))
    return true
end

-- Окно выбора открывается у игрока, который управляет героем-целью: бун уже потрачен, выбор за ним.
local function OpenChoice(target, itemName)
    local playerID = target:GetPlayerOwnerID()
    local player = playerID ~= nil and playerID >= 0 and PlayerResource:GetPlayer(playerID) or nil
    if not player then
        return false
    end

    local abilities = {}
    for _, ability in ipairs(ChoiceCandidates(itemName, target)) do
        table.insert(abilities, ability:entindex())
    end
    if #abilities == 0 then
        return false
    end

    CustomGameEventManager:Send_ServerToPlayer(player, CHOICE_EVENTS.open, {
        boon = itemName,
        target = target:entindex(),
        abilities = abilities,
    })
    return true
end

-- Показать следующий невыбранный бун героя (после выбора, после перезагрузки UI).
local function OpenNextChoice(target)
    if not target or target:IsNull() then
        return
    end
    for _, itemName in ipairs(CHOICE_ORDER) do
        local pending = target:FindModifierByName(PendingModifierName(itemName))
        if pending and pending:GetStackCount() > 0 and OpenChoice(target, itemName) then
            return
        end
    end
end

local function AddPendingChoice(caster, target, itemName)
    local name = PendingModifierName(itemName)
    local pending = target:FindModifierByName(name)
    if pending then
        pending:IncrementStackCount()
    else
        pending = target:AddNewModifier(target, nil, name, {})
        if not pending then
            print("[CaravanBoon] Failed to apply " .. name)
            return false
        end
    end
    return true
end

-- Бун тратится на следующем кадре, а не прямо в OnSpellStart: удаление предмета посреди его же
-- применения (особенно из слота нейтрального предмета) роняло игру (access violation в server.dll).
-- До удаления предмет помечен trinityBoonConsumed и повторно не применяется.
-- Из нейтрального слота бун сначала перекладывается в свободный слот инвентаря, если такой есть.
local CONSUME_NEUTRAL_SLOT = DOTA_ITEM_NEUTRAL_SLOT or 16

local function FindItemSlot(unit, item)
    for slot = 0, 20 do
        if unit:GetItemInSlot(slot) == item then
            return slot
        end
    end
    return nil
end

local function ConsumeBoonItem(caster, item)
    item.trinityBoonConsumed = true
    local itemName = item.boonName
    Timers:CreateTimer(FrameTime(), function()
        if item:IsNull() then
            return
        end
        if not caster or caster:IsNull() then
            UTIL_Remove(item)
            return
        end
        local slot = FindItemSlot(caster, item)
        BoonLog("consume " .. tostring(itemName) .. " from slot " .. tostring(slot))
        if slot == CONSUME_NEUTRAL_SLOT then
            for free = 0, 8 do
                if not caster:GetItemInSlot(free) then
                    caster:SwapItems(slot, free)
                    slot = FindItemSlot(caster, item)
                    BoonLog("consume: moved to slot " .. tostring(slot))
                    break
                end
            end
        end
        if slot then
            caster:RemoveItem(item)
        else
            UTIL_Remove(item)
        end
        BoonLog("consumed " .. tostring(itemName))
    end)
end

local function ItemOnSpellStart(self)
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    local target = self:GetCursorTarget()
    local def = self.boonDef
    BoonLog("cast " .. tostring(self.boonName) .. " caster " .. UnitLabel(caster) .. " target " .. UnitLabel(target)
        .. " def " .. tostring(def ~= nil) .. " display " .. tostring(self.caravanDisplay == true))
    if not def or self.caravanDisplay or self.trinityBoonConsumed or not IsValidBoonTarget(caster, target) then
        BoonLog("cast rejected: invalid target or item")
        return
    end

    if def.kind == "choice" then
        -- Бун тратится сразу; цель получает видимый «ожидающий» модификатор и окно выбора способности.
        if not AddPendingChoice(caster, target, self.boonName) then
            return
        end
        ConsumeBoonItem(caster, self)
        OpenChoice(target, self.boonName)
        return
    end

    if def.kind == "scepter" then
        if target:HasModifier(SCEPTER_MODIFIER) then
            return
        end
        if not target:AddNewModifier(target, nil, SCEPTER_MODIFIER, {}) then
            print("[CaravanBoon] Failed to apply " .. SCEPTER_MODIFIER)
            return
        end
    elseif def.kind == "aegis" then
        if target:HasModifier(AEGIS_MODIFIER) or target:HasModifier(TRINITY_AEGIS_MODIFIER) then
            BoonLog("aegis rejected: target already has Aegis")
            return
        end
        local duration = def.values and def.values.duration or 60
        if not CaravanBoons.GiveAegis(target, duration) then
            return
        end
    elseif not ApplyStatBoon(caster, target, def) then
        return
    end

    ConsumeBoonItem(caster, self)
end

-- ---------------------------------------------------------------- Аегис
-- Сначала ванильный modifier_aegis; если движок его не создал (нет предмета-источника) —
-- свой modifier_trinity_aegis: та же иконка и таймер, при смерти герой возрождается на месте
-- через AEGIS_REINCARNATE_TIME сек. (MODIFIER_PROPERTY_REINCARNATION), после чего Аегис пропадает.

local modifier_trinity_aegis = class({})

function modifier_trinity_aegis:IsHidden() return false end
function modifier_trinity_aegis:IsPurgable() return false end
function modifier_trinity_aegis:IsPurgeException() return false end
function modifier_trinity_aegis:RemoveOnDeath() return false end
function modifier_trinity_aegis:IsDebuff() return false end
function modifier_trinity_aegis:GetTexture() return "item_aegis" end

function modifier_trinity_aegis:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_REINCARNATION,
        MODIFIER_EVENT_ON_DEATH,
    }
end

function modifier_trinity_aegis:ReincarnateTime()
    if self.used then
        return -1
    end
    return AEGIS_REINCARNATE_TIME
end

function modifier_trinity_aegis:OnDeath(params)
    if not IsServer() or params.unit ~= self:GetParent() or self.used then
        return
    end
    self.used = true
    -- Снимаем после возрождения: удаление в момент смерти может отменить возрождение.
    self:StartIntervalThink(0.25)
end

function modifier_trinity_aegis:OnIntervalThink()
    local parent = self:GetParent()
    if not parent or parent:IsNull() or parent:IsAlive() then
        self:Destroy()
    end
end

LinkLuaModifier(TRINITY_AEGIS_MODIFIER, "items/caravan_boons", LUA_MODIFIER_MOTION_NONE)
Publish(TRINITY_AEGIS_MODIFIER, modifier_trinity_aegis)

CaravanBoons = CaravanBoons or {}

function CaravanBoons.GiveAegis(hero, duration)
    if not hero or hero:IsNull() then
        return nil
    end
    duration = tonumber(duration) or 60
    hero:RemoveModifierByName(AEGIS_MODIFIER)
    hero:RemoveModifierByName(TRINITY_AEGIS_MODIFIER)

    local aegis = hero:AddNewModifier(hero, nil, AEGIS_MODIFIER, { duration = duration })
    local source = AEGIS_MODIFIER
    if not aegis then
        aegis = hero:AddNewModifier(hero, nil, TRINITY_AEGIS_MODIFIER, { duration = duration })
        source = TRINITY_AEGIS_MODIFIER
    end
    if not aegis then
        print("[CaravanBoon] Failed to apply Aegis to " .. tostring(hero:GetUnitName()))
        return nil
    end
    -- Ванильный Аегис может проигнорировать duration из kv.
    if aegis.SetDuration then
        aegis:SetDuration(duration, true)
    end
    EmitSoundOn("Aegis.Activate", hero)
    print("[CaravanBoon] Aegis " .. source .. " for " .. tostring(duration) .. "s on " .. tostring(hero:GetUnitName()))
    return aegis
end

-- ---------------------------------------------------------------- модификаторы стат-бунов

local function ModifierFalse()
    return false
end

local function ModifierGetTexture(self)
    return self.boonDef.texture
end

local function ModifierOnCreated(self)
    if IsServer() and self:GetStackCount() < 1 then
        self:SetStackCount(1)
    end
end

local function ModifierDeclareFunctions(self)
    return self.boonDef.properties
end

local function MakeValueGetter(key, sign, perAbility)
    return function(self, params)
        if perAbility and params and IsBoonExcludedAbility(params.ability) then
            return 0
        end
        return (self.boonDef.values[key] or 0) * sign * self:GetStackCount()
    end
end

local function BuildStatModifier(def)
    local modifier = class({})
    modifier.boonDef = def
    modifier.IsHidden = ModifierFalse
    modifier.IsPurgable = ModifierFalse
    modifier.IsPurgeException = ModifierFalse
    modifier.RemoveOnDeath = ModifierFalse
    modifier.IsDebuff = ModifierFalse
    modifier.GetTexture = ModifierGetTexture
    modifier.OnCreated = ModifierOnCreated
    modifier.DeclareFunctions = ModifierDeclareFunctions

    local values = {}
    for key, value in pairs(def.values or {}) do
        if key == "bonus_all_stats" then
            values.bonus_strength = (values.bonus_strength or 0) + value
            values.bonus_agility = (values.bonus_agility or 0) + value
            values.bonus_intellect = (values.bonus_intellect or 0) + value
        else
            values[key] = (values[key] or 0) + value
        end
    end
    def.values = values

    local properties = {}
    for key, value in pairs(values) do
        local spec = VALUE_PROPERTIES[key]
        if not spec then
            print("[CaravanBoon] Unknown boon value " .. tostring(key))
        elseif value ~= 0 then
            local property = _G[spec[1]]
            if property ~= nil then
                table.insert(properties, property)
                modifier[spec[2]] = MakeValueGetter(key, spec[3] or 1, spec[4])
            else
                print("[CaravanBoon] Missing modifier property " .. spec[1])
            end
        end
    end
    def.properties = properties
    return modifier
end

-- Иконка модификатора с выбором — иконка выбранной способности.
local function ChoiceTexture(self, fallback)
    local ability = self:GetAbility()
    if ability and ability.GetAbilityTextureName then
        local ok, texture = pcall(ability.GetAbilityTextureName, ability)
        if ok and texture and texture ~= "" then
            return texture
        end
    end
    return fallback
end

-- ---------------------------------------------------------------- модификатор двух зарядов
-- Один экземпляр на выбранную способность (MULTIPLE); способность — GetAbility() модификатора.
-- Стаки — текущие заряды. Свою перезарядку способность ставит как обычно; модификатор её снимает,
-- пока остался заряд, а при 0 зарядов держит КД до восстановления следующего заряда.

local modifier_item_boon_twin_charges = class({})

function modifier_item_boon_twin_charges:IsHidden() return false end
function modifier_item_boon_twin_charges:IsPurgable() return false end
function modifier_item_boon_twin_charges:IsPurgeException() return false end
function modifier_item_boon_twin_charges:RemoveOnDeath() return false end
function modifier_item_boon_twin_charges:IsDebuff() return false end

function modifier_item_boon_twin_charges:GetAttributes()
    return MODIFIER_ATTRIBUTE_MULTIPLE + MODIFIER_ATTRIBUTE_PERMANENT
end

function modifier_item_boon_twin_charges:GetTexture()
    local ability = self:GetAbility()
    if ability and ability.GetAbilityTextureName then
        local ok, texture = pcall(ability.GetAbilityTextureName, ability)
        if ok and texture and texture ~= "" then
            return texture
        end
    end
    return BOONS[TWIN.item].texture
end

function modifier_item_boon_twin_charges:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_ABILITY_FULLY_CAST,
        MODIFIER_PROPERTY_TOOLTIP,
    }
end

function modifier_item_boon_twin_charges:OnTooltip()
    return math.floor((TWIN.cooldown_multiplier - 1) * 100 + 0.5)
end

function modifier_item_boon_twin_charges:OnCreated()
    if not IsServer() then
        return
    end
    self.charges = TWIN.max_charges
    self.restoreAt = nil
    self.castCredit = 0
    self.castCreditUntil = 0
    self:SetStackCount(self.charges)
    self:StartIntervalThink(TWIN.think)
end

function modifier_item_boon_twin_charges:RestoreTime()
    local ability = self:GetAbility()
    local level = math.max(0, (ability:GetLevel() or 1) - 1)
    local cooldown = SafeCall(ability, "GetEffectiveCooldown", level) or SafeCall(ability, "GetCooldown", level) or 0
    return math.max(0.1, cooldown * TWIN.cooldown_multiplier)
end

function modifier_item_boon_twin_charges:SetCharges(value)
    self.charges = math.max(0, math.min(TWIN.max_charges, value))
    self:SetStackCount(self.charges)
end

function modifier_item_boon_twin_charges:SpendCharge(now)
    self:SetCharges(self.charges - 1)
    if not self.restoreAt then
        self.restoreAt = now + self:RestoreTime()
    end
end

-- Привести КД способности к числу зарядов: есть заряд — КД нет, нет зарядов — КД до следующего заряда.
function modifier_item_boon_twin_charges:SyncCooldown(now)
    local ability = self:GetAbility()
    if self.charges > 0 then
        if not ability:IsCooldownReady() then
            ability:EndCooldown()
        end
        return
    end
    local remaining = math.max(0, (self.restoreAt or now) - now)
    if remaining <= 0 then
        return
    end
    local current = ability:GetCooldownTimeRemaining() or 0
    if math.abs(current - remaining) > 0.1 then
        ability:EndCooldown()
        ability:StartCooldown(remaining)
    end
end

function modifier_item_boon_twin_charges:OnAbilityFullyCast(params)
    if not IsServer() or params.unit ~= self:GetParent() or params.ability ~= self:GetAbility() then
        return
    end
    local ability = self:GetAbility()
    local now = GameRules:GetGameTime()
    self:SpendCharge(now)
    if ability:IsCooldownReady() then
        -- Перезарядка начнётся позже (конец канала, отпускание): снимем её в OnIntervalThink.
        if self.charges > 0 then
            self.castCredit = self.castCredit + 1
            self.castCreditUntil = now + TWIN.cast_credit_time
        end
    end
    self:SyncCooldown(now)
end

function modifier_item_boon_twin_charges:OnIntervalThink()
    local ability = self:GetAbility()
    local parent = self:GetParent()
    if not ability or ability:IsNull() or not parent or parent:IsNull() then
        self:Destroy()
        return
    end

    local now = GameRules:GetGameTime()
    if self.castCredit > 0 and now > self.castCreditUntil then
        self.castCredit = 0
    end

    -- Восстановление заряда.
    if self.restoreAt and now >= self.restoreAt then
        self:SetCharges(self.charges + 1)
        if self.charges < TWIN.max_charges then
            self.restoreAt = now + self:RestoreTime()
        else
            self.restoreAt = nil
        end
        self:SyncCooldown(now)
        return
    end

    if self.charges > 0 then
        if not ability:IsCooldownReady() then
            -- Перезарядка началась без события каста (поздний старт или чужой эффект).
            if self.castCredit > 0 then
                self.castCredit = self.castCredit - 1
            else
                self:SpendCharge(now)
            end
            self:SyncCooldown(now)
        end
        return
    end

    -- Зарядов нет. Способность готова раньше заряда — её обновили (Refresher, Rearm): заряды полные.
    if ability:IsCooldownReady() and self.restoreAt and self.restoreAt - now > 0.5 then
        self:SetCharges(TWIN.max_charges)
        self.restoreAt = nil
        self.castCredit = 0
        return
    end
    self:SyncCooldown(now)
end



LinkLuaModifier(TWIN.modifier, "items/caravan_boons", LUA_MODIFIER_MOTION_NONE)
Publish(TWIN.modifier, modifier_item_boon_twin_charges)

-- ---------------------------------------------------------------- вампиризм выбранной способности
-- Урон выбранной способности (inflictor) по врагам лечит героя: по героям и иллюзиям — lifesteal_hero_pct,
-- по остальным юнитам — lifesteal_creep_pct от нанесённого урона. Постройки не считаются.

local VAMPIRISM = BOONS.item_boon_vampirism.values
local VAMPIRISM_PARTICLE = "particles/items3_fx/octarine_core_lifesteal.vpcf"

local modifier_item_boon_vampirism = class({})

function modifier_item_boon_vampirism:IsHidden() return false end
function modifier_item_boon_vampirism:IsPurgable() return false end
function modifier_item_boon_vampirism:IsPurgeException() return false end
function modifier_item_boon_vampirism:RemoveOnDeath() return false end
function modifier_item_boon_vampirism:IsDebuff() return false end

function modifier_item_boon_vampirism:GetAttributes()
    return MODIFIER_ATTRIBUTE_MULTIPLE + MODIFIER_ATTRIBUTE_PERMANENT
end

function modifier_item_boon_vampirism:GetTexture()
    return ChoiceTexture(self, BOONS.item_boon_vampirism.texture)
end

function modifier_item_boon_vampirism:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_TAKEDAMAGE,
        MODIFIER_PROPERTY_TOOLTIP,
        MODIFIER_PROPERTY_TOOLTIP2,
    }
end

function modifier_item_boon_vampirism:OnTooltip()
    return VAMPIRISM.lifesteal_hero_pct
end

function modifier_item_boon_vampirism:OnTooltip2()
    return VAMPIRISM.lifesteal_creep_pct
end

function modifier_item_boon_vampirism:OnTakeDamage(params)
    if not IsServer() then
        return
    end
    local parent = self:GetParent()
    local ability = self:GetAbility()
    if params.attacker ~= parent or not ability or params.inflictor ~= ability then
        return
    end
    local unit = params.unit
    if not unit or unit:IsNull() or unit == parent or unit:GetTeamNumber() == parent:GetTeamNumber() then
        return
    end
    if unit.IsBuilding and unit:IsBuilding() then
        return
    end
    if DOTA_DAMAGE_FLAG_NO_SPELL_LIFESTEAL and HasFlag(params.damage_flags, DOTA_DAMAGE_FLAG_NO_SPELL_LIFESTEAL) then
        return
    end
    if not parent:IsAlive() then
        return
    end

    local pct = unit:IsHero() and VAMPIRISM.lifesteal_hero_pct or VAMPIRISM.lifesteal_creep_pct
    local amount = (tonumber(params.damage) or 0) * pct / 100
    if amount <= 0 then
        return
    end

    if parent.HealWithParams then
        parent:HealWithParams(amount, ability, false, true, parent, true)
    else
        parent:Heal(amount, ability)
    end
    local fx = ParticleManager:CreateParticle(VAMPIRISM_PARTICLE, PATTACH_ABSORIGIN_FOLLOW, parent)
    ParticleManager:ReleaseParticleIndex(fx)
end

LinkLuaModifier("modifier_item_boon_vampirism", "items/caravan_boons", LUA_MODIFIER_MOTION_NONE)
Publish("modifier_item_boon_vampirism", modifier_item_boon_vampirism)

-- ---------------------------------------------------------------- ускорение от выбранной способности
-- Каждое применение выбранной способности даёт герою +move_speed_pct% скорости передвижения на duration сек.
-- Повторное применение обновляет длительность.

local QUICKENING = BOONS.item_boon_quickening.values
local QUICKENING_PARTICLE = "particles/items2_fx/phase_boots.vpcf"

local modifier_item_boon_quickening = class({})

function modifier_item_boon_quickening:IsHidden() return false end
function modifier_item_boon_quickening:IsPurgable() return false end
function modifier_item_boon_quickening:IsPurgeException() return false end
function modifier_item_boon_quickening:RemoveOnDeath() return false end
function modifier_item_boon_quickening:IsDebuff() return false end

function modifier_item_boon_quickening:GetAttributes()
    return MODIFIER_ATTRIBUTE_MULTIPLE + MODIFIER_ATTRIBUTE_PERMANENT
end

function modifier_item_boon_quickening:GetTexture()
    return ChoiceTexture(self, BOONS.item_boon_quickening.texture)
end

function modifier_item_boon_quickening:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_ABILITY_FULLY_CAST,
        MODIFIER_PROPERTY_TOOLTIP,
        MODIFIER_PROPERTY_TOOLTIP2,
    }
end

function modifier_item_boon_quickening:OnTooltip()
    return QUICKENING.move_speed_pct
end

function modifier_item_boon_quickening:OnTooltip2()
    return QUICKENING.duration
end

function modifier_item_boon_quickening:OnAbilityFullyCast(params)
    if not IsServer() then
        return
    end
    local parent = self:GetParent()
    if params.unit ~= parent or params.ability ~= self:GetAbility() then
        return
    end
    parent:AddNewModifier(parent, nil, QUICKENING_HASTE_MODIFIER, { duration = QUICKENING.duration })
end

LinkLuaModifier("modifier_item_boon_quickening", "items/caravan_boons", LUA_MODIFIER_MOTION_NONE)
Publish("modifier_item_boon_quickening", modifier_item_boon_quickening)

local modifier_item_boon_quickening_haste = class({})

function modifier_item_boon_quickening_haste:IsHidden() return false end
function modifier_item_boon_quickening_haste:IsPurgable() return true end
function modifier_item_boon_quickening_haste:IsDebuff() return false end

function modifier_item_boon_quickening_haste:GetTexture()
    return BOONS.item_boon_quickening.texture
end

function modifier_item_boon_quickening_haste:GetEffectName()
    return QUICKENING_PARTICLE
end

function modifier_item_boon_quickening_haste:GetEffectAttachType()
    return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_item_boon_quickening_haste:DeclareFunctions()
    return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE }
end

function modifier_item_boon_quickening_haste:GetModifierMoveSpeedBonus_Percentage()
    return QUICKENING.move_speed_pct
end

LinkLuaModifier(QUICKENING_HASTE_MODIFIER, "items/caravan_boons", LUA_MODIFIER_MOTION_NONE)
Publish(QUICKENING_HASTE_MODIFIER, modifier_item_boon_quickening_haste)

-- ---------------------------------------------------------------- линза выбранной способности
-- Дальность применения выбранной способности +cast_range (складывается с Aether Lens и др.).

local LENS = BOONS.item_boon_lens.values

local modifier_item_boon_lens = class({})

function modifier_item_boon_lens:IsHidden() return false end
function modifier_item_boon_lens:IsPurgable() return false end
function modifier_item_boon_lens:IsPurgeException() return false end
function modifier_item_boon_lens:RemoveOnDeath() return false end
function modifier_item_boon_lens:IsDebuff() return false end

function modifier_item_boon_lens:GetAttributes()
    return MODIFIER_ATTRIBUTE_MULTIPLE + MODIFIER_ATTRIBUTE_PERMANENT
end

function modifier_item_boon_lens:GetTexture()
    return ChoiceTexture(self, BOONS.item_boon_lens.texture)
end

function modifier_item_boon_lens:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_CAST_RANGE_BONUS_STACKING,
        MODIFIER_PROPERTY_TOOLTIP,
    }
end

function modifier_item_boon_lens:GetModifierCastRangeBonusStacking(params)
    if params and params.ability ~= nil and params.ability == self:GetAbility() then
        return LENS.cast_range
    end
    return 0
end

function modifier_item_boon_lens:OnTooltip()
    return LENS.cast_range
end

LinkLuaModifier("modifier_item_boon_lens", "items/caravan_boons", LUA_MODIFIER_MOTION_NONE)
Publish("modifier_item_boon_lens", modifier_item_boon_lens)

-- ---------------------------------------------------------------- Дедалус выбранной способности
-- Каждый экземпляр урона выбранной способности с шансом crit_chance% увеличен на crit_bonus_pct%.
-- Над целью — число критического урона, как у Daedalus.

local DAEDALUS = BOONS.item_boon_daedalus.values

local modifier_item_boon_daedalus = class({})

function modifier_item_boon_daedalus:IsHidden() return false end
function modifier_item_boon_daedalus:IsPurgable() return false end
function modifier_item_boon_daedalus:IsPurgeException() return false end
function modifier_item_boon_daedalus:RemoveOnDeath() return false end
function modifier_item_boon_daedalus:IsDebuff() return false end

function modifier_item_boon_daedalus:GetAttributes()
    return MODIFIER_ATTRIBUTE_MULTIPLE + MODIFIER_ATTRIBUTE_PERMANENT
end

function modifier_item_boon_daedalus:GetTexture()
    return ChoiceTexture(self, BOONS.item_boon_daedalus.texture)
end

function modifier_item_boon_daedalus:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_TOTALDAMAGEOUTGOING_PERCENTAGE,
        MODIFIER_EVENT_ON_TAKEDAMAGE,
        MODIFIER_PROPERTY_TOOLTIP,
        MODIFIER_PROPERTY_TOOLTIP2,
    }
end

function modifier_item_boon_daedalus:OnTooltip()
    return DAEDALUS.crit_chance
end

function modifier_item_boon_daedalus:OnTooltip2()
    return DAEDALUS.crit_bonus_pct
end

local function IsIgnoredDamage(flags)
    return (DOTA_DAMAGE_FLAG_REFLECTION and HasFlag(flags, DOTA_DAMAGE_FLAG_REFLECTION))
        or (DOTA_DAMAGE_FLAG_HPLOSS and HasFlag(flags, DOTA_DAMAGE_FLAG_HPLOSS))
end

function modifier_item_boon_daedalus:GetModifierTotalDamageOutgoing_Percentage(params)
    if not IsServer() or not params then
        return 0
    end
    local ability = self:GetAbility()
    if not ability or params.attacker ~= self:GetParent() or params.inflictor ~= ability then
        return 0
    end
    if IsIgnoredDamage(params.damage_flags) then
        return 0
    end
    if RandomInt(1, 100) > DAEDALUS.crit_chance then
        return 0
    end
    local target = params.target
    if target and not target:IsNull() then
        self.critTargets = self.critTargets or {}
        self.critTargets[target:entindex()] = GameRules:GetGameTime()
    end
    return DAEDALUS.crit_bonus_pct
end

function modifier_item_boon_daedalus:OnTakeDamage(params)
    if not IsServer() or not self.critTargets then
        return
    end
    if params.attacker ~= self:GetParent() or params.inflictor ~= self:GetAbility() then
        return
    end
    local unit = params.unit
    if not unit or unit:IsNull() then
        return
    end
    local index = unit:entindex()
    local time = self.critTargets[index]
    if time and GameRules:GetGameTime() - time < 0.05 then
        self.critTargets[index] = nil
        local damage = math.floor((tonumber(params.damage) or 0) + 0.5)
        if damage > 0 then
            SendOverheadEventMessage(nil, OVERHEAD_ALERT_CRITICAL, unit, damage, nil)
        end
    end
end

LinkLuaModifier("modifier_item_boon_daedalus", "items/caravan_boons", LUA_MODIFIER_MOTION_NONE)
Publish("modifier_item_boon_daedalus", modifier_item_boon_daedalus)

-- ---------------------------------------------------------------- гривсы выбранной способности
-- Каждое применение выбранной способности снимает с героя дебаффы обычным развеиванием
-- (как Guardian Greaves: оглушения и прочее, что требует сильного развеивания, не снимаются).

local GREAVES_PARTICLE = "particles/generic_gameplay/generic_purge.vpcf"

local modifier_item_boon_greaves = class({})

function modifier_item_boon_greaves:IsHidden() return false end
function modifier_item_boon_greaves:IsPurgable() return false end
function modifier_item_boon_greaves:IsPurgeException() return false end
function modifier_item_boon_greaves:RemoveOnDeath() return false end
function modifier_item_boon_greaves:IsDebuff() return false end

function modifier_item_boon_greaves:GetAttributes()
    return MODIFIER_ATTRIBUTE_MULTIPLE + MODIFIER_ATTRIBUTE_PERMANENT
end

function modifier_item_boon_greaves:GetTexture()
    return ChoiceTexture(self, BOONS.item_boon_greaves.texture)
end

function modifier_item_boon_greaves:DeclareFunctions()
    return { MODIFIER_EVENT_ON_ABILITY_FULLY_CAST }
end

function modifier_item_boon_greaves:OnAbilityFullyCast(params)
    if not IsServer() then
        return
    end
    local parent = self:GetParent()
    if params.unit ~= parent or params.ability ~= self:GetAbility() then
        return
    end
    -- Purge(положительные, отрицательные, только кадр, оглушения, исключения): обычное развеивание дебаффов.
    parent:Purge(false, true, false, false, false)
    local fx = ParticleManager:CreateParticle(GREAVES_PARTICLE, PATTACH_ABSORIGIN_FOLLOW, parent)
    ParticleManager:ReleaseParticleIndex(fx)
end

LinkLuaModifier("modifier_item_boon_greaves", "items/caravan_boons", LUA_MODIFIER_MOTION_NONE)
Publish("modifier_item_boon_greaves", modifier_item_boon_greaves)

-- ---------------------------------------------------------------- октарин выбранной способности
-- Перезарядка выбранной способности короче на cooldown_reduction_pct% (складывается с другими снижениями).

local OCTARINE = BOONS.item_boon_octarine.values

local modifier_item_boon_octarine = class({})

function modifier_item_boon_octarine:IsHidden() return false end
function modifier_item_boon_octarine:IsPurgable() return false end
function modifier_item_boon_octarine:IsPurgeException() return false end
function modifier_item_boon_octarine:RemoveOnDeath() return false end
function modifier_item_boon_octarine:IsDebuff() return false end

function modifier_item_boon_octarine:GetAttributes()
    return MODIFIER_ATTRIBUTE_MULTIPLE + MODIFIER_ATTRIBUTE_PERMANENT
end

function modifier_item_boon_octarine:GetTexture()
    return ChoiceTexture(self, BOONS.item_boon_octarine.texture)
end

function modifier_item_boon_octarine:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE,
        MODIFIER_PROPERTY_TOOLTIP,
    }
end

function modifier_item_boon_octarine:GetModifierPercentageCooldown(params)
    if params and params.ability ~= nil and params.ability == self:GetAbility() then
        return OCTARINE.cooldown_reduction_pct
    end
    return 0
end

function modifier_item_boon_octarine:OnTooltip()
    return OCTARINE.cooldown_reduction_pct
end

LinkLuaModifier("modifier_item_boon_octarine", "items/caravan_boons", LUA_MODIFIER_MOTION_NONE)
Publish("modifier_item_boon_octarine", modifier_item_boon_octarine)

-- ---------------------------------------------------------------- Веномансер выбранной способности
-- Модификаторы с конечной длительностью, которые выбранная способность вешает на врагов
-- (entindex_ability_const = эта способность, цель из другой команды), длятся на debuff_duration_pct% дольше.
-- Длительность меняет фильтр GameMode:ModifierGainedFilter → CaravanBoons.ModifierGainedFilter,
-- поэтому сопротивление эффектам цели применяется уже к удвоенной длительности.

local VENOMANCER = BOONS.item_boon_venomancer.values

CaravanBoons = CaravanBoons or {}
-- entindex способности → сколько бунов Веномансера на ней (обычно 1).
CaravanBoons.VenomAbilities = CaravanBoons.VenomAbilities or {}

local modifier_item_boon_venomancer = class({})

function modifier_item_boon_venomancer:IsHidden() return false end
function modifier_item_boon_venomancer:IsPurgable() return false end
function modifier_item_boon_venomancer:IsPurgeException() return false end
function modifier_item_boon_venomancer:RemoveOnDeath() return false end
function modifier_item_boon_venomancer:IsDebuff() return false end

function modifier_item_boon_venomancer:GetAttributes()
    return MODIFIER_ATTRIBUTE_MULTIPLE + MODIFIER_ATTRIBUTE_PERMANENT
end

function modifier_item_boon_venomancer:GetTexture()
    return ChoiceTexture(self, BOONS.item_boon_venomancer.texture)
end

function modifier_item_boon_venomancer:DeclareFunctions()
    return { MODIFIER_PROPERTY_TOOLTIP }
end

function modifier_item_boon_venomancer:OnTooltip()
    return VENOMANCER.debuff_duration_pct
end

function modifier_item_boon_venomancer:OnCreated()
    if not IsServer() then
        return
    end
    local ability = self:GetAbility()
    if ability then
        self.abilityIndex = ability:entindex()
        CaravanBoons.VenomAbilities[self.abilityIndex] = (CaravanBoons.VenomAbilities[self.abilityIndex] or 0) + 1
    end
end

function modifier_item_boon_venomancer:OnDestroy()
    if not IsServer() or not self.abilityIndex then
        return
    end
    local count = (CaravanBoons.VenomAbilities[self.abilityIndex] or 1) - 1
    CaravanBoons.VenomAbilities[self.abilityIndex] = count > 0 and count or nil
end

LinkLuaModifier("modifier_item_boon_venomancer", "items/caravan_boons", LUA_MODIFIER_MOTION_NONE)
Publish("modifier_item_boon_venomancer", modifier_item_boon_venomancer)

-- Вызывается из GameMode:ModifierGainedFilter. Меняет data.duration, ничего не запрещает.
function CaravanBoons.ModifierGainedFilter(data)
    local abilityIndex = data and data.entindex_ability_const
    if not abilityIndex or not CaravanBoons.VenomAbilities[abilityIndex] then
        return
    end
    local duration = tonumber(data.duration) or -1
    if duration <= 0 then
        return
    end
    local ability = EntIndexToHScript(abilityIndex)
    local parent = data.entindex_parent_const and EntIndexToHScript(data.entindex_parent_const) or nil
    if not ability or ability:IsNull() or not parent or parent:IsNull() then
        return
    end
    local owner = ability:GetCaster()
    if not owner or owner:IsNull() or parent:GetTeamNumber() == owner:GetTeamNumber() then
        return
    end
    data.duration = duration * (1 + VENOMANCER.debuff_duration_pct / 100)
end

-- ---------------------------------------------------------------- Холи локет выбранной способности
-- Лечение, у которого источник (inflictor) — выбранная способность, сильнее на heal_amp_pct%:
-- и себя, и союзников. Меняет GameMode:HealingFilter → CaravanBoons.HealingFilter.
-- Регенерация (модификаторы HEALTH_REGEN) через фильтр не идёт и не усиливается.

local HOLY_LOCKET = BOONS.item_boon_holy_locket.values

-- entindex способности → сколько бунов Холи локета на ней (обычно 1).
CaravanBoons.LocketAbilities = CaravanBoons.LocketAbilities or {}

local modifier_item_boon_holy_locket = class({})

function modifier_item_boon_holy_locket:IsHidden() return false end
function modifier_item_boon_holy_locket:IsPurgable() return false end
function modifier_item_boon_holy_locket:IsPurgeException() return false end
function modifier_item_boon_holy_locket:RemoveOnDeath() return false end
function modifier_item_boon_holy_locket:IsDebuff() return false end

function modifier_item_boon_holy_locket:GetAttributes()
    return MODIFIER_ATTRIBUTE_MULTIPLE + MODIFIER_ATTRIBUTE_PERMANENT
end

function modifier_item_boon_holy_locket:GetTexture()
    return ChoiceTexture(self, BOONS.item_boon_holy_locket.texture)
end

function modifier_item_boon_holy_locket:DeclareFunctions()
    return { MODIFIER_PROPERTY_TOOLTIP }
end

function modifier_item_boon_holy_locket:OnTooltip()
    return HOLY_LOCKET.heal_amp_pct
end

function modifier_item_boon_holy_locket:OnCreated()
    if not IsServer() then
        return
    end
    local ability = self:GetAbility()
    if ability then
        self.abilityIndex = ability:entindex()
        CaravanBoons.LocketAbilities[self.abilityIndex] = (CaravanBoons.LocketAbilities[self.abilityIndex] or 0) + 1
    end
end

function modifier_item_boon_holy_locket:OnDestroy()
    if not IsServer() or not self.abilityIndex then
        return
    end
    local count = (CaravanBoons.LocketAbilities[self.abilityIndex] or 1) - 1
    CaravanBoons.LocketAbilities[self.abilityIndex] = count > 0 and count or nil
end

LinkLuaModifier("modifier_item_boon_holy_locket", "items/caravan_boons", LUA_MODIFIER_MOTION_NONE)
Publish("modifier_item_boon_holy_locket", modifier_item_boon_holy_locket)

-- Вызывается из GameMode:HealingFilter. Меняет data.heal, ничего не запрещает.
function CaravanBoons.HealingFilter(data)
    local abilityIndex = data and data.entindex_inflictor_const
    if not abilityIndex or not CaravanBoons.LocketAbilities[abilityIndex] then
        return
    end
    local heal = tonumber(data.heal) or 0
    if heal <= 0 then
        return
    end
    local ability = EntIndexToHScript(abilityIndex)
    local target = data.entindex_target_const and EntIndexToHScript(data.entindex_target_const) or nil
    if not ability or ability:IsNull() or not target or target:IsNull() then
        return
    end
    local owner = ability:GetCaster()
    -- Только себя и союзников: лечение врагов (если способность так умеет) не усиливается.
    if not owner or owner:IsNull() or target:GetTeamNumber() ~= owner:GetTeamNumber() then
        return
    end
    data.heal = heal * (1 + HOLY_LOCKET.heal_amp_pct / 100)
end

-- ---------------------------------------------------------------- Кайя выбранной способности
-- Все коэффициенты Силы магии выбранной способности умножены на (1 + mind_power_coefficient_pct / 100).
-- Способности читают коэффициенты через GetSpecialValueFor, поэтому подмена значения работает и для урона,
-- и для строк коэффициентов в тултипе. Подсказку Силы магии (CustomAbilityTooltips) учитывает
-- CaravanBoons.MindPowerCoefficientFactor.

local KAYA = BOONS.item_boon_kaya.values
local KAYA_MODIFIER = "modifier_item_boon_kaya"

local modifier_item_boon_kaya = class({})

function modifier_item_boon_kaya:IsHidden() return false end
function modifier_item_boon_kaya:IsPurgable() return false end
function modifier_item_boon_kaya:IsPurgeException() return false end
function modifier_item_boon_kaya:RemoveOnDeath() return false end
function modifier_item_boon_kaya:IsDebuff() return false end

function modifier_item_boon_kaya:GetAttributes()
    return MODIFIER_ATTRIBUTE_MULTIPLE + MODIFIER_ATTRIBUTE_PERMANENT
end

function modifier_item_boon_kaya:GetTexture()
    return ChoiceTexture(self, BOONS.item_boon_kaya.texture)
end

function modifier_item_boon_kaya:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL,
        MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL_VALUE,
        MODIFIER_PROPERTY_TOOLTIP,
    }
end

function modifier_item_boon_kaya:OnTooltip()
    return KAYA.mind_power_coefficient_pct
end

local function KayaFactor()
    return 1 + KAYA.mind_power_coefficient_pct / 100
end

function modifier_item_boon_kaya:GetModifierOverrideAbilitySpecial(params)
    local ability = self:GetAbility()
    if not params or not ability or params.ability ~= ability then
        return 0
    end
    return IsMindPowerCoefficientKey(ability:GetAbilityName(), params.ability_special_value) and 1 or 0
end

function modifier_item_boon_kaya:GetModifierOverrideAbilitySpecialValue(params)
    local ability = self:GetAbility()
    if not params or not ability then
        return 0
    end
    local level = tonumber(params.ability_special_level)
    if level == nil or level < 0 then
        level = math.max(0, ability:GetLevel() - 1)
    end
    local base = ability:GetLevelSpecialValueNoOverride(params.ability_special_value, level) or 0
    return base * KayaFactor()
end

LinkLuaModifier(KAYA_MODIFIER, "items/caravan_boons", LUA_MODIFIER_MOTION_NONE)
Publish(KAYA_MODIFIER, modifier_item_boon_kaya)

-- ---------------------------------------------------------------- защита: бун с выбором на ульте / «Дай пять»
-- Выбор таких способностей запрещён (IsHeroAbility), но модификатор мог появиться раньше правила
-- или в обход окна. Тогда эффект ничего не делает, а на сервере модификатор снимается
-- и бун возвращается игроку на повторный выбор.

local CHOICE_GUARDED_HOOKS = {
    GetModifierPercentageCooldown = 0,
    GetModifierCastRangeBonusStacking = 0,
    GetModifierTotalDamageOutgoing_Percentage = 0,
    GetModifierOverrideAbilitySpecial = 0,
    OnAbilityFullyCast = false,
    OnTakeDamage = false,
    OnIntervalThink = false,
}

local function GuardChoiceModifier(itemName, modifierName)
    local modifier = _G[modifierName]
    if type(modifier) ~= "table" or modifier.trinityExcludedGuard then
        return
    end
    modifier.trinityExcludedGuard = true

    for hook, blocked in pairs(CHOICE_GUARDED_HOOKS) do
        local original = modifier[hook]
        if type(original) == "function" then
            modifier[hook] = function(self, ...)
                if IsBoonExcludedAbility(self:GetAbility()) then
                    if blocked == false then
                        return nil
                    end
                    return blocked
                end
                return original(self, ...)
            end
        end
    end

    local onCreated = modifier.OnCreated
    modifier.OnCreated = function(self, ...)
        if IsServer() and IsBoonExcludedAbility(self:GetAbility()) then
            local parent = self:GetParent()
            print("[CaravanBoon] " .. modifierName .. " on excluded ability "
                .. tostring(SafeCall(self:GetAbility(), "GetAbilityName")) .. ": removed, boon returned")
            self.trinityExcluded = true
            Timers:CreateTimer(FrameTime(), function()
                if not self:IsNull() then
                    self:Destroy()
                end
                if parent and not parent:IsNull() and AddPendingChoice(parent, parent, itemName) then
                    OpenNextChoice(parent)
                end
            end)
            return
        end
        if onCreated then
            return onCreated(self, ...)
        end
    end

    -- Если модификатор снят до регистрации (venomancer / holy_locket), OnDestroy ничего не вычитает лишнего.
    local onDestroy = modifier.OnDestroy
    if onDestroy then
        modifier.OnDestroy = function(self, ...)
            if self.trinityExcluded then
                return
            end
            return onDestroy(self, ...)
        end
    end
end

for itemName, choice in pairs(CHOICE) do
    GuardChoiceModifier(itemName, choice.modifier)
end

-- Множитель коэффициента Силы магии для подсказки (клиент и сервер): 1, если буна Кайи на способности нет.
function CaravanBoons.MindPowerCoefficientFactor(ability)
    if not ability or ability:IsNull() or not ability.GetCaster then
        return 1
    end
    local caster = ability:GetCaster()
    if not caster or caster:IsNull() or type(caster.FindAllModifiersByName) ~= "function" then
        return 1
    end
    local ok, list = pcall(caster.FindAllModifiersByName, caster, KAYA_MODIFIER)
    if not ok or type(list) ~= "table" then
        return 1
    end
    for _, modifier in ipairs(list) do
        if modifier:GetAbility() == ability then
            return KayaFactor()
        end
    end
    return 1
end

-- ---------------------------------------------------------------- выбор способности (Panorama → сервер)

CaravanBoons = CaravanBoons or {}
CaravanBoons.TWIN = TWIN
CaravanBoons.CHOICE = CHOICE
CaravanBoons.ChoiceCandidates = ChoiceCandidates
CaravanBoons.IsChoiceEligible = IsChoiceEligible
CaravanBoons.PARTICLES = { VAMPIRISM_PARTICLE, QUICKENING_PARTICLE, GREAVES_PARTICLE }

local function SendChoiceResult(playerID, ok, itemName, targetIndex)
    local player = PlayerResource:GetPlayer(playerID)
    if player then
        CustomGameEventManager:Send_ServerToPlayer(player, CHOICE_EVENTS.result, {
            ok = ok and 1 or 0,
            boon = itemName or "",
            target = targetIndex or -1,
        })
    end
end

function CaravanBoons.OnChoicePick(event)
    local playerID = event and event.PlayerID
    if playerID == nil then
        return
    end
    local itemName = tostring(event.boon or "")
    local targetIndex = tonumber(event.target) or -1
    local target = targetIndex >= 0 and EntIndexToHScript(targetIndex) or nil
    local ability = EntIndexToHScript(tonumber(event.ability) or -1)
    local choice = CHOICE[itemName]

    local ok = false
    if choice and target and not target:IsNull() and target:IsRealHero()
        and target:GetPlayerOwnerID() == playerID
        and ability and not ability:IsNull()
        and IsChoiceEligible(itemName, target, ability)
    then
        local pending = target:FindModifierByName(PendingModifierName(itemName))
        if pending and pending:GetStackCount() > 0 then
            -- Группа (разрывы SF): модификатор на каждую подходящую способность группы, бун тратится один.
            local modifier = target:AddNewModifier(target, ability, choice.modifier, {})
            if modifier then
                for _, member in ipairs(ChoiceGroupAbilities(target, ability)) do
                    if member ~= ability and choice.eligible(target, member)
                        and not FindChoiceModifier(target, choice.modifier, member)
                    then
                        target:AddNewModifier(target, member, choice.modifier, {})
                    end
                end
                if pending:GetStackCount() > 1 then
                    pending:DecrementStackCount()
                else
                    pending:Destroy()
                end
                ok = true
            else
                print("[CaravanBoon] Failed to apply " .. choice.modifier)
            end
        end
    end
    SendChoiceResult(playerID, ok, itemName, targetIndex)
    if ok then
        OpenNextChoice(target)
    end
end

function CaravanBoons.OnChoiceRequest(event)
    local playerID = event and event.PlayerID
    if playerID == nil or not PlayerResource:IsValidPlayerID(playerID) then
        return
    end
    OpenNextChoice(PlayerResource:GetSelectedHeroEntity(playerID))
end

if IsServer() and CustomGameEventManager then
    for _, key in ipairs({ "CaravanBoonsTwinListener", "CaravanBoonsRequestListener" }) do
        if _G[key] then
            CustomGameEventManager:UnregisterListener(_G[key])
            _G[key] = nil
        end
    end
    _G.CaravanBoonsTwinListener = CustomGameEventManager:RegisterListener(CHOICE_EVENTS.pick, function(_, event)
        CaravanBoons.OnChoicePick(event)
    end)
    _G.CaravanBoonsRequestListener = CustomGameEventManager:RegisterListener(CHOICE_EVENTS.request, function(_, event)
        CaravanBoons.OnChoiceRequest(event)
    end)
end

-- ---------------------------------------------------------------- «бун ждёт выбора способности»

local function MakePendingModifier(itemName)
    local modifier = class({})
    modifier.IsHidden = function() return false end
    modifier.IsPurgable = function() return false end
    modifier.IsPurgeException = function() return false end
    modifier.RemoveOnDeath = function() return false end
    modifier.IsDebuff = function() return false end
    modifier.GetTexture = function() return BOONS[itemName].texture end
    modifier.OnCreated = function(self)
        if IsServer() and self:GetStackCount() < 1 then
            self:SetStackCount(1)
        end
    end
    return modifier
end

for _, itemName in ipairs(CHOICE_ORDER) do
    local name = PendingModifierName(itemName)
    LinkLuaModifier(name, "items/caravan_boons", LUA_MODIFIER_MOTION_NONE)
    Publish(name, MakePendingModifier(itemName))
end

-- ---------------------------------------------------------------- регистрация

for itemName, def in pairs(BOONS) do
    if not def.kind then
        def.modifier = "modifier_" .. itemName
        LinkLuaModifier(def.modifier, "items/caravan_boons", LUA_MODIFIER_MOTION_NONE)
        Publish(def.modifier, BuildStatModifier(def))
    end

    local item = class({})
    item.boonDef = def
    item.boonName = itemName
    item.CastFilterResultTarget = ItemCastFilter
    item.GetCustomCastErrorTarget = ItemCastError
    item.OnSpellStart = ItemOnSpellStart
    Publish(itemName, item)
end

CaravanBoons.BOONS = BOONS
