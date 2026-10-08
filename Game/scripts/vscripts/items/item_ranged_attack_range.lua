-- Trinity: бонусы предметов (Grove Bow, Паразма, Ballista, BKB, Midas, Fallen Sky, Satanic, Butterfly), которых нет в ванильных C++-модификаторах.
--   * bonus_attack_range_ranged — дальность атаки, только героям дальнего боя.
--     От нескольких предметов не складывается: берётся наибольшее значение, в том числе с учётом
--     ванильной дальности Dragon Lance / Hurricane Pike (Lua добавляет только превышение над ней).
--   * Статы, которые ванильный модификатор предмета не выдаёт (у лука ИНТ и ЛОВ, у Паразмы ЛОВ).
--     Складываются по числу предметов.
-- Значения берутся из KV (npc_items_custom.txt). Считаются только слоты 1–6.
-- Модификатор вешается при изменении инвентаря (gamemode.lua) и живёт на герое постоянно.

LinkLuaModifier("modifier_trinity_item_bonuses", "items/item_ranged_attack_range", LUA_MODIFIER_MOTION_NONE)

TrinityRangedAttackRange = TrinityRangedAttackRange or {}

-- range: читать bonus_attack_range_ranged; int/agi: KV-ключ стата, который выдаёт Lua
-- (ключи, которые уже читает ванильный модификатор предмета, здесь указывать нельзя — будет двойной бонус).
-- mres/armor: сопротивление магии / броня, которые ванильный C++-модификатор предмета не выдаёт.
-- manaamp: усиление восстановления маны в % (от нескольких Lua-предметов не складывается, берётся наибольшее).
-- aspd_active: { key, modifier } — скорость атаки, пока на герое висит модификатор активки предмета (Satanic: Unholy Rage).
-- aspd: постоянная скорость атаки; mspct: скорость бега в % (Butterfly: статы Elven Tunic). Складываются по числу предметов.
TrinityRangedAttackRange.ITEMS = {
    item_grove_bow       = { range = true, int = "bonus_intellect", agi = "bonus_agility" },
    item_devastator      = { range = true, agi = "bonus_agility" },
    item_ballista        = { range = true },                       -- статы выдаёт свой Lua (items/item_ballista_trinity.lua)
    item_black_king_bar  = { mres = "bonus_magic_resistance" },  -- от Minotaur Horn
    item_hand_of_midas   = { armor = "bonus_armor" },            -- от Iron Talon
    item_fallen_sky      = { agi = "bonus_agility", manaamp = "mana_regen_multiplier" }, -- от Meteor Hammer
    item_satanic         = { aspd_active = { key = "unholy_bonus_attack_speed", modifier = "modifier_item_satanic_unholy" } },
    item_butterfly       = { aspd = "trinity_attack_speed", mspct = "trinity_move_speed_pct" }, -- от Elven Tunic
}

TrinityRangedAttackRange.RANGE_KEY = "bonus_attack_range_ranged"

-- Ванильные предметы, чей C++-модификатор сам даёт дальность дальникам (между собой не складываются).
TrinityRangedAttackRange.VANILLA_RANGE_ITEMS = {
    item_dragon_lance   = "base_attack_range",
    item_hurricane_pike = "base_attack_range",
}

function TrinityRangedAttackRange.Ensure(hero)
    if not IsServer() then return end
    if not hero or hero:IsNull() then return end
    if not hero:HasModifier("modifier_trinity_item_bonuses") then
        hero:AddNewModifier(hero, nil, "modifier_trinity_item_bonuses", {})
    end
end

function TrinityRangedAttackRange.Compute(hero)
    local result = { range = 0, int = 0, agi = 0, mres = 0, armor = 0, manaamp = 0, aspd = 0, mspct = 0 }
    if not hero or hero:IsNull() then
        return result
    end

    local ranged = hero:IsRangedAttacker()
    local vanilla_range = 0
    for slot = DOTA_ITEM_SLOT_1, DOTA_ITEM_SLOT_6 do
        local item = hero:GetItemInSlot(slot)
        local name = item and not item:IsNull() and item:GetAbilityName()
        local vanilla_key = ranged and name and TrinityRangedAttackRange.VANILLA_RANGE_ITEMS[name]
        if vanilla_key then
            vanilla_range = math.max(vanilla_range, item:GetSpecialValueFor(vanilla_key) or 0)
        end
        local cfg = name and TrinityRangedAttackRange.ITEMS[name]
        if cfg then
            if cfg.range and ranged then
                result.range = math.max(result.range, item:GetSpecialValueFor(TrinityRangedAttackRange.RANGE_KEY) or 0)
            end
            if cfg.int then
                result.int = result.int + (item:GetSpecialValueFor(cfg.int) or 0)
            end
            if cfg.agi then
                result.agi = result.agi + (item:GetSpecialValueFor(cfg.agi) or 0)
            end
            if cfg.mres then
                result.mres = result.mres + (item:GetSpecialValueFor(cfg.mres) or 0)
            end
            if cfg.armor then
                result.armor = result.armor + (item:GetSpecialValueFor(cfg.armor) or 0)
            end
            if cfg.manaamp then
                result.manaamp = math.max(result.manaamp, item:GetSpecialValueFor(cfg.manaamp) or 0)
            end
            if cfg.aspd_active and hero:HasModifier(cfg.aspd_active.modifier) then
                result.aspd = result.aspd + (item:GetSpecialValueFor(cfg.aspd_active.key) or 0)
            end
            if cfg.aspd then
                result.aspd = result.aspd + (item:GetSpecialValueFor(cfg.aspd) or 0)
            end
            if cfg.mspct then
                result.mspct = result.mspct + (item:GetSpecialValueFor(cfg.mspct) or 0)
            end
        end
    end
    -- Дальность не складывается с ванильной: итог = max(Lua, ванилла), Lua выдаёт только превышение.
    result.range = math.max(result.range - vanilla_range, 0)
    return result
end

modifier_trinity_item_bonuses = class({
    IsHidden        = function(self) return true end,
    IsPurgable      = function(self) return false end,
    IsDebuff        = function(self) return false end,
    RemoveOnDeath   = function(self) return false end,
    GetAttributes   = function(self) return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE end,
})

function modifier_trinity_item_bonuses:OnCreated()
    self.range = 0
    self.int = 0
    self.agi = 0
    self.mres = 0
    self.armor = 0
    self.manaamp = 0
    self.aspd = 0
    self.mspct = 0
    if not IsServer() then return end
    self:SetHasCustomTransmitterData(true)
    self:OnIntervalThink()
    self:StartIntervalThink(0.2)
end

function modifier_trinity_item_bonuses:OnIntervalThink()
    local parent = self:GetParent()
    local v = TrinityRangedAttackRange.Compute(parent)
    if v.range ~= self.range or v.int ~= self.int or v.agi ~= self.agi or v.mres ~= self.mres or v.armor ~= self.armor or v.manaamp ~= self.manaamp or v.aspd ~= self.aspd or v.mspct ~= self.mspct then
        local stats_changed = v.int ~= self.int or v.agi ~= self.agi
        self.range = v.range
        self.int = v.int
        self.agi = v.agi
        self.mres = v.mres
        self.armor = v.armor
        self.manaamp = v.manaamp
        self.aspd = v.aspd
        self.mspct = v.mspct
        self:SendBuffRefreshToClients()
        if stats_changed and parent.CalculateStatBonus then
            parent:CalculateStatBonus(true)
        end
    end
end

function modifier_trinity_item_bonuses:AddCustomTransmitterData()
    return { range = self.range, int = self.int, agi = self.agi, mres = self.mres, armor = self.armor, manaamp = self.manaamp, aspd = self.aspd, mspct = self.mspct }
end

function modifier_trinity_item_bonuses:HandleCustomTransmitterData(data)
    self.range = data.range or 0
    self.int = data.int or 0
    self.agi = data.agi or 0
    self.mres = data.mres or 0
    self.armor = data.armor or 0
    self.manaamp = data.manaamp or 0
    self.aspd = data.aspd or 0
    self.mspct = data.mspct or 0
end

function modifier_trinity_item_bonuses:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_ATTACK_RANGE_BONUS,
        MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
        MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
        MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
        MODIFIER_PROPERTY_MP_REGEN_AMPLIFY_PERCENTAGE,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
    }
end

function modifier_trinity_item_bonuses:GetModifierAttackRangeBonus()
    return self.range or 0
end

function modifier_trinity_item_bonuses:GetModifierBonusStats_Intellect()
    return self.int or 0
end

function modifier_trinity_item_bonuses:GetModifierBonusStats_Agility()
    return self.agi or 0
end

function modifier_trinity_item_bonuses:GetModifierMagicalResistanceBonus()
    return self.mres or 0
end

function modifier_trinity_item_bonuses:GetModifierPhysicalArmorBonus()
    return self.armor or 0
end

function modifier_trinity_item_bonuses:GetModifierMPRegenAmplify_Percentage()
    return self.manaamp or 0
end

function modifier_trinity_item_bonuses:GetModifierAttackSpeedBonus_Constant()
    return self.aspd or 0
end

function modifier_trinity_item_bonuses:GetModifierMoveSpeedBonus_Percentage()
    return self.mspct or 0
end
