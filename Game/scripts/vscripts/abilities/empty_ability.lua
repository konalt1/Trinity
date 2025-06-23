LinkLuaModifier("modifier_empty_ability", "abilities/empty_ability", LUA_MODIFIER_MOTION_NONE)

empty_ability = class({})

function empty_ability:GetIntrinsicModifierName()
    return "modifier_empty_ability"
end

-- Модификатор с цифрой "1"
modifier_empty_ability = class({
    IsHidden = function(self) return false end,
    IsPurgable = function(self) return false end,
    IsBuff = function(self) return true end,
    RemoveOnDeath = function(self) return false end,
    DeclareFunctions = function(self) return {
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
        MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,
    } end,
})

function modifier_empty_ability:OnCreated()
    if not IsServer() then
        return
    end
    local parent = self:GetParent()
    if parent and parent.GetPhysicalArmorBaseValue then
        self.base_armor = parent:GetPhysicalArmorBaseValue()
    else
        self.base_armor = 0
    end
    self:StartIntervalThink(0.2)
end

function modifier_empty_ability:OnIntervalThink()
    local parent = self:GetParent()
    if parent and parent.GetAgility then
        self:SetStackCount(parent:GetAgility())
    end
end

function modifier_empty_ability:GetModifierPhysicalArmorBonus()
    local debuff = -self:GetStackCount() * 0.16
    if self.base_armor then
        debuff = math.max(debuff, -self.base_armor)
    end
    return debuff
end

function modifier_empty_ability:GetModifierMoveSpeedBonus_Constant()
    return self:GetStackCount()
end

function modifier_empty_ability:GetTexture()
    return "phantom_assassin_coup_de_grace"
end 