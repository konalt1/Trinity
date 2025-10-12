LinkLuaModifier("modifier_mind_power_buff", "abilities/mind_power_buff", LUA_MODIFIER_MOTION_NONE)

mind_power_buff = class({})

function mind_power_buff:OnSpellStart()
    local caster = self:GetCaster()
    local target = self:GetCursorTarget()
    local duration = self:GetSpecialValueFor("duration")
    local mind_power_bonus = self:GetSpecialValueFor("mind_power_bonus")
    
    -- Накладываем модификатор на цель
    target:AddNewModifier(
        caster,
        self,
        "modifier_mind_power_buff",
        {duration = duration}
    )
    
    -- Воспроизводим эффекты
    self:PlayEffects(target)
end


-- Модификатор для временного бонуса к mind power
modifier_mind_power_buff = class({
    IsHidden = function(self) return false end,
    IsPurgable = function(self) return true end,
    IsBuff = function(self) return true end,
    RemoveOnDeath = function(self) return true end,
})

function modifier_mind_power_buff:OnCreated()
    if not IsServer() then
        return
    end
    
    -- Получаем значение бонуса из способности
    self.mind_power_bonus = self:GetAbility():GetSpecialValueFor("mind_power_bonus")
end

function modifier_mind_power_buff:OnRefresh()
    if not IsServer() then
        return
    end
    
    -- Обновляем значение при обновлении модификатора
    self.mind_power_bonus = self:GetAbility():GetSpecialValueFor("mind_power_bonus")
end

-- Функция для получения бонуса к mind power
function modifier_mind_power_buff:GetModifierMindPowerBonus()
    return self.mind_power_bonus or 0
end

function modifier_mind_power_buff:GetTexture()
    return "phantom_assassin_coup_de_grace"
end

function modifier_mind_power_buff:GetEffectName()
    return "particles/generic_gameplay/generic_buff.vpcf"
end

function modifier_mind_power_buff:GetEffectAttachType()
    return PATTACH_ABSORIGIN_FOLLOW
end 