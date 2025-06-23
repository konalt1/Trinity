print("=== Loading game_managers/config.lua ===")

require("game_managers/xp_think")

-- Настройки способностей - легко включать/отключать
local ABILITY_SETTINGS = {
    MIND_POWER_ENABLED = true,  -- Включено
    EMPTY_ABILITY_ENABLED = true,  -- Включено
}

function InitGameManagers()
    print("=== InitGameManagers called ===")
    xp_think()
    
    -- Добавляем задержку для выдачи способностей
    Timers:CreateTimer(0.1, function()
        GiveAbilitiesToAllHeroes()
    end)
end

function GiveAbilitiesToAllHeroes()
    print("=== GiveAbilitiesToAllHeroes called ===")
    
    -- Список способностей, которые нужно выдать всем героям
    local abilities_to_give = {}
    
    -- Добавляем способности в зависимости от настроек
    if ABILITY_SETTINGS.MIND_POWER_ENABLED then
        table.insert(abilities_to_give, "mind_power")
        print("=== Mind power enabled ===")
    end
    
    if ABILITY_SETTINGS.EMPTY_ABILITY_ENABLED then
        table.insert(abilities_to_give, "empty_ability")
        print("=== Empty ability enabled ===")
    end
    
    -- Если нет способностей для выдачи, выходим
    if #abilities_to_give == 0 then
        print("=== No abilities to distribute ===")
        return
    end
    
    print("=== Abilities to give: " .. table.concat(abilities_to_give, ", ") .. " ===")
    
    -- Получаем всех героев
    local heroes = HeroList:GetAllHeroes()
    print("=== Found " .. #heroes .. " heroes ===")
    
    for _, hero in pairs(heroes) do
        if hero:IsRealHero() and not hero:IsNull() then
            print("=== Processing hero: " .. hero:GetUnitName() .. " ===")
            -- Выдаем каждую способность
            for _, ability_name in pairs(abilities_to_give) do
                if not hero:HasAbility(ability_name) then
                    hero:AddAbility(ability_name)
                    print("=== Gave ability " .. ability_name .. " to " .. hero:GetUnitName() .. " ===")
                else
                    print("=== Hero " .. hero:GetUnitName() .. " already has " .. ability_name .. " ===")
                end
            end
        end
    end
    
    print("=== Abilities distribution completed ===")
end