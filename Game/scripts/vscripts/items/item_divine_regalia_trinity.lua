-- Trinity: Divine Regalia (в ванилле нейтралка, в Trinity покупается: Demon Edge + Mithril Hammer + рецепт 1000).
--   * Пассив: бонус урона (не меньше суммы компонентов: 40 + 24).
-- Входит в Divine Rapier. Значения берутся из KV (npc_items_custom.txt, "item_divine_regalia").

LinkLuaModifier("modifier_item_divine_regalia_trinity", "items/item_divine_regalia_trinity", LUA_MODIFIER_MOTION_NONE)

item_divine_regalia = class({})

function item_divine_regalia:GetIntrinsicModifierName()
    return "modifier_item_divine_regalia_trinity"
end

modifier_item_divine_regalia_trinity = class({
    IsHidden      = function(self) return true end,
    IsPurgable    = function(self) return false end,
    RemoveOnDeath = function(self) return false end,
    GetAttributes = function(self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
})

function modifier_item_divine_regalia_trinity:OnCreated()
    local ability = self:GetAbility()
    if not ability then return end
    self.damage = ability:GetSpecialValueFor("bonus_damage")
end

function modifier_item_divine_regalia_trinity:OnRefresh()
    self:OnCreated()
end

function modifier_item_divine_regalia_trinity:DeclareFunctions()
    return { MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE }
end

function modifier_item_divine_regalia_trinity:GetModifierPreAttack_BonusDamage()
    return self.damage
end
