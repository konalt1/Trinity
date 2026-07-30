LinkLuaModifier("modifier_custom_fountain_aura", "abilities/custom_fountain_aura", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_custom_fountain_aura_buff", "abilities/custom_fountain_aura", LUA_MODIFIER_MOTION_NONE)

_G.CUSTOM_FOUNTAIN_AURA_DEBUG_ENABLED = _G.CUSTOM_FOUNTAIN_AURA_DEBUG_ENABLED or false

if IsServer() and not _G.CUSTOM_FOUNTAIN_AURA_DEBUG_COMMAND_REGISTERED then
    Convars:RegisterCommand("fountain_aura_debug", function(_, value)
        if value == nil or value == "" then
            _G.CUSTOM_FOUNTAIN_AURA_DEBUG_ENABLED = not _G.CUSTOM_FOUNTAIN_AURA_DEBUG_ENABLED
        else
            local normalized = string.lower(tostring(value))
            _G.CUSTOM_FOUNTAIN_AURA_DEBUG_ENABLED = normalized == "1" or normalized == "true" or normalized == "on"
        end

        local state = _G.CUSTOM_FOUNTAIN_AURA_DEBUG_ENABLED and "ON" or "OFF"
        print("[FountainAura] Debug " .. state .. " (blue=vanilla, green=custom)")
    end, "Toggle fountain aura debug: fountain_aura_debug [0|1]", FCVAR_CHEAT)

    _G.CUSTOM_FOUNTAIN_AURA_DEBUG_COMMAND_REGISTERED = true
end

custom_fountain_aura = class({})

function custom_fountain_aura:GetIntrinsicModifierName()
    return "modifier_custom_fountain_aura"
end

modifier_custom_fountain_aura = class({})

function modifier_custom_fountain_aura:IsHidden()
    return true
end

function modifier_custom_fountain_aura:IsPurgable()
    return false
end

function modifier_custom_fountain_aura:RemoveOnDeath()
    return false
end

function modifier_custom_fountain_aura:OnCreated()
    if IsServer() then
        self:StartIntervalThink(0.25)
    end
end

function modifier_custom_fountain_aura:OnIntervalThink()
    if not _G.CUSTOM_FOUNTAIN_AURA_DEBUG_ENABLED then
        return
    end

    local fountain = self:GetParent()
    local ability = self:GetAbility()

    if not fountain or fountain:IsNull() or not ability or ability:IsNull() then
        return
    end

    local origin = fountain:GetAbsOrigin()
    local vanilla_radius = ability:GetSpecialValueFor("vanilla_radius")
    local custom_radius = ability:GetSpecialValueFor("radius")
    local draw_duration = 0.3

    DebugDrawCircle(origin, Vector(80, 160, 255), 255, vanilla_radius, false, draw_duration)
    DebugDrawCircle(origin, Vector(80, 255, 120), 255, custom_radius, false, draw_duration)

    local units = FindUnitsInRadius(
        fountain:GetTeamNumber(),
        origin,
        nil,
        custom_radius,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_INVULNERABLE,
        FIND_ANY_ORDER,
        false
    )

    local vanilla_count = 0
    local custom_count = 0

    for _, unit in ipairs(units) do
        if unit:HasModifier("modifier_fountain_aura_buff") then
            vanilla_count = vanilla_count + 1
            DebugDrawCircle(unit:GetAbsOrigin(), Vector(80, 160, 255), 255, 48, false, draw_duration)
        elseif unit:HasModifier("modifier_custom_fountain_aura_buff") then
            custom_count = custom_count + 1
            DebugDrawCircle(unit:GetAbsOrigin(), Vector(80, 255, 120), 255, 48, false, draw_duration)
        end
    end

    local status = string.format(
        "Fountain aura | vanilla: %d | custom: %d | radius: %d",
        vanilla_count,
        custom_count,
        custom_radius
    )
    DebugDrawText(origin + Vector(0, 0, 180), status, false, draw_duration)
end

function modifier_custom_fountain_aura:IsAura()
    return true
end

function modifier_custom_fountain_aura:GetModifierAura()
    return "modifier_custom_fountain_aura_buff"
end

function modifier_custom_fountain_aura:GetAuraRadius()
    return self:GetAbility():GetSpecialValueFor("radius")
end

function modifier_custom_fountain_aura:GetAuraSearchTeam()
    return DOTA_UNIT_TARGET_TEAM_FRIENDLY
end

function modifier_custom_fountain_aura:GetAuraSearchType()
    return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC
end

function modifier_custom_fountain_aura:GetAuraSearchFlags()
    return DOTA_UNIT_TARGET_FLAG_INVULNERABLE
end

function modifier_custom_fountain_aura:GetAuraDuration()
    return self:GetAbility():GetSpecialValueFor("aura_linger_duration")
end

function modifier_custom_fountain_aura:GetAuraEntityReject(target)
    if target:HasModifier("modifier_fountain_aura_buff") then
        return true
    end

    local fountain = self:GetParent()
    local vanilla_radius = self:GetAbility():GetSpecialValueFor("vanilla_radius")
    local distance = (target:GetAbsOrigin() - fountain:GetAbsOrigin()):Length2D()

    return distance <= vanilla_radius
end

modifier_custom_fountain_aura_buff = class({})

function modifier_custom_fountain_aura_buff:IsHidden()
    return false
end

function modifier_custom_fountain_aura_buff:IsPurgable()
    return false
end

function modifier_custom_fountain_aura_buff:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_HEALTH_REGEN_PERCENTAGE,
        MODIFIER_PROPERTY_MANA_REGEN_TOTAL_PERCENTAGE,
    }
end

function modifier_custom_fountain_aura_buff:GetModifierHealthRegenPercentage()
    if self:GetParent():HasModifier("modifier_fountain_aura_buff") then
        return 0
    end

    return self:GetAbility():GetSpecialValueFor("health_regen_pct")
end

function modifier_custom_fountain_aura_buff:GetModifierTotalPercentageManaRegen()
    if self:GetParent():HasModifier("modifier_fountain_aura_buff") then
        return 0
    end

    return self:GetAbility():GetSpecialValueFor("mana_regen_pct")
end
