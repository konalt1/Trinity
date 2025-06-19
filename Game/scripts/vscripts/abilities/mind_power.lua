LinkLuaModifier("modifier_mind_power", "abilities/mind_power", LUA_MODIFIER_MOTION_NONE)

mind_power = class({})

function mind_power:GetIntrinsicModifierName()
    return "modifier_mind_power"
end

-- Постоянный бафф модификатор (видимый в окошке модификаторов)
modifier_mind_power = class({
    IsHidden = function(self) return false end,
    IsPurgable = function(self) return false end,
    IsBuff = function(self) return true end,
    RemoveOnDeath = function(self) return false end,
})

function modifier_mind_power:OnCreated()
    if not IsServer() then
        return
    end
    
    -- Запускаем проверку каждые 0.1 секунды для обновления значения
    self:StartIntervalThink(0.1)
    
    -- Воспроизводим эффект при создании баффа
    self:PlayEffects()
end

function modifier_mind_power:OnIntervalThink()
    local unit = self:GetCaster()
    
    -- Получаем интеллект героя с бонусами от предметов
    local intelligence = unit:GetIntellect(false)
    
    -- Ограничиваем значение для корректного отображения (максимум 999)
    local display_value = math.min(intelligence, 999)
    
    -- Устанавливаем стек модификатора
    self:SetStackCount(display_value)
    
    -- Отладочная информация в консоль
    print("Intelligence: " .. intelligence .. ", Display value: " .. display_value)
end

function modifier_mind_power:PlayEffects()
    local particle_cast = "particles/generic_gameplay/generic_buff.vpcf"
    local sound_cast = "Hero_Omniknight.Purification"
    
    -- Создаем частицы
    local effect_cast = ParticleManager:CreateParticle(particle_cast, PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
    ParticleManager:SetParticleControl(effect_cast, 0, self:GetParent():GetOrigin())
    ParticleManager:ReleaseParticleIndex(effect_cast)
    
    -- Воспроизводим звук
    EmitSoundOn(self:GetParent(), sound_cast)
end

function modifier_mind_power:GetTexture()
    return "phantom_assassin_coup_de_grace"
end 