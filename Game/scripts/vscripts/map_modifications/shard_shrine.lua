local activeTimer = nil
local heroesInArea = {}  -- таблица героев в зоне
local currentHero = nil

-- Получить количество героев в зоне
local function GetHeroCount()
    local count = 0
    for _, _ in pairs(heroesInArea) do
        count = count + 1
    end
    return count
end

-- Получить любого героя из зоны
local function GetAnyHeroInArea()
    for _, hero in pairs(heroesInArea) do
        if hero and IsValidEntity(hero) then
            return hero
        end
    end
    return nil
end

-- Удалить героя из зоны (при выходе или смерти)
local function RemoveHeroFromArea(hero)
    if not hero then return end
    
    local heroId = hero:GetEntityIndex()
    if not heroesInArea[heroId] then return end  -- герой не в зоне
    
    heroesInArea[heroId] = nil
    print("[Shard Shrine] Hero removed - Heroes in area: " .. GetHeroCount())
    
    -- Если ушёл текущий герой, назначаем нового
    if currentHero == hero then
        currentHero = GetAnyHeroInArea()
        if currentHero then
            print("[Shard Shrine] New hero takes over capture")
        end
    end
    
    -- Отменяем таймер только если зона пуста
    if GetHeroCount() == 0 then
        print("[Shard Shrine] Area empty - Timer cancelled!")
        if activeTimer then
            Timers:RemoveTimer(activeTimer)
            activeTimer = nil
            currentHero = nil
        end
    end
end

-- Обработчик смерти героя
local function OnHeroDeath(event)
    local hero = EntIndexToHScript(event.entindex_killed)
    if hero and hero:IsRealHero() then
        RemoveHeroFromArea(hero)
    end
end

-- Подписываемся на событие смерти
ListenToGameEvent("entity_killed", OnHeroDeath, nil)

function OnStart(trigger)
    local hero = trigger.activator
    if not hero or not hero:IsRealHero() then return end
    
    -- Добавляем героя в таблицу
    local heroId = hero:GetEntityIndex()
    heroesInArea[heroId] = hero
    print("[Shard Shrine] Hero entered - Heroes in area: " .. GetHeroCount())
    
    -- Если таймер уже активен, не запускаем новый
    if activeTimer then
        print("[Shard Shrine] Timer already active, hero added to queue")
        return
    end
    
    currentHero = hero
    local countdown = 5
    print("[Shard Shrine] Timer started - " .. countdown .. " seconds")
    
    activeTimer = Timers:CreateTimer(1.0, function()
        if GetHeroCount() == 0 then
            return nil  -- все герои покинули зону
        end
        
        countdown = countdown - 1
        
        if countdown > 0 then
            print("[Shard Shrine] " .. countdown .. " seconds remaining...")
            return 1.0  -- повторить через 1 секунду
        else
            print("[Shard Shrine] Timer finished! Giving Aghanim's Shard!")
            
            -- Выдаём шард текущему герою (или любому оставшемуся)
            local rewardHero = currentHero
            if not rewardHero or not IsValidEntity(rewardHero) then
                rewardHero = GetAnyHeroInArea()
            end
            
            if rewardHero and IsValidEntity(rewardHero) then
                rewardHero:AddItemByName("item_aghanims_shard")
            end
            
            activeTimer = nil
            currentHero = nil
            return nil  -- остановить таймер
        end
    end)
end

function OnEnd(trigger)
    local hero = trigger.activator
    if not hero or not hero:IsRealHero() then return end
    
    RemoveHeroFromArea(hero)
end

