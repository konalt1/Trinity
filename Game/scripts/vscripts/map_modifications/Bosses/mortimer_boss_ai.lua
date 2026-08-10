require("map_modifications/Bosses/mortimer_level_scaling")

local AGGRO_RADIUS = 1200
local ATTACK_ENGAGE_RADIUS = 600
local COMBAT_TIMEOUT = 15
local GOBBLE_RADIUS = 300
local GOBBLE_OFFSET = 300
local WAYPOINT_REACH_DISTANCE = 100

local PATHWAY_POINTS = {
    "Roshan_pathway",
    "Roshan_pathway_2",
    "Roshan_pathway_final",
}

local GOBBLE_IGNORED_UNITS = {
    ["npc_guardian_good"] = true,
    ["npc_guardian_bad"] = true,
}

local function IsUsable(ability)
    return ability and ability:GetLevel() > 0 and ability:IsFullyCastable()
end

local function FindClosestVisibleEnemy(radius)
    local enemies = FindUnitsInRadius(
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

    for _, enemy in ipairs(enemies) do
        if thisEntity:CanEntityBeSeenByMyTeam(enemy) then
            return enemy
        end
    end

    return nil
end

local function FindGobbleTarget()
    local radius = thisEntity.gobble and thisEntity.gobble:GetSpecialValueFor("effect_radius") or GOBBLE_RADIUS
    local offset = thisEntity.gobble and thisEntity.gobble:GetSpecialValueFor("effect_offset") or GOBBLE_OFFSET
    local nearbyUnits = FindUnitsInRadius(
        thisEntity:GetTeamNumber(),
        thisEntity:GetAbsOrigin(),
        nil,
        radius + offset,
        DOTA_UNIT_TARGET_TEAM_BOTH,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        FIND_CLOSEST,
        false
    )

    for _, unit in ipairs(nearbyUnits) do
        if unit ~= thisEntity
            and unit:IsAlive()
            and thisEntity:CanEntityBeSeenByMyTeam(unit)
            and not GOBBLE_IGNORED_UNITS[unit:GetUnitName()]
            and not unit:IsAncient()
            and unit:GetUnitName() ~= "npc_mortimer_boss_finale" then
            return unit
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

local function GetCurrentWaypointPosition()
    local waypointName = PATHWAY_POINTS[thisEntity.currentWaypointIndex or 1]
    local waypoint = waypointName and Entities:FindByName(nil, waypointName) or nil
    return waypoint and waypoint:GetAbsOrigin() or nil
end

local function MoveAlongPathway()
    local waypointPosition = GetCurrentWaypointPosition()
    if not waypointPosition then
        print("[MortimerBoss] Pathway waypoint is missing; stopping pathway movement.")
        thisEntity.pathwayEnabled = false
        return 0.5
    end

    if (thisEntity:GetAbsOrigin() - waypointPosition):Length2D() < WAYPOINT_REACH_DISTANCE then
        thisEntity.currentWaypointIndex = thisEntity.currentWaypointIndex + 1
        waypointPosition = GetCurrentWaypointPosition()

        if not waypointPosition then
            thisEntity.reachedFinalPoint = true
            UTIL_Remove(thisEntity)
            return nil
        end
    end

    thisEntity:MoveToPosition(waypointPosition)
    return 0.35
end

local function UpdatePathwayVisibility()
    local now = GameRules:GetGameTime()
    if now < (thisEntity.nextVisibilityUpdate or 0) then
        return
    end

    thisEntity.nextVisibilityUpdate = now + 0.5
    local position = thisEntity:GetAbsOrigin()
    AddFOWViewer(DOTA_TEAM_GOODGUYS, position, 800, 1.0, false)
    AddFOWViewer(DOTA_TEAM_BADGUYS, position, 800, 1.0, false)
end

function Spawn(entityKeyValues)
    if not IsServer() or not thisEntity or not IsValidEntity(thisEntity) then
        return
    end

    MortimerLevelScaling:ApplyToBoss(thisEntity, thisEntity.mortimerLevel or thisEntity.spawnNumber or 1)
    thisEntity:AddActivityModifier("walk")
    thisEntity.gobble = thisEntity:FindAbilityByName("mortimer_gobble_up")
    thisEntity.cookie = thisEntity:FindAbilityByName("snapfire_firesnap_cookie")
    thisEntity.currentWaypointIndex = 1
    thisEntity.lastHealth = thisEntity:GetHealth()
    thisEntity.lastCombatTime = 0
    thisEntity.isInCombat = false
    thisEntity.reachedFinalPoint = false
    thisEntity.nextVisibilityUpdate = 0

    for _, ability in pairs({ thisEntity.gobble, thisEntity.cookie }) do
        if ability then
            ability:SetLevel(math.max(1, ability:GetMaxLevel()))
            ability:SetActivated(true)
        end
    end

    if thisEntity.gobble then thisEntity.gobble:SetHidden(false) end
    if thisEntity.cookie then thisEntity.cookie:SetHidden(false) end

    thisEntity:SetContextThink("MortimerBossBehavior", MortimerBossBehavior, 0.25)
end

function MortimerBossBehavior()
    if not thisEntity or not IsValidEntity(thisEntity) or not thisEntity:IsAlive() then
        return nil
    end

    if GameRules:IsGamePaused() then
        return 0.25
    end

    if thisEntity.pathwayEnabled then
        UpdatePathwayVisibility()

        local health = thisEntity:GetHealth()
        if health < (thisEntity.lastHealth or health) then
            thisEntity.isInCombat = true
            thisEntity.lastCombatTime = GameRules:GetGameTime()
        end
        thisEntity.lastHealth = health
    end

    if thisEntity:IsChanneling() or thisEntity:GetCurrentActiveAbility() then
        return 0.1
    end

    if thisEntity.gobble and thisEntity.gobble:IsSequenceActive() then
        return 0.1
    end

    if IsUsable(thisEntity.gobble) then
        local gobbleTarget = FindGobbleTarget()
        if gobbleTarget then
            FacePosition(gobbleTarget:GetAbsOrigin())
            thisEntity:CastAbilityNoTarget(thisEntity.gobble, -1)
            return 0.4
        end
    end

    local enemy = FindClosestVisibleEnemy(AGGRO_RADIUS)

    if enemy and IsUsable(thisEntity.cookie) then
        FacePosition(enemy:GetAbsOrigin())
        thisEntity:CastAbilityOnTarget(thisEntity, thisEntity.cookie, -1)
        return 0.4
    end

    if thisEntity.pathwayEnabled then
        if thisEntity.isInCombat then
            local timeSinceCombat = GameRules:GetGameTime() - thisEntity.lastCombatTime
            if not enemy or timeSinceCombat >= COMBAT_TIMEOUT then
                thisEntity.isInCombat = false
            elseif (enemy:GetAbsOrigin() - thisEntity:GetAbsOrigin()):Length2D() <= ATTACK_ENGAGE_RADIUS then
                thisEntity:MoveToTargetToAttack(enemy)
                return 0.3
            else
                thisEntity:Stop()
                return 0.5
            end
        end

        return MoveAlongPathway()
    end

    return 0.35
end
