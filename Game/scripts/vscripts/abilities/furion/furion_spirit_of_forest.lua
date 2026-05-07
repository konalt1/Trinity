LinkLuaModifier("modifier_furion_spirit_of_forest", "abilities/furion/furion_spirit_of_forest", LUA_MODIFIER_MOTION_NONE)

furion_spirit_of_forest         = class({})
modifier_furion_spirit_of_forest = class({})

--------------------------------------------------------------------------------
-- Passive ability — выдаёт интринсик-модификатор
--------------------------------------------------------------------------------
function furion_spirit_of_forest:GetIntrinsicModifierName()
    return "modifier_furion_spirit_of_forest"
end

-- На всякий случай: при прокачке — обновляем модификатор
function furion_spirit_of_forest:OnUpgrade()
    local caster = self:GetCaster()
    if not caster or caster:IsNull() then return end

    -- Убеждаемся что модификатор есть
    if not caster:HasModifier("modifier_furion_spirit_of_forest") then
        caster:AddNewModifier(caster, self, "modifier_furion_spirit_of_forest", {})
    end
end

--------------------------------------------------------------------------------
-- Modifier
--------------------------------------------------------------------------------
function modifier_furion_spirit_of_forest:IsHidden()     return false end
function modifier_furion_spirit_of_forest:IsDebuff()     return false end
function modifier_furion_spirit_of_forest:IsPurgable()   return false end
function modifier_furion_spirit_of_forest:RemoveOnDeath() return false end
function modifier_furion_spirit_of_forest:IsAura()       return false end

-- Визуальный эффект — реальная существующая частица из Доты
function modifier_furion_spirit_of_forest:GetEffectName()
    return "particles/units/heroes/hero_furion/furion_spawn_ambient.vpcf"
end

function modifier_furion_spirit_of_forest:GetEffectAttachType()
    return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_furion_spirit_of_forest:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
    }
end

-- Стак = число деревьев рядом (обновляется каждые 0.5 сек)
function modifier_furion_spirit_of_forest:OnCreated()
    self:SetStackCount(0)
    if IsServer() then
        self:StartIntervalThink(0.5)
    end
end

function modifier_furion_spirit_of_forest:OnRefresh()
    -- ничего не делаем, стаки уже обновляются тинком
end

function modifier_furion_spirit_of_forest:OnIntervalThink()
    if not IsServer() then return end

    local ability = self:GetAbility()
    if not ability or ability:IsNull() or ability:GetLevel() == 0 then
        self:SetStackCount(0)
        return
    end

    local parent = self:GetParent()
    if not parent or parent:IsNull() then return end

    local radius = ability:GetSpecialValueFor("tree_radius")

    -- Считаем деревья в радиусе
    local treeCount = 0
    local ok, trees = pcall(function()
        return GridNav:GetAllTreesAround(parent:GetAbsOrigin(), radius, true)
    end)
    if ok and trees then
        treeCount = #trees
    end

    self:SetStackCount(treeCount)
end

-- Бонус урона читается из стаков (уже посчитанных тинком)
function modifier_furion_spirit_of_forest:GetModifierPreAttack_BonusDamage()
    local ability = self:GetAbility()
    if not ability or ability:IsNull() or ability:GetLevel() == 0 then return 0 end
    return ability:GetSpecialValueFor("damage_per_tree") * self:GetStackCount()
end

-- Бонус скорости атаки читается из стаков
function modifier_furion_spirit_of_forest:GetModifierAttackSpeedBonus_Constant()
    local ability = self:GetAbility()
    if not ability or ability:IsNull() or ability:GetLevel() == 0 then return 0 end
    return ability:GetSpecialValueFor("attack_speed_per_tree") * self:GetStackCount()
end
