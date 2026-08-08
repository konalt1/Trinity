LinkLuaModifier("modifier_mind_power", "abilities/mind_power", LUA_MODIFIER_MOTION_NONE)

require("game_managers/custom_ability_tooltips")

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
    self.synced_mind_power = 0
    if not IsServer() then return end

    self:SetHasCustomTransmitterData(true)
    -- Запускаем проверку каждые 0.1 секунды для обновления значения
    self:StartIntervalThink(0.1)
end

function modifier_mind_power:OnIntervalThink()
    local unit = self:GetParent()
    local total = GetHeroMindPower(unit)
    local display_value = math.max(0, math.min(total, 999))
    self:SetStackCount(display_value)

    if self.last_net_table_value ~= total then
        self.last_net_table_value = total
        self.synced_mind_power = total
        CustomNetTables:SetTableValue("mind_power", tostring(unit:entindex()), {
            value = total,
        })
        self:SendBuffRefreshToClients()
    end
end

function modifier_mind_power:AddCustomTransmitterData()
    return {
        mind_power = self.synced_mind_power or 0,
    }
end

function modifier_mind_power:HandleCustomTransmitterData(data)
    self.synced_mind_power = tonumber(data and data.mind_power) or 0
end

function modifier_mind_power:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL,
        MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL_VALUE,
    }
end

function modifier_mind_power:GetModifierOverrideAbilitySpecial(params)
    if IsServer() or not params then return 0 end

    return CustomAbilityTooltips:ShouldOverrideMindPowerSpecial(
        params.ability,
        params.ability_special_value
    ) and 1 or 0
end

function modifier_mind_power:GetModifierOverrideAbilitySpecialValue(params)
    if IsServer() or not params then return 0 end

    return CustomAbilityTooltips:GetMindPowerSpecialValue(
        params.ability,
        params.ability_special_value,
        params.ability_special_level,
        self.synced_mind_power
    ) or 0
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
