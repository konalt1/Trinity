LinkLuaModifier("modifier_item_kaya_mind_power", "items/item_kaya_mind_power", LUA_MODIFIER_MOTION_NONE)

item_kaya_mind_power = class({})

function item_kaya_mind_power:GetIntrinsicModifierName()
    return "modifier_item_kaya_mind_power"
end

-- Модификатор для Kaya, который дает бонус к mind power
modifier_item_kaya_mind_power = class({
    IsHidden = function(self) return false end,
    IsPurgable = function(self) return false end,
    IsBuff = function(self) return true end,
    RemoveOnDeath = function(self) return false end,
})

function modifier_item_kaya_mind_power:OnCreated()
    if not IsServer() then
        return
    end
    
    -- Получаем значение mind_power_bonus из предмета
    self.mind_power_bonus = self:GetAbility():GetSpecialValueFor("mind_power_bonus")
end

function modifier_item_kaya_mind_power:OnRefresh()
    if not IsServer() then
        return
    end
    
    -- Обновляем значение при обновлении модификатора
    self.mind_power_bonus = self:GetAbility():GetSpecialValueFor("mind_power_bonus")
end

-- Функция для получения бонуса к mind power
function modifier_item_kaya_mind_power:GetModifierMindPowerBonus()
    return self.mind_power_bonus or 0
end

function modifier_item_kaya_mind_power:GetTexture()
    return "item_kaya"
end

function modifier_item_kaya_mind_power:GetModifierBonusIntellect()
    return self:GetAbility():GetSpecialValueFor("bonus_intellect")
end

function modifier_item_kaya_mind_power:GetModifierConstantManaRegen()
    return self:GetAbility():GetSpecialValueFor("mana_regen_multiplier")
end

function modifier_item_kaya_mind_power:GetModifierSpellLifesteal()
    return self:GetAbility():GetSpecialValueFor("spell_lifesteal_amp")
end 