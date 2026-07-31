local AGGRO_RADIUS = 1200
local GOBBLE_RADIUS = 450

local function IsUsable(ability)
    return ability and ability:GetLevel() > 0 and ability:IsFullyCastable()
end

local function FindEnemies(radius)
    return FindUnitsInRadius(
        thisEntity:GetTeamNumber(),
        thisEntity:GetAbsOrigin(),
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        FIND_CLOSEST,
        false
    )
end

local function FindGobbleTarget()
    local allies = FindUnitsInRadius(
        thisEntity:GetTeamNumber(),
        thisEntity:GetAbsOrigin(),
        nil,
        GOBBLE_RADIUS,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_CLOSEST,
        false
    )

    for _, ally in ipairs(allies) do
        if ally ~= thisEntity
            and ally:IsAlive()
            and not ally:IsAncient()
            and ally:GetUnitName() ~= "npc_mortimer_boss_finale" then
            return ally
        end
    end

    return nil
end

local function FacePosition(position)
    local direction = position - thisEntity:GetAbsOrigin()
    direction.z = 0
    if direction:Length2D() > 0 then
        thisEntity:SetForwardVector(direction:Normalized())
    end
end

function Spawn(entityKeyValues)
    if not IsServer() or not thisEntity or not IsValidEntity(thisEntity) then
        return
    end

    thisEntity.gobble = thisEntity:FindAbilityByName("snapfire_gobble_up")
    thisEntity.cookie = thisEntity:FindAbilityByName("snapfire_firesnap_cookie")
    thisEntity.spit = thisEntity:FindAbilityByName("snapfire_spit_creep")

    for _, ability in pairs({ thisEntity.gobble, thisEntity.cookie, thisEntity.spit }) do
        if ability then
            ability:SetLevel(math.max(1, ability:GetMaxLevel()))
            ability:SetActivated(true)
        end
    end

    -- Gobble Up is normally granted by Aghanim's Scepter. This boss owns it
    -- innately, while Spit Creep remains hidden until Gobble Up swaps it in.
    if thisEntity.gobble then thisEntity.gobble:SetHidden(false) end
    if thisEntity.cookie then thisEntity.cookie:SetHidden(false) end
    if thisEntity.spit then thisEntity.spit:SetHidden(true) end

    thisEntity:SetContextThink("MortimerBossBehavior", MortimerBossBehavior, 0.25)
end

function MortimerBossBehavior()
    if not thisEntity or not IsValidEntity(thisEntity) or not thisEntity:IsAlive() then
        return nil
    end

    if GameRules:IsGamePaused() then
        return 0.25
    end

    if thisEntity:IsChanneling() or thisEntity:GetCurrentActiveAbility() then
        return 0.1
    end

    local enemies = FindEnemies(AGGRO_RADIUS)
    local enemy = enemies[1]
    if not enemy then
        return 0.4
    end

    -- Spit immediately once Gobble Up has swapped/enabled its companion action.
    if IsUsable(thisEntity.spit) and not thisEntity.spit:IsHidden() then
        FacePosition(enemy:GetAbsOrigin())
        thisEntity:CastAbilityOnPosition(enemy:GetAbsOrigin(), thisEntity.spit, -1)
        return 0.4
    end

    if IsUsable(thisEntity.gobble) then
        local gobbleTarget = FindGobbleTarget()
        if gobbleTarget then
            thisEntity:CastAbilityOnTarget(gobbleTarget, thisEntity.gobble, -1)
            return 0.4
        end
    end

    if IsUsable(thisEntity.cookie) then
        FacePosition(enemy:GetAbsOrigin())
        thisEntity:CastAbilityOnTarget(thisEntity, thisEntity.cookie, -1)
        return 0.4
    end

    return 0.35
end
