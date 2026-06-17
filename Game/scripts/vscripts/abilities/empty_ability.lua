LinkLuaModifier("modifier_empty_ability", "abilities/empty_ability", LUA_MODIFIER_MOTION_NONE)



empty_ability = class({})



function empty_ability:GetIntrinsicModifierName()

    return "modifier_empty_ability"

end



modifier_empty_ability = class({

    IsHidden = function(self) return true end,

    IsPurgable = function(self) return false end,

    IsBuff = function(self) return true end,

    RemoveOnDeath = function(self) return false end,

    DeclareFunctions = function(self) return {

        MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,

    } end,

})



function modifier_empty_ability:OnCreated()

    if not IsServer() then

        return

    end

    self.reward_accumulator = 0

    self:StartIntervalThink(0.2)

end



function modifier_empty_ability:OnIntervalThink()

    if not IsServer() then

        return

    end

    local parent = self:GetParent()

    if not parent then

        return

    end



    if parent.GetAgility then

        self:SetStackCount(parent:GetAgility())

    end



    self.reward_accumulator = self.reward_accumulator + 0.2

    if self.reward_accumulator >= 1.0 and parent:IsAlive() then

        self.reward_accumulator = self.reward_accumulator - 1.0

        parent:AddExperience(2, DOTA_ModifyXP_Unspecified, false, false)

        parent:ModifyGold(2, true, DOTA_ModifyGold_Unspecified)

    end

end



function modifier_empty_ability:GetModifierMoveSpeedBonus_Constant()

    return self:GetStackCount() * 0.5

end



function modifier_empty_ability:GetTexture()

    return "phantom_assassin_coup_de_grace"

end


