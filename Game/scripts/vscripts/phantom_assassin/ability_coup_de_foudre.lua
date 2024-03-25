LinkLuaModifier("modifier_coup_de_foudre", "phantom_assassin/ability_coup_de_foudre", 0)
LinkLuaModifier("modifier_coup_de_foudre_buff", "phantom_assassin/ability_coup_de_foudre", 0)
LinkLuaModifier("modifier_coup_de_foudre_buff2", "phantom_assassin/ability_coup_de_foudre", 0)

ability_coup_de_foudre = ability_coup_de_foudre or class({})

function ability_coup_de_foudre:GetIntrinsicModifierName()
    return "modifier_coup_de_foudre"
end

modifier_coup_de_foudre = modifier_coup_de_foudre or class({})

function modifier_coup_de_foudre:OnCreated(_)
    if not IsServer() then
        return
    end

    self.activation_delay = self:GetAbility():GetSpecialValueFor("activation_delay")
    self.dagger_buff_time = self:GetAbility():GetSpecialValueFor("dagger_buff_time")

    GameRules:GetGameModeEntity():SetThink(
            "OnThink",
            self,
            self:GetCaster():GetUnitName() .. "$" .. self:GetName(),
            0
    )
end

function modifier_coup_de_foudre:IsPurgable()
    return false
end

function modifier_coup_de_foudre:IsHidden()
    return true
end

function modifier_coup_de_foudre:OnThink()
    local unit = self:GetCaster()

    if unit:CanBeSeenByAnyOpposingTeam() then
        unit:RemoveModifierByName("modifier_coup_de_foudre_buff")
    else
        unit:AddNewModifier(
                unit,
                self:GetAbility(),
                "modifier_coup_de_foudre_buff",
                { duration = -1 }
        )
    end

    return self.activation_delay
end

modifier_coup_de_foudre_buff = modifier_coup_de_foudre_buff or class({})

function modifier_coup_de_foudre_buff:OnCreated()
    self.is_crit = false
end

function modifier_coup_de_foudre_buff:IsPurgable()
    return false
end

function modifier_coup_de_foudre_buff:IsHidden()
    return false
end

function modifier_coup_de_foudre_buff:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE,
        MODIFIER_EVENT_ON_ATTACK_LANDED,
        MODIFIER_EVENT_ON_ABILITY_FULLY_CAST
    }
end

function modifier_coup_de_foudre_buff:GetModifierPreAttack_CriticalStrike(params)
    if not IsServer() or self:GetParent():PassivesDisabled() then
        return
    end

    local pa = params.attacker
    if pa ~= self:GetParent() then
        return
    end

    local target = params.target
    if not target:IsHero() or target:GetTeam() == pa:GetTeam() then
        return
    end
    local crit_bonus = self:GetAbility():GetSpecialValueFor("crit_bonus")
    self.is_crit = true
    return crit_bonus
end

function modifier_coup_de_foudre_buff:OnAttackLanded(params)
    if self:GetParent() == params.attacker and self.is_crit then
        EmitSoundOnLocationWithCaster(
                params.target:GetAbsOrigin(),
                "Hero_PhantomAssassin.CoupDeGrace",
                self:GetCaster()
        )
        self.is_crit = false
    end
end

function modifier_coup_de_foudre_buff:OnAbilityFullyCast(event)
    if (
            IsServer() and
            event.ability:GetAbilityName() == "phantom_assassin_stifling_dagger" and
            event.target ~= nil and
            event.target:IsHero()
    ) then
        self:GetParent():AddNewModifier(
                self:GetParent(),
                self:GetAbility(),
                "modifier_coup_de_foudre_buff2",
                { duration = self:GetAbility():GetSpecialValueFor("dagger_buff_time") }
        )
    end
end

modifier_coup_de_foudre_buff2 = modifier_coup_de_foudre_buff2 or modifier_coup_de_foudre_buff
