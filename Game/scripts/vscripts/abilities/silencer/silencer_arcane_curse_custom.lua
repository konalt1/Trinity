LinkLuaModifier("modifier_silencer_arcane_curse_custom_debuff", "abilities/silencer/silencer_arcane_curse_custom", LUA_MODIFIER_MOTION_NONE)

silencer_arcane_curse_custom = class({})
modifier_silencer_arcane_curse_custom_debuff = class({})

function silencer_arcane_curse_custom:GetAOERadius()
    return self:GetSpecialValueFor("radius")
end

function silencer_arcane_curse_custom:OnSpellStart()
    local caster = self:GetCaster()
    local target_point = self:GetCursorPosition()
    local radius = self:GetSpecialValueFor("radius")
    local duration = self:GetSpecialValueFor("base_duration")

    local enemies = FindUnitsInRadius(
        caster:GetTeamNumber(),
        target_point,
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    for _, enemy in pairs(enemies) do
        enemy:AddNewModifier(caster, self, "modifier_silencer_arcane_curse_custom_debuff", { duration = duration })
    end

    local particle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_silencer/silencer_curse_aoe.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    ParticleManager:SetParticleControl(particle, 0, target_point)
    ParticleManager:SetParticleControl(particle, 1, Vector(radius, radius, radius))
    ParticleManager:ReleaseParticleIndex(particle)

    EmitSoundOnLocationWithCaster(target_point, "Hero_Silencer.Curse.Cast", caster)
end

function modifier_silencer_arcane_curse_custom_debuff:IsDebuff()
    return true
end

function modifier_silencer_arcane_curse_custom_debuff:IsPurgable()
    return true
end

function modifier_silencer_arcane_curse_custom_debuff:GetTexture()
    return "silencer_arcane_curse"
end

function modifier_silencer_arcane_curse_custom_debuff:GetEffectName()
    return "particles/units/heroes/hero_silencer/silencer_curse.vpcf"
end

function modifier_silencer_arcane_curse_custom_debuff:GetEffectAttachType()
    return PATTACH_OVERHEAD_FOLLOW
end

function modifier_silencer_arcane_curse_custom_debuff:OnCreated()
    local ability = self:GetAbility()
    local caster = self:GetCaster()

    if not ability or ability:IsNull() or not caster or caster:IsNull() then
        return
    end

    self.damage = ability:GetSpecialValueFor("damage")
    self.initial_damage = ability:GetSpecialValueFor("initial_damage")
    self.slow_pct = ability:GetSpecialValueFor("slow_pct")
    self.penalty_duration = ability:GetSpecialValueFor("penalty_duration")
    self.mind_power_multiplier = ability:GetSpecialValueFor("mind_power_multiplier")
    self.remaining_time = self:GetRemainingTime()

    if not IsServer() then
        return
    end

    self:ApplyInitialDamage()
    self:StartIntervalThink(1)
end

function modifier_silencer_arcane_curse_custom_debuff:OnRefresh()
    self:OnCreated()
end

function modifier_silencer_arcane_curse_custom_debuff:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
        MODIFIER_EVENT_ON_ABILITY_FULLY_CAST,
    }
end

function modifier_silencer_arcane_curse_custom_debuff:GetModifierMoveSpeedBonus_Percentage()
    return -(self.slow_pct or 0)
end

function modifier_silencer_arcane_curse_custom_debuff:GetMindPowerDamageBonus()
    local caster = self:GetCaster()
    if not caster or caster:IsNull() then
        return 0
    end

    local mind_power = GetHeroMindPower(caster) or 0
    return mind_power * (self.mind_power_multiplier or 0)
end

function modifier_silencer_arcane_curse_custom_debuff:ApplyInitialDamage()
    local ability = self:GetAbility()
    local caster = self:GetCaster()
    local parent = self:GetParent()

    if not ability or ability:IsNull() or not caster or caster:IsNull() or not parent or parent:IsNull() then
        return
    end

    ApplyDamage({
        victim = parent,
        attacker = caster,
        damage = math.max(0, (self.initial_damage or 0) + self:GetMindPowerDamageBonus()),
        damage_type = DAMAGE_TYPE_MAGICAL,
        ability = ability
    })
end

function modifier_silencer_arcane_curse_custom_debuff:ApplyTickDamage()
    local ability = self:GetAbility()
    local caster = self:GetCaster()
    local parent = self:GetParent()

    if not ability or ability:IsNull() or not caster or caster:IsNull() or not parent or parent:IsNull() then
        return
    end

    ApplyDamage({
        victim = parent,
        attacker = caster,
        damage = math.max(0, (self.damage or 0) + self:GetMindPowerDamageBonus()),
        damage_type = DAMAGE_TYPE_MAGICAL,
        ability = ability
    })
end

function modifier_silencer_arcane_curse_custom_debuff:OnIntervalThink()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if not parent or parent:IsNull() then
        self:Destroy()
        return
    end

    self:ApplyTickDamage()

    if parent:IsSilenced() then
        self:SetDuration(self.remaining_time, true)
        return
    end

    self.remaining_time = self.remaining_time - 1.0
    if self.remaining_time <= 0 then
        self:Destroy()
    end
end

function modifier_silencer_arcane_curse_custom_debuff:OnAbilityFullyCast(keys)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if not keys or keys.unit ~= parent then
        return
    end

    local cast_ability = keys.ability
    if not cast_ability or cast_ability:IsNull() then
        return
    end

    if cast_ability:IsItem() then
        return
    end

    if parent:IsSilenced() then
        return
    end

    local addition = self.penalty_duration or 0
    if addition <= 0 then
        return
    end

    self.remaining_time = (self.remaining_time or self:GetRemainingTime()) + addition
    self:SetDuration(self.remaining_time, true)
end
