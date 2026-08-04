MortimerLevelScaling = MortimerLevelScaling or {}

LinkLuaModifier(
    "modifier_mortimer_level_scaling",
    "map_modifications/Bosses/mortimer_level_scaling",
    LUA_MODIFIER_MOTION_NONE
)

local CONFIG = {
    health = { base = 3500, per_level = 3000 },
    armor = { base = 20, per_level = 5 },
    attack_damage_min = { base = 200, per_level = 100 },
    attack_damage_max = { base = 200, per_level = 100 },
    cookie_damage_pct_per_level = 25,
    gobble_spit_distance_per_level = 300,
    kisses_projectiles_per_level = 4,
    kisses_duration_per_level = 3,
    kisses_impact_damage_per_level = 100,
    kisses_burn_damage_per_level = 20,
    kisses_burn_duration_per_level = 0.5,
}

MortimerLevelScaling.CONFIG = CONFIG

local function NormalizeLevel(level)
    return math.max(1, math.floor(tonumber(level) or 1))
end

local function GetLevelBonus(unit)
    return MortimerLevelScaling:GetLevel(unit) - 1
end

local function ScaleFromBase(base, perLevel, unit)
    return base + perLevel * GetLevelBonus(unit)
end

function MortimerLevelScaling:GetLevel(unit)
    if not unit or unit:IsNull() then
        return 1
    end

    return NormalizeLevel(unit.mortimerLevel or unit.spawnNumber)
end

function MortimerLevelScaling:SetUnitLevel(unit, level)
    if not unit or unit:IsNull() then
        return
    end

    level = NormalizeLevel(level)
    unit.mortimerLevel = level

    local currentLevel = unit.GetLevel and unit:GetLevel() or 1
    if unit.CreatureLevelUp and currentLevel < level then
        unit:CreatureLevelUp(level - currentLevel)
    end
end

function MortimerLevelScaling:ApplyToBoss(boss, level)
    if not IsServer() or not boss or boss:IsNull() then
        return
    end

    self:SetUnitLevel(boss, level)

    local maxHealth = ScaleFromBase(CONFIG.health.base, CONFIG.health.per_level, boss)
    boss:SetBaseMaxHealth(maxHealth)
    boss:SetMaxHealth(maxHealth)
    boss:SetHealth(maxHealth)
    boss:SetPhysicalArmorBaseValue(ScaleFromBase(CONFIG.armor.base, CONFIG.armor.per_level, boss))
    boss:SetBaseDamageMin(ScaleFromBase(CONFIG.attack_damage_min.base, CONFIG.attack_damage_min.per_level, boss))
    boss:SetBaseDamageMax(ScaleFromBase(CONFIG.attack_damage_max.base, CONFIG.attack_damage_max.per_level, boss))

    local modifier = boss:FindModifierByName("modifier_mortimer_level_scaling")
    if modifier then
        modifier:ForceRefresh()
    else
        boss:AddNewModifier(boss, nil, "modifier_mortimer_level_scaling", {})
    end
end

function MortimerLevelScaling:GetGobbleSpitMaxDistance(ability)
    return ability:GetSpecialValueFor("spit_max_distance")
        + CONFIG.gobble_spit_distance_per_level * GetLevelBonus(ability:GetCaster())
end

function MortimerLevelScaling:GetKissesProjectileCount(ability)
    return ability:GetSpecialValueFor("projectile_count")
        + CONFIG.kisses_projectiles_per_level * GetLevelBonus(ability:GetCaster())
end

function MortimerLevelScaling:GetKissesDuration(ability)
    return ability:GetSpecialValueFor("volley_duration")
        + CONFIG.kisses_duration_per_level * GetLevelBonus(ability:GetCaster())
end

function MortimerLevelScaling:GetKissesImpactDamage(ability)
    return ability:GetSpecialValueFor("damage_per_impact")
        + CONFIG.kisses_impact_damage_per_level * GetLevelBonus(ability:GetCaster())
end

function MortimerLevelScaling:GetKissesBurnDamage(ability)
    return ability:GetSpecialValueFor("burn_damage")
        + CONFIG.kisses_burn_damage_per_level * GetLevelBonus(ability:GetCaster())
end

function MortimerLevelScaling:GetKissesBurnDuration(ability)
    return ability:GetSpecialValueFor("burn_ground_duration")
        + CONFIG.kisses_burn_duration_per_level * GetLevelBonus(ability:GetCaster())
end

modifier_mortimer_level_scaling = class({})

function modifier_mortimer_level_scaling:IsHidden()
    return true
end

function modifier_mortimer_level_scaling:IsPurgable()
    return false
end

function modifier_mortimer_level_scaling:RemoveOnDeath()
    return true
end

function modifier_mortimer_level_scaling:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_TOTALDAMAGEOUTGOING_PERCENTAGE,
    }
end

function modifier_mortimer_level_scaling:GetModifierTotalDamageOutgoing_Percentage(params)
    if not params or params.attacker ~= self:GetParent() then
        return 0
    end

    local inflictor = params and params.inflictor
    if not inflictor or inflictor:IsNull() or inflictor:GetName() ~= "snapfire_firesnap_cookie" then
        return 0
    end

    return CONFIG.cookie_damage_pct_per_level * GetLevelBonus(self:GetParent())
end
