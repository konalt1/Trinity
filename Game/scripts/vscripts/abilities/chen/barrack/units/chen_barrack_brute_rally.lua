chen_barrack_brute_rally = class({})
modifier_chen_barrack_brute_rally_autocast = class({})

local SCRIPT_PATH = "abilities/chen/barrack/units/chen_barrack_brute_rally"
local COOLDOWN_ABILITY_NAME = "chen_barrack_brute_rally"
local CHRONOMANCER_UNIT_NAME = "npc_chen_barrack_brute"
local MAX_ABILITY_SLOTS = 24

LinkLuaModifier("modifier_chen_barrack_brute_rally_autocast", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)

local function IsValidUnit(unit)
    return unit and not unit:IsNull() and unit:IsAlive()
end

local function IsHeroOrCreep(unit)
    if not IsValidUnit(unit) then
        return false
    end

    if unit:IsHero() then
        return true
    end

    if unit.IsCreep and unit:IsCreep() then
        return true
    end

    return unit.IsCreature and unit:IsCreature()
end

local function IsChronomancerUnit(unit)
    return IsValidUnit(unit) and unit:GetUnitName() == CHRONOMANCER_UNIT_NAME
end

local function IsValidCooldownTarget(caster, target)
    if not IsValidUnit(caster) or not IsValidUnit(target) or target == caster then
        return false
    end

    if target:GetTeamNumber() ~= caster:GetTeamNumber() then
        return false
    end

    if target:IsBuilding() or target:IsInvulnerable() then
        return false
    end

    return IsHeroOrCreep(target)
end

local function GetUnitAbilityCount(unit)
    if unit.GetAbilityCount then
        local count = unit:GetAbilityCount()
        if count and count > 0 then
            return count
        end
    end

    return MAX_ABILITY_SLOTS
end

local function IsReducibleAbility(ability)
    if not ability or ability:IsNull() then
        return false
    end

    if ability:GetLevel() <= 0 then
        return false
    end

    local name = ability:GetAbilityName()
    if name == "attribute_bonus" or name == "generic_hidden" then
        return false
    end

    return ability:GetCooldownTimeRemaining() > 0
end

local function HasReducibleCooldown(target)
    if not IsValidUnit(target) then
        return false
    end

    for index = 0, GetUnitAbilityCount(target) - 1 do
        local ability = target:GetAbilityByIndex(index)
        if IsReducibleAbility(ability) then
            return true
        end
    end

    return false
end

local function FindAutoCooldownTarget(caster, ability)
    if not IsValidUnit(caster) or not ability or ability:IsNull() then
        return nil
    end

    local radius = ability:GetSpecialValueFor("search_radius")
    local allies = FindUnitsInRadius(
        caster:GetTeamNumber(),
        caster:GetAbsOrigin(),
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_CLOSEST,
        false
    )

    local bestCreep
    for _, ally in pairs(allies) do
        if not IsChronomancerUnit(ally) and IsValidCooldownTarget(caster, ally) and HasReducibleCooldown(ally) then
            if ally:IsRealHero() then
                return ally
            end

            bestCreep = bestCreep or ally
        end
    end

    return bestCreep
end

local function ReduceAbilityCooldown(ability, amount)
    local remaining = ability:GetCooldownTimeRemaining()
    if remaining <= 0 then
        return false
    end

    local newCooldown = math.max(0, remaining - amount)
    ability:EndCooldown()
    if newCooldown > 0 then
        ability:StartCooldown(newCooldown)
    end

    return true
end

local function PlayCooldownReductionParticle(caster, target)
    local particle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_keeper_of_the_light/keeper_chakra_magic.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        caster
    )
    ParticleManager:SetParticleControlEnt(
        particle,
        0,
        caster,
        PATTACH_POINT_FOLLOW,
        "attach_attack1",
        caster:GetAbsOrigin(),
        true
    )
    ParticleManager:SetParticleControlEnt(
        particle,
        1,
        target,
        PATTACH_POINT_FOLLOW,
        "attach_hitloc",
        target:GetAbsOrigin(),
        true
    )
    ParticleManager:ReleaseParticleIndex(particle)
