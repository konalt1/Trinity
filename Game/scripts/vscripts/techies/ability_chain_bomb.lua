LinkLuaModifier("modifier_unit_chain_bomb", "techies/ability_chain_bomb", 0)
LinkLuaModifier("modifier_unit_damage_listener", "techies/ability_chain_bomb", 0)

ability_chain_bomb = ability_chain_bomb or class({})

function ability_chain_bomb:OnCreated()
end

function ability_chain_bomb:OnSpellStart()
    CreateUnitByNameAsync(
            "npc_dota3_chainbomb",
            self:GetCursorPosition(),
            true,
            nil,
            nil,
            self:GetCaster():GetTeam(),
            function (bomb)
                self:OnBombCreated(bomb)
            end
    )
end

function ability_chain_bomb:OnBombCreated(bomb)
    local duration = 300

    local listener = CreateUnitByName("npc_dota_damage_listener", bomb:GetOrigin(), true, nil, nil, DOTA_TEAM_NOTEAM)
    listener:AddNewModifier(listener, self, "modifier_kill", { duration = duration })
    listener:AddNewModifier(listener, self, "modifier_unit_damage_listener", nil)
    bomb.listener = listener;

    bomb:AddNewModifier(bomb, self, "modifier_kill", { duration = duration })
    bomb:AddNewModifier(bomb, self, "modifier_unit_chain_bomb", nil)
end

modifier_unit_chain_bomb = modifier_unit_chain_bomb or class({
    IsHidden                = function(self) return false end,
    IsPurgable              = function(self) return false end,
})

function modifier_unit_chain_bomb:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_DEATH,
        MODIFIER_PROPERTY_PERSISTENT_INVISIBILITY,
        MODIFIER_PROPERTY_INVISIBILITY_LEVEL,
    }
end

function modifier_unit_chain_bomb:GetModifierPersistentInvisibility()
    return 1
end

function modifier_unit_chain_bomb:GetModifierInvisibilityLevel()
    return 1
end

function modifier_unit_chain_bomb:OnDeath(event)
    if (
            IsServer() and
            event.unit == self:GetParent()
    ) then
        local units = FindUnitsInRadius(
                self:GetAbility():GetCaster():GetTeam(),
                event.unit:GetOrigin(),
                nil,
                400,
                DOTA_UNIT_TARGET_TEAM_ENEMY,
                DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
                DOTA_UNIT_TARGET_FLAG_NONE,
                FIND_ANY_ORDER,
                false
        )
        local pos = self:GetParent():GetOrigin()
        local fx = ParticleManager:CreateParticle(
                "particles/units/heroes/hero_techies/techies_blast_off.vpcf",
                PATTACH_CUSTOMORIGIN,
                self:GetParent()
        )
        ParticleManager:SetParticleControl(fx, 0, pos)
        ParticleManager:ReleaseParticleIndex(fx)

        for _, unit in ipairs(units) do
            ApplyDamage({
                victim = unit,
                attacker = self:GetAbility():GetCaster(),
                damage = self:GetAbility():GetSpecialValueFor("damage"),
                damage_type = DAMAGE_TYPE_MAGICAL,
                ability = self:GetAbility()
            })
        end
    end
end

function modifier_unit_chain_bomb:CheckState()
    return {
        [MODIFIER_STATE_NO_UNIT_COLLISION] = true,
        [MODIFIER_STATE_LOW_ATTACK_PRIORITY] = true,
        [MODIFIER_STATE_NOT_ON_MINIMAP] = true,
        [MODIFIER_STATE_SPECIALLY_DENIABLE] = true,
        [MODIFIER_STATE_NO_HEALTH_BAR] = true,
    }
end


modifier_unit_damage_listener = modifier_unit_damage_listener or class({
    IsHidden                = function(self) return true end,
    IsPurgable              = function(self) return false end,
})

function modifier_unit_damage_listener:CheckState()
    return {
        [MODIFIER_STATE_NO_UNIT_COLLISION] = true,
        [MODIFIER_STATE_NOT_ON_MINIMAP] = true,
        [MODIFIER_STATE_NO_HEALTH_BAR] = true,
        [MODIFIER_STATE_UNTARGETABLE] = true,
        [MODIFIER_STATE_UNSELECTABLE] = true,
    }
end

function modifier_unit_damage_listener:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
        MODIFIER_EVENT_ON_DEATH,
    }
end

function modifier_unit_damage_listener:GetModifierIncomingDamage_Percentage(event)
    local caster = self:GetAbility():GetCaster()
    if (
            not IsServer() or
            event.target ~= self:GetParent()
    ) then
        return 0
    end

    -- damage blocked
    if (
            event.attacker ~= caster
    ) then
        return -100
    end

    return 0
end

function modifier_unit_damage_listener:OnDeath(event)
    if (
            IsServer() and
            event.unit == self:GetParent()
    ) then
        local units = FindUnitsInRadius(
                self:GetAbility():GetCaster():GetTeam(),
                event.unit:GetOrigin(),
                nil,
                400,
                DOTA_UNIT_TARGET_TEAM_FRIENDLY,
                DOTA_UNIT_TARGET_BASIC,
                DOTA_UNIT_TARGET_FLAG_NONE,
                FIND_ANY_ORDER,
                false
        )

        for _, unit in ipairs(units) do
            if unit:GetUnitName() == "npc_dota3_chainbomb" then
                ApplyDamage({
                    victim = unit,
                    attacker = self:GetParent(),
                    damage = 1,
                    damage_type = DAMAGE_TYPE_MAGICAL,
                    ability = self:GetAbility()
                })
            end
        end
    end
end
