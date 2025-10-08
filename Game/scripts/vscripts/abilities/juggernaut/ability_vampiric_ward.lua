LinkLuaModifier("modifier_ward_vampiric_aura", "Juggernaut/ability_vampiric_ward", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_ward_vampiric_aura_buff", "Juggernaut/ability_vampiric_ward", LUA_MODIFIER_MOTION_NONE)

ability_vampiric_ward = class({})

function ability_vampiric_ward:OnSpellStart()
    CreateUnitByNameAsync(
            "npc_dota_juggernaut_vampiric_ward",
            self:GetCursorPosition(),
            true,
            self:GetCaster(),
            self:GetCaster(),
            self:GetCaster():GetTeam(),
            function (unit)
                self:OnWardCreated(unit)
            end
    )
end

function ability_vampiric_ward:OnWardCreated(ward)
    ward:AddNewModifier(self:GetCaster(), self, "modifier_ward_vampiric_aura", {})
    ward:AddNewModifier(self:GetCaster(), self, "modifier_kill", { duration = self:GetSpecialValueFor("vampiric_ward_duration") })
    ward:SetControllableByPlayer(self:GetCaster():GetPlayerID(), false)

    local radius = self:GetSpecialValueFor("aura_radius")
    local particle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_juggernaut/juggernaut_healing_ward_base.vpcf", 
        PATTACH_ABSORIGIN_FOLLOW, 
        ward
    )
    ParticleManager:SetParticleControl(particle, 1, Vector(radius, 0, 0))
    ParticleManager:ReleaseParticleIndex(particle)
end


modifier_ward_vampiric_aura = modifier_ward_vampiric_aura or class({
    IsHidden =              function(_) return true end,
    IsPurgable =            function(_) return false end,
    IsAura =                function(_) return true end,
    GetModifierAura =       function(_) return "modifier_ward_vampiric_aura_buff" end,
    GetAuraRadius =         function(self) return self:GetAbility():GetSpecialValueFor("aura_radius") end,
    GetAuraDuration =       function(_) return 2.0 end,
    GetAuraSearchTeam =     function(_) return DOTA_UNIT_TARGET_TEAM_BOTH end,
    GetAuraSearchType =     function(_) return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_CREEP end,
    IsAuraActiveOnDeath =   function(_) return false end,
    GetAuraSearchFlags =    function() return DOTA_UNIT_TARGET_FLAG_NOT_ILLUSIONS end,
})

function modifier_ward_vampiric_aura:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_EXTRA_HEALTH_BONUS,
        MODIFIER_PROPERTY_INCOMING_PHYSICAL_DAMAGE_CONSTANT
    }
end

function modifier_ward_vampiric_aura:GetModifierExtraHealthBonus()
    return self:GetAbility():GetSpecialValueFor("healing_ward_bonus_health")
end

function modifier_ward_vampiric_aura:GetModifierIncomingPhysicalDamageConstant(event)
    if (
            not IsServer() or
            event.target ~= self:GetParent()
    ) then
        return 0
    end

    return -event.damage + 1
end

modifier_ward_vampiric_aura_buff = class({
    IsBuff =         function() return self.isBuff end,
    IsHidden =         function() return false end,
    DeclareFunctions = function() return {
     MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE, 
     MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
    } end,
})

function modifier_ward_vampiric_aura_buff:OnCreated()
    local parent = self:GetParent()

    self.isBuff = self:GetCaster():GetTeamNumber() == self:GetParent():GetTeamNumber()

    if self.isBuff then 
        AddModifierLifesteal(parent, self:GetAbility():GetSpecialValueFor("lifesteal_percent"))
    end
end

function modifier_ward_vampiric_aura_buff:OnDestroy()
    local parent = self:GetParent()

    if self.isBuff then 
        RemoveModifierLifesteal(parent, self:GetAbility():GetSpecialValueFor("lifesteal_percent"))
    end
end

function modifier_ward_vampiric_aura_buff:GetModifierMoveSpeedBonus_Percentage()
    if not self.isBuff then 
        return self:GetAbility():GetSpecialValueFor("slow_move_speed")
    end
end

function modifier_ward_vampiric_aura_buff:GetModifierAttackSpeedBonus_Constant()
    if self.isBuff then 
        return self:GetAbility():GetSpecialValueFor("bonus_attack_speed")
    end
end
 