print("=== Loading game_managers/config.lua ===")

require("game_managers/xp_think")

function InitGameManagers()
    xp_think()
    GiveAbilitiesToAllHeroes()
end

function GiveAbilitiesToAllHeroes()
    -- Список способностей, которые нужно выдать всем героям
    local abilities_to_give = {
        -- "mind_power",  // Временно отключено
        -- "empty_ability"  // Временно отключено
    }
    
    -- Получаем всех героев
    local heroes = HeroList:GetAllHeroes()
    
    for _, hero in pairs(heroes) do
        if hero:IsRealHero() and not hero:IsNull() then
            -- Выдаем каждую способность
            for _, ability_name in pairs(abilities_to_give) do
                if not hero:HasAbility(ability_name) then
                    hero:AddAbility(ability_name)
                    print("=== Gave ability " .. ability_name .. " to " .. hero:GetUnitName() .. " ===")
                end
            end
        end
    end
    
    print("=== Abilities distribution completed ===")
end