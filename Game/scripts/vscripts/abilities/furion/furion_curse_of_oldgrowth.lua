LinkLuaModifier("modifier_furion_curse_of_oldgrowth", "abilities/furion/furion_curse_of_oldgrowth", LUA_MODIFIER_MOTION_NONE)

furion_curse_of_oldgrowth         = class({})
modifier_furion_curse_of_oldgrowth = class({})

function furion_curse_of_oldgrowth:OnSpellStart()
    if not IsServer() then return end
    local target = self:GetCursorTarget()
    target:AddNewModifier(self:GetCaster(), self, "modifier_furion_curse_of_oldgrowth",
        { duration = self:GetSpecialValueFor("curse_duration") })
    local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_furion/furion_sprout_ambient.vpcf", PATTACH_ABSORIGIN_FOLLOW, target)
    ParticleManager:ReleaseParticleIndex(fx)
    EmitSoundOn("Hero_Furion.Sprout", target)
end

function modifier_furion_curse_of_oldgrowth:IsHidden()   return false end
function modifier_furion_curse_of_oldgrowth:IsDebuff()   return true  end
function modifier_furion_curse_of_oldgrowth:IsPurgable()  return true  end

function modifier_furion_curse_of_oldgrowth:GetEffectName()
    return "particles/units/heroes/hero_furion/furion_curse_ambient.vpcf"
end
function modifier_furion_curse_of_oldgrowth:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function modifier_furion_curse_of_oldgrowth:DeclareFunctions()
    return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE, MODIFIER_PROPERTY_PROVIDES_FOW_POSITION }
end
function modifier_furion_curse_of_oldgrowth:GetModifierMoveSpeedBonus_Percentage()
    local a = self:GetAbility(); if not a or a:IsNull() then return 0 end
    return -a:GetSpecialValueFor("slow_pct")
end
function modifier_furion_curse_of_oldgrowth:GetModifierProvidesFOWVision() return 1 end

function modifier_furion_curse_of_oldgrowth:OnCreated()
    if IsServer() then self:StartIntervalThink(1.0) end
end
function modifier_furion_curse_of_oldgrowth:OnIntervalThink()
    if not IsServer() then return end
    local a = self:GetAbility(); if not a or a:IsNull() then return end
    local treeCount = 0
    local ok, trees = pcall(function() return GridNav:GetAllTreesAround(self:GetParent():GetAbsOrigin(), a:GetSpecialValueFor("tree_check_radius"), true) end)
    if ok and trees then treeCount = #trees end
    ApplyDamage({ victim = self:GetParent(), attacker = self:GetCaster(), damage = a:GetSpecialValueFor("curse_damage_base") + a:GetSpecialValueFor("curse_damage_per_tree") * treeCount, damage_type = DAMAGE_TYPE_MAGICAL, ability = a })
end
