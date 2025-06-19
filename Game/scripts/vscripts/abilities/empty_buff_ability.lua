LinkLuaModifier("modifier_empty_buff_ability", "abilities/empty_buff_ability", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_empty_buff_ability_buff", "abilities/empty_buff_ability", LUA_MODIFIER_MOTION_NONE)

empty_buff_ability = class({})

function empty_buff_ability:GetIntrinsicModifierName()
    return "modifier_empty_buff_ability"
end

-- Основной модификатор способности (скрытый)
modifier_empty_buff_ability = class({
    IsHidden = function(self) return true end,
    IsPurgable = function(self) return false end,
    RemoveOnDeath = function(self) return false end,
})

function modifier_empty_buff_ability:OnCreated()
    if not IsServer() then
        return
    end
    
    -- Получаем значения из способности
    self.activation_delay = self:GetAbility():GetSpecialValueFor("activation_delay") or 2.0
    
    -- Запускаем проверку каждые 0.1 секунды
    self:StartIntervalThink(0.1)
end

function modifier_empty_buff_ability:OnIntervalThink()
    local unit = self:GetCaster()
    
    -- Проверяем условия для активации баффа
    -- Например, когда герой невидим или использует определенную способность
    if not unit:CanBeSeenByAnyOpposingTeam() then
        self:AddBuff(unit)
    end
end

function modifier_empty_buff_ability:AddBuff(unit)
    if not self.modifier then
        self.modifier = unit:AddNewModifier(
            unit,
            self:GetAbility(),
            "modifier_empty_buff_ability_buff",
            {} -- Убираем duration, чтобы бафф был перманентным
        )
    end
end

-- Бафф модификатор (видимый, перманентный)
modifier_empty_buff_ability_buff = class({
    IsHidden = function(self) return false end,
    IsPurgable = function(self) return false end -- Делаем неочищаемым
    IsBuff = function(self) return true end,
    RemoveOnDeath = function(self) return false end,
})

function modifier_empty_buff_ability_buff:OnCreated()
    if not IsServer() then
        return
    end
    
    -- Получаем значения из способности
    self.bonus_damage = self:GetAbility():GetSpecialValueFor("bonus_damage") or 50
    self.bonus_armor = self:GetAbility():GetSpecialValueFor("bonus_armor") or 5
    
    -- Воспроизводим эффект при создании баффа
    self:PlayEffects()
end

function modifier_empty_buff_ability_buff:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
    }
end

function modifier_empty_buff_ability_buff:GetModifierPreAttack_BonusDamage()
    return self.bonus_damage
end

function modifier_empty_buff_ability_buff:GetModifierPhysicalArmorBonus()
    return self.bonus_armor
end

function modifier_empty_buff_ability_buff:PlayEffects()
    local particle_cast = "particles/generic_gameplay/generic_buff.vpcf"
    local sound_cast = "Hero_Omniknight.Purification"
    
    -- Создаем частицы
    local effect_cast = ParticleManager:CreateParticle(particle_cast, PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
    ParticleManager:SetParticleControl(effect_cast, 0, self:GetParent():GetOrigin())
    ParticleManager:ReleaseParticleIndex(effect_cast)
    
    -- Воспроизводим звук
    EmitSoundOn(self:GetParent(), sound_cast)
end

function modifier_empty_buff_ability_buff:GetTexture()
    return "phantom_assassin_coup_de_grace"
end 