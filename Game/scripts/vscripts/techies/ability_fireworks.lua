LinkLuaModifier("modifier_fireworks", "techies/ability_fireworks", 0)

ability_fireworks = ability_fireworks or class({})


function ability_fireworks:GetIntrinsicModifierName()
    return "modifier_fireworks"
end

modifier_fireworks = modifier_fireworks or class({})


function modifier_fireworks:OnCreated()
    self.splash_radius = self:GetAbility():GetSpecialValueFor("splash_radius")
    self.splash_percent = self:GetAbility():GetSpecialValueFor("splash_percent")
end

function modifier_fireworks:OnRefresh()
    self:OnCreated()
end


function modifier_fireworks:IsPurgable()
    return false
end

function modifier_fireworks:IsHidden()
    return true
end

function modifier_fireworks:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_ATTACK_LANDED,
        MODIFIER_PROPERTY_ATTACK_RANGE_BONUS,
    }
end

function modifier_fireworks:OnCreated()
    self.bonusAttackRange = self:GetAbility():GetSpecialValueFor("bonus_attack_range")
end

function modifier_fireworks:OnRefresh()
    self:OnCreated()
end

function modifier_fireworks:GetModifierAttackRangeBonus()
    return self.bonusAttackRange
end

function modifier_fireworks:OnAttackLanded(event)
    if (
        IsServer() and
        event.attacker == self:GetParent() and
        not self:GetParent():PassivesDisabled()
    ) then
        local enemies = FindUnitsInRadius(
                self:GetParent():GetTeamNumber(),
                event.target:GetOrigin(),
                nil,
                self.splash_radius,
                DOTA_UNIT_TARGET_TEAM_ENEMY,
                DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
                DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_NOT_NIGHTMARED,	--
                FIND_ANY_ORDER,
                false
        )

        local damage = event.original_damage * self.splash_percent / 100
        for _, unit in pairs(enemies) do
            if unit ~= event.target then
                ApplyDamage({
                    victim = unit,
                    attacker = self:GetParent(),
                    damage = damage,
                    damage_type = DAMAGE_TYPE_MAGICAL,
                    ability = self:GetAbility(),
                })
            end
        end
    end
end