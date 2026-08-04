MortimerBoss = MortimerBoss or {}

require("map_modifications/Bosses/mortimer_level_scaling")

local BOSS_NAME = "npc_mortimer_boss"
local FINALE_NAME = "npc_mortimer_boss_finale"
local CELEBRATION_DURATION = 2.5
local WAYPOINT_REACH_DISTANCE = 100

local PATHWAY_POINTS = {
    "Roshan_pathway",
    "Roshan_pathway_2",
    "Roshan_pathway_final",
}

local function IsAlive(unit)
    return unit and IsValidEntity(unit) and unit:IsAlive()
end

local function GetOpposingPlayerTeam(team)
    if team == DOTA_TEAM_GOODGUYS then
        return DOTA_TEAM_BADGUYS
    end
    if team == DOTA_TEAM_BADGUYS then
        return DOTA_TEAM_GOODGUYS
    end

    return nil
end

local function StartFinaleRetreat(finale, waypointIndex)
    finale:AddActivityModifier("walk")
    finale.currentWaypointIndex = waypointIndex or 1

    finale:SetContextThink("MortimerFinaleRetreat", function()
        if not IsAlive(finale) then
            return nil
        end

        if GameRules:IsGamePaused() then
            return 0.25
        end

        local waypointName = PATHWAY_POINTS[finale.currentWaypointIndex]
        local waypoint = waypointName and Entities:FindByName(nil, waypointName) or nil
        if not waypoint then
            if waypointName then
                print("[MortimerBoss] Finale pathway waypoint is missing: " .. waypointName)
            end
            UTIL_Remove(finale)
            return nil
        end

        local waypointPosition = waypoint:GetAbsOrigin()
        if (finale:GetAbsOrigin() - waypointPosition):Length2D() < WAYPOINT_REACH_DISTANCE then
            finale.currentWaypointIndex = finale.currentWaypointIndex + 1
            waypointName = PATHWAY_POINTS[finale.currentWaypointIndex]
            waypoint = waypointName and Entities:FindByName(nil, waypointName) or nil

            if not waypoint then
                UTIL_Remove(finale)
                return nil
            end

            waypointPosition = waypoint:GetAbsOrigin()
        end

        local position = finale:GetAbsOrigin()
        AddFOWViewer(DOTA_TEAM_GOODGUYS, position, 800, 1.0, false)
        AddFOWViewer(DOTA_TEAM_BADGUYS, position, 800, 1.0, false)
        finale:MoveToPosition(waypointPosition)
        return 0.35
    end, 0)
end

function MortimerBoss:StartFinale(killedBoss, targetTeam)
    local position = killedBoss:GetAbsOrigin()
    local waypointIndex = killedBoss.currentWaypointIndex or 1
    -- Replace the corpse with the animated finale actor so two Mortimers do not
    -- overlap while the normal death animation is still visible.
    killedBoss:AddNoDraw()
    local finale = CreateUnitByName(
        FINALE_NAME,
        position,
        true,
        nil,
        nil,
        killedBoss:GetTeamNumber()
    )

    if not finale then
        print("[MortimerBoss] Failed to create the finale unit")
        return
    end

    finale:SetForwardVector(killedBoss:GetForwardVector())
    MortimerLevelScaling:SetUnitLevel(finale, MortimerLevelScaling:GetLevel(killedBoss))
    finale.towerKillRewardTeam = GetOpposingPlayerTeam(targetTeam)
    finale:AddNewModifier(finale, nil, "modifier_invulnerable", {})
    finale:AddNewModifier(finale, nil, "modifier_phased", {})
    finale:ResetSequence("snapfire_taunt")

    Timers:CreateTimer(CELEBRATION_DURATION, function()
        if not IsAlive(finale) then
            return nil
        end

        local kisses = finale:FindAbilityByName("mortimer_finale_kisses")

        if kisses then
            kisses:SetLevel(math.max(1, kisses:GetMaxLevel()))
            local targetPosition = kisses:GetCurrentTargetPosition(nil, targetTeam)
            if targetPosition then
                finale:SetForwardVector((targetPosition - finale:GetAbsOrigin()):Normalized())
                kisses:FireVolley(targetPosition, targetTeam, function()
                    StartFinaleRetreat(finale, waypointIndex)
                end)
                return nil
            end
        end

        StartFinaleRetreat(finale, waypointIndex)
        return nil
    end)
end

function MortimerBoss:OnEntityKilled(unit, event)
    if unit and unit:GetUnitName() == BOSS_NAME then
        local attackerIndex = event and (event.entindex_attacker or event.entindex_attacker_const)
        local attacker = attackerIndex and EntIndexToHScript(attackerIndex) or nil
        local killerTeam = attacker and not attacker:IsNull() and attacker:GetTeamNumber() or nil
        self:StartFinale(unit, GetOpposingPlayerTeam(killerTeam))
    end
end

function MortimerBoss:Init()
    Convars:RegisterCommand("spawn_mortimer_boss", function(_, x, y, z)
        local position
        if x and y and z then
            position = Vector(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 128)
        else
            local hero = PlayerResource:GetSelectedHeroEntity(0)
            if hero then
                position = hero:GetAbsOrigin() + hero:GetForwardVector() * 350
            else
                position = Vector(0, 0, 128)
            end
        end

        CreateUnitByName(BOSS_NAME, position, true, nil, nil, DOTA_TEAM_NEUTRALS)
    end, "Spawn Mortimer boss: spawn_mortimer_boss [x y z]", FCVAR_CHEAT)
end
