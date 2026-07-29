require("game_managers/xp_think")

-- Настройки способностей - легко включать/отключать
local ABILITY_SETTINGS = {
    MIND_POWER_ENABLED = true,  -- Включено
    EMPTY_ABILITY_ENABLED = true,  -- Включено
}

function InitGameManagers()
    xp_think()
    
    -- Добавляем задержку для выдачи способностей
    Timers:CreateTimer(0.1, function()
        GiveAbilitiesToAllHeroes()
    end)
end

function GiveAbilitiesToAllHeroes()
    -- Список способностей, которые нужно выдать всем героям
    local abilities_to_give = {}
    
    -- Добавляем способности в зависимости от настроек
    if ABILITY_SETTINGS.MIND_POWER_ENABLED then
        table.insert(abilities_to_give, "mind_power")
    end
    
    if ABILITY_SETTINGS.EMPTY_ABILITY_ENABLED then
        table.insert(abilities_to_give, "empty_ability")
    end
    
    -- Если нет способностей для выдачи, выходим
    if #abilities_to_give == 0 then
        return
    end
    
    -- Получаем всех героев
    local heroes = HeroList:GetAllHeroes()
    
    for _, hero in pairs(heroes) do
        if hero:IsRealHero() and not hero:IsNull() then
            -- Выдаем каждую способность
            for _, ability_name in pairs(abilities_to_give) do
                if not hero:HasAbility(ability_name) then
                    hero:AddAbility(ability_name)
                end
            end
        end
    end
    
end
