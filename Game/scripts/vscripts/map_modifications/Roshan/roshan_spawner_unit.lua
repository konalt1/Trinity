--[[
    Roshan Spawner Unit AI
    
    Этот скрипт прикрепляется к юниту-спавнеру на карте
    и создаёт рошанов по таймеру из своей позиции.
    
    - Первый спавн на 600 секунде (10 минута)
    - Повторный спавн каждые 240 секунд (4 минуты)
    - Не спавнит нового, если предыдущий ещё жив
]]

-- Конфигурация
local SPAWN_INTERVAL = 360                          -- Интервал спавна в секундах (6 минут)
local FIRST_SPAWN_DELAY = 600                     -- Время первого спавна (10 минута)
local ROSHAN_UNIT_NAME = "npc_dota_roshan_pathway"  -- Какого рошана спавним
local VISION_DURATION = 5.0                         -- Длительность обзора при спавне
local VISION_RADIUS = 800                           -- Радиус обзора при спавне

function Spawn(entityKeyValues)
    thisEntity.currentRoshan = nil
    thisEntity.spawnCount = 0
    
    -- Делаем спавнер неуязвимым
    thisEntity:AddNewModifier(thisEntity, nil, "modifier_invulnerable", {})
    
    -- Запускаем спавн после задержки
    Timers:CreateTimer(FIRST_SPAWN_DELAY, function()
        return SpawnRoshanLoop()
    end)
    
    print("[RoshanSpawner] Инициализирован. Первый спавн через " .. FIRST_SPAWN_DELAY .. " сек, затем каждые " .. SPAWN_INTERVAL .. " сек.")
end

function SpawnRoshanLoop()
    -- Проверяем, что спавнер ещё жив
    if not thisEntity or not IsValidEntity(thisEntity) or not thisEntity:IsAlive() then
        print("[RoshanSpawner] Спавнер уничтожен, прекращаем спавн.")
        return nil
    end
    
    -- Ждём пока игра реально началась (game time >= 0)
    if GameRules:GetDOTATime(false, false) < 0 then
        return 1.0
    end
    
    -- Не спавним нового, если предыдущий ещё жив
    if thisEntity.currentRoshan and IsValidEntity(thisEntity.currentRoshan) and thisEntity.currentRoshan:IsAlive() then
        print("[RoshanSpawner] Предыдущий рошан ещё жив, пропускаем спавн.")
        return SPAWN_INTERVAL
    end
    
    -- Спавним рошана
    local spawnPos = thisEntity:GetAbsOrigin()
    
    local roshan = CreateUnitByName(
        ROSHAN_UNIT_NAME,
        spawnPos,
        true,   -- find clear space
        nil,    -- owner
        nil,    -- ability
        DOTA_TEAM_NEUTRALS
    )
    
    if roshan then
        -- Увеличиваем номер спавна и передаём его Рошану,
        -- чтобы AI корректно посчитал прирост статов.
        thisEntity.spawnCount = (thisEntity.spawnCount or 0) + 1
        roshan.spawnNumber = thisEntity.spawnCount

        print("[RoshanSpawner] Рошан заспавнен на позиции: " .. tostring(spawnPos))
        
        -- Снимаем неуязвимость (модификатор), если движок навесил
        roshan:RemoveModifierByName("modifier_invulnerable")
        
        -- Сохраняем ссылку на текущего рошана
        thisEntity.currentRoshan = roshan
        
        -- Поворачиваем рошана случайным образом
        roshan:SetAngles(0, RandomFloat(0, 360), 0)
        
        -- === ОПОВЕЩЕНИЕ ОБЕИХ КОМАНД ===
        
        -- 1. Даём обзор обеим командам
        AddFOWViewer(DOTA_TEAM_GOODGUYS, spawnPos, VISION_RADIUS, VISION_DURATION, false)
        AddFOWViewer(DOTA_TEAM_BADGUYS, spawnPos, VISION_RADIUS, VISION_DURATION, false)
        
        -- 2. Пинг на миникарте для обеих команд
        GameRules:ExecuteTeamPing(DOTA_TEAM_GOODGUYS, spawnPos.x, spawnPos.y, roshan, 0)
        GameRules:ExecuteTeamPing(DOTA_TEAM_BADGUYS, spawnPos.x, spawnPos.y, roshan, 0)
        
        -- 3. Звук рёва рошана
        EmitSoundOn("RoshanDT.Scream", roshan)

        print("[RoshanSpawner] Номер спавна: " .. roshan.spawnNumber)
    else
        print("[RoshanSpawner] ОШИБКА: Не удалось создать рошана!")
    end
    
    -- Возвращаем интервал для следующего спавна
    return SPAWN_INTERVAL
end
