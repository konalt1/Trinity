local activeTimer = nil
local heroesInArea = {}  -- таблица союзных героев в зоне
local enemiesInArea = {}  -- таблица вражеских героев в зоне
local heroesWaiting = {}  -- герои, ожидающие окончания кулдауна
local currentHero = nil
local capturingTeam = nil  -- команда, которая захватывает
local countdown = nil  -- текущий отсчёт таймера (инициализируется при захвате)
local captureParticle = nil  -- визуальный эффект захвата (растущий)
local capturePosition = nil  -- позиция захвата
local shrinePosition = nil  -- позиция шрайна для пинга
local shrineRadius = nil  -- радиус триггера
local isOnCooldown = false  -- флаг кулдауна
local currentRadius = 0  -- текущий радиус партикла
local elapsedTime = 0  -- прошедшее время захвата
local shrineInitialized = false  -- флаг инициализации шрайна

-- Допустимые команды (Radiant = 2, Dire = 3)
local TEAM_RADIANT = DOTA_TEAM_GOODGUYS or 2
local TEAM_DIRE = DOTA_TEAM_BADGUYS or 3

-- Настройки
local CAPTURE_TIME = 5  -- время захвата в секундах
local ACTIVATION_INTERVAL = 30  -- интервал активации (каждые 30 секунд игрового времени)
local nextActivationTime = 30  -- следующее время активации (начинаем с 0:30)
local activationTimerStarted = false  -- флаг, что таймер активации запущен

-- ============================================
-- НАСТРОЙКА ПОЗИЦИИ ШРАЙНА
-- Укажи здесь координаты шрайна на карте
-- Можно узнать через getpos в консоли игры
-- ============================================
local SHRINE_FIXED_POSITION = Vector(0, 0, 128)  -- ИЗМЕНИ ЭТО НА РЕАЛЬНУЮ ПОЗИЦИЮ
local SHRINE_FIXED_RADIUS = 300  -- радиус зоны захвата

-- Эффект захвата (прогресс-кольцо)
local CAPTURE_PARTICLE = "particles/generic_gameplay/launchpad_progress_ring.vpcf"

-- Прекеш ресурсов
function Precache(context)
    PrecacheResource("particle", CAPTURE_PARTICLE, context)
    print("[Shard Shrine] Resources precached")
end

