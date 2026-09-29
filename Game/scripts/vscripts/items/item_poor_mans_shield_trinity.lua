-- Trinity: Poor Man's Shield (Lua-версия ванильной нейтралки, покупается: Ring of Regen + Fluffy Hat + рецепт).
--   * Пассив: здоровье и регенерация (от компонентов).
--   * Пассив: блок урона от атак (block_chance против героев — block_chance_hero).
--     Не работает вместе с Vanguard / Crimson Guard: блок в Dota не складывается.
-- Входит в Vanguard. Значения берутся из KV (npc_items_custom.txt, "item_poor_mans_shield").

LinkLuaModifier("modifier_item_poor_mans_shield_trinity", "items/item_poor_mans_shield_trinity", LUA_MODIFIER_MOTION_NONE)

local STRONGER_BLOCK = {
    "modifier_item_vanguard",
    "modifier_item_crimson_guard",
}

item_poor_mans_shield = class({})

function item_poor_mans_shield:GetIntrinsicModifierName()
    return "modifier_item_poor_mans_shield_trinity"
end

modifier_item_poor_mans_shield_trinity = class({
    IsHidden      = function(self) return true end,
    IsPurgable    = function(self) return false end,
    RemoveOnDeath = function(self) return false end,
    GetAttributes = function(self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
})

function modifier_item_poor_mans_shield_trinity:OnCreated()
    local ability = self:GetAbility()
    if not ability then return end
    self.health = ability:GetSpecialValueFor("bonus_health")
    self.regen = ability:GetSpecialValueFor("bonus_health_regen")
    self.block_melee = ability:GetSpecialValueFor("damage_block_melee")
    self.block_ranged = ability:GetSpecialValueFor("damage_block_ranged")
    self.chance = ability:GetSpecialValueFor("block_chance")
    self.chance_hero = ability:GetSpecialValueFor("block_chance_hero")
end

function modifier_item_poor_mans_shield_trinity:OnRefresh()
    self:OnCreated()
end

function modifier_item_poor_mans_shield_trinity:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_HEALTH_BONUS,
        MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
        MODIFIER_PROPERTY_PHYSICAL_CONSTANT_BLOCK,
    }
end

function modifier_item_poor_mans_shield_trinity:GetModifierHealthBonus()
    return self.health
end

function modifier_item_poor_mans_shield_trinity:GetModifierConstantHealthRegen()
    return self.regen
end

function modifier_item_poor_mans_shield_trinity:GetModifierPhysical_ConstantBlock(params)
    if not IsServer() then return 0 end
    local parent = self:GetParent()
    if params.inflictor then return 0 end
    if params.damage_category and params.damage_category ~= DOTA_DAMAGE_CATEGORY_ATTACK then return 0 end
    if parent:FindModifierByName(self:GetName()) ~= self then return 0 end
    for _, name in ipairs(STRONGER_BLOCK) do
        if parent:HasModifier(name) then return 0 end
    end

    local attacker = params.attacker
    local chance = (attacker and not attacker:IsNull() and attacker:IsHero()) and self.chance_hero or self.chance
    if not RollPercentage(chance) then return 0 end
    return parent:IsRangedAttacker() and self.block_ranged or self.block_melee
end
