--[[
    Shimmering Lake Mechanic (Мерцающее Озеро)
    
    Механика захвата Aghanim's Shard:
    - Озеро активируется каждые ACTIVATION_INTERVAL секунд игрового времени
    - Герои/иллюзии могут захватывать озеро, удерживаясь в нём
    - При входе противника - прогресс на паузе (но сохраняется)
    - Иллюзии участвуют в захвате, но не могут его завершить
    - При выходе всех - мгновенный сброс прогресса
]]

-- =============================================================================
-- CONFIGURATION
-- =============================================================================
local CONFIG = {
    -- Timing
    FIRST_ACTIVATION_TIME = 420,    -- (sec) Первая активация на 7:00 игрового времени
    ACTIVATION_INTERVAL = 240,      -- (sec) Интервал активации (каждые 4 минуты: 7:00, 11:00, 15:00, ...)
    CAPTURE_TIME = 5.0,             -- (sec) Время, необходимое для захвата
    
    -- Alerts
    ALERT_COOLDOWN = 30.0,          -- (sec) КД на звук/пинг оповещения при входе
    VISION_DURATION = 5.0,          -- (sec) Длительность раскрытия тумана при входе
    VISION_RADIUS = 500,            -- (units) Радиус раскрытия тумана войны
    
    -- Visuals
    PARTICLE_RADIUS = 300,          -- (units) Визуальный радиус круга прогресса
    
    -- System
    THINK_INTERVAL = 0.03,          -- (sec) Частота обновления логики (~30 FPS)
    
    -- Sounds (placeholders - заменить на реальные)
    SOUND_CAPTURE_LOOP = nil,       -- Looping звук во время захвата (будет добавлен)
    SOUND_CAPTURE_COMPLETE = "Item.MoonShard.Consume",  -- Звук получения шарда
    SOUND_ALERT = "General.PingAttack",                 -- Звук оповещения
}

-- =============================================================================
-- STATE
-- =============================================================================
local state = {
    -- Activation
    is_active = false,              -- Активно ли озеро (доступен ли шард)
    next_activation_time = 0,       -- Следующее время активации (игровое время)
    
    -- Capture
    capture_progress = 0.0,         -- Текущий прогресс захвата (0.0 ... CAPTURE_TIME)
    capturing_team = nil,           -- Команда, которая сейчас захватывает (или nil)
    
    -- Units tracking
    units_inside = {},              -- Map: [ent_index] -> { handle, enter_time, team, is_illusion }
    
    -- Alerts
    alert_cd_timestamp = 0,         -- Время окончания КД оповещения
    
    -- Visuals & Audio
    particle_fx = nil,              -- Handle партикла прогресса
    capture_sound = nil,            -- Handle looping звука захвата
    
    -- Cached
    trigger_center = Vector(0, 0, 0),
}

-- =============================================================================
-- UTILITY FUNCTIONS
-- =============================================================================

-- Получить текущее игровое время (без учёта паузы, без негативного времени)
local function GetGameTime()
    return GameRules:GetDOTATime(false, false)
end

-- Проверка валидной команды (Radiant/Dire)
local function IsValidTeam(team_id)
    return team_id == DOTA_TEAM_GOODGUYS or team_id == DOTA_TEAM_BADGUYS
end

-- Проверить, есть ли у героя шард
local function HasShard(hero)
    if not hero or not IsValidEntity(hero) then return true end
    return hero:HasModifier("modifier_item_aghanims_shard")
end

-- Проверить, нужен ли шард команде (есть ли хоть один игрок без шарда)
local function DoesTeamNeedShard(team_id)
    for i = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
        if PlayerResource:IsValidPlayer(i) and PlayerResource:GetTeam(i) == team_id then
            local hero = PlayerResource:GetSelectedHeroEntity(i)
            if hero and IsValidEntity(hero) and not HasShard(hero) then
                return true
            end
        end
    end
    return false
end