end

local function ReduceTargetCooldowns(caster, target, ability)
    if not IsValidCooldownTarget(caster, target) or not ability or ability:IsNull() then
        return false
    end

    local cooldownReduction = ability:GetSpecialValueFor("cooldown_reduction")
    if cooldownReduction <= 0 then
        return false
    end

    local reducedAny = false
    for index = 0, GetUnitAbilityCount(target) - 1 do
        local targetAbility = target:GetAbilityByIndex(index)
        if IsReducibleAbility(targetAbility) then
            reducedAny = ReduceAbilityCooldown(targetAbility, cooldownReduction) or reducedAny
        end
    end

    if not reducedAny then
        return false
    end

    PlayCooldownReductionParticle(caster, target)
    target:EmitSound("Hero_KeeperOfTheLight.ChakraMagic.Target")

    return true
end

function ChenBarrackEnableBruteAutocast(brute)
    if not IsValidUnit(brute) then
        return
    end

    local ability = brute:FindAbilityByName(COOLDOWN_ABILITY_NAME)
    if ability and not ability:IsNull() and not ability:GetAutoCastState() then
        ability:ToggleAutoCast()
    end
end

function chen_barrack_brute_rally:Precache(context)
    PrecacheResource("particle", "particles/units/heroes/hero_keeper_of_the_light/keeper_chakra_magic.vpcf", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_keeper_of_the_light.vsndevts", context)
end

function chen_barrack_brute_rally:GetIntrinsicModifierName()
    return "modifier_chen_barrack_brute_rally_autocast"
end

function chen_barrack_brute_rally:CastFilterResultTarget(target)
    if not IsServer() then
        return UF_SUCCESS
    end

    if not IsValidCooldownTarget(self:GetCaster(), target) then
        return UF_FAIL_CUSTOM
    end

    if not HasReducibleCooldown(target) then
        return UF_FAIL_CUSTOM
    end

    return UF_SUCCESS
end

function chen_barrack_brute_rally:GetCustomCastErrorTarget(target)
    if not IsValidCooldownTarget(self:GetCaster(), target) then
        return "#dota_hud_error_cant_cast_on_other"
    end

    return "#dota_hud_error_no_abilities_on_cooldown"
end

function chen_barrack_brute_rally:OnSpellStart()
    if not IsServer() then
        return
    end

    ReduceTargetCooldowns(self:GetCaster(), self:GetCursorTarget(), self)
end

function modifier_chen_barrack_brute_rally_autocast:IsHidden()
    return true
end

function modifier_chen_barrack_brute_rally_autocast:IsPurgable()
    return false
end

function modifier_chen_barrack_brute_rally_autocast:OnCreated()
    if not IsServer() then
        return
    end

    local ability = self:GetAbility()
    if ability and not ability:IsNull() and not ability:GetAutoCastState() then
        ability:ToggleAutoCast()
    end

    local interval = 0.25
    if ability and not ability:IsNull() then
        local thinkInterval = ability:GetSpecialValueFor("think_interval")
        if thinkInterval and thinkInterval > 0 then
            interval = thinkInterval
        end
    end

    self:StartIntervalThink(interval)
end

function modifier_chen_barrack_brute_rally_autocast:OnIntervalThink()
    if not IsServer() then
        return
    end

    local caster = self:GetParent()
    local ability = self:GetAbility()
    if not IsValidUnit(caster) or not ability or ability:IsNull() then
        return
    end

    if not ability:GetAutoCastState() or not ability:IsFullyCastable() then
        return
    end

    if caster:IsStunned() or caster:IsHexed() or caster:IsSilenced() then
        return
    end

    local target = FindAutoCooldownTarget(caster, ability)
    if not target then
        return
    end

    if (caster:GetAbsOrigin() - target:GetAbsOrigin()):Length2D() > ability:GetCastRange(caster:GetAbsOrigin(), target) then
        return
    end

    if ReduceTargetCooldowns(caster, target, ability) then
        ability:UseResources(false, false, false, true)
    end
end
