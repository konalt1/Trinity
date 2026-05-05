LinkLuaModifier("modifier_chen_barrack", "abilities/chen/chen_barrack", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_barrack_producing", "abilities/chen/chen_barrack", LUA_MODIFIER_MOTION_NONE)

chen_barrack            = class({})
chen_barrack_spawn_t1   = class({})
chen_barrack_spawn_t2   = class({})
chen_barrack_spawn_t3   = class({})
chen_barrack_spawn_ancient = class({})
chen_barrack_self_destruct = class({})
modifier_chen_barrack          = class({})
modifier_chen_barrack_producing = class({})

local BARRACK_MODEL = "models/props_structures/good_barracks_melee001.vmdl"

-- ============================================================
-- FAMILY TABLE  (match patterns → tier pools)
-- ============================================================
local CHEN_BARRACK_FAMILIES = {
    -- Семья Сатиров
    {
        name  = "satyr",
        match = {"satyr"},
        units = {
            {"npc_dota_neutral_satyr_trickster"},      -- T1
            {"npc_dota_neutral_satyr_soulstealer"},    -- T2
            {"npc_dota_neutral_satyr_hellcaller"},     -- T3
            {"npc_dota_neutral_satyr_hellcaller"},     -- Ancient
        },
    },
    -- Семья Троллей/Огров
    {
        name  = "troll",
        match = {"dark_troll", "forest_troll", "ogre"},
        units = {
            {"npc_dota_neutral_dark_troll"},           -- T1
            {"npc_dota_neutral_ogre_magi"},            -- T2
            {"npc_dota_neutral_ogre_mauler"},          -- T3
            {"npc_dota_neutral_ogre_mauler"},          -- Ancient
        },
    },
    -- Семья Волков/Кобольдов
    {
        name  = "wolf",
        match = {"wolf", "kobold"},
        units = {
            {"npc_dota_neutral_kobold"},               -- T1
            {"npc_dota_neutral_giant_wolf"},           -- T2
            {"npc_dota_neutral_alpha_wolf"},           -- T3
            {"npc_dota_neutral_alpha_wolf"},           -- Ancient
        },
    },
    -- Семья Кентавров
    {
        name  = "centaur",
        match = {"centaur"},
        units = {
            {"npc_dota_neutral_centaur_outrunner"},    -- T1
            {"npc_dota_neutral_centaur_courser"},      -- T2
            {"npc_dota_neutral_centaur_khan"},         -- T3
            {"npc_dota_neutral_centaur_khan"},         -- Ancient
        },
    },
    -- Семья Големов
    {
        name  = "golem",
        match = {"mud_golem", "rock_golem", "clay_golem", "golem"},
        units = {
            {"npc_dota_neutral_mud_golem"},            -- T1
            {"npc_dota_neutral_rock_golem"},           -- T2
            {"npc_dota_neutral_rock_golem"},           -- T3
            {"npc_dota_neutral_granite_golem"},        -- Ancient
        },
    },
    -- Семья Гарпий
    {
        name  = "harpy",
        match = {"harpy"},
        units = {
            {"npc_dota_neutral_harpy_scout"},          -- T1
            {"npc_dota_neutral_harpy_storm"},          -- T2
            {"npc_dota_neutral_harpy_storm"},          -- T3
            {"npc_dota_neutral_harpy_storm"},          -- Ancient
        },
    },
    -- Семья Медведей
    {
        name  = "hellbear",
        match = {"polar_furbolg", "furbolg", "hellbear"},
        units = {
            {"npc_dota_neutral_polar_furbolg_champion"}, -- T1
            {"npc_dota_neutral_polar_furbolg_ursa_warrior"}, -- T2
            {"npc_dota_neutral_polar_furbolg_ursa_warrior"}, -- T3
            {"npc_dota_neutral_polar_furbolg_ursa_warrior"}, -- Ancient
        },
    },
    -- Семья Вилдвингов
    {
        name  = "wildkin",
        match = {"wildkin", "wildwing"},
        units = {
            {"npc_dota_neutral_wildkin"},              -- T1
            {"npc_dota_neutral_wildkin_ripper"},       -- T2
            {"npc_dota_neutral_enraged_wildkin"},      -- T3
            {"npc_dota_neutral_enraged_wildkin"},      -- Ancient
        },
    },
}

-- Tier pools for random selection (vanilla neutrals only)
local TIER_POOLS = {
    -- T1 крипы
    {
        "npc_dota_neutral_kobold",
        "npc_dota_neutral_satyr_trickster",
        "npc_dota_neutral_dark_troll",
        "npc_dota_neutral_centaur_outrunner",
        "npc_dota_neutral_harpy_scout",
        "npc_dota_neutral_wildkin",
        "npc_dota_neutral_polar_furbolg_champion",
        "npc_dota_neutral_mud_golem",
    },
    -- T2 крипы
    {
        "npc_dota_neutral_giant_wolf",
        "npc_dota_neutral_satyr_soulstealer",
        "npc_dota_neutral_ogre_magi",
        "npc_dota_neutral_centaur_courser",
        "npc_dota_neutral_harpy_storm",
        "npc_dota_neutral_wildkin_ripper",
        "npc_dota_neutral_polar_furbolg_ursa_warrior",
        "npc_dota_neutral_rock_golem",
    },
    -- T3 крипы
    {
        "npc_dota_neutral_alpha_wolf",
        "npc_dota_neutral_satyr_hellcaller",
        "npc_dota_neutral_ogre_mauler",
        "npc_dota_neutral_centaur_khan",
        "npc_dota_neutral_enraged_wildkin",
        "npc_dota_neutral_rock_golem",
    },
    -- Ancient крипы
    {
        "npc_dota_neutral_granite_golem",
        "npc_dota_neutral_black_dragon",
        "npc_dota_neutral_prowler_acolyte",
        "npc_dota_neutral_prowler_shaman",
    },
}

-- Generic fallback units per tier
local GENERIC_TIER_UNITS = TIER_POOLS

-- ============================================================
-- UTILITY FUNCTIONS
-- ============================================================
local function GetTalentValue(hero, talentName, valueName, fallback)
    if not hero or hero:IsNull() then return fallback or 0 end
    local talent = hero:FindAbilityByName(talentName)
    if not talent or talent:IsNull() or talent:GetLevel() <= 0 then return fallback or 0 end
    local value = valueName and talent:GetSpecialValueFor(valueName) or 0
    if value == 0 then value = talent:GetSpecialValueFor("value") end
    return value or fallback or 0
end

local function HasScepterUpgrade(hero)
    if not hero or hero:IsNull() then return false end
    if hero.HasScepter and hero:HasScepter() then return true end
    return hero:HasModifier("modifier_item_ultimate_scepter") or
           hero:HasModifier("modifier_item_ultimate_scepter_consumed")
end

local function IsChenBarrackUnit(unit)
    if not unit or unit:IsNull() then return false end
    return string.find(unit:GetUnitName() or "", "npc_chen_barrack", 1, true) == 1
end

local function IsChenTamedCreep(unit, caster)
    if not unit or unit:IsNull() or not unit:IsAlive() then return false end
    if not unit:IsCreep() or unit:IsHero() or unit:IsAncient() or unit:IsBuilding() then return false end
    if IsChenBarrackUnit(unit) then return false end
    return unit:GetTeamNumber() == caster:GetTeamNumber()
end

local function GetBarrackOwnerHero(unit)
    if not unit or unit:IsNull() then return nil end
    local owner = unit:GetOwnerEntity()
    if owner and not owner:IsNull() and owner:IsRealHero() then return owner end
    if unit.chen_barrack_owner_entindex then
        local h = EntIndexToHScript(unit.chen_barrack_owner_entindex)
        if h and not h:IsNull() and h:IsRealHero() then return h end
    end
    return nil
end

local function HasEnoughGold(hero, cost)
    if not hero or hero:IsNull() then return false end
    local pid = hero:GetPlayerOwnerID()
    if pid == nil or pid < 0 then return false end
    return PlayerResource:GetGold(pid) >= cost
end

local function GiveGoldToHero(hero, gold)
    if not hero or hero:IsNull() or gold <= 0 then return end
    hero:ModifyGold(gold, true, DOTA_ModifyGold_Unspecified)
    local player = hero:GetPlayerOwner()
    if player then SendOverheadEventMessage(player, OVERHEAD_ALERT_GOLD, hero, gold, nil) end
end

local function SpendGold(hero, cost)
    if cost <= 0 then return end
    hero:ModifyGold(-cost, false, DOTA_ModifyGold_Unspecified)
end

local function LevelUnitAbilities(unit)
    local count = (unit and unit.GetAbilityCount) and unit:GetAbilityCount() or 6
    for slot = 0, count - 1 do
        local ab = unit:GetAbilityByIndex(slot)
        if ab and not ab:IsNull() and ab:GetLevel() == 0 then ab:SetLevel(1) end
    end
end

local function GetFamilyByUnitName(unitName)
    if not unitName or unitName == "" then return nil end
    for _, family in ipairs(CHEN_BARRACK_FAMILIES) do
        for _, pattern in ipairs(family.match) do
            if string.find(unitName, pattern, 1, true) then return family end
        end
    end
    return nil
end

-- Returns max tier available: 1-3 by ult level, 4 with scepter
local function GetBarrackMaxTier(barrack)
    local owner = GetBarrackOwnerHero(barrack)
    if not owner then return 1 end
    local ult = owner:FindAbilityByName("chen_barrack")
    if not ult or ult:IsNull() then return 1 end
    local lv = ult:GetLevel()
    if lv <= 0 then return 1 end
    if HasScepterUpgrade(owner) then return 4 end
    return lv
end

local function GetBarrackMaxBarracks(caster)
    local ult = caster:FindAbilityByName("chen_barrack")
    if not ult or ult:IsNull() then return 1 end
    local lv = ult:GetLevel()
    if lv <= 0 then return 1 end
    if HasScepterUpgrade(caster) then return 4 end
    return lv
end

local function GetUnitForTier(barrack, tier)
    local family = GetFamilyByUnitName(barrack.chen_source_unit_name or "")
    if family and family.units[tier] and #family.units[tier] > 0 then
        -- Выбираем рандомного юнита из семьи
        return family.units[tier][RandomInt(1, #family.units[tier])]
    end
    -- Fallback: рандомный юнит из общего пула
    local pool = TIER_POOLS[tier]
    if pool and #pool > 0 then
        return pool[RandomInt(1, #pool)]
    end
    return "npc_dota_neutral_kobold"
end

-- ============================================================
-- PRODUCTION SYSTEM
-- ============================================================
local function InitBarrackState(barrack)
    barrack.chen_production_queue    = barrack.chen_production_queue  or {}
    barrack.chen_reserved_gold       = barrack.chen_reserved_gold     or 0
    barrack.chen_production_active   = barrack.chen_production_active or false
    barrack.chen_is_destroyed        = barrack.chen_is_destroyed      or false
end

local function GetBarrackQueuedCount(barrack)
    InitBarrackState(barrack)
    return #barrack.chen_production_queue + (barrack.chen_production_active and 1 or 0)
end

local function RefundReservedGold(barrack)
    InitBarrackState(barrack)
    local gold = math.floor(barrack.chen_reserved_gold or 0)
    if gold <= 0 then return end
    barrack.chen_reserved_gold = 0
    local owner = GetBarrackOwnerHero(barrack)
    if not owner then return end

    local recipients = {}
    for pid = 0, (DOTA_MAX_PLAYERS or 24) - 1 do
        if PlayerResource:IsValidPlayerID(pid) and
           PlayerResource:GetTeam(pid) == owner:GetTeamNumber() then
            local h = PlayerResource:GetSelectedHeroEntity(pid)
            if h and not h:IsNull() then table.insert(recipients, h) end
        end
    end
    if #recipients == 0 then GiveGoldToHero(owner, gold); return end

    local share     = math.floor(gold / #recipients)
    local remainder = gold - share * #recipients
    for i, h in ipairs(recipients) do
        GiveGoldToHero(h, share + (i == 1 and remainder or 0))
    end
end

local function CompleteProduction(barrack, item)
    if not barrack or barrack:IsNull() or not barrack:IsAlive() or barrack.chen_is_destroyed then return end
    local owner = GetBarrackOwnerHero(barrack)
    if not owner then return end

    local pid      = owner:GetPlayerOwnerID()
    local team     = owner:GetTeamNumber()
    local spawnPos = barrack:GetAbsOrigin() + barrack:GetForwardVector() * (item.spawn_distance or 200) + RandomVector(80)

    local summon
    for _, unitName in ipairs({ item.unit_name, item.fallback_unit_name }) do
        if unitName and unitName ~= "" then
            summon = CreateUnitByName(unitName, spawnPos, true, owner, owner, team)
            if summon then break end
        end
    end

    if not summon then
        GiveGoldToHero(owner, item.gold_cost or 0)
        barrack.chen_reserved_gold = math.max(0, (barrack.chen_reserved_gold or 0) - (item.gold_cost or 0))
        return
    end

    summon:SetOwner(owner)
    summon:SetControllableByPlayer(pid, true)
    if summon.SetPlayerID then summon:SetPlayerID(pid) end
    summon.chen_barrack_spawned  = true
    summon.chen_owner_entindex   = owner:entindex()
    LevelUnitAbilities(summon)
    FindClearSpaceForUnit(summon, spawnPos, true)
    summon:Stop()

    barrack.chen_reserved_gold = math.max(0, (barrack.chen_reserved_gold or 0) - (item.gold_cost or 0))
    EmitSoundOn("Hero_Chen.TeleportLoop", summon)
end

local StartNextProduction
StartNextProduction = function(barrack)
    if not barrack or barrack:IsNull() or not barrack:IsAlive() or barrack.chen_is_destroyed then return end
    InitBarrackState(barrack)
    if barrack.chen_production_active then return end

    local item = table.remove(barrack.chen_production_queue, 1)
    if not item then return end

    barrack.chen_production_active = true
    barrack.chen_current_order     = item
    local prodTime = tonumber(item.production_time) or 10
    barrack:AddNewModifier(barrack, nil, "modifier_chen_barrack_producing",
        { duration = prodTime, production_time = prodTime })

    Timers:CreateTimer(item.production_time or 1, function()
        if barrack and not barrack:IsNull() and barrack:IsAlive() and not barrack.chen_is_destroyed then
            CompleteProduction(barrack, item)
            barrack.chen_production_active = false
            barrack.chen_current_order     = nil
            StartNextProduction(barrack)
        end
    end)
end

-- ============================================================
-- SHARED SPAWN HELPERS
-- ============================================================
local function BarrackSpawnCastFilter(self, tier)
    local barrack = self:GetCaster()
    local owner   = GetBarrackOwnerHero(barrack)
    if not owner or owner:IsNull() then return UF_FAIL_CUSTOM end
    if tier > GetBarrackMaxTier(barrack)   then return UF_FAIL_CUSTOM end
    InitBarrackState(barrack)
    if GetBarrackQueuedCount(barrack) >= 5 then return UF_FAIL_CUSTOM end
    local cost = math.max(0, self:GetSpecialValueFor("gold_cost") -
        GetTalentValue(owner, "special_bonus_unique_custom_chen_8", "gold_cost_reduction", 0))
    if not HasEnoughGold(owner, cost) then return UF_FAIL_CUSTOM end
    return UF_SUCCESS
end

local function BarrackSpawnCastError(self, tier)
    local barrack = self:GetCaster()
    local owner   = GetBarrackOwnerHero(barrack)
    if not owner or owner:IsNull()        then return "#dota_hud_error_chen_barrack_no_owner"    end
    if tier > GetBarrackMaxTier(barrack)  then return "#dota_hud_error_chen_barrack_tier_locked" end
    InitBarrackState(barrack)
    if GetBarrackQueuedCount(barrack) >= 5 then return "#dota_hud_error_chen_barrack_queue_full" end
    local cost = math.max(0, self:GetSpecialValueFor("gold_cost") -
        GetTalentValue(owner, "special_bonus_unique_custom_chen_8", "gold_cost_reduction", 0))
    if not HasEnoughGold(owner, cost) then return "#dota_hud_error_not_enough_gold" end
    return ""
end

local function QueueBarrackTier(self, tier)
    if not IsServer() then return end
    local barrack = self:GetCaster()
    local owner   = GetBarrackOwnerHero(barrack)
    if not owner then return end
    if tier > GetBarrackMaxTier(barrack) then return end

    local cost = self:GetSpecialValueFor("gold_cost")
    cost = math.max(0, cost - GetTalentValue(owner, "special_bonus_unique_custom_chen_8", "gold_cost_reduction", 0))
    if not HasEnoughGold(owner, cost) then return end

    InitBarrackState(barrack)
    if GetBarrackQueuedCount(barrack) >= 5 then return end

    local prodTime = self:GetSpecialValueFor("production_time")
    prodTime = math.max(1, prodTime - GetTalentValue(owner, "special_bonus_unique_custom_chen_8", "production_time_reduction", 0))

    SpendGold(owner, cost)
    barrack.chen_reserved_gold = (barrack.chen_reserved_gold or 0) + cost

    -- Выбираем рандомного юнита из пула
    local pool = TIER_POOLS[tier]
    local unitName = "npc_dota_neutral_kobold"
    if pool and #pool > 0 then
        unitName = pool[RandomInt(1, #pool)]
    end

    table.insert(barrack.chen_production_queue, {
        unit_name         = unitName,
        fallback_unit_name = unitName,
        gold_cost         = cost,
        production_time   = prodTime,
        spawn_distance    = self:GetSpecialValueFor("spawn_distance"),
    })

    EmitSoundOn("General.Buy", barrack)
    StartNextProduction(barrack)
end

-- ============================================================
-- CHEN_BARRACK  (hero ultimate — target tamed creep)
-- ============================================================
function chen_barrack:CastFilterResultTarget(target)
    return IsChenTamedCreep(target, self:GetCaster()) and UF_SUCCESS or UF_FAIL_CUSTOM
end
function chen_barrack:GetCustomCastErrorTarget()
    return "#dota_hud_error_chen_barrack_invalid_target"
end

function chen_barrack:OnSpellStart()
    if not IsServer() then return end
    local caster = self:GetCaster()
    local target = self:GetCursorTarget()
    if not IsChenTamedCreep(target, caster) then return end

    local team = caster:GetTeamNumber()

    -- Find owned barracks
    local allUnits = FindUnitsInRadius(team, caster:GetAbsOrigin(), nil, FIND_UNITS_EVERYWHERE,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_ALL, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
    local existing = {}
    for _, u in pairs(allUnits) do
        if u and not u:IsNull() and u:IsAlive() and u:GetUnitName() == "npc_chen_barrack" then
            if u.chen_barrack_owner_entindex == caster:entindex() then
                table.insert(existing, u)
            end
        end
    end
    table.sort(existing, function(a, b)
        return (a.chen_barrack_created_time or 0) < (b.chen_barrack_created_time or 0)
    end)

    local maxBarracks = GetBarrackMaxBarracks(caster)
    while #existing >= maxBarracks do
        local oldest = table.remove(existing, 1)
        if oldest and not oldest:IsNull() then
            oldest.chen_is_destroyed = true
            RefundReservedGold(oldest)
            oldest:Kill(nil, oldest)
        end
    end

    -- Capture creep data
    local origin         = target:GetAbsOrigin()
    local forward        = target:GetForwardVector()
    local pid            = caster:GetPlayerOwnerID()
    local targetUnitName = target:GetUnitName()
    local targetMaxHP    = math.max(target:GetMaxHealth(), target:GetHealth())
    local bonusHealth    = self:GetSpecialValueFor("bonus_health")
    local minHealth      = self:GetSpecialValueFor("minimum_barrack_health")
    local family         = GetFamilyByUnitName(targetUnitName)

    target.chen_skip_bounty_share = true
    UTIL_Remove(target)

    local barrack = CreateUnitByName("npc_chen_barrack", origin, true, caster, caster, team)
    if not barrack then return end

    barrack.chen_barrack_owner_entindex = caster:entindex()
    barrack.chen_barrack_created_time   = GameRules:GetGameTime()
    barrack.chen_source_unit_name       = targetUnitName
    barrack.chen_family_name            = family and family.name or "generic"
    barrack:SetOwner(caster)
    barrack:SetControllableByPlayer(pid, true)
    if barrack.SetPlayerID then barrack:SetPlayerID(pid) end
    barrack:SetForwardVector(forward)
    barrack:SetMoveCapability(DOTA_UNIT_CAP_MOVE_NONE)

    local hp = math.max(minHealth, targetMaxHP + bonusHealth)
    hp = hp + GetTalentValue(caster, "special_bonus_unique_custom_chen_7", "barrack_health", 0)
    barrack:SetBaseMaxHealth(hp)
    barrack:SetMaxHealth(hp)
    barrack:SetHealth(hp)

    barrack:SetModel(BARRACK_MODEL)
    barrack:SetOriginalModel(BARRACK_MODEL)

    InitBarrackState(barrack)
    LevelUnitAbilities(barrack)
    barrack:AddNewModifier(caster, self, "modifier_chen_barrack", {})

    -- VFX
    local p1 = ParticleManager:CreateParticle("particles/econ/events/ti6/hero_transform_dust.vpcf", PATTACH_ABSORIGIN, barrack)
    ParticleManager:SetParticleControl(p1, 0, origin)
    ParticleManager:SetParticleControl(p1, 1, Vector(200, 200, 200))
    ParticleManager:ReleaseParticleIndex(p1)
    local p2 = ParticleManager:CreateParticle("particles/items_fx/aegis_respawn.vpcf", PATTACH_ABSORIGIN, barrack)
    ParticleManager:SetParticleControl(p2, 0, origin)
    ParticleManager:SetParticleControl(p2, 1, origin + Vector(0, 0, 500))
    ParticleManager:ReleaseParticleIndex(p2)
    EmitSoundOn("Hero_Chen.HolyPersuasionEnemy", barrack)
end

-- ============================================================
-- SPAWN TIER 1
-- ============================================================
function chen_barrack_spawn_t1:CastFilterResult() return BarrackSpawnCastFilter(self, 1) end
function chen_barrack_spawn_t1:GetCustomCastError() return BarrackSpawnCastError(self, 1) end
function chen_barrack_spawn_t1:OnSpellStart() QueueBarrackTier(self, 1) end

-- ============================================================
-- SPAWN TIER 2
-- ============================================================
function chen_barrack_spawn_t2:CastFilterResult() return BarrackSpawnCastFilter(self, 2) end
function chen_barrack_spawn_t2:GetCustomCastError() return BarrackSpawnCastError(self, 2) end
function chen_barrack_spawn_t2:OnSpellStart() QueueBarrackTier(self, 2) end

-- ============================================================
-- SPAWN TIER 3
-- ============================================================
function chen_barrack_spawn_t3:CastFilterResult() return BarrackSpawnCastFilter(self, 3) end
function chen_barrack_spawn_t3:GetCustomCastError() return BarrackSpawnCastError(self, 3) end
function chen_barrack_spawn_t3:OnSpellStart() QueueBarrackTier(self, 3) end

-- ============================================================
-- SPAWN ANCIENT (scepter)
-- ============================================================
function chen_barrack_spawn_ancient:CastFilterResult() return BarrackSpawnCastFilter(self, 4) end
function chen_barrack_spawn_ancient:GetCustomCastError() return BarrackSpawnCastError(self, 4) end
function chen_barrack_spawn_ancient:OnSpellStart() QueueBarrackTier(self, 4) end

-- ============================================================
-- SELF DESTRUCT
-- ============================================================
function chen_barrack_self_destruct:CastFilterResult()
    local b = self:GetCaster()
    if not IsChenBarrackUnit(b) or not b:IsAlive() then return UF_FAIL_CUSTOM end
    return UF_SUCCESS
end
function chen_barrack_self_destruct:GetCustomCastError()
    return "#dota_hud_error_chen_barrack_self_destruct_invalid"
end
function chen_barrack_self_destruct:OnSpellStart()
    if not IsServer() then return end
    local b = self:GetCaster()
    if not IsChenBarrackUnit(b) or not b:IsAlive() then return end

    local p = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_techies/techies_remote_mines_detonate.vpcf", PATTACH_ABSORIGIN, b)
    ParticleManager:SetParticleControl(p, 0, b:GetAbsOrigin())
    ParticleManager:ReleaseParticleIndex(p)
    EmitSoundOn("Hero_Techies.RemoteMine.Detonate", b)

    b.chen_is_destroyed = true
    RefundReservedGold(b)

    local radius = self:GetSpecialValueFor("radius")
    local damage = self:GetSpecialValueFor("damage")
    local nearby = FindUnitsInRadius(b:GetTeamNumber(), b:GetAbsOrigin(), nil, radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
    for _, u in pairs(nearby) do
        if u and not u:IsNull() and u:IsAlive() then
            ApplyDamage({ victim = u, attacker = b, damage = damage,
                damage_type = DAMAGE_TYPE_MAGICAL, ability = self })
        end
    end
    b:Kill(self, b)
end

-- ============================================================
-- MODIFIER: modifier_chen_barrack  (death → refund)
-- ============================================================
function modifier_chen_barrack:IsHidden() return true end
function modifier_chen_barrack:IsPurgable() return false end
function modifier_chen_barrack:RemoveOnDeath() return true end
function modifier_chen_barrack:DeclareFunctions() return { MODIFIER_EVENT_ON_DEATH } end
function modifier_chen_barrack:OnDeath(params)
    if not IsServer() then return end
    local parent = self:GetParent()
    if not params.unit or params.unit ~= parent then return end
    parent.chen_is_destroyed = true
    RefundReservedGold(parent)
end

-- ============================================================
-- MODIFIER: modifier_chen_barrack_producing  (production timer)
-- ============================================================
function modifier_chen_barrack_producing:IsHidden() return false end
function modifier_chen_barrack_producing:IsDebuff() return false end
function modifier_chen_barrack_producing:IsPurgable() return false end
function modifier_chen_barrack_producing:GetEffectName()
    return "particles/econ/events/ti6/hero_transform_dust.vpcf"
end
function modifier_chen_barrack_producing:GetEffectAttachType()
    return PATTACH_ABSORIGIN_FOLLOW
end
function modifier_chen_barrack_producing:OnCreated(kv)
    if IsServer() then EmitSoundOn("Building.Construction", self:GetParent()) end
    if kv and kv.production_time then
        self:SetDuration(tonumber(kv.production_time) or 10, false)
    end
end
function modifier_chen_barrack_producing:OnDestroy()
    if IsServer() then EmitSoundOn("Building.Complete", self:GetParent()) end
end