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

end

function modifier_mind_power:OnIntervalThink()
    local unit = self:GetParent()
    local total = GetHeroMindPower(unit)
    local display_value = math.max(0, math.min(total, 999))
    self:SetStackCount(display_value)
end


function modifier_mind_power:GetTexture()
    return "phantom_assassin_coup_de_grace"
end

-- Функция для отображения правильного значения Mind Power в интерфейсе
function modifier_mind_power:GetModifierStackCount()
    -- Возвращаем текущее значение стека, которое устанавливается в OnIntervalThink
    return self:GetStackCount()
end

function modifier_mind_power:OnDestroy()
    if not IsServer() then
        return
    end
end 