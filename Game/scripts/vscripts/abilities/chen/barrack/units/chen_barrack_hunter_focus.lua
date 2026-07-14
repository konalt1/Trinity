chen_barrack_anti_creep_mana_burn = class({})
chen_barrack_anti_creep_dash = class({})
modifier_chen_barrack_anti_creep_mana_burn = class({})
modifier_chen_barrack_anti_creep_dash = class({})
modifier_chen_barrack_anti_creep_dash_autocast = class({})

local SCRIPT_PATH = "abilities/chen/barrack/units/chen_barrack_hunter_focus"
local MANA_BURN_MODIFIER = "modifier_chen_barrack_anti_creep_mana_burn"
local DASH_MODIFIER = "modifier_chen_barrack_anti_creep_dash"

LinkLuaModifier("modifier_chen_barrack_anti_creep_mana_burn", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_barrack_anti_creep_dash", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_barrack_anti_creep_dash_autocast", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)

local function IsValidUnit(unit)
    return unit and not unit:IsNull()
end

local function GetManaBurnValue(ability)
    if not ability or ability:IsNull() then
        return 0
    end

    local value = ability:GetSpecialValueFor("mana_burn")
    if value and value > 0 then
        return value
    end

    return math.max(0, ability:GetLevelSpecialValueFor("mana_burn", 0))
end

local function BurnMana(target, amount, ability)
    local currentMana = target:GetMana()
    local manaToBurn = math.min(amount, currentMana)
    if manaToBurn <= 0 then
        return 0
    end

    if target.Script_ReduceMana then
        target:Script_ReduceMana(manaToBurn, ability)
    elseif target.ReduceMana then
        target:ReduceMana(manaToBurn)
    else
        target:SetMana(math.max(0, currentMana - manaToBurn))
    end

    return manaToBurn
end

local function CanUseDash(caster, ability)
    if not IsValidUnit(caster) or not ability or ability:IsNull() then
        return false
    end

    if caster:HasModifier(DASH_MODIFIER) or not ability:IsFullyCastable() then
        return false
    end

    return not caster:IsSilenced() and not caster:IsStunned() and not caster:IsHexed()
end

local function IsValidDashTarget(caster, target)
    if not IsValidUnit(caster) or not IsValidUnit(target) then
        return false
    end

    if not target:IsAlive() or target:IsBuilding() or target:GetTeamNumber() == caster:GetTeamNumber() then
        return false
    end

    return true
end

local function ApplyDash(caster, ability, startCooldown)
    if not IsServer() or not CanUseDash(caster, ability) then
        return false
    end

    caster:AddNewModifier(caster, ability, DASH_MODIFIER, {
        duration = ability:GetSpecialValueFor("buff_duration"),
    })

    if startCooldown then
        ability:StartCooldown(ability:GetCooldown(ability:GetLevel() - 1))
    end

    return true
end

local function TryUseDashOnTarget(caster, ability, target)
    if not CanUseDash(caster, ability) or not IsValidDashTarget(caster, target) then
        return false
    end

    local distance = (target:GetAbsOrigin() - caster:GetAbsOrigin()):Length2D()
    local attackRange = caster:Script_GetAttackRange()
    if distance <= attackRange then
        return false
    end

    local searchRadius = ability:GetSpecialValueFor("autocast_search_radius")
    if searchRadius > 0 and distance > searchRadius then
        return false
    end

    return ApplyDash(caster, ability, true)
end

function chen_barrack_anti_creep_mana_burn:GetIntrinsicModifierName()
    return MANA_BURN_MODIFIER
end

function chen_barrack_anti_creep_mana_burn:OnUpgrade()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    if IsValidUnit(caster) and not caster:HasModifier(MANA_BURN_MODIFIER) then
        caster:AddNewModifier(caster, self, MANA_BURN_MODIFIER, {})
    end
end

function chen_barrack_anti_creep_dash:GetIntrinsicModifierName()
    return "modifier_chen_barrack_anti_creep_dash_autocast"
end

function chen_barrack_anti_creep_dash:OnSpellStart()
    if not IsServer() then
        return
    end

    ApplyDash(self:GetCaster(), self, false)
end

function modifier_chen_barrack_anti_creep_mana_burn:IsHidden()
    return true
end

function modifier_chen_barrack_anti_creep_mana_burn:IsPurgable()
    return false
end

function modifier_chen_barrack_anti_creep_mana_burn:OnCreated()
    if not IsServer() then
        return
    end

    local ability = self:GetAbility()
    if ability and not ability:IsNull() and ability:GetLevel() <= 0 then
        ability:SetLevel(1)
    end
end

function modifier_chen_barrack_anti_creep_mana_burn:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_ATTACK_LANDED,
    }
end

function modifier_chen_barrack_anti_creep_mana_burn:OnAttackLanded(params)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if params.attacker ~= parent then
        return
    end

    local target = params.target
    local ability = self:GetAbility()
    if not IsValidUnit(target) or not ability or ability:IsNull() then
        return
    end

    if target:IsBuilding() or target:GetTeamNumber() == parent:GetTeamNumber() then
        return
    end

    local manaBurn = GetManaBurnValue(ability)
    if manaBurn <= 0 or target:GetMana() <= 0 then
        return
    end

    local burned = BurnMana(target, manaBurn, ability)
    if burned > 0 then
        target:EmitSound("Hero_Antimage.ManaBreak")
    end
end

function modifier_chen_barrack_anti_creep_dash_autocast:IsHidden()
    return true
end

function modifier_chen_barrack_anti_creep_dash_autocast:IsPurgable()
    return false
end

function modifier_chen_barrack_anti_creep_dash_autocast:OnCreated()
    if not IsServer() then
        return
    end

    local ability = self:GetAbility()
    if ability and not ability:IsNull() and not ability:GetAutoCastState() then
        ability:ToggleAutoCast()
    end

    self:StartIntervalThink(0.25)
end

function modifier_chen_barrack_anti_creep_dash_autocast:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_ATTACK_START,
    }
end

function modifier_chen_barrack_anti_creep_dash_autocast:OnAttackStart(params)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    local ability = self:GetAbility()
    if params.attacker ~= parent or not ability or ability:IsNull() then
        return
    end

    if not ability:GetAutoCastState() then
        return
    end

    TryUseDashOnTarget(parent, ability, params.target)

    -- Не дашить, если мы уже в диапазоне атаки
end

function modifier_chen_barrack_anti_creep_dash_autocast:OnIntervalThink()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    local ability = self:GetAbility()
    if not ability or ability:IsNull() or not ability:GetAutoCastState() then
        return
    end

    TryUseDashOnTarget(parent, ability, parent:GetAttackTarget())

end

function modifier_chen_barrack_anti_creep_dash:IsHidden()
    return false
end

function modifier_chen_barrack_anti_creep_dash:IsPurgable()
    return true
end

function modifier_chen_barrack_anti_creep_dash:GetTexture()
    return "antimage_blink"
end

function modifier_chen_barrack_anti_creep_dash:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
    }
end

function modifier_chen_barrack_anti_creep_dash:GetModifierMoveSpeedBonus_Percentage()
    local ability = self:GetAbility()
    if not ability or ability:IsNull() then
        return 0
    end

    return ability:GetSpecialValueFor("bonus_movespeed_pct")
end
