LinkLuaModifier("modifier_coup_de_foudre", "phantom_assassin/ability_coup_de_foudre", 0)
LinkLuaModifier("modifier_coup_de_foudre_buff", "phantom_assassin/ability_coup_de_foudre", 0)

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


    self:StartIntervalThink(0.1)
end

function modifier_coup_de_foudre:IsPurgable()
    return false  
end

function modifier_coup_de_foudre:IsHidden()
    return true 
end

function modifier_coup_de_foudre:OnIntervalThink()
    local unit = self:GetCaster()
    if unit:HasModifier("modifier_phantom_assassin_blur_active") then 
        self:AddBuff(unit)
        return
    end

    if not unit:CanBeSeenByAnyOpposingTeam() then
        self:AddBuff(unit)
    else 
        if not self.timer then 
            self.timer = Timers:CreateTimer(self.activation_delay, function()
                if self.modifier then 
                    self.modifier:Destroy()
                    self.modifier = nil
                end
                self.timer = nil
            end)
        end
    end
end

function modifier_coup_de_foudre:AddBuff(unit)
    if not self.modifier then 
        self.modifier = unit:AddNewModifier(
            unit,
            self:GetAbility(),
            "modifier_coup_de_foudre_buff",
            {}
        )
    end
    if self.timer then 
        Timers:RemoveTimer(self.timer)
        self.timer = nil
    end 
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
