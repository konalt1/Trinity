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
end


modifier_ward_vampiric_aura = modifier_ward_vampiric_aura or class({
    IsHidden =              function(_) return true end,
    IsPurgable =            function(_) return false end,
    IsAura =                function(_) return true end,
    GetModifierAura =       function(_) return "modifier_ward_vampiric_aura_buff" end,
    GetAuraRadius =         function(self) return self:GetAbility():GetSpecialValueFor("aura_radius") end,
    GetAuraDuration =       function(_) return 2.0 end,
    GetAuraSearchTeam =     function(_) return DOTA_UNIT_TARGET_TEAM_FRIENDLY end,
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
    IsDebuff =         function() return false end,
    IsHidden =         function() return false end,
    DeclareFunctions = function() return { MODIFIER_EVENT_ON_TAKEDAMAGE } end,
})

function modifier_ward_vampiric_aura_buff:OnTakeDamage(event)
    if (
            not IsServer() or
            event.attacker ~= self:GetParent() or
            event.damage_category ~= DOTA_DAMAGE_CATEGORY_ATTACK
    ) then
        return
    end

    local fx = ParticleManager:CreateParticle(
            "particles/generic_gameplay/generic_lifesteal.vpcf",
            PATTACH_ABSORIGIN_FOLLOW,
            self:GetParent()
    )
    ParticleManager:SetParticleControl(fx, 0, self:GetParent():GetAbsOrigin())
    ParticleManager:ReleaseParticleIndex(fx)
    self:GetParent():HealWithParams(
            event.damage * self:GetAbility():GetSpecialValueFor("lifesteal_percent") / 100,
            self:GetAbility(),
            true,
            true,
            self:GetParent(),
            false
    )
end
