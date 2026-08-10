LinkLuaModifier("modifier_item_yasha_and_kaya_trinity", "items/item_yasha_and_kaya", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_yasha_combination_armor", "items/item_yasha_and_kaya", LUA_MODIFIER_MOTION_NONE)

local YASHA_ARMOR_ITEMS = {
    item_sange_and_yasha = true,
    item_yasha_and_kaya = true,
}

function EnsureYashaCombinationArmor(hero)
    if not hero or hero:IsNull() or not hero:IsRealHero() or hero:IsIllusion() then
        return
    end

    local modifier = hero:FindModifierByName("modifier_item_yasha_combination_armor")
    if modifier then
        modifier:ForceRefresh()
    else
        hero:AddNewModifier(hero, nil, "modifier_item_yasha_combination_armor", {})
    end
end

item_yasha_and_kaya = class({})

function item_yasha_and_kaya:GetIntrinsicModifierName()
    return "modifier_item_yasha_and_kaya_trinity"
end

modifier_item_yasha_and_kaya_trinity = class({})

function modifier_item_yasha_and_kaya_trinity:IsHidden()
    return true
end

function modifier_item_yasha_and_kaya_trinity:IsPurgable()
    return false
end

function modifier_item_yasha_and_kaya_trinity:RemoveOnDeath()
    return false
end

function modifier_item_yasha_and_kaya_trinity:GetAttributes()
    return MODIFIER_ATTRIBUTE_MULTIPLE
end

function modifier_item_yasha_and_kaya_trinity:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
        MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_MANA_REGEN_TOTAL_PERCENTAGE,
        MODIFIER_PROPERTY_CASTTIME_PERCENTAGE,
    }
end

function modifier_item_yasha_and_kaya_trinity:GetModifierBonusStats_Agility()
    return self:GetItemSpecialValue("bonus_agility")
end

function modifier_item_yasha_and_kaya_trinity:GetModifierBonusStats_Intellect()
    return self:GetItemSpecialValue("bonus_intellect")
end

function modifier_item_yasha_and_kaya_trinity:GetModifierAttackSpeedBonus_Constant()
    return self:GetItemSpecialValue("bonus_attack_speed")
end

function modifier_item_yasha_and_kaya_trinity:GetModifierTotalPercentageManaRegen()
    return self:GetItemSpecialValue("mana_regen_multiplier")
end

function modifier_item_yasha_and_kaya_trinity:GetModifierPercentageCasttime()
    return -self:GetItemSpecialValue("cast_speed_pct")
end

function modifier_item_yasha_and_kaya_trinity:GetItemSpecialValue(name)
    local item = self:GetAbility()
    if not item or item:IsNull() then
        return 0
    end

    return item:GetSpecialValueFor(name)
end

modifier_item_yasha_combination_armor = class({})

function modifier_item_yasha_combination_armor:IsHidden()
    return true
end

function modifier_item_yasha_combination_armor:IsPurgable()
    return false
end

function modifier_item_yasha_combination_armor:RemoveOnDeath()
    return false
end

function modifier_item_yasha_combination_armor:OnCreated()
    if not IsServer() then
        return
    end

    self:UpdateArmorBonus()
    self:StartIntervalThink(0.2)
end

function modifier_item_yasha_combination_armor:OnRefresh()
    if IsServer() then
        self:UpdateArmorBonus()
        self:StartIntervalThink(0.2)
    end
end

function modifier_item_yasha_combination_armor:OnIntervalThink()
    self:UpdateArmorBonus()
end

function modifier_item_yasha_combination_armor:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
    }
end

function modifier_item_yasha_combination_armor:UpdateArmorBonus()
    local hero = self:GetParent()
    local total = 0

    -- Только основные слоты: предметы в рюкзаке не должны давать броню.
    for slot = 0, 5 do
        local item = hero:GetItemInSlot(slot)
        if item and not item:IsNull() and YASHA_ARMOR_ITEMS[item:GetAbilityName()] then
            total = total + item:GetSpecialValueFor("bonus_armor")
        end
    end

    if self:GetStackCount() ~= total then
        self:SetStackCount(total)
    end
end

function modifier_item_yasha_combination_armor:GetModifierPhysicalArmorBonus()
    return self:GetStackCount()
end

-- При script_reload событие npc_spawned не повторяется, поэтому обновляем
-- уже существующих героев прямо при загрузке модуля.
if IsServer() and PlayerResource then
    for player_id = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
        EnsureYashaCombinationArmor(PlayerResource:GetSelectedHeroEntity(player_id))
    end
end
