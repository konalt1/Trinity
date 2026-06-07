chen_barrack_heal = class({})
modifier_chen_barrack_healer_ai = class({})

local SCRIPT_PATH = "abilities/chen/barrack/units/chen_barrack_heal"
local HEAL_ABILITY_NAME = "chen_barrack_heal"

LinkLuaModifier("modifier_chen_barrack_healer_ai", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)

local function IsValidUnit(unit)
    return unit and not unit:IsNull() and unit:IsAlive()
end

local function GetHealthFraction(unit)
    local maxHealth = unit:GetMaxHealth()
    if maxHealth <= 0 then
        return 1
    end
    return unit:GetHealth() / maxHealth
end

local function IsWoundedAlly(caster, ally, thresholdFraction)
    if not IsValidUnit(ally) or ally == caster then
        return false
    end

    if ally:GetTeamNumber() ~= caster:GetTeamNumber() then
        return false
    end

    if ally:IsInvulnerable() or ally:IsMagicImmune() then
        return false
    end

    return GetHealthFraction(ally) < thresholdFraction
end

local function FindAutoHealTarget(caster, ability)
    if not IsValidUnit(caster) or not ability or ability:IsNull() then
        return nil
    end

    local radius = ability:GetSpecialValueFor("search_radius")
    local thresholdFraction = ability:GetSpecialValueFor("wound_threshold_pct") / 100

    local allies = FindUnitsInRadius(
        caster:GetTeamNumber(),
        caster:GetAbsOrigin(),
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    local bestHero
    local bestHeroFraction = 2
    local bestCreep
    local bestCreepFraction = 2

    for _, ally in pairs(allies) do
        if IsWoundedAlly(caster, ally, thresholdFraction) then
            local fraction = GetHealthFraction(ally)
            if ally:IsRealHero() then
                if fraction < bestHeroFraction then
                    bestHero = ally
                    bestHeroFraction = fraction
                end
            elseif fraction < bestCreepFraction then
                bestCreep = ally
                bestCreepFraction = fraction
            end
        end
    end

    return bestHero or bestCreep
end

function ChenBarrackApplyHeal(caster, target, ability)
    if not IsValidUnit(caster) or not IsValidUnit(target) or not ability or ability:IsNull() then
        return
    end

    local healAmount = ability:GetSpecialValueFor("heal_amount")
    target:Heal(healAmount, ability)

    local particle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_chen/chen_hand_of_god.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        target
    )
    ParticleManager:ReleaseParticleIndex(particle)
    target:EmitSound("Hero_Chen.HandOfGodHealCreep")
end

function ChenBarrackEnableHealerAutocast(healer)
    if not IsValidUnit(healer) then
        return
    end

    local ability = healer:FindAbilityByName(HEAL_ABILITY_NAME)
    if ability and not ability:IsNull() and not ability:GetAutoCastState() then
        ability:ToggleAutoCast()
    end
end

function chen_barrack_heal:Precache(context)
    PrecacheResource("particle", "particles/units/heroes/hero_chen/chen_hand_of_god.vpcf", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_chen.vsndevts", context)
end

function chen_barrack_heal:GetIntrinsicModifierName()
    return "modifier_chen_barrack_healer_ai"
end

function chen_barrack_heal:OnSpellStart()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    local target = self:GetCursorTarget()
    if not IsValidUnit(caster) or not IsValidUnit(target) then
        return
    end

    ChenBarrackApplyHeal(caster, target, self)
end

function chen_barrack_heal:OnToggle()
    if not IsServer() then
        return
    end
end

function modifier_chen_barrack_healer_ai:IsHidden()
    return true
end

function modifier_chen_barrack_healer_ai:IsPurgable()
    return false
end

function modifier_chen_barrack_healer_ai:GetHealAbility()
    return self:GetAbility()
end

function modifier_chen_barrack_healer_ai:IsAutocastActive()
    local ability = self:GetHealAbility()
    return ability and not ability:IsNull() and ability:GetAutoCastState()
end

function modifier_chen_barrack_healer_ai:OnCreated()
    if not IsServer() then
        return
    end

    local ability = self:GetHealAbility()
    local interval = 0.25
    if ability and not ability:IsNull() then
        local thinkInterval = ability:GetSpecialValueFor("think_interval")
        if thinkInterval and thinkInterval > 0 then
            interval = thinkInterval
        end
    end

    self:StartIntervalThink(interval)
end

function modifier_chen_barrack_healer_ai:OnIntervalThink()
    if not IsServer() then
        return
    end

    if not self:IsAutocastActive() then
        return
    end

    local caster = self:GetParent()
    local ability = self:GetHealAbility()
    if not IsValidUnit(caster) or not ability or ability:IsNull() then
        return
    end

    if not ability:IsFullyCastable() then
        return
    end

    if caster:IsStunned() or caster:IsHexed() or caster:IsSilenced() then
        return
    end

    local target = FindAutoHealTarget(caster, ability)
    if not target then
        return
    end

    if (caster:GetAbsOrigin() - target:GetAbsOrigin()):Length2D() > ability:GetCastRange(caster:GetAbsOrigin(), target) then
        return
    end

    ChenBarrackApplyHeal(caster, target, ability)
    ability:UseResources(false, false, false, true)
end
