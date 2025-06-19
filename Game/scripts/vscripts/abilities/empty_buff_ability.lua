LinkLuaModifier("modifier_empty_buff_ability", "abilities/empty_buff_ability", LUA_MODIFIER_MOTION_NONE)

empty_buff_ability = class({})

function empty_buff_ability:GetIntrinsicModifierName()
    return "modifier_empty_buff_ability"
end

-- Постоянный бафф модификатор (видимый в окошке модификаторов)
modifier_empty_buff_ability = class({
    IsHidden = function(self) return false end,
    IsPurgable = function(self) return false end,
    IsBuff = function(self) return true end,
    RemoveOnDeath = function(self) return false end,
})

function modifier_empty_buff_ability:OnCreated()
    if not IsServer() then
        return
    end
    
    -- Устанавливаем стек модификатора в 1 (отображается как цифра на баффе)
    self:SetStackCount(1)
    
    -- Воспроизводим эффект при создании баффа
    self:PlayEffects()
end

function modifier_empty_buff_ability:PlayEffects()
    local particle_cast = "particles/generic_gameplay/generic_buff.vpcf"
    local sound_cast = "Hero_Omniknight.Purification"
    
    -- Создаем частицы
    local effect_cast = ParticleManager:CreateParticle(particle_cast, PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
    ParticleManager:SetParticleControl(effect_cast, 0, self:GetParent():GetOrigin())
    ParticleManager:ReleaseParticleIndex(effect_cast)
    
    -- Воспроизводим звук
    EmitSoundOn(self:GetParent(), sound_cast)
end

function modifier_empty_buff_ability:GetTexture()
    return "phantom_assassin_coup_de_grace"
end 