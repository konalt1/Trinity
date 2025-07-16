-- Mind Power Local Buff Modifier
-- Используется способностью Doom Soul Devour для накопления бонуса Mind Power
-- Бонус сохраняется до конца игры

print("Loading mind_power_local_buff.lua")

LinkLuaModifier("modifier_mind_power_local_buff", "abilities/mind_power_local_buff", LUA_MODIFIER_MOTION_NONE)

print("Registered modifier_mind_power_local_buff")

modifier_mind_power_local_buff = class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_mind_power_local_buff:IsHidden()
    return false
end

function modifier_mind_power_local_buff:IsDebuff()
    return false
end

function modifier_mind_power_local_buff:IsPurgable()
    return false
end

function modifier_mind_power_local_buff:GetAttributes()
    return MODIFIER_ATTRIBUTE_MULTIPLE
end

function modifier_mind_power_local_buff:RemoveOnDeath()
    return false
end

function modifier_mind_power_local_buff:IsPermanent()
    return true
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_mind_power_local_buff:OnCreated()
    print("Mind Power Local Buff: OnCreated called")
    if not IsServer() then 
        print("Mind Power Local Buff: Not server, returning")
        return 
    end
    
    self.mind_power_bonus = self:GetStackCount()
    print("Mind Power Local Buff: Created with +" .. self.mind_power_bonus .. " for " .. self:GetParent():GetUnitName())
end

function modifier_mind_power_local_buff:OnRefresh()
    if not IsServer() then return end
    
    self.mind_power_bonus = self:GetStackCount()
    print("Mind Power Local Buff: Updated to +" .. self.mind_power_bonus .. " for " .. self:GetParent():GetUnitName())
end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_mind_power_local_buff:GetModifierMindPowerBonus()
    return self.mind_power_bonus or 0
end

function modifier_mind_power_local_buff:GetTexture()
    return "doom_bringer_devour"
end

function modifier_mind_power_local_buff:GetEffectName()
    return "particles/units/heroes/hero_doom_bringer/doom_bringer_devour_aura.vpcf"
end

function modifier_mind_power_local_buff:GetEffectAttachType()
    return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_mind_power_local_buff:GetModifierDisplayName()
    return "Soul Power"
end

function modifier_mind_power_local_buff:GetModifierDescription()
    return "Increases Mind Power by " .. (self.mind_power_bonus or 0) .. " through devoured souls."
end 