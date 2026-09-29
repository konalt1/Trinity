-- Trinity: Chipped Vest (Lua-версия ванильной нейтралки, покупается: Chainmail + Blades of Attack).
--   * Пассив: броня и урон (от компонентов).
--   * Пассив: атакующий враг получает damage_return_hero / damage_return_creep физического урона.
-- Входит в Blade Mail. Значения берутся из KV (npc_items_custom.txt, "item_chipped_vest").

LinkLuaModifier("modifier_item_chipped_vest_trinity", "items/item_chipped_vest_trinity", LUA_MODIFIER_MOTION_NONE)

item_chipped_vest = class({})

function item_chipped_vest:GetIntrinsicModifierName()
    return "modifier_item_chipped_vest_trinity"
end

modifier_item_chipped_vest_trinity = class({
    IsHidden      = function(self) return true end,
    IsPurgable    = function(self) return false end,
    RemoveOnDeath = function(self) return false end,
    GetAttributes = function(self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
})

function modifier_item_chipped_vest_trinity:OnCreated()
    local ability = self:GetAbility()
    if not ability then return end
    self.armor = ability:GetSpecialValueFor("bonus_armor")
    self.damage = ability:GetSpecialValueFor("bonus_damage")
    self.return_hero = ability:GetSpecialValueFor("damage_return_hero")
    self.return_creep = ability:GetSpecialValueFor("damage_return_creep")
end

function modifier_item_chipped_vest_trinity:OnRefresh()
    self:OnCreated()
end

function modifier_item_chipped_vest_trinity:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        MODIFIER_EVENT_ON_ATTACK_LANDED,
    }
end

function modifier_item_chipped_vest_trinity:GetModifierPhysicalArmorBonus()
    return self.armor
end

function modifier_item_chipped_vest_trinity:GetModifierPreAttack_BonusDamage()
    return self.damage
end

function modifier_item_chipped_vest_trinity:OnAttackLanded(params)
    if not IsServer() then return end
    local parent = self:GetParent()
    local attacker = params.attacker
    if params.target ~= parent or parent:IsIllusion() then return end
    if not attacker or attacker:IsNull() or attacker:IsBuilding() or attacker:IsOther() then return end
    if attacker:GetTeamNumber() == parent:GetTeamNumber() then return end
    -- Несколько жилетов не складывают возврат: срабатывает только первый модификатор.
    if parent:FindModifierByName(self:GetName()) ~= self then return end

    ApplyDamage({
        victim = attacker,
        attacker = parent,
        damage = attacker:IsHero() and self.return_hero or self.return_creep,
        damage_type = DAMAGE_TYPE_PHYSICAL,
        damage_flags = DOTA_DAMAGE_FLAG_REFLECTION + DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION + DOTA_DAMAGE_FLAG_NO_SPELL_LIFESTEAL,
        ability = self:GetAbility(),
    })
end
