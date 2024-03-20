LinkLuaModifier("modifier_coup_de_foudre", "npc_spawn/phantom_assassin/ability_coup_de_foudre", 0)

ability_coup_de_foudre = ability_coup_de_foudre or class({})

function ability_coup_de_foudre:GetIntrinsicModifierName()
    return "modifier_coup_de_foudre"
end

modifier_coup_de_foudre = modifier_coup_de_foudre or class({})

function modifier_coup_de_foudre:OnCreated()
    self.crit = false
end

function modifier_coup_de_foudre:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE,
        MODIFIER_EVENT_ON_ATTACK_LANDED
    }
end

function modifier_coup_de_foudre:IsPurgable()
    return false
end

function modifier_coup_de_foudre:IsHidden()
    return true
end

function modifier_coup_de_foudre:GetModifierPreAttack_CriticalStrike(params)
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

    if params.attacker:CanBeSeenByAnyOpposingTeam() then
        return
    end

    local coup_de_grace = pa:FindAbilityByName("phantom_assassin_coup_de_grace")
    local crit_bonus = coup_de_grace:GetSpecialValueFor("crit_bonus")
    if crit_bonus > 0 then
        self.crit = true
    end
    return crit_bonus
end

function modifier_coup_de_foudre:OnAttackLanded(params)
    if self:GetParent() == params.attacker and self.crit then
        EmitSoundOnLocationWithCaster(
                params.target:GetAbsOrigin(),
                "Hero_PhantomAssassin.CoupDeGrace",
                self:GetCaster()
        )
        self.crit = false
    end
end
