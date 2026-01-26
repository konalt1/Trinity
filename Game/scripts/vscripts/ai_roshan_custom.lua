LinkLuaModifier("modifier_roshan_custom_gospawn", "ai_roshan_custom", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_roshan_custom_spawn", "ai_roshan_custom", LUA_MODIFIER_MOTION_NONE)

function Spawn( entityKeyValues )
    if not IsServer() then
        return
    end
    if not IsValidEntity(thisEntity) then return end

    -- Настройки Рошана
    thisEntity.agro = 1100  -- Радиус агро
    thisEntity.spawn = thisEntity:GetAbsOrigin()  -- Запоминаем точку спавна
    thisEntity.slam = thisEntity:FindAbilityByName("roshan_slam")  -- Способность slam

    print("[Roshan AI] Инициализация: spawn = " .. tostring(thisEntity.spawn) .. ", agro = " .. thisEntity.agro)

    -- Применяем модификатор спавна на 2 секунды (неуязвимость)
    thisEntity:AddNewModifier(thisEntity, nil, "modifier_roshan_custom_spawn", {duration = 2})

    -- Запускаем AI
    thisEntity:SetContextThink("bevavior", bevavior, FrameTime())
end


function bevavior()
    if not IsValidEntity(thisEntity) then return -1 end
    if not thisEntity:IsAlive() then return -1 end

    if GameRules:IsGamePaused() then
        return 0.5
    end

    -- Режим спавна - не делаем ничего
    if thisEntity:HasModifier("modifier_roshan_custom_spawn") then
        return 0.1
    end

    -- Режим возврата к точке спавна
    if thisEntity:HasModifier("modifier_roshan_custom_gospawn") then
        if (thisEntity:GetAbsOrigin() - thisEntity.spawn):Length2D() < 10 then
            thisEntity:RemoveModifierByName("modifier_roshan_custom_gospawn")
            print("[Roshan AI] Вернулся к точке спавна")
        else
            thisEntity:MoveToPosition(thisEntity.spawn)
            return 0.1
        end
    end

    ---------------------------------------------------------------------------------------------------
    -- Поиск врагов
    ---------------------------------------------------------------------------------------------------

    -- Враги для использования способности (если slam существует)
    local enemy_for_ability = {}
    if thisEntity.slam and thisEntity.slam:IsFullyCastable() then
        enemy_for_ability = FindUnitsInRadius(
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
    end

    -- Враги для атаки в радиусе агро
    local enemy_for_attack = FindUnitsInRadius(
        thisEntity:GetTeamNumber(), 
        thisEntity:GetAbsOrigin(), 
        nil, 
        thisEntity.agro, 
        DOTA_UNIT_TARGET_TEAM_ENEMY, 
        DOTA_UNIT_TARGET_BASIC + DOTA_UNIT_TARGET_HERO, 
        DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_NOT_ANCIENTS, 
        FIND_CLOSEST, 
        false
    )

    ---------------------------------------------------------------------------------------------------
    -- Использование способностей
    ---------------------------------------------------------------------------------------------------

    local control = false
    if thisEntity:IsSilenced() or thisEntity:IsHexed() then
        control = true
    end

    if control == false and thisEntity.slam then
        if thisEntity.slam:IsFullyCastable() then
            if IsValidEntity(enemy_for_ability[1]) then
                print("[Roshan AI] Использую Slam!")
                thisEntity:CastAbilityNoTarget(thisEntity.slam, 1)
                return 0.6
            end
        end
    end

    ---------------------------------------------------------------------------------------------------
    -- Основное поведение
    ---------------------------------------------------------------------------------------------------

    local enemy = enemy_for_attack[1]

    -- Если враг в радиусе агро И Рошан близко к точке спавна
    if ((thisEntity:GetAbsOrigin() - thisEntity.spawn):Length2D() < thisEntity.agro) and IsValidEntity(enemy) then
        -- Атаковать врага
        thisEntity:MoveToTargetToAttack(enemy)
    else
        -- Если далеко от точки спавна - вернуться
        if ((thisEntity:GetAbsOrigin() - thisEntity.spawn):Length2D() > 10) then
            print("[Roshan AI] Возвращаюсь к точке спавна")
            thisEntity:AddNewModifier(thisEntity, nil, "modifier_roshan_custom_gospawn", {})
            thisEntity:MoveToPosition(thisEntity.spawn)
        end
    end

    return 0.5
end

---------------------------------------------------------------------------------------------------
-- МОДИФИКАТОРЫ
---------------------------------------------------------------------------------------------------

-- Модификатор возврата к спавну
modifier_roshan_custom_gospawn = class({})

function modifier_roshan_custom_gospawn:IsHidden()
    return false
end

function modifier_roshan_custom_gospawn:IsPurgable()
    return false
end

function modifier_roshan_custom_gospawn:GetTexture()
    return "roshan_bash"
end

-- Модификатор защиты при спавне
modifier_roshan_custom_spawn = class({})

function modifier_roshan_custom_spawn:IsHidden()
    return false
end

function modifier_roshan_custom_spawn:IsPurgable()
    return false
end

function modifier_roshan_custom_spawn:CheckState()
    return {
        [MODIFIER_STATE_INVULNERABLE] = true,
        [MODIFIER_STATE_NO_HEALTH_BAR] = true,
    }
end

function modifier_roshan_custom_spawn:GetTexture()
    return "modifier_invulnerable"
end
