chen_barrack_hunter_overload = class({})
chen_barrack_anti_creep_dash = class({})
modifier_chen_barrack_hunter_overload = class({})
modifier_chen_barrack_hunter_overload_tooltip = class({})
modifier_chen_barrack_anti_creep_dash = class({})
modifier_chen_barrack_anti_creep_dash_autocast = class({})

require("game_managers/custom_ability_tooltips")

local SCRIPT_PATH = "abilities/chen/barrack/units/chen_barrack_hunter_focus"
local OVERLOAD_MODIFIER = "modifier_chen_barrack_hunter_overload"
local DASH_MODIFIER = "modifier_chen_barrack_anti_creep_dash"
local COUNTDOWN_PARTICLE = "particles/units/heroes/hero_ursa/ursa_enrage_buff.vpcf"
local EXPLOSION_PARTICLE = "particles/units/heroes/hero_ursa/ursa_earthshock.vpcf"

LinkLuaModifier("modifier_chen_barrack_hunter_overload", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_barrack_hunter_overload_tooltip", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_barrack_anti_creep_dash", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_barrack_anti_creep_dash_autocast", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)

local function IsValidUnit(unit)
    return unit and not unit:IsNull()
end

local function GetOwnerHero(unit)
    if ChenBarrackGold and ChenBarrackGold.GetOwnerHero then
        local hero = ChenBarrackGold.GetOwnerHero(unit)
        if IsValidUnit(hero) and hero.IsRealHero and hero:IsRealHero() then
            return hero
        end
    end

    local owner = unit and unit.GetOwnerEntity and unit:GetOwnerEntity() or nil
    if IsValidUnit(owner) and owner.IsRealHero and owner:IsRealHero() then
        return owner
    end

    return nil
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

function chen_barrack_hunter_overload:Precache(context)
    PrecacheResource("model", "models/creeps/neutral_creeps/n_creep_furbolg/n_creep_furbolg_disrupter.vmdl", context)
    PrecacheResource("particle", COUNTDOWN_PARTICLE, context)
    PrecacheResource("particle", EXPLOSION_PARTICLE, context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ursa.vsndevts", context)
end

function chen_barrack_hunter_overload:GetIntrinsicModifierName()
    return "modifier_chen_barrack_hunter_overload_tooltip"
end

function chen_barrack_hunter_overload:GetAOERadius()
    return self:GetSpecialValueFor("radius")
end

function chen_barrack_hunter_overload:GetDamage()
    local ownerHero = GetOwnerHero(self:GetCaster())
    local mindPower = 0
    if ownerHero and GetHeroMindPower then
        mindPower = GetHeroMindPower(ownerHero) or 0
    end

    return math.max(0,
        self:GetSpecialValueFor("damage")
        + mindPower * self:GetSpecialValueFor("mind_power_multiplier")
    )
end

function chen_barrack_hunter_overload:OnSpellStart()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    if not IsValidUnit(caster) or not caster:IsAlive() then
        return
    end

    caster:AddNewModifier(caster, self, OVERLOAD_MODIFIER, {
        duration = self:GetSpecialValueFor("countdown_duration"),
    })
    caster:EmitSound("Hero_Ursa.Enrage")
end

function modifier_chen_barrack_hunter_overload_tooltip:IsHidden()
    return true
end

function modifier_chen_barrack_hunter_overload_tooltip:IsPurgable()
    return false
end

function modifier_chen_barrack_hunter_overload_tooltip:OnCreated()
    self.synced_mind_power = 0
    if not IsServer() then return end

    self:SetHasCustomTransmitterData(true)
    self:StartIntervalThink(0.1)
end

function modifier_chen_barrack_hunter_overload_tooltip:OnIntervalThink()
    local ownerHero = GetOwnerHero(self:GetParent())
    local mindPower = ownerHero and GetHeroMindPower and (GetHeroMindPower(ownerHero) or 0) or 0
    if self.synced_mind_power == mindPower then return end

    self.synced_mind_power = mindPower
    self:SendBuffRefreshToClients()
end

function modifier_chen_barrack_hunter_overload_tooltip:AddCustomTransmitterData()
    return {
        mind_power = self.synced_mind_power or 0,
    }
end

function modifier_chen_barrack_hunter_overload_tooltip:HandleCustomTransmitterData(data)
    self.synced_mind_power = tonumber(data and data.mind_power) or 0
end

function modifier_chen_barrack_hunter_overload_tooltip:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL,
        MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL_VALUE,
    }
end

function modifier_chen_barrack_hunter_overload_tooltip:GetModifierOverrideAbilitySpecial(params)
    if IsServer() or not params then return 0 end

    return CustomAbilityTooltips:ShouldOverrideMindPowerSpecial(
        params.ability,
        params.ability_special_value
    ) and 1 or 0
end

function modifier_chen_barrack_hunter_overload_tooltip:GetModifierOverrideAbilitySpecialValue(params)
    if IsServer() or not params then return 0 end

    return CustomAbilityTooltips:GetMindPowerSpecialValue(
        params.ability,
        params.ability_special_value,
        params.ability_special_level,
        self.synced_mind_power
    ) or 0
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

function modifier_chen_barrack_hunter_overload:IsHidden()
    return false
end

function modifier_chen_barrack_hunter_overload:IsPurgable()
    return false
end

function modifier_chen_barrack_hunter_overload:GetTexture()
    return "ursa_enrage"
end

function modifier_chen_barrack_hunter_overload:OnCreated()
    if not IsServer() then
        return
    end

    self.explodeAt = GameRules:GetGameTime() + self:GetDuration()
    local particle = ParticleManager:CreateParticle(COUNTDOWN_PARTICLE, PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
    self:AddParticle(particle, false, false, -1, false, false)
end

function modifier_chen_barrack_hunter_overload:OnDestroy()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    local ability = self:GetAbility()
    if not IsValidUnit(parent) or not parent:IsAlive() or not ability or ability:IsNull() then
        return
    end

    if GameRules:GetGameTime() + 0.05 < (self.explodeAt or math.huge) then
        return
    end

    local position = parent:GetAbsOrigin()
    local damage = ability:GetDamage()
    local radius = ability:GetSpecialValueFor("radius")
    local enemies = FindUnitsInRadius(
        parent:GetTeamNumber(),
        position,
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    for _, enemy in pairs(enemies) do
        if IsValidUnit(enemy) and enemy:IsAlive() then
            ApplyDamage({
                victim = enemy,
                attacker = parent,
                damage = damage,
                damage_type = DAMAGE_TYPE_MAGICAL,
                ability = ability,
            })
        end
    end

    local particle = ParticleManager:CreateParticle(EXPLOSION_PARTICLE, PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(particle, 0, position)
    ParticleManager:SetParticleControl(particle, 1, Vector(radius, 0, 0))
    ParticleManager:ReleaseParticleIndex(particle)
    parent:EmitSound("Hero_Ursa.Earthshock")

    ApplyDamage({
        victim = parent,
        attacker = parent,
        damage = damage,
        damage_type = DAMAGE_TYPE_MAGICAL,
        ability = ability,
    })
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
    return "ursa_earthshock"
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
