LinkLuaModifier("modifier_tinker_rearm_custom", "abilities/tinker/tinker_rearm_custom", LUA_MODIFIER_MOTION_NONE)

tinker_rearm_custom = class({})

function tinker_rearm_custom:OnSpellStart()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    caster:AddNewModifier(caster, self, "modifier_tinker_rearm_custom", {
        duration = self:GetSpecialValueFor("duration"),
    })
end

modifier_tinker_rearm_custom = class({})

function modifier_tinker_rearm_custom:IsHidden()
    return false
end

function modifier_tinker_rearm_custom:IsPurgable()
    return false
end

function modifier_tinker_rearm_custom:IsBuff()
    return true
end

function modifier_tinker_rearm_custom:RemoveOnDeath()
    return true
end

function modifier_tinker_rearm_custom:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_ABILITY_FULLY_CAST,
    }
end

function modifier_tinker_rearm_custom:OnCreated()
    local ability = self:GetAbility()
    self.cooldown = ability and ability:GetSpecialValueFor("cooldown") or 0

    if not IsServer() then
        return
    end

    self:PlayRearmEffects()
    self:StartIntervalThink(1.7)
end

function modifier_tinker_rearm_custom:OnAbilityFullyCast(event)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if event.unit ~= parent then
        return
    end

    local ability = event.ability
    if not ability or ability:IsNull() or ability == self:GetAbility() then
        return
    end

    ability:EndCooldown()
    if self.cooldown > 0 then
        ability:StartCooldown(self.cooldown)
    end
end

function modifier_tinker_rearm_custom:OnIntervalThink()
    self:PlayRearmEffects()
end

function modifier_tinker_rearm_custom:PlayRearmEffects()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    EmitSoundOn("sounds/weapons/hero/tinker/rearm.vsnd", parent)
    parent:StartGesture(ACT_DOTA_TINKER_REARM3)
end

function modifier_tinker_rearm_custom:OnDestroy()
    if not IsServer() then
        return
    end

    self:GetParent():FadeGesture(ACT_DOTA_TINKER_REARM3)
end
