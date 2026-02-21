--[[
    AI для Рошана, идущего по пути (Pathway Roshan)
    
    Поведение:
    - Движется по точкам: Roshan_pathway → Roshan_pathway_2 → Roshan_pathway_final
    - При получении урона останавливается и атакует
    - Если 15 секунд без боя — продолжает движение
    - При смерти дропает аегис
    - При достижении финальной точки — исчезает без дропа
]]

-- Список точек пути в порядке следования
local PATHWAY_POINTS = {
    "Roshan_pathway",
    "Roshan_pathway_2", 
    "Roshan_pathway_final",
}

-- Время без боя для продолжения движения (в секундах)
local COMBAT_TIMEOUT = 15

-- Радиус достижения точки
local WAYPOINT_REACH_DISTANCE = 100

-- Радиус агро
local AGRO_RADIUS = 600

-- Время ожидания на точках (в секундах)
local WAYPOINT_WAIT_TIME = 60

-- На каких точках останавливаться (по имени)
local WAIT_AT_WAYPOINTS = {
    ["Roshan_pathway"] = true,
    ["Roshan_pathway_2"] = true
}

-- Максимальное расстояние от точки ожидания (leash)
local LEASH_DISTANCE = 1500

-- Глобальная таблица для отслеживания рошанов, достигших конца пути
if PathwayRoshanRegistry == nil then
    PathwayRoshanRegistry = {}
end

function Spawn(entityKeyValues)
    if not IsServer() then
        return
    end
    
    if not IsValidEntity(thisEntity) then 
        return 
    end

    -- Инициализация переменных
    thisEntity.currentWaypointIndex = 1
    thisEntity.lastCombatTime = 0
    thisEntity.lastHealth = thisEntity:GetHealth()
    thisEntity.isInCombat = false
    thisEntity.reachedFinalPoint = false
    thisEntity.slam = thisEntity:FindAbilityByName("roshan_slam")
    thisEntity.isWaiting = false
    thisEntity.waitEndTime = 0
    thisEntity.anchorPosition = nil  -- Позиция привязки для leash
    thisEntity.isReturningToAnchor = false  -- Возвращаемся к точке привязки
    thisEntity.isStopped = false  -- Флаг чтобы не спамить Stop()
    
    -- Регистрируем рошана
    PathwayRoshanRegistry[thisEntity:entindex()] = {
        entity = thisEntity,
        reachedFinalPoint = false
    }
    
    print("[Roshan Pathway] Инициализация. Начинаем движение к первой точке: " .. PATHWAY_POINTS[1])

    -- Запускаем основной цикл поведения
    thisEntity:SetContextThink("PathwayBehavior", PathwayBehavior, 0.1)
end

-- Получить позицию текущей целевой точки
function GetCurrentWaypointPosition()
    if thisEntity.currentWaypointIndex > #PATHWAY_POINTS then
        return nil
    end
    
    local waypointName = PATHWAY_POINTS[thisEntity.currentWaypointIndex]
    local waypoint = Entities:FindByName(nil, waypointName)
    
    if waypoint then
        return waypoint:GetAbsOrigin()
    else
        print("[Roshan Pathway] ОШИБКА: Точка " .. waypointName .. " не найдена!")
        return nil
    end
end

-- Проверить, достигли ли мы текущей точки
function HasReachedCurrentWaypoint()
    local waypointPos = GetCurrentWaypointPosition()
    if not waypointPos then
        return false
    end
    
    local distance = (thisEntity:GetAbsOrigin() - waypointPos):Length2D()
    return distance < WAYPOINT_REACH_DISTANCE
end

-- Перейти к следующей точке
function MoveToNextWaypoint()
    thisEntity.currentWaypointIndex = thisEntity.currentWaypointIndex + 1
    
    if thisEntity.currentWaypointIndex > #PATHWAY_POINTS then
        -- Достигли финальной точки — исчезаем без дропа
        print("[Roshan Pathway] Достигнута финальная точка. Рошан исчезает.")
        thisEntity.reachedFinalPoint = true
        
        -- Обновляем регистр
        if PathwayRoshanRegistry[thisEntity:entindex()] then
            PathwayRoshanRegistry[thisEntity:entindex()].reachedFinalPoint = true
        end
        
        -- Удаляем юнита без смерти (UTIL_Remove)
        UTIL_Remove(thisEntity)
        return false
    end
    
    print("[Roshan Pathway] Переход к точке: " .. PATHWAY_POINTS[thisEntity.currentWaypointIndex])
    return true
