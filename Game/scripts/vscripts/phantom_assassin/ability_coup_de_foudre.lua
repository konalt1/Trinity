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

function modifier_coup_de_foudre:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE,
        MODIFIER_EVENT_ON_DEATH,
    }  
end

function modifier_coup_de_foudre:IsPurgable()
    return false  
end

function modifier_coup_de_foudre:IsHidden()
    return true 
end

function modifier_coup_de_foudre:OnDeath(event)
    local parent = self:GetParent()
    local unit = event.unit

    if event.attacker ~= parent then return end
    if not unit:IsRealHero() then return end
    if self:GetAbility():GetSpecialValueFor("refresh_items") == 0 then return end

    parent:EmitSound("DOTA_Item.Refresher.Activate")
    ParticleManager:SetParticleControlEnt(ParticleManager:CreateParticle("particles/items2_fx/refresher.vpcf", PATTACH_ABSORIGIN_FOLLOW, parent), 0, parent, PATTACH_POINT_FOLLOW, "attach_hitloc", parent:GetAbsOrigin(), true)
    
    for i = 0, 8 do
        if parent:GetItemInSlot(i) and parent:GetItemInSlot(i):IsRefreshable() then 
            parent:GetItemInSlot(i):EndCooldown()
        end
    end    
end


function modifier_coup_de_foudre:GetModifierPreAttack_CriticalStrike(params)
    if not IsServer() or self:GetParent():PassivesDisabled() then
        return
    end

    local ability = self:GetAbility()

    if ability:GetSpecialValueFor("attack_for_activate") == 0 then return end
    local pa = params.attacker

    if pa ~= self:GetParent() then
        return
    end

    local target = params.target
    if not target:IsHero() or target:GetTeam() == pa:GetTeam() then
        return
    end
    local crit_bonus = self:GetAbility():GetSpecialValueFor("crit_bonus")
    self:IncrementStackCount()

    if self:GetStackCount() >= ability:GetSpecialValueFor("attack_for_activate") then 
        self:SetStackCount(0)
        EmitSoundOnLocationWithCaster(
            target:GetAbsOrigin(),
            "Hero_PhantomAssassin.CoupDeGrace",
            self:GetCaster()
        )

        return crit_bonus
    end
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
