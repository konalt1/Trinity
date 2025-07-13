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
    
    print("=== Mind Power Modifier Created ===")
    print("Hero: " .. self:GetParent():GetUnitName())
    print("Hero Level: " .. self:GetParent():GetLevel())
    print("Intelligence: " .. self:GetParent():GetIntellect(false))
    print("==================================")
    
    -- Запускаем проверку каждые 0.1 секунды для обновления значения
    self:StartIntervalThink(0.1)
    
    -- Воспроизводим эффект при создании баффа
    self:PlayEffects()
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
    
    -- Отладочная информация только при наличии бонусов
    if base_mind_power > 0 or item_bonus > 0 or local_bonus > 0 then
        print("Mind Power for " .. unit:GetUnitName() .. ": Base=" .. base_mind_power .. 
              ", Int=" .. intelligence_bonus .. 
              ", Items=" .. item_bonus .. 
              ", Local=" .. local_bonus .. 
              ", Total=" .. total_mind_power .. 
              ", Display=" .. display_value)
    else
        -- Показываем базовую информацию даже без бонусов
        print("Mind Power for " .. unit:GetUnitName() .. ": Base=" .. base_mind_power .. 
              ", Int=" .. intelligence_bonus .. 
              ", Items=" .. item_bonus .. 
              ", Local=" .. local_bonus .. 
              ", Total=" .. total_mind_power .. 
              ", Display=" .. display_value)
    end
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

-- Функция для отображения правильного значения Mind Power в интерфейсе
function modifier_mind_power:GetModifierStackCount()
    -- Возвращаем текущее значение стека, которое устанавливается в OnIntervalThink
    return self:GetStackCount()
end

function modifier_mind_power:OnDestroy()
    if not IsServer() then
        return
    end
    
    print("Mind Power: Modifier destroyed for " .. self:GetParent():GetUnitName() .. " with stack: " .. self:GetStackCount())
end 