-- Создать визуальный эффект захвата
local function CreateCaptureEffect(position)
    -- Сначала уничтожаем предыдущий партикл (если есть)
    if captureParticle then
        ParticleManager:DestroyParticle(captureParticle, false)
        ParticleManager:ReleaseParticleIndex(captureParticle)
        captureParticle = nil
    end
    
    local targetRadius = shrineRadius or 300  -- конечный радиус
    currentRadius = 0  -- начинаем с нулевого радиуса
    elapsedTime = 0  -- сбрасываем прошедшее время
    
    -- Партикл прогресса (растущий от 0)
    captureParticle = ParticleManager:CreateParticle(CAPTURE_PARTICLE, PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(captureParticle, 0, position)  -- позиция
    ParticleManager:SetParticleControl(captureParticle, 1, Vector(CAPTURE_TIME, currentRadius, 0))  -- начальный радиус = 0
    capturePosition = position
    
    print("[Shard Shrine] Capture progress ring created with target radius: " .. targetRadius)
end

-- Удалить визуальный эффект захвата
local function DestroyCaptureEffect()
    currentRadius = 0
    elapsedTime = 0
    
    if captureParticle then
        ParticleManager:DestroyParticle(captureParticle, false)
        ParticleManager:ReleaseParticleIndex(captureParticle)
        captureParticle = nil
        print("[Shard Shrine] Capture effect destroyed")
    end
end

-- Пинг на миникарте для всех игроков
local function PingMinimap(position)
    if not position then return end
    
    -- Пинг для обеих команд (type: 0-normal, 1-danger, 2-?, 3-?, 4-?, 5-?, 6-?)
    ExecuteTeamPing(DOTA_TEAM_GOODGUYS, position.x, position.y, nil, 0)
    ExecuteTeamPing(DOTA_TEAM_BADGUYS, position.x, position.y, nil, 0)
    
    print("[Shard Shrine] Minimap ping sent!")
end

-- Проверить, является ли команда допустимой
local function IsValidTeam(teamNumber)
    return teamNumber == TEAM_RADIANT or teamNumber == TEAM_DIRE
end

-- Получить количество героев в таблице
local function GetTableCount(tbl)
    local count = 0
    for _, _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- Получить любого героя из таблицы
local function GetAnyHeroFromTable(tbl)
    for _, hero in pairs(tbl) do
        if hero and IsValidEntity(hero) then
            return hero
        end
    end
    return nil
end

-- Проверить, оспаривается ли захват
local function IsContested()
    return GetTableCount(enemiesInArea) > 0
end

-- Запустить таймер захвата
local function StartCaptureTimer()
    if activeTimer then return end
    
    countdown = CAPTURE_TIME
    elapsedTime = 0
    local lastSecond = CAPTURE_TIME
    local targetRadius = shrineRadius or 300
    local updateInterval = 0.01
    local radiusPerTick = targetRadius / (CAPTURE_TIME / updateInterval)
    print("[Shard Shrine] Timer started - " .. countdown .. " seconds")
    
    activeTimer = Timers:CreateTimer(updateInterval, function()
        if GetTableCount(heroesInArea) == 0 then
            return nil
        end
        
        if IsContested() then
            if math.floor(CAPTURE_TIME - elapsedTime) ~= lastSecond then
                print("[Shard Shrine] CONTESTED - Timer paused...")
            end
            return updateInterval
        end
        
        -- Обновляем время и радиус
        elapsedTime = elapsedTime + updateInterval
        currentRadius = currentRadius + radiusPerTick
        if currentRadius > targetRadius then currentRadius = targetRadius end
        
        -- Обновляем партикл
        if captureParticle then
            ParticleManager:SetParticleControl(captureParticle, 1, Vector(CAPTURE_TIME, currentRadius, 0))
        end
        
        -- Выводим лог каждую секунду
        local currentSecond = math.floor(CAPTURE_TIME - elapsedTime)
        if currentSecond ~= lastSecond and currentSecond >= 0 then
            lastSecond = currentSecond
            if currentSecond > 0 then
                print("[Shard Shrine] " .. currentSecond .. " seconds remaining...")
            end
        end
        
        if elapsedTime >= CAPTURE_TIME then
            print("[Shard Shrine] Timer finished! Giving Aghanim's Shard!")
            
            local rewardHero = currentHero
            if not rewardHero or not IsValidEntity(rewardHero) then
                rewardHero = GetAnyHeroFromTable(heroesInArea)
            end
            
            if rewardHero and IsValidEntity(rewardHero) then
                rewardHero:AddItemByName("item_aghanims_shard")
            end
            
            DestroyCaptureEffect()
            activeTimer = nil
            currentHero = nil
            capturingTeam = nil
            countdown = CAPTURE_TIME
            heroesInArea = {}
            enemiesInArea = {}
            
            StartCooldownUntilNextActivation()
            return nil
        end
        
        return updateInterval
    end)
end

-- Получить текущее игровое время
local function GetGameTime()
    return GameRules:GetDOTATime(false, false)
end

-- Вычислить следующее время активации (кратное ACTIVATION_INTERVAL)
local function CalculateNextActivationTime()
    local currentTime = GetGameTime()
    local nextTime = math.ceil(currentTime / ACTIVATION_INTERVAL) * ACTIVATION_INTERVAL
    -- Если текущее время точно на интервале, берём следующий
    if nextTime <= currentTime then
        nextTime = nextTime + ACTIVATION_INTERVAL
    end
    return nextTime
end

-- Проверить, активна ли зона
local function IsZoneActive()
    local currentTime = GetGameTime()
    return currentTime >= nextActivationTime
end

-- Запустить ожидание следующей активации
local function StartCooldownUntilNextActivation()
    nextActivationTime = CalculateNextActivationTime()
    isOnCooldown = true
    activationTimerStarted = true
    
    local currentTime = GetGameTime()
    local waitTime = nextActivationTime - currentTime
    
    local minutes = math.floor(nextActivationTime / 60)
    local seconds = nextActivationTime % 60
    print("[Shard Shrine] Zone on cooldown until " .. minutes .. ":" .. string.format("%02d", seconds))
    
    Timers:CreateTimer(waitTime, function()
        isOnCooldown = false
        activationTimerStarted = false
        print("[Shard Shrine] Zone now active! (Game time: " .. minutes .. ":" .. string.format("%02d", seconds) .. ")")
        
        -- Пинг на миникарте
        PingMinimap(shrinePosition)
        
        -- Проверяем, есть ли ожидающие герои
        local waitingHero = GetAnyHeroFromTable(heroesWaiting)
        if waitingHero and IsValidEntity(waitingHero) then
            print("[Shard Shrine] Starting capture for waiting heroes!")
            
            -- Переносим ожидающих в активные
            for id, hero in pairs(heroesWaiting) do
                if hero and IsValidEntity(hero) then
                    local heroTeam = hero:GetTeamNumber()
                    if IsValidTeam(heroTeam) then
                        if not capturingTeam then
                            capturingTeam = heroTeam
                            heroesInArea[id] = hero
                            currentHero = hero
                            CreateCaptureEffect(shrinePosition)
                        elseif heroTeam == capturingTeam then
                            heroesInArea[id] = hero
                        else
                            enemiesInArea[id] = hero
                        end
                    end
                end
            end
            heroesWaiting = {}
            
            -- Запускаем таймер захвата
            if capturingTeam then
                StartCaptureTimer()
            end
        else
            print("[Shard Shrine] Ready for capture!")
        end
    end)
end

-- Удалить героя из зоны (при выходе или смерти)
local function RemoveHeroFromArea(hero)
    if not hero then return end
    
    local heroId = hero:GetEntityIndex()
    local heroTeam = hero:GetTeamNumber()
    
    -- Игнорируем героев не из Radiant/Dire
    if not IsValidTeam(heroTeam) then return end
    
    -- Проверяем, враг это или союзник
    if heroesInArea[heroId] then
        heroesInArea[heroId] = nil
        print("[Shard Shrine] Ally removed - Allies in area: " .. GetTableCount(heroesInArea))
        
        -- Если ушёл текущий герой, назначаем нового
        if currentHero == hero then
            currentHero = GetAnyHeroFromTable(heroesInArea)
            if currentHero then
                print("[Shard Shrine] New ally takes over capture")
            end
        end
        
        -- Если все союзники ушли, но есть враги — враги перехватывают захват
        if GetTableCount(heroesInArea) == 0 then
            if GetTableCount(enemiesInArea) > 0 then
                print("[Shard Shrine] All allies left - Enemies take over capture!")
                
                -- Враги становятся новой захватывающей командой
                heroesInArea = enemiesInArea
                enemiesInArea = {}
                
                -- Определяем новую команду
                local newHero = GetAnyHeroFromTable(heroesInArea)
                if newHero then
                    capturingTeam = newHero:GetTeamNumber()
                    currentHero = newHero
                    print("[Shard Shrine] Team " .. capturingTeam .. " now capturing, " .. countdown .. " seconds remaining")
                end
                
                -- Таймер продолжает работать с тем же countdown
            else
                -- Зона полностью пуста
                print("[Shard Shrine] Area empty - Timer cancelled!")
                DestroyCaptureEffect()
                if activeTimer then
                    Timers:RemoveTimer(activeTimer)
                    activeTimer = nil
                    currentHero = nil
                    capturingTeam = nil
                    countdown = CAPTURE_TIME  -- сбрасываем отсчёт
                end
            end
        end
    elseif enemiesInArea[heroId] then
        enemiesInArea[heroId] = nil
        print("[Shard Shrine] Enemy removed - Enemies in area: " .. GetTableCount(enemiesInArea))
        
        if not IsContested() and activeTimer then
            print("[Shard Shrine] Capture resumed!")
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

-- Глобальный таймер пинга
local globalPingTimerStarted = false

local function StartGlobalPingTimer()
    if globalPingTimerStarted then return end
    globalPingTimerStarted = true
    
    print("[Shard Shrine] Global ping timer started!")
    
    -- Таймер проверяет каждую секунду, не пора ли пинговать
    Timers:CreateTimer(1.0, function()
        local currentTime = GetGameTime()
        
        -- Используем shrinePosition если задана, иначе фиксированную позицию
        local pingPosition = shrinePosition or SHRINE_FIXED_POSITION
        
        -- Если время активации наступило и зона не на кулдауне
        if currentTime >= nextActivationTime and not isOnCooldown then
            print("[Shard Shrine] Activation time reached! Pinging at " .. tostring(pingPosition))
            PingMinimap(pingPosition)
            
            -- Обновляем следующее время активации
            nextActivationTime = nextActivationTime + ACTIVATION_INTERVAL
            local minutes = math.floor(nextActivationTime / 60)
            local seconds = nextActivationTime % 60
            print("[Shard Shrine] Next activation at " .. minutes .. ":" .. string.format("%02d", seconds))
        end
        
        return 1.0  -- повторяем каждую секунду
    end)
end

-- Инициализация шрайна при старте игры
local function InitializeShrine()
    if shrineInitialized then return end
    shrineInitialized = true
    
    -- Используем фиксированную позицию если не задана через триггер
    if not shrinePosition then
        shrinePosition = SHRINE_FIXED_POSITION
        shrineRadius = SHRINE_FIXED_RADIUS
        print("[Shard Shrine] Using fixed position: " .. tostring(shrinePosition))
    end
    
    -- Запускаем глобальный таймер пинга
    StartGlobalPingTimer()
    
    print("[Shard Shrine] Shrine initialized! First activation at 0:30")
end

-- Слушаем событие начала игры
ListenToGameEvent("game_rules_state_change", function()
    local state = GameRules:State_Get()
    
    -- Инициализируем когда игра начинается
    if state == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
        -- Небольшая задержка чтобы все entity загрузились
        Timers:CreateTimer(0.1, function()
            InitializeShrine()
        end)
    end
end, nil)

function OnStart(trigger)
    local hero = trigger.activator
    if not hero or not hero:IsRealHero() then return end
    
    local heroId = hero:GetEntityIndex()
    local heroTeam = hero:GetTeamNumber()
    
    -- Игнорируем героев не из Radiant/Dire
    if not IsValidTeam(heroTeam) then
        print("[Shard Shrine] Invalid team " .. heroTeam .. " - ignoring")
        return
    end
    
    -- Сохраняем позицию и радиус шрайна (центр триггера)
    if not shrinePosition or shrinePosition == SHRINE_FIXED_POSITION then
        shrinePosition = trigger.caller:GetAbsOrigin()
        -- Получаем радиус триггера из его размеров
        local bounds = trigger.caller:GetBoundingMaxs()
        shrineRadius = math.max(bounds.x, bounds.y)
        print("[Shard Shrine] Trigger position updated: " .. tostring(shrinePosition))
        print("[Shard Shrine] Trigger radius: " .. shrineRadius)
    end
    
    -- Проверяем, активна ли зона (по игровому времени)
    if not IsZoneActive() or isOnCooldown then
        heroesWaiting[heroId] = hero
        local minutes = math.floor(nextActivationTime / 60)
        local seconds = nextActivationTime % 60
        print("[Shard Shrine] Zone not active - hero waiting until " .. minutes .. ":" .. string.format("%02d", seconds))
        
        -- Запускаем таймер ожидания активации (если ещё не запущен)
        if not activationTimerStarted and not isOnCooldown then
            activationTimerStarted = true
            local currentTime = GetGameTime()
            local waitTime = nextActivationTime - currentTime
            
            if waitTime > 0 then
                print("[Shard Shrine] Activation timer started, waiting " .. string.format("%.1f", waitTime) .. " seconds")
                Timers:CreateTimer(waitTime, function()
                    activationTimerStarted = false
                    
                    -- Пинг на миникарте
                    PingMinimap(shrinePosition)
                    
                    -- Проверяем, есть ли ожидающие герои
                    local waitingHero = GetAnyHeroFromTable(heroesWaiting)
                    if waitingHero and IsValidEntity(waitingHero) then
                        print("[Shard Shrine] Zone now active! Starting capture for waiting heroes!")
                        
                        -- Переносим ожидающих в активные
                        for id, h in pairs(heroesWaiting) do
                            if h and IsValidEntity(h) then
                                local hTeam = h:GetTeamNumber()
                                if IsValidTeam(hTeam) then
                                    if not capturingTeam then
                                        capturingTeam = hTeam
                                        heroesInArea[id] = h
                                        currentHero = h
                                        CreateCaptureEffect(shrinePosition)
                                    elseif hTeam == capturingTeam then
                                        heroesInArea[id] = h
                                    else
                                        enemiesInArea[id] = h
                                    end
                                end
                            end
                        end
                        heroesWaiting = {}
                        
                        -- Запускаем таймер захвата
                        if capturingTeam then
                            StartCaptureTimer()
                        end
                    else
                        print("[Shard Shrine] Zone now active - ready for capture!")
                    end
                end)
            end
        end
        
        return
    end
    
    -- Если захват ещё не начат, этот герой начинает захват
    if not capturingTeam then
        capturingTeam = heroTeam
        heroesInArea[heroId] = hero
        
        -- Создаём визуальный эффект на позиции героя
        CreateCaptureEffect(shrinePosition)
        
        print("[Shard Shrine] Capture started by team " .. heroTeam)
    elseif heroTeam == capturingTeam then
        -- Союзник заходит в зону
        heroesInArea[heroId] = hero
        print("[Shard Shrine] Ally entered - Allies in area: " .. GetTableCount(heroesInArea))
    else
        -- Враг заходит в зону
        enemiesInArea[heroId] = hero
        print("[Shard Shrine] Enemy entered - CONTESTED! Enemies: " .. GetTableCount(enemiesInArea))
        return  -- враги не запускают таймер
    end
    
    -- Если таймер уже активен, не запускаем новый
    if activeTimer then
        print("[Shard Shrine] Timer already active, hero added to queue")
        return
    end
    
    currentHero = hero
    StartCaptureTimer()
end

function OnEnd(trigger)
    local hero = trigger.activator
    if not hero or not hero:IsRealHero() then return end
    
    -- Удаляем из списка ожидания (если на кулдауне)
    local heroId = hero:GetEntityIndex()
    if heroesWaiting[heroId] then
        heroesWaiting[heroId] = nil
        print("[Shard Shrine] Hero removed from waiting list")
        return
    end
    
    RemoveHeroFromArea(hero)
end

