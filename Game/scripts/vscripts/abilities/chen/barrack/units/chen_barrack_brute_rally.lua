chen_barrack_brute_rally = class({})
modifier_chen_barrack_brute_rally = class({})
modifier_chen_barrack_brute_rally_aura = class({})
modifier_chen_barrack_brute_rally_autocast = class({})

local SCRIPT_PATH = "abilities/chen/barrack/units/chen_barrack_brute_rally"
local RALLY_AURA_MODIFIER = "modifier_chen_barrack_brute_rally_aura"
local RALLY_ABILITY_NAME = "chen_barrack_brute_rally"

LinkLuaModifier("modifier_chen_barrack_brute_rally", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_barrack_brute_rally_aura", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_barrack_brute_rally_autocast", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)

local function IsValidUnit(unit)
    return unit and not unit:IsNull() and unit:IsAlive()
end

local function ApplyBruteRally(ability, caster, startCooldown)
    if not IsServer() or not ability or ability:IsNull() or not IsValidUnit(caster) then
        return false
    end

    if not ability:IsFullyCastable() then
        return false
    end

    if caster:IsSilenced() or caster:IsStunned() or caster:IsHexed() then
        return false
    end

    local duration = ability:GetSpecialValueFor("buff_duration")
    local existing = caster:FindModifierByName(RALLY_AURA_MODIFIER)
    if existing then
        existing:SetDuration(duration, true)
    else
        caster:AddNewModifier(caster, ability, RALLY_AURA_MODIFIER, {
            duration = duration,
        })
    end

    caster:EmitSound("Hero_Ursa.Enrage")

    if startCooldown then
        ability:StartCooldown(ability:GetCooldown(ability:GetLevel() - 1))
    end

    return true
end

function ChenBarrackEnableBruteAutocast(brute)
    if not IsValidUnit(brute) then
        return
    end

    local ability = brute:FindAbilityByName(RALLY_ABILITY_NAME)
    if ability and not ability:IsNull() and not ability:GetAutoCastState() then
        ability:ToggleAutoCast()
    end
end

function chen_barrack_brute_rally:Precache(context)
    PrecacheResource("model", "models/heroes/ursa/ursa.vmdl", context)
    PrecacheResource("particle", "particles/units/heroes/hero_ursa/ursa_overpower_buff.vpcf", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ursa.vsndevts", context)
end

function chen_barrack_brute_rally:GetIntrinsicModifierName()
    return "modifier_chen_barrack_brute_rally_autocast"
end

function chen_barrack_brute_rally:OnSpellStart()
    if not IsServer() then
        return
    end

    ApplyBruteRally(self, self:GetCaster(), false)
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
end

function modifier_chen_barrack_brute_rally_autocast:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_TAKEN_DAMAGE,
    }
end

function modifier_chen_barrack_brute_rally_autocast:OnTakeDamage(params)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    local ability = self:GetAbility()
    if not IsValidUnit(parent) or not ability or ability:IsNull() then
        return
    end

    if params.unit ~= parent then
        return
    end

    if not ability:GetAutoCastState() then
        return
    end

    if not params.damage or params.damage <= 0 then
        return
    end

    if params.damage_type ~= DAMAGE_TYPE_PHYSICAL then
        return
    end

    ApplyBruteRally(ability, parent, true)
end

function modifier_chen_barrack_brute_rally_aura:IsHidden()
    return false
end

function modifier_chen_barrack_brute_rally_aura:IsPurgable()
    return true
end

function modifier_chen_barrack_brute_rally_aura:GetTexture()
    return "ursa_overpower"
end

function modifier_chen_barrack_brute_rally_aura:OnCreated()
    if not IsServer() then
        return
    end

    local ability = self:GetAbility()
    if ability and not ability:IsNull() then
        self.radius = ability:GetSpecialValueFor("radius")
    end

    local particle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_ursa/ursa_overpower_buff.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        self:GetParent()
    )
    self:AddParticle(particle, false, false, -1, false, false)
end

function modifier_chen_barrack_brute_rally_aura:IsAura()
    return true
end

function modifier_chen_barrack_brute_rally_aura:GetAuraRadius()
    if self.radius and self.radius > 0 then
        return self.radius
    end

    local ability = self:GetAbility()
    if ability and not ability:IsNull() then
        return ability:GetSpecialValueFor("radius")
    end

    return 200
end

function modifier_chen_barrack_brute_rally_aura:GetAuraSearchTeam()
    return DOTA_UNIT_TARGET_TEAM_FRIENDLY
end

function modifier_chen_barrack_brute_rally_aura:GetAuraSearchType()
    return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC
end

function modifier_chen_barrack_brute_rally_aura:GetAuraSearchFlags()
    return DOTA_UNIT_TARGET_FLAG_NONE
end

function modifier_chen_barrack_brute_rally_aura:GetModifierAura()
    return "modifier_chen_barrack_brute_rally"
end

function modifier_chen_barrack_brute_rally:IsHidden()
    return false
end

function modifier_chen_barrack_brute_rally:IsPurgable()
    return true
end

function modifier_chen_barrack_brute_rally:GetTexture()
    return "ursa_overpower"
end

function modifier_chen_barrack_brute_rally:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
    }
end

function modifier_chen_barrack_brute_rally:GetModifierAttackSpeedBonus_Constant()
    local ability = self:GetAbility()
    if not ability or ability:IsNull() then
        return 0
    end

    return ability:GetSpecialValueFor("bonus_attack_speed")
end