end

-- Проверка получения урона (по изменению HP)
function CheckForDamageTaken()
    if not IsValidEntity(thisEntity) then return false end
    
    local currentHealth = thisEntity:GetHealth()
    local damageTaken = thisEntity.lastHealth - currentHealth
    thisEntity.lastHealth = currentHealth
    
    return damageTaken > 0
end

-- Дроп аегиса на позиции смерти
function DropAegis(position)
    local aegis = CreateItem("item_aegis", nil, nil)
    
    if aegis then
        local drop = CreateItemOnPositionSync(position, aegis)
        if drop then
            local randomOffset = Vector(RandomFloat(-30, 30), RandomFloat(-30, 30), 0)
            drop:SetAbsOrigin(position + randomOffset)
            print("[Roshan Pathway] Аегис создан на позиции: " .. tostring(position))
        end
    else
        print("[Roshan Pathway] ОШИБКА: Не удалось создать аегис!")
    end
end

-- Основной цикл поведения
function PathwayBehavior()
    if not IsValidEntity(thisEntity) then 
        print("[Roshan Pathway] thisEntity не валиден!")
        return nil 
    end
    
    if not thisEntity:IsAlive() then
        -- Рошан умер — дропаем аегис (если не достиг финальной точки)
        if not thisEntity.reachedFinalPoint and not thisEntity.aegisDropped then
            thisEntity.aegisDropped = true
            DropAegis(thisEntity:GetAbsOrigin())
        end
        return nil
    end

    if GameRules:IsGamePaused() then
        return 0.5
    end

    -- Не прерываем если рошан кастует способность или атакует
    if thisEntity:IsChanneling() or thisEntity:GetCurrentActiveAbility() ~= nil or thisEntity:IsAttacking() then
        return 0.1
    end

    local currentTime = GameRules:GetGameTime()
    
    -- Проверяем, получили ли мы урон
    if CheckForDamageTaken() then
        thisEntity.lastCombatTime = currentTime
        thisEntity.isInCombat = true
    end
    
    -- Поиск врагов в радиусе агро
    local enemies = FindUnitsInRadius(
        thisEntity:GetTeamNumber(),
        thisEntity:GetAbsOrigin(),
        nil,
        AGRO_RADIUS,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_BASIC + DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_NOT_ANCIENTS,
        FIND_CLOSEST,
        false
    )

    -- Проверяем наличие врагов в радиусе атаки
    local enemyInAttackRange = nil
    for _, enemy in pairs(enemies) do
        if IsValidEntity(enemy) and enemy:IsAlive() then
            local distToEnemy = (thisEntity:GetAbsOrigin() - enemy:GetAbsOrigin()):Length2D()
            if distToEnemy < 300 then -- Близкий враг
                enemyInAttackRange = enemy
                break
            end
        end
    end

    -- Использование Slam если есть враги рядом
    if thisEntity.slam and thisEntity.slam:IsFullyCastable() then
        local enemiesForSlam = FindUnitsInRadius(
            thisEntity:GetTeamNumber(),
            thisEntity:GetAbsOrigin(),
            nil,
            thisEntity.slam:GetSpecialValueFor("radius") or 350,
            DOTA_UNIT_TARGET_TEAM_ENEMY,
            DOTA_UNIT_TARGET_BASIC + DOTA_UNIT_TARGET_HERO,
            DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_NOT_ANCIENTS,
            FIND_CLOSEST,
            false
        )
        
        if #enemiesForSlam > 0 then
            thisEntity:CastAbilityNoTarget(thisEntity.slam, -1)
            return 0.5
        end
    end

    -- Проверка leash (если есть точка привязки)
    if thisEntity.anchorPosition then
        local distanceFromAnchor = (thisEntity:GetAbsOrigin() - thisEntity.anchorPosition):Length2D()
        
        if distanceFromAnchor > LEASH_DISTANCE then
            -- Слишком далеко от точки — возвращаемся
            thisEntity.isReturningToAnchor = true
            thisEntity.isInCombat = false
            print("[Roshan Pathway] Слишком далеко от точки! Возвращаемся.")
        end
        
        -- Если возвращаемся к точке привязки
        if thisEntity.isReturningToAnchor then
            if distanceFromAnchor < WAYPOINT_REACH_DISTANCE then
                -- Вернулись на место
                thisEntity.isReturningToAnchor = false
                print("[Roshan Pathway] Вернулись на точку ожидания.")
            else
                -- Ещё не дошли — идём к точке
                thisEntity:MoveToPosition(thisEntity.anchorPosition)
                thisEntity.isStopped = false
                return 0.3
            end
        end
    end

    -- Логика боя
    if thisEntity.isInCombat then
        local timeSinceCombat = currentTime - thisEntity.lastCombatTime
        
        if timeSinceCombat >= COMBAT_TIMEOUT then
            -- 15 секунд без боя — выходим из режима боя
            thisEntity.isInCombat = false
            print("[Roshan Pathway] Выход из боя. Продолжаем движение.")
        elseif enemyInAttackRange then
            -- Атакуем только если ещё не атакуем (чтобы не прерывать Bash и атаки)
            if not thisEntity:IsAttacking() then
                thisEntity:MoveToTargetToAttack(enemyInAttackRange)
                thisEntity.isStopped = false
            end
            return 0.3
        elseif #enemies == 0 then
            -- Врагов нет вообще — выходим из боя и продолжаем движение
            thisEntity.isInCombat = false
        else
            -- Враг убежал но ещё в радиусе агро — ждём на месте
            if not thisEntity.isStopped then
                thisEntity:Stop()
                thisEntity.isStopped = true
            end
            return 0.5
        end
    end

    -- Проверка ожидания на точке
    if thisEntity.isWaiting then
        local currentTime = GameRules:GetGameTime()
        if currentTime >= thisEntity.waitEndTime then
            -- Время ожидания истекло — убираем привязку и продолжаем
            thisEntity.isWaiting = false
            thisEntity.anchorPosition = nil
            thisEntity.isStopped = false
            print("[Roshan Pathway] Ожидание завершено. Продолжаем движение.")
        else
            -- Ещё ждём — стоим на месте (если не в бою)
            if not thisEntity.isInCombat and not thisEntity.isStopped then
                thisEntity:Stop()
                thisEntity.isStopped = true
            end
            return 0.5
        end
    end

    -- Движение по пути
    if HasReachedCurrentWaypoint() then
        local currentWaypointName = PATHWAY_POINTS[thisEntity.currentWaypointIndex]
        
        -- Проверяем, нужно ли ждать на этой точке
        if WAIT_AT_WAYPOINTS[currentWaypointName] and not thisEntity.hasWaitedAtCurrentWaypoint then
            thisEntity.isWaiting = true
            thisEntity.waitEndTime = GameRules:GetGameTime() + WAYPOINT_WAIT_TIME
            thisEntity.hasWaitedAtCurrentWaypoint = true
            thisEntity.anchorPosition = GetCurrentWaypointPosition()  -- Устанавливаем точку привязки
            thisEntity.isStopped = false  -- Сбросим флаг, чтобы Stop() вызвался один раз
            print("[Roshan Pathway] Достигли " .. currentWaypointName .. ". Ожидание " .. WAYPOINT_WAIT_TIME .. " секунд. Leash: " .. LEASH_DISTANCE)
            return 0.5
        end
        
        -- Переходим к следующей точке
        thisEntity.hasWaitedAtCurrentWaypoint = false
        if not MoveToNextWaypoint() then
            return nil -- Достигли конца пути
        end
    end

    -- Двигаемся к текущей точке
    local waypointPos = GetCurrentWaypointPosition()
    if waypointPos then
        thisEntity:MoveToPosition(waypointPos)
        thisEntity.isStopped = false
    end

    return 0.5
end
