-- Trinity: Ballista (в ванилле нейтралка, выведенная из игры). Собирается: Dragon Lance + Grove Bow + рецепт.
-- Наследует эффекты обоих компонентов:
--   * Статы Dragon Lance (сила, ловкость) и Grove Bow (интеллект, ловкость, скорость атаки) - суммой.
--   * Дальность атаки только дальникам (bonus_attack_range_ranged) выдаёт общий модификатор
--     items/item_ranged_attack_range.lua (не складывается с Grove Bow / Паразмой / Dragon Lance / Hurricane Pike).
--   * Пассив Grove Bow: атаки снижают сопротивление магии цели на magic_resistance_reduction% на debuff_duration сек.
--     С ванильным дебаффом Grove Bow не складывается.
--   * Ванильный пассив Баллисты: атака отталкивает цель на knockback_distance за knockback_duration сек.
--     Иллюзии не отталкивают; древних (боссы, Рошан) не отталкивает. Чистый урон с атак не наносится.
-- Значения берутся из KV (npc_items_custom.txt, "item_ballista").

LinkLuaModifier("modifier_item_ballista_trinity", "items/item_ballista_trinity", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_ballista_trinity_debuff", "items/item_ballista_trinity", LUA_MODIFIER_MOTION_NONE)

item_ballista = class({})

function item_ballista:GetIntrinsicModifierName()
    return "modifier_item_ballista_trinity"
end

--------------------------------------------------------------------------------
-- Пассив: статы + снижение сопротивления магии атаками
--------------------------------------------------------------------------------

modifier_item_ballista_trinity = class({
    IsHidden      = function(self) return true end,
    IsPurgable    = function(self) return false end,
    RemoveOnDeath = function(self) return false end,
    GetAttributes = function(self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
})

function modifier_item_ballista_trinity:OnCreated()
    local ability = self:GetAbility()
    if not ability then return end
    self.strength = ability:GetSpecialValueFor("bonus_strength")
    self.agility = ability:GetSpecialValueFor("bonus_agility")
    self.intellect = ability:GetSpecialValueFor("bonus_intellect")
    self.attack_speed = ability:GetSpecialValueFor("bonus_attack_speed")
    self.mres_reduction = ability:GetSpecialValueFor("magic_resistance_reduction")
    self.debuff_duration = ability:GetSpecialValueFor("debuff_duration")
    self.knockback_distance = ability:GetSpecialValueFor("knockback_distance")
    self.knockback_duration = ability:GetSpecialValueFor("knockback_duration")
end

function modifier_item_ballista_trinity:OnRefresh()
    self:OnCreated()
end

function modifier_item_ballista_trinity:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
        MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
        MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_EVENT_ON_ATTACK_LANDED,
    }
end

function modifier_item_ballista_trinity:GetModifierBonusStats_Strength()
    return self.strength or 0
end

function modifier_item_ballista_trinity:GetModifierBonusStats_Agility()
    return self.agility or 0
end

function modifier_item_ballista_trinity:GetModifierBonusStats_Intellect()
    return self.intellect or 0
end

function modifier_item_ballista_trinity:GetModifierAttackSpeedBonus_Constant()
    return self.attack_speed or 0
end

function modifier_item_ballista_trinity:OnAttackLanded(params)
    if not IsServer() then return end
    local parent = self:GetParent()
    if params.attacker ~= parent then return end
    -- Несколько Баллист не дают несколько дебаффов: срабатывает только первый модификатор.
    if parent:FindModifierByName(self:GetName()) ~= self then return end

    local target = params.target
    if not target or target:IsNull() or not target:IsAlive() then return end
    if target:IsBuilding() or target:IsOther() then return end
    if target:GetTeamNumber() == parent:GetTeamNumber() then return end

    local ability = self:GetAbility()
    target:AddNewModifier(parent, ability, "modifier_item_ballista_trinity_debuff", {
        duration = self.debuff_duration,
        reduction = self.mres_reduction,
    })

    if parent:IsIllusion() then return end
    if target:IsAncient() or (self.knockback_distance or 0) <= 0 then return end
    local origin = parent:GetAbsOrigin()
    target:AddNewModifier(parent, ability, "modifier_knockback", {
        center_x = origin.x,
        center_y = origin.y,
        center_z = origin.z,
        knockback_distance = self.knockback_distance,
        knockback_duration = self.knockback_duration,
        knockback_height = 0,
        should_stun = 0,
        duration = self.knockback_duration,
    })
end

--------------------------------------------------------------------------------
-- Дебафф: снижение сопротивления магии
--------------------------------------------------------------------------------

modifier_item_ballista_trinity_debuff = class({
    IsHidden      = function(self) return false end,
    IsDebuff      = function(self) return true end,
    IsPurgable    = function(self) return true end,
    GetTexture    = function(self) return "item_ballista" end,
})

function modifier_item_ballista_trinity_debuff:OnCreated(kv)
    self.reduction = 0
    if not IsServer() then return end
    self.reduction = kv.reduction or 0
    self:SetHasCustomTransmitterData(true)
end

function modifier_item_ballista_trinity_debuff:OnRefresh(kv)
    if not IsServer() then return end
    self.reduction = kv.reduction or self.reduction
    self:SendBuffRefreshToClients()
end

function modifier_item_ballista_trinity_debuff:AddCustomTransmitterData()
    return { reduction = self.reduction }
end

function modifier_item_ballista_trinity_debuff:HandleCustomTransmitterData(data)
    self.reduction = data.reduction or 0
end

function modifier_item_ballista_trinity_debuff:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
    }
end

function modifier_item_ballista_trinity_debuff:GetModifierMagicalResistanceBonus()
    -- С ванильным дебаффом Grove Bow не складывается.
    if self:GetParent():HasModifier("modifier_item_grove_bow_debuff") then
        return 0
    end
    return -(self.reduction or 0)
end
