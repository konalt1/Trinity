-- Trinity: Minotaur Horn (Lua-версия ванильной нейтралки, покупается: Broadsword + Shawl + рецепт).
--   * Пассив: бонус к урону и сопротивление магии (от компонентов).
--   * Активка: иммунитет к магии на duration секунд (ванильный модификатор BKB).
-- Значения берутся из KV (npc_items_custom.txt, "item_minotaur_horn").

LinkLuaModifier("modifier_item_minotaur_horn_trinity", "items/item_minotaur_horn_trinity", LUA_MODIFIER_MOTION_NONE)

item_minotaur_horn = class({})

function item_minotaur_horn:Precache(context)
    PrecacheResource("particle", "particles/items_fx/black_king_bar_avatar.vpcf", context)
end

function item_minotaur_horn:GetIntrinsicModifierName()
    return "modifier_item_minotaur_horn_trinity"
end

function item_minotaur_horn:OnSpellStart()
    local caster = self:GetCaster()
    -- Ванильное поведение: слабое (basic) развеивание, а не сильное — 4-й аргумент true.
    caster:Purge(false, true, false, true, false)
    caster:AddNewModifier(caster, self, "modifier_black_king_bar_immune", {
        duration = self:GetSpecialValueFor("duration"),
    })
    EmitSoundOn("DOTA_Item.BlackKingBar.Activate", caster)
end

-- ============================================================
-- Пассив владельца: урон + сопротивление магии
-- ============================================================
modifier_item_minotaur_horn_trinity = class({
    IsHidden      = function(self) return true end,
    IsPurgable    = function(self) return false end,
    RemoveOnDeath = function(self) return false end,
    GetAttributes = function(self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
})

function modifier_item_minotaur_horn_trinity:OnCreated()
    local ability = self:GetAbility()
    self.damage = ability and ability:GetSpecialValueFor("bonus_damage") or 0
    self.magic_resistance = ability and ability:GetSpecialValueFor("bonus_magic_resistance") or 0
end

function modifier_item_minotaur_horn_trinity:OnRefresh()
    self:OnCreated()
end

function modifier_item_minotaur_horn_trinity:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
    }
end

function modifier_item_minotaur_horn_trinity:GetModifierPreAttack_BonusDamage()
    return self.damage
end

function modifier_item_minotaur_horn_trinity:GetModifierMagicalResistanceBonus()
    return self.magic_resistance
end
