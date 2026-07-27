LinkLuaModifier("modifier_lion_spirit_siphon_custom", "abilities/lion/lion_spirit_siphon_custom", LUA_MODIFIER_MOTION_NONE)

local function LionGetMindPower(unit)
    if GetHeroMindPower then
        return GetHeroMindPower(unit) or 0
    end
    if unit and not unit:IsNull() and unit.GetIntellect then
        return unit:GetIntellect(false) or 0
    end
    return 0
end

local LION_SPIRIT_SIPHON_PARTICLE = "particles/units/heroes/hero_death_prophet/death_prophet_spiritsiphon.vpcf"

local function LionCreateSiphonParticle(caster, target)
    if not caster or caster:IsNull() or not target or target:IsNull() then
        return nil
    end

    local particle = ParticleManager:CreateParticle(LION_SPIRIT_SIPHON_PARTICLE, PATTACH_ABSORIGIN_FOLLOW, target)
    ParticleManager:SetParticleControlEnt(particle, 0, caster, PATTACH_POINT_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)
    ParticleManager:SetParticleControlEnt(particle, 1, target, PATTACH_POINT_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), true)
    return particle
end

lion_spirit_siphon_custom = class({})

function lion_spirit_siphon_custom:CastFilterResultTarget(target)
    if not target or target:IsNull() then
        return UF_FAIL_CUSTOM
    end
    if target and not target:IsNull() and target:GetMaxMana() <= 0 then
        return UF_FAIL_CUSTOM
    end
    return UnitFilter(
        target,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        self:GetCaster():GetTeamNumber()
    )
end

function lion_spirit_siphon_custom:GetCustomCastErrorTarget(target)
    if not target or target:IsNull() then
        return ""
    end
    if target and not target:IsNull() and target:GetMaxMana() <= 0 then
        return "#dota_hud_error_target_has_no_mana"
    end
    return ""
end

function lion_spirit_siphon_custom:OnSpellStart()
    local caster = self:GetCaster()
    local target = self:GetCursorTarget()
    if not target or target:IsNull() then
        return
    end

    if target:TriggerSpellAbsorb(self) then
        return
    end

    target:AddNewModifier(caster, self, "modifier_lion_spirit_siphon_custom", {
        duration = self:GetSpecialValueFor("duration"),
    })

    EmitSoundOn("Hero_DeathProphet.SpiritSiphon.Cast", caster)
    EmitSoundOn("Hero_DeathProphet.SpiritSiphon.Target", target)
end

modifier_lion_spirit_siphon_custom = class({})

function modifier_lion_spirit_siphon_custom:IsHidden() return false end
function modifier_lion_spirit_siphon_custom:IsDebuff() return true end
function modifier_lion_spirit_siphon_custom:IsPurgable() return true end
function modifier_lion_spirit_siphon_custom:GetTexture() return "lion_mana_drain" end

function modifier_lion_spirit_siphon_custom:OnCreated()
    local ability = self:GetAbility()
    self.tick_interval = ability:GetSpecialValueFor("tick_interval")
    self.break_distance = ability:GetSpecialValueFor("break_distance")
    self.health_drain_pct = ability:GetSpecialValueFor("health_drain_pct") / 100

    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    local caster = self:GetCaster()
    if not parent or parent:IsNull() or not caster or caster:IsNull() then
        self:Destroy()
        return
    end

    self.particle = LionCreateSiphonParticle(caster, parent)
    if self.particle then
        self:AddParticle(self.particle, false, false, -1, false, false)
    end

    self:StartIntervalThink(self.tick_interval)
end

function modifier_lion_spirit_siphon_custom:OnRefresh()
    local ability = self:GetAbility()
    self.tick_interval = ability:GetSpecialValueFor("tick_interval")
    self.break_distance = ability:GetSpecialValueFor("break_distance")
    self.health_drain_pct = ability:GetSpecialValueFor("health_drain_pct") / 100
end

function modifier_lion_spirit_siphon_custom:OnDestroy()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if parent and not parent:IsNull() then
        StopSoundOn("Hero_DeathProphet.SpiritSiphon.Target", parent)
    end
end

function modifier_lion_spirit_siphon_custom:OnIntervalThink()
    local parent = self:GetParent()
    local caster = self:GetCaster()
    local ability = self:GetAbility()

    if not parent or parent:IsNull() or not caster or caster:IsNull() or not ability or ability:IsNull() then
        self:Destroy()
        return
    end
    if not caster:IsAlive() or not parent:IsAlive() then
        self:Destroy()
        return
    end
    if (caster:GetAbsOrigin() - parent:GetAbsOrigin()):Length2D() > self.break_distance then
        self:Destroy()
        return
    end

    local mana_per_second = ability:GetSpecialValueFor("mana_drain_per_second")
        + LionGetMindPower(caster) * ability:GetSpecialValueFor("mind_power_multiplier")
    local mana_to_drain = math.max(0, mana_per_second * self.tick_interval)
    local mana_before = parent:GetMana()

    if parent.Script_ReduceMana then
        parent:Script_ReduceMana(mana_to_drain, ability)
    elseif parent.ReduceMana then
        parent:ReduceMana(mana_to_drain)
    end

    local mana_drained = math.max(0, mana_before - parent:GetMana())
    if mana_drained <= 0 then
        return
    end

    caster:GiveMana(mana_drained)

    local health_damage = mana_drained * self.health_drain_pct
    ApplyDamage({
        victim = parent,
        attacker = caster,
        damage = health_damage,
        damage_type = ability:GetAbilityDamageType(),
        ability = ability,
    })
    caster:Heal(health_damage, ability)

    SendOverheadEventMessage(nil, OVERHEAD_ALERT_MANA_LOSS, parent, math.floor(mana_drained), nil)
    SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, caster, math.floor(health_damage), nil)
end

