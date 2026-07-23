LinkLuaModifier("modifier_silencer_last_word_custom_debuff", "abilities/silencer/silencer_last_word_custom", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_silencer_last_word_custom_silence", "abilities/silencer/silencer_last_word_custom", LUA_MODIFIER_MOTION_NONE)

silencer_last_word_custom = class({})
modifier_silencer_last_word_custom_debuff = class({})
modifier_silencer_last_word_custom_silence = class({})

function silencer_last_word_custom:OnSpellStart()
    local caster = self:GetCaster()

    if not caster or caster:IsNull() then
        return
    end

    local duration = self:GetSpecialValueFor("debuff_duration")
    local target = self:GetCursorTarget()
    if not target or target:IsNull() then
        return
    end

    if target:TriggerSpellAbsorb(self) then
        return
    end

    target:AddNewModifier(caster, self, "modifier_silencer_last_word_custom_debuff", { duration = duration })

    EmitSoundOn("Hero_Silencer.LastWord.Cast", caster)
    EmitSoundOn("Hero_Silencer.LastWord.Target", target)
end

function modifier_silencer_last_word_custom_debuff:IsDebuff()
    return true
end

function modifier_silencer_last_word_custom_debuff:IsPurgable()
    return true
end

function modifier_silencer_last_word_custom_debuff:GetEffectName()
    return "particles/units/heroes/hero_silencer/silencer_last_word_status.vpcf"
end

function modifier_silencer_last_word_custom_debuff:GetEffectAttachType()
    return PATTACH_OVERHEAD_FOLLOW
end

function modifier_silencer_last_word_custom_debuff:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_ABILITY_FULLY_CAST,
        MODIFIER_PROPERTY_PROVIDES_FOW_POSITION,
    }
end

function modifier_silencer_last_word_custom_debuff:GetModifierProvidesFOWVision()
    return 1
end

function modifier_silencer_last_word_custom_debuff:OnCreated()
    local ability = self:GetAbility()

    if ability and not ability:IsNull() then
        self.damage = ability:GetSpecialValueFor("damage")
        self.silence_duration = ability:GetSpecialValueFor("silence_duration")
        self.mind_power_multiplier = ability:GetSpecialValueFor("mind_power_multiplier")
    end

    if not IsServer() then
        return
    end

    self.triggered = false
    self:StartIntervalThink(self:GetRemainingTime())
end

function modifier_silencer_last_word_custom_debuff:OnRefresh()
    self:OnCreated()
end

function modifier_silencer_last_word_custom_debuff:OnIntervalThink()
    if not IsServer() then
        return
    end

    self:TriggerLastWord()
end

function modifier_silencer_last_word_custom_debuff:OnAbilityFullyCast(keys)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if not keys or keys.unit ~= parent then
        return
    end

    local cast_ability = keys.ability
    if not cast_ability or cast_ability:IsNull() or cast_ability:IsItem() then
        return
    end

    self:TriggerLastWord()
end

function modifier_silencer_last_word_custom_debuff:GetMindPowerDamageBonus()
    local caster = self:GetCaster()
    if not caster or caster:IsNull() then
        return 0
    end

    local mind_power = 0
    if GetHeroMindPower then
        mind_power = GetHeroMindPower(caster) or 0
    elseif caster.GetIntellect then
        mind_power = caster:GetIntellect(false) or 0
    end

    return mind_power * (self.mind_power_multiplier or 0)
end

function modifier_silencer_last_word_custom_debuff:TriggerLastWord()
    if self.triggered then
        return
    end

    local ability = self:GetAbility()
    local caster = self:GetCaster()
    local parent = self:GetParent()

    if not ability or ability:IsNull() or not caster or caster:IsNull() or not parent or parent:IsNull() then
        self:Destroy()
        return
    end

    self.triggered = true

    local total_damage = math.max(0, (self.damage or 0) + self:GetMindPowerDamageBonus())
    ApplyDamage({
        victim = parent,
        attacker = caster,
        damage = total_damage,
        damage_type = DAMAGE_TYPE_MAGICAL,
        ability = ability,
    })

    parent:AddNewModifier(caster, ability, "modifier_silencer_last_word_custom_silence", { duration = self.silence_duration or 0 })

    local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_silencer/silencer_last_word_dmg.vpcf", PATTACH_ABSORIGIN_FOLLOW, parent)
    ParticleManager:ReleaseParticleIndex(particle)

    EmitSoundOn("Hero_Silencer.LastWord.Damage", parent)
    self:Destroy()
end

function modifier_silencer_last_word_custom_silence:IsDebuff()
    return true
end

function modifier_silencer_last_word_custom_silence:IsPurgable()
    return true
end

function modifier_silencer_last_word_custom_silence:GetEffectName()
    return "particles/generic_gameplay/generic_silenced.vpcf"
end

function modifier_silencer_last_word_custom_silence:GetEffectAttachType()
    return PATTACH_OVERHEAD_FOLLOW
end

function modifier_silencer_last_word_custom_silence:CheckState()
    return {
        [MODIFIER_STATE_SILENCED] = true,
    }
end

function modifier_silencer_last_word_custom_silence:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_PROVIDES_FOW_POSITION,
    }
end

function modifier_silencer_last_word_custom_silence:GetModifierProvidesFOWVision()
    return 1
end
