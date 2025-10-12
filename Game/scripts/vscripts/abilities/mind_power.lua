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
    
    -- 1. Базовый Mind Power (из KV файла способности)
    local base_mind_power = 0
    local mind_power_ability = unit:FindAbilityByName("mind_power")
    if mind_power_ability then
        base_mind_power = mind_power_ability:GetSpecialValueFor("base_mind_power") or 0
    end
    
    -- 2. Бонус от интеллекта (1 единица Mind Power за каждую единицу интеллекта)
    local intelligence_bonus = unit:GetIntellect(false)
    
    -- 3. Бонусы от предметов
    local item_bonus = 0
    local item_details = {}
    for i = 0, 8 do
        local item = unit:GetItemInSlot(i)
        if item then
            local mind_power_bonus_value = item:GetSpecialValueFor("mind_power_bonus")
            if mind_power_bonus_value and mind_power_bonus_value > 0 then
                item_bonus = item_bonus + mind_power_bonus_value
                table.insert(item_details, {name = item:GetName(), bonus = mind_power_bonus_value})
            end
        end
    end
    
    -- 4. Локальные бонусы от других модификаторов (кроме самого modifier_mind_power)
    local local_bonus = 0
    local modifier_details = {}
    for _, modifier in pairs(unit:FindAllModifiers()) do
        if modifier.GetModifierMindPowerBonus and modifier ~= self then
            local bonus = modifier:GetModifierMindPowerBonus()
            if bonus and bonus > 0 then
                local_bonus = local_bonus + bonus
                local modifier_name = modifier:GetName() or "unknown"
                local is_permanent = not modifier.IsPurgable or not modifier:IsPurgable()
                table.insert(modifier_details, {
                    name = modifier_name, 
                    bonus = bonus, 
                    permanent = is_permanent
                })
            end
        end
    end
    
    -- Итоговое значение mind power
    local total_mind_power = base_mind_power + intelligence_bonus + item_bonus + local_bonus
    
    -- Ограничиваем значение для корректного отображения (максимум 999)
    local display_value = math.min(total_mind_power, 999)
    
    -- Устанавливаем значение в стек для отображения в интерфейсе
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