-- Подсчитать юнитов по командам внутри озера
local function AnalyzeUnitsInside()
    local teams = {}                -- team_id -> { count, has_real_hero, units[] }
    local total_count = 0
    
    for idx, data in pairs(state.units_inside) do
        -- Проверяем валидность и жизнь юнита
        if not IsValidEntity(data.handle) or not data.handle:IsAlive() then
            state.units_inside[idx] = nil
        else
            total_count = total_count + 1
            
            if not teams[data.team] then
                teams[data.team] = { count = 0, has_real_hero = false, units = {} }
            end
            
            teams[data.team].count = teams[data.team].count + 1
            table.insert(teams[data.team].units, data)
            
            if not data.is_illusion then
                teams[data.team].has_real_hero = true
            end
        end
    end
    
    -- Подсчёт команд
    local team_count = 0
    local single_team = nil
    for team_id, _ in pairs(teams) do
        team_count = team_count + 1
        single_team = team_id
    end
    
    return {
        teams = teams,
        team_count = team_count,
        single_team = single_team,
        total_count = total_count,
        is_empty = total_count == 0,
        is_contested = team_count > 1,
    }
end

-- =============================================================================
-- VISUAL & AUDIO FUNCTIONS
-- =============================================================================

-- Создать партикл прогресса
local function CreateProgressParticle()
    if state.particle_fx then return end
    
    state.particle_fx = ParticleManager:CreateParticle(
        "particles/generic_gameplay/launchpad_progress_ring.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    ParticleManager:SetParticleControl(state.particle_fx, 0, state.trigger_center)
    ParticleManager:SetParticleControl(state.particle_fx, 1, Vector(CONFIG.PARTICLE_RADIUS, 0, 0))
end

-- Обновить партикл прогресса
local function UpdateProgressParticle()
    if not state.particle_fx then return end
    
    local progress_ratio = state.capture_progress / CONFIG.CAPTURE_TIME
    local current_radius = progress_ratio * CONFIG.PARTICLE_RADIUS
    
    ParticleManager:SetParticleControl(state.particle_fx, 1, Vector(CONFIG.PARTICLE_RADIUS, current_radius, 0))
end

-- Уничтожить партикл прогресса
local function DestroyProgressParticle()
    if state.particle_fx then
        ParticleManager:DestroyParticle(state.particle_fx, true)  -- true = immediate
        ParticleManager:ReleaseParticleIndex(state.particle_fx)
        state.particle_fx = nil
    end
end

-- Запустить звук захвата (looping)
local function StartCaptureSound()
    if CONFIG.SOUND_CAPTURE_LOOP and not state.capture_sound then
        state.capture_sound = EmitSoundOn(CONFIG.SOUND_CAPTURE_LOOP, thisEntity)
    end
end

-- Остановить звук захвата
local function StopCaptureSound()
    if state.capture_sound and CONFIG.SOUND_CAPTURE_LOOP then
        StopSoundOn(CONFIG.SOUND_CAPTURE_LOOP, thisEntity)
        state.capture_sound = nil
    end
end

-- Раскрыть область для обеих команд
local function RevealArea()
    AddFOWViewer(DOTA_TEAM_GOODGUYS, state.trigger_center, CONFIG.VISION_RADIUS, CONFIG.VISION_DURATION, false)
    AddFOWViewer(DOTA_TEAM_BADGUYS, state.trigger_center, CONFIG.VISION_RADIUS, CONFIG.VISION_DURATION, false)
end

-- Отправить пинг обеим командам
local function PingBothTeams()
    local coords = state.trigger_center
    GameRules:ExecuteTeamPing(DOTA_TEAM_GOODGUYS, coords.x, coords.y, nil, 0)
    GameRules:ExecuteTeamPing(DOTA_TEAM_BADGUYS, coords.x, coords.y, nil, 0)
    
    if CONFIG.SOUND_ALERT then
        EmitGlobalSound(CONFIG.SOUND_ALERT)
    end
end

-- =============================================================================
-- ALERT SYSTEM
-- =============================================================================

-- Попробовать отправить оповещение (с учётом КД)
local function TryTriggerAlert()
    local now = GetGameTime()
    
    if now >= state.alert_cd_timestamp then
        state.alert_cd_timestamp = now + CONFIG.ALERT_COOLDOWN
        
        PingBothTeams()
        RevealArea()
        
        return true
    end
    
    return false
end

-- =============================================================================
-- ACTIVATION SYSTEM
-- =============================================================================

-- Вычислить следующее время активации
local function CalculateNextActivationTime()
    local current_time = GetGameTime()
    
    -- Если игра ещё не началась или время отрицательное
    if current_time < 0 then
        return CONFIG.FIRST_ACTIVATION_TIME
    end
    
    -- Находим следующий интервал, кратный ACTIVATION_INTERVAL, >= FIRST_ACTIVATION_TIME
    local intervals_passed = math.floor((current_time - CONFIG.FIRST_ACTIVATION_TIME) / CONFIG.ACTIVATION_INTERVAL)
    local next_time = CONFIG.FIRST_ACTIVATION_TIME + (intervals_passed + 1) * CONFIG.ACTIVATION_INTERVAL
    
    -- Если текущее время ровно на интервале, берём следующий
    if current_time >= CONFIG.FIRST_ACTIVATION_TIME and 
       math.abs(current_time - (CONFIG.FIRST_ACTIVATION_TIME + intervals_passed * CONFIG.ACTIVATION_INTERVAL)) < 0.1 then
        next_time = CONFIG.FIRST_ACTIVATION_TIME + (intervals_passed + 1) * CONFIG.ACTIVATION_INTERVAL
    end
    
    return next_time
end

-- Активировать озеро (шард стал доступен)
local function ActivateLake()
    state.is_active = true
    state.capture_progress = 0.0
    state.capturing_team = nil
    
    -- Оповещаем всех о доступности (используем систему с КД)
    -- Сбрасываем КД чтобы следующий вход гарантированно сработал
    state.alert_cd_timestamp = 0
    TryTriggerAlert()
    
    -- Создаём партикл (прогресс = 0)
    CreateProgressParticle()
end

-- Деактивировать озеро (после захвата)
local function DeactivateLake()
    state.is_active = false
    state.capture_progress = 0.0
    state.capturing_team = nil
    state.next_activation_time = CalculateNextActivationTime()
    
    DestroyProgressParticle()
    StopCaptureSound()
end

-- =============================================================================
-- CAPTURE SYSTEM
-- =============================================================================

-- Полный сброс захвата (все вышли)
local function ResetCapture()
    state.capture_progress = 0.0
    state.capturing_team = nil
    
    DestroyProgressParticle()
    StopCaptureSound()
    
    -- Пересоздаём партикл с нулевым прогрессом если озеро активно
    if state.is_active then
        CreateProgressParticle()
    end
end

-- Выдать награду команде
local function GrantShardToTeam(team_id)
    local analysis = AnalyzeUnitsInside()
    local team_data = analysis.teams[team_id]
    
    if not team_data then return false end
    
    -- Собираем кандидатов (только реальные герои в озере)
    local candidates = {}
    for _, data in ipairs(team_data.units) do
        if not data.is_illusion and IsValidEntity(data.handle) and data.handle:IsAlive() then
            table.insert(candidates, data)
        end
    end
    
    -- Сортируем по времени входа (первый вошедший - приоритет)
    table.sort(candidates, function(a, b) return a.enter_time < b.enter_time end)
    
    local winner_hero = nil
    
    -- Ищем первого без шарда среди присутствующих
    for _, data in ipairs(candidates) do
        if not HasShard(data.handle) then
            winner_hero = data.handle
            break
        end
    end
    
    -- Если все в озере уже с шардами - ищем случайного союзника без шарда
    if not winner_hero then
        local global_candidates = {}
        for i = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
            if PlayerResource:IsValidPlayer(i) and PlayerResource:GetTeam(i) == team_id then
                local hero = PlayerResource:GetSelectedHeroEntity(i)
                if hero and IsValidEntity(hero) and not HasShard(hero) then
                    table.insert(global_candidates, hero)
                end
            end
        end
        
        if #global_candidates > 0 then
            winner_hero = global_candidates[RandomInt(1, #global_candidates)]
        end
    end
    
    -- Выдаём награду
    if winner_hero then
        winner_hero:AddItemByName("item_aghanims_shard")
        
        if CONFIG.SOUND_CAPTURE_COMPLETE then
            EmitSoundOn(CONFIG.SOUND_CAPTURE_COMPLETE, winner_hero)
        end
        
        return true
    end
    
    return false
end

-- =============================================================================
-- MAIN THINK LOOP
-- =============================================================================

function LakeThink()
    local dt = CONFIG.THINK_INTERVAL
    local now = GetGameTime()
    
    -- 1. Проверка активации озера
    if not state.is_active then
        if now >= state.next_activation_time then
            ActivateLake()
        else
            return CONFIG.THINK_INTERVAL
        end
    end
    
    -- 2. Анализ юнитов внутри
    local analysis = AnalyzeUnitsInside()
    
    -- 3. Обработка пустого озера
    if analysis.is_empty then
        -- Если был прогресс - сбрасываем
        if state.capture_progress > 0 then
            ResetCapture()
        end
        return CONFIG.THINK_INTERVAL
    end
    
    -- 4. Обработка оспаривания (contested)
    if analysis.is_contested then
        -- Прогресс на паузе, но сохраняется
        -- Звук захвата продолжает играть
        UpdateProgressParticle()
        return CONFIG.THINK_INTERVAL
    end
    
    -- 5. Одна команда внутри
    local team_id = analysis.single_team
    local team_data = analysis.teams[team_id]
    
    -- Проверяем, нужен ли шард команде
    if not DoesTeamNeedShard(team_id) then
        -- Команда не нуждается в шарде - прогресс не идёт
        UpdateProgressParticle()
        return CONFIG.THINK_INTERVAL
    end
    
    -- Обновляем захватывающую команду (для перехвата)
    if state.capturing_team ~= team_id then
        state.capturing_team = team_id
        -- Прогресс сохраняется при перехвате
    end
    
    -- 6. Увеличиваем прогресс
    state.capture_progress = state.capture_progress + dt
    
    -- Запускаем звук захвата если ещё не запущен
    if state.capture_progress > 0 and not state.capture_sound then
        StartCaptureSound()
    end
    
    -- 7. Проверка завершения захвата
    if state.capture_progress >= CONFIG.CAPTURE_TIME then
        -- Проверяем, есть ли реальный герой для получения награды
        if team_data.has_real_hero then
            -- Захват завершён!
            if GrantShardToTeam(team_id) then
                DeactivateLake()
            else
                -- Не удалось выдать (все с шардами?) - сброс
                ResetCapture()
            end
        else
            -- Только иллюзии - ждём реального героя, прогресс = max
            state.capture_progress = CONFIG.CAPTURE_TIME
        end
    end
    
    -- 8. Обновляем визуал
    UpdateProgressParticle()
    
    return CONFIG.THINK_INTERVAL
end

-- =============================================================================
-- API FUNCTIONS (вызываются движком)
-- =============================================================================

function Precache(context)
    PrecacheResource("particle", "particles/generic_gameplay/launchpad_progress_ring.vpcf", context)
    -- Добавить звуки когда будут готовы
    -- PrecacheResource("soundfile", "soundevents/custom_sounds.vsndevts", context)
end

function Spawn()
    if not thisEntity then return end
    
    state.trigger_center = thisEntity:GetAbsOrigin()
    state.next_activation_time = CONFIG.FIRST_ACTIVATION_TIME
    state.is_active = false
    
    -- Запускаем Think loop
    thisEntity:SetContextThink("LakeThink", LakeThink, CONFIG.THINK_INTERVAL)
end

function Activate()
    -- Используется если триггер стартует выключенным
end

-- =============================================================================
-- TRIGGER EVENTS (вызываются при входе/выходе из триггера)
-- =============================================================================

function OnStart(event)
    local unit = event.activator
    if not unit or unit:IsNull() then return end
    if not unit:IsHero() then return end
    
    local team = unit:GetTeamNumber()
    if not IsValidTeam(team) then return end
    
    local is_illusion = unit:IsIllusion()
    local ent_index = unit:GetEntityIndex()
    
    -- Оповещение срабатывает на всех (герои + иллюзии)
    if state.is_active then
        TryTriggerAlert()
    end
    
    -- Добавляем в трекинг (герои и иллюзии)
    state.units_inside[ent_index] = {
        handle = unit,
        enter_time = GameRules:GetGameTime(),
        team = team,
        is_illusion = is_illusion,
    }
end

function OnEnd(event)
    local unit = event.activator
    if not unit or unit:IsNull() then return end
    
    local ent_index = unit:GetEntityIndex()
    
    -- Удаляем из трекинга
    if state.units_inside[ent_index] then
        state.units_inside[ent_index] = nil
    end
end
