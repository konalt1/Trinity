chen_barrack_hunter_focus = class({})
modifier_chen_barrack_hunter_focus = class({})
modifier_chen_barrack_hunter_focus_autocast = class({})

local SCRIPT_PATH = "abilities/chen/barrack/units/chen_barrack_hunter_focus"
local FOCUS_MODIFIER = "modifier_chen_barrack_hunter_focus"

LinkLuaModifier("modifier_chen_barrack_hunter_focus", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_barrack_hunter_focus_autocast", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)

local function IsValidUnit(unit)
    return unit and not unit:IsNull()
end

local function ApplyHunterFocus(ability, caster, startCooldown)
    if not IsServer() or not ability or ability:IsNull() or not IsValidUnit(caster) then
        return false
    end

    if caster:HasModifier(FOCUS_MODIFIER) then
        return false
    end

    if not ability:IsFullyCastable() then
        return false
    end

    if caster:IsSilenced() or caster:IsStunned() or caster:IsHexed() then
        return false
    end

    local duration = ability:GetSpecialValueFor("buff_duration")
    caster:AddNewModifier(caster, ability, FOCUS_MODIFIER, {
        duration = duration,
    })

    if startCooldown then
        ability:StartCooldown(ability:GetCooldown(ability:GetLevel() - 1))
    end

    return true
end

function chen_barrack_hunter_focus:GetIntrinsicModifierName()
    return "modifier_chen_barrack_hunter_focus_autocast"
end

function chen_barrack_hunter_focus:OnSpellStart()
    if not IsServer() then
        return
    end

    ApplyHunterFocus(self, self:GetCaster(), false)
end

function modifier_chen_barrack_hunter_focus_autocast:IsHidden()
    return true
end

function modifier_chen_barrack_hunter_focus_autocast:IsPurgable()
    return false
end

function modifier_chen_barrack_hunter_focus_autocast:OnCreated()
    if not IsServer() then
        return
    end

    local ability = self:GetAbility()
    if ability and not ability:IsNull() and not ability:GetAutoCastState() then
        ability:ToggleAutoCast()
    end
end

function modifier_chen_barrack_hunter_focus_autocast:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_ATTACK_START,
    }
end

function modifier_chen_barrack_hunter_focus_autocast:OnAttackStart(params)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    local ability = self:GetAbility()
    if not IsValidUnit(parent) or not ability or ability:IsNull() then
        return
    end

    if params.attacker ~= parent then
        return
    end

    if not ability:GetAutoCastState() then
        return
    end

    local target = params.target
    if not IsValidUnit(target) or not target:IsCreep() then
        return
    end

    ApplyHunterFocus(ability, parent, true)
end

function modifier_chen_barrack_hunter_focus:IsHidden()
    return false
end

function modifier_chen_barrack_hunter_focus:IsPurgable()
    return true
end

function modifier_chen_barrack_hunter_focus:GetTexture()
    return "beastmaster_inner_beast"
end

function modifier_chen_barrack_hunter_focus:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
    }
end

function modifier_chen_barrack_hunter_focus:GetModifierPreAttack_BonusDamage(event)
    local ability = self:GetAbility()
    if not ability or ability:IsNull() then
        return 0
    end

    local target = event.target
    if not IsValidUnit(target) or not target:IsCreep() then
        return 0
    end

    return ability:GetSpecialValueFor("bonus_damage")
end
