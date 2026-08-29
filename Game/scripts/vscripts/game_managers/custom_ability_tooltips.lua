CustomAbilityTooltips = CustomAbilityTooltips or {}

-- Keep tooltip-only metadata outside npc_abilities_custom.txt. Unknown fields in an
-- ability definition can be consumed unpredictably by the native Dota tooltip.
local MIND_POWER_RULES = {
    tusk_ice = {
        damage = "mind_power_multiplier",
    },
    chen_holy_persuasion_custom = {
        bonus_health = "mind_power_health_multiplier",
    },
    chen_ultimate_aura = {
        bonus_health = "mind_power_health_multiplier",
        bonus_damage = "mind_power_damage_multiplier",
    },
    pudge_meat_hook_trinity = {
        damage = "mind_power_multiplier",
    },
    pudge_rot_trinity = {
        rot_damage = "mind_power_damage_multiplier",
        rot_radius = "mind_power_radius_multiplier",
    },
    ember_searing_chains_trinity = {
        damage_per_second = "mind_power_multiplier",
    },
    ember_flame_guard_passive = {
        mind_power_damage_bonus = "mind_power_multiplier",
        magic_damage_amp = "magic_damage_amp_mind_power_multiplier",
    },
    ember_spirit_activate_fire_remnant_trinity = {
        damage = "mind_power_multiplier",
    },
    doom_scorched_earth_lua = {
        damage_per_second = "mind_power_damage_multiplier",
    },
    doom_ultimate_aura = {
        damage_per_second = "mind_power_multiplier",
    },
    juggernaut_blade_fury_lua = {
        blade_fury_damage = "mind_power_multiplier",
    },
    juggernaut_bloodlust = {
        heal_per_attack = "mind_power_heal_multiplier",
    },
    lich_frost_blast_lua = {
        aoe_damage = "mind_power_multiplier",
    },
    lich_frost_shield_lua = {
        damage = "mind_power_damage_multiplier",
    },
    lich_spark_wraith = {
        spark_damage_base = "mind_power_multiplier",
    },
    lion_impale_custom = {
        damage = "mind_power_multiplier",
    },
    lion_spirit_siphon_custom = {
        mana_drain_per_second = "mind_power_multiplier",
    },
    lion_finger_of_death_custom = {
        damage = "mind_power_multiplier",
    },
    ogre_magi_strength_boost = {
        base_strength_bonus = "mind_power_multiplier",
    },
    custom_purification = {
        heal = "mind_power_multiplier",
    },
    omniknight_repel_lua = {
        heal_amount = "mind_power_multiplier",
    },
    holy_ground = {
        heal_amount = "mind_power_multiplier",
    },
    omniknight_holy_grenade = {
        damage = "mind_power_multiplier",
    },
    silencer_arcane_curse_custom = {
        initial_damage = "mind_power_multiplier",
        damage = "mind_power_multiplier",
    },
    silencer_last_word_custom = {
        damage = "mind_power_multiplier",
    },
    silent_square = {
        base_duration = "mind_power_duration_bonus",
        base_side_length = "mind_power_side_bonus",
    },
    focus = {
        shield_amount = "mind_power_multiplier",
    },
    nevermore_shadowraze1_trinity = {
        shadowraze_damage = "mind_power_multiplier",
    },
    nevermore_shadowraze2_trinity = {
        shadowraze_damage = "mind_power_multiplier",
    },
    nevermore_shadowraze3_trinity = {
        shadowraze_damage = "mind_power_multiplier",
    },
    nevermore_requiem_trinity = {
        damage = "mind_power_multiplier",
    },
    techies_suicide_custom = {
        damage = "mind_power_multiplier",
    },
    ability_fireworks = {
        bonus_magic_damage = "mind_power_multiplier",
    },
    ability_chain_bomb = {
        damage = "mind_power_multiplier",
    },
    chen_barrack_hunter_overload = {
        damage = "mind_power_multiplier",
    },
    tinker_laser_custom = {
        laser_damage = "mind_power_multiplier",
    },
    tinker_march_of_the_machines_custom = {
        damage = "mind_power_multiplier",
    },
    tinker_deploy_turrets_custom = {
        drop_damage = "drop_mind_power_multiplier",
        missile_damage = "missile_mind_power_multiplier",
    },
    dawnbreaker_celestial_hammer_custom = {
        hammer_damage = "mind_power_multiplier",
    },
    largo_childhood_memories = {
        stomp_damage = "mind_power_multiplier",
    },
    largo_catchy_lick_trinity = {
        damage = "mind_power_multiplier",
    },
    largo_frogstomp_trinity = {
        damage_per_stomp = "mind_power_multiplier",
    },
    largo_song_fight_song = {
        burst_damage = 1.0,
    },
    -- Numeric multiplier: vanilla Aether Remnant has no mind_power_multiplier KV.
    -- Server scaling is applied by modifier_void_spirit_mind_power, not by rewriting the ability.
    void_spirit_aether_remnant = {
        impact_damage = 1.0,
    },
    void_spirit_dissimilate_trinity = {
        damage = "mind_power_multiplier",
    },
    void_spirit_astral_step_trinity = {
        pop_damage = "mind_power_multiplier",
    },
}

CustomAbilityTooltips.MIND_POWER_RULES = MIND_POWER_RULES

function CustomAbilityTooltips:GetMindPowerMultiplierKey(ability_name, special_value_name)
    local ability_rules = MIND_POWER_RULES[ability_name]
    if not ability_rules then
        return nil
    end
    return ability_rules[special_value_name]
end

function CustomAbilityTooltips:IsNumericMindPowerMultiplier(ability_name, special_value_name)
    return type(self:GetMindPowerMultiplierKey(ability_name, special_value_name)) == "number"
end

function CustomAbilityTooltips:ShouldOverrideMindPowerSpecial(ability, special_value_name)
    if not ability or ability:IsNull() then return false end
    return self:GetMindPowerMultiplierKey(ability:GetAbilityName(), special_value_name) ~= nil
end

function CustomAbilityTooltips:GetMindPowerMultiplierAmount(ability, special_value_name, special_level)
    local multiplier_key = self:GetMindPowerMultiplierKey(ability:GetAbilityName(), special_value_name)
    if multiplier_key == nil then
        return nil
    end

    if type(multiplier_key) == "number" then
        return multiplier_key
    end

    local level = tonumber(special_level)
    if level == nil or level < 0 then
        level = math.max(0, ability:GetLevel() - 1)
    end

    return ability:GetLevelSpecialValueNoOverride(multiplier_key, level)
end

function CustomAbilityTooltips:GetMindPowerSpecialValue(ability, special_value_name, special_level, mind_power)
    if not ability or ability:IsNull() then return nil end

    local multiplier = self:GetMindPowerMultiplierAmount(ability, special_value_name, special_level)
    if multiplier == nil then return nil end

    local level = tonumber(special_level)
    if level == nil or level < 0 then
        level = math.max(0, ability:GetLevel() - 1)
    end

    local base_value = ability:GetLevelSpecialValueNoOverride(special_value_name, level)
    return math.max(0, base_value + (tonumber(mind_power) or 0) * multiplier)
end
