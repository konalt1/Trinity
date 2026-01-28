local activeTimer = nil
local heroesInArea = {}  -- таблица союзных героев в зоне
local enemiesInArea = {}  -- таблица вражеских героев в зоне
local heroesWaiting = {}  -- герои, ожидающие окончания кулдауна
local currentHero = nil
local capturingTeam = nil  -- команда, которая захватывает
local countdown = nil  -- текущий отсчёт таймера (инициализируется при захвате)
local captureParticle = nil  -- визуальный эффект захвата
local capturePosition = nil  -- позиция захвата
local isOnCooldown = false  -- флаг кулдауна

-- Допустимые команды (Radiant = 2, Dire = 3)
local TEAM_RADIANT = DOTA_TEAM_GOODGUYS or 2
local TEAM_DIRE = DOTA_TEAM_BADGUYS or 3

-- Настройки
local CAPTURE_TIME = 5  -- время захвата в секундах
local ACTIVATION_INTERVAL = 30  -- интервал активации (каждые 30 секунд игрового времени)
local nextActivationTime = 30  -- следующее время активации (начинаем с 0:30)

-- Эффект захвата
local CAPTURE_PARTICLE = "particles/econ/generic/generic_aoe_shockwave_1/generic_aoe_shockwave_1.vpcf"

-- Прекеш ресурсов
function Precache(context)
    PrecacheResource("particle", CAPTURE_PARTICLE, context)
    print("[Shard Shrine] Resources precached")
end

-- Создать визуальный эффект захвата
local function CreateCaptureEffect(position)
    if captureParticle then
        ParticleManager:DestroyParticle(captureParticle, false)
    end
    
    captureParticle = ParticleManager:CreateParticle(CAPTURE_PARTICLE, PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(captureParticle, 0, position)
    ParticleManager:SetParticleControl(captureParticle, 1, position)
    capturePosition = position
    print("[Shard Shrine] Capture effect created")
end

-- Удалить визуальный эффект захвата
local function DestroyCaptureEffect()
    if captureParticle then
        ParticleManager:DestroyParticle(captureParticle, false)
        ParticleManager:ReleaseParticleIndex(captureParticle)
        captureParticle = nil
        print("[Shard Shrine] Capture effect destroyed")
    end
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
    
    local currentTime = GetGameTime()
    local waitTime = nextActivationTime - currentTime
    
    local minutes = math.floor(nextActivationTime / 60)
    local seconds = nextActivationTime % 60
    print("[Shard Shrine] Zone on cooldown until " .. minutes .. ":" .. string.format("%02d", seconds))
    
    Timers:CreateTimer(waitTime, function()
        isOnCooldown = false
        print("[Shard Shrine] Zone now active! (Game time: " .. minutes .. ":" .. string.format("%02d", seconds) .. ")")
        
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
                            CreateCaptureEffect(hero:GetAbsOrigin())
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
            if capturingTeam and not activeTimer then
                countdown = CAPTURE_TIME
                print("[Shard Shrine] Timer started - " .. countdown .. " seconds")
                
                activeTimer = Timers:CreateTimer(1.0, function()
                    if GetTableCount(heroesInArea) == 0 then
                        return nil
                    end
                    
                    if IsContested() then
                        print("[Shard Shrine] CONTESTED - Timer paused...")
                        return 1.0
                    end
                    
                    countdown = countdown - 1
                    
                    if countdown > 0 then
                        print("[Shard Shrine] " .. countdown .. " seconds remaining...")
                        return 1.0
                    else
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
                end)
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
    
    -- Если на кулдауне — добавляем в список ожидания
    if isOnCooldown then
        heroesWaiting[heroId] = hero
        print("[Shard Shrine] Zone on cooldown - hero added to waiting list")
        return
    end
    
    -- Если захват ещё не начат, этот герой начинает захват
    if not capturingTeam then
        capturingTeam = heroTeam
        heroesInArea[heroId] = hero
        
        -- Создаём визуальный эффект на позиции героя
        CreateCaptureEffect(hero:GetAbsOrigin())
        
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
    countdown = CAPTURE_TIME  -- сбрасываем отсчёт для нового захвата
    print("[Shard Shrine] Timer started - " .. countdown .. " seconds")
    
    activeTimer = Timers:CreateTimer(1.0, function()
        if GetTableCount(heroesInArea) == 0 then
            return nil  -- все союзники покинули зону
        end
        
        -- Если захват оспаривается, ставим на паузу
        if IsContested() then
            print("[Shard Shrine] CONTESTED - Timer paused...")
            return 1.0  -- продолжаем проверять каждую секунду
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
                rewardHero = GetAnyHeroFromTable(heroesInArea)
            end
            
            if rewardHero and IsValidEntity(rewardHero) then
                rewardHero:AddItemByName("item_aghanims_shard")
            end
            
            DestroyCaptureEffect()
            activeTimer = nil
            currentHero = nil
            capturingTeam = nil
            countdown = CAPTURE_TIME  -- сбрасываем для следующего захвата
            heroesInArea = {}
            enemiesInArea = {}
            
            -- Запускаем кулдаун
            isOnCooldown = true
            print("[Shard Shrine] Zone on cooldown for " .. COOLDOWN_TIME .. " seconds")
            
            Timers:CreateTimer(COOLDOWN_TIME, function()
                isOnCooldown = false
                print("[Shard Shrine] Zone cooldown finished!")
                
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
                                    CreateCaptureEffect(hero:GetAbsOrigin())
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
                    if capturingTeam and not activeTimer then
                        countdown = CAPTURE_TIME
                        print("[Shard Shrine] Timer started - " .. countdown .. " seconds")
                        
                        activeTimer = Timers:CreateTimer(1.0, function()
                            if GetTableCount(heroesInArea) == 0 then
                                return nil
                            end
                            
                            if IsContested() then
                                print("[Shard Shrine] CONTESTED - Timer paused...")
                                return 1.0
                            end
                            
                            countdown = countdown - 1
                            
                            if countdown > 0 then
                                print("[Shard Shrine] " .. countdown .. " seconds remaining...")
                                return 1.0
                            else
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
                                
                                -- Снова на кулдаун
                                isOnCooldown = true
                                print("[Shard Shrine] Zone on cooldown for " .. COOLDOWN_TIME .. " seconds")
                                
                                Timers:CreateTimer(COOLDOWN_TIME, function()
                                    isOnCooldown = false
                                    print("[Shard Shrine] Zone cooldown finished - ready for capture!")
                                end)
                                
                                return nil
                            end
                        end)
                    end
                else
                    print("[Shard Shrine] Ready for capture!")
                end
            end)
            
            return nil  -- остановить таймер
        end
    end)
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

