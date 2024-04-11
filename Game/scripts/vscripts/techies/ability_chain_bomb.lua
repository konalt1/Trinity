LinkLuaModifier("modifier_unit_chain_bomb", "techies/ability_chain_bomb", 0)

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
            DOTA_TEAM_NOTEAM,
            function (bomb)
                local duration = 300
                bomb:AddNewModifier(bomb, self, "modifier_kill", { duration = duration })
                bomb:AddNewModifier(bomb, self, "modifier_unit_chain_bomb", nil)
                bomb:MakeVisibleToTeam(self:GetCaster():GetTeam(), duration)
            end
    )
end

modifier_unit_chain_bomb = modifier_unit_chain_bomb or class({
    IsHidden                = function(self) return false end,
    IsPurgable              = function(self) return false end,
})

function modifier_unit_chain_bomb:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_DEATH,
    }
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
                "particles/units/heroes/hero_techies/techies_remote_mines_detonate.vpcf",
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
        [MODIFIER_STATE_NO_HEALTH_BAR] = true,
        [MODIFIER_STATE_LOW_ATTACK_PRIORITY] = true,
        [MODIFIER_STATE_NOT_ON_MINIMAP] = true,
    }
end
