MortimerBoss = MortimerBoss or {}

require("map_modifications/Bosses/mortimer_level_scaling")

local BOSS_NAME = "npc_mortimer_boss"
local FINALE_NAME = "npc_mortimer_boss_finale"
local CELEBRATION_DURATION = 2.5
local WAYPOINT_REACH_DISTANCE = 100
local DEBUG_VISION_RADIUS = 800
local DEBUG_VISION_DURATION = 5

local PATHWAY_POINTS = {
    "Roshan_pathway",
    "Roshan_pathway_2",
    "Roshan_pathway_final",
}

local function IsAlive(unit)
    return unit and IsValidEntity(unit) and unit:IsAlive()
end

local function SafeCall(unit, methodName, fallback, ...)
    if not unit or not IsValidEntity(unit) then
        return fallback
    end

    local method = unit[methodName]
    if type(method) ~= "function" then
        return fallback
    end

    local ok, value = pcall(method, unit, ...)
    if not ok then
        return fallback
    end

    return value
end

local function BoolText(value)
    if value == nil then
        return "unknown"
    end

    return value and "true" or "false"
end

local function DescribeUnit(unit)
    if not unit or not IsValidEntity(unit) then
        return "invalid"
    end

    return string.format(
        "%s[%d] team=%s alive=%s invulnerable=%s attack_immune=%s out_of_game=%s ancient=%s neutral_type=%s boss=%s",
        SafeCall(unit, "GetUnitName", "unknown"),
        SafeCall(unit, "entindex", -1),
        tostring(SafeCall(unit, "GetTeamNumber", "unknown")),
        BoolText(SafeCall(unit, "IsAlive", nil)),
        BoolText(SafeCall(unit, "IsInvulnerable", nil)),
        BoolText(SafeCall(unit, "IsAttackImmune", nil)),
        BoolText(SafeCall(unit, "IsOutOfGame", nil)),
        BoolText(SafeCall(unit, "IsAncient", nil)),
        BoolText(SafeCall(unit, "IsNeutralUnitType", nil)),
        BoolText(SafeCall(unit, "IsBoss", nil))
    )
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
            local mortimerLevel = MortimerLevelScaling:GetLevel(finale)
            kisses:SetLevel(math.min(mortimerLevel, kisses:GetMaxLevel()))
            local decision = kisses:ResolveTarget(nil, targetTeam)
            kisses:LogDecision("start", decision, {
                snapshot = true,
                suffix = string.format(" level=%d", mortimerLevel),
            })
            if decision.position then
                finale:SetForwardVector((decision.position - finale:GetAbsOrigin()):Normalized())
                kisses:FireVolley(decision.position, targetTeam, function()
                    StartFinaleRetreat(finale, waypointIndex)
                end)
                return nil
            end

            kisses:LogDecision("refuse", decision)
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

function MortimerBoss:DebugAttackOrder(data)
    if not self.attackDebugEnabled
        or not data
        or data.order_type ~= DOTA_UNIT_ORDER_ATTACK_TARGET
    then
        return
    end

    local targetIndex = tonumber(data.entindex_target)
    local target = targetIndex and EntIndexToHScript(targetIndex) or nil
    if not target or target:IsNull() or target:GetUnitName() ~= BOSS_NAME then
        return
    end

    print("[MortimerAttackDebug] target " .. DescribeUnit(target))

    for _, unitIndex in pairs(data.units or {}) do
        local attackerIndex = tonumber(unitIndex)
        local attacker = attackerIndex and EntIndexToHScript(attackerIndex) or nil
        if attacker and not attacker:IsNull() then
            local distance = (attacker:GetAbsOrigin() - target:GetAbsOrigin()):Length2D()
            local visible = SafeCall(attacker, "CanEntityBeSeenByMyTeam", nil, target)
            print(string.format(
                "[MortimerAttackDebug] attacker %s distance=%.1f visible=%s",
                DescribeUnit(attacker),
                distance,
                BoolText(visible)
            ))

            Timers:CreateTimer(0.2, function()
                if not IsAlive(attacker) or not IsAlive(target) then
                    return nil
                end

                local attackTarget = SafeCall(attacker, "GetAttackTarget", nil)
                print(string.format(
                    "[MortimerAttackDebug] after=0.2 attacker=%d attack_target=%s",
                    attacker:entindex(),
                    DescribeUnit(attackTarget)
                ))
                return nil
            end)
        end
    end
end

function MortimerBoss:Init()
    if self.commandsRegistered then
        return
    end
    self.commandsRegistered = true
    if self.spawnerDebugEnabled == nil then
        self.spawnerDebugEnabled = false
    end

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

        local boss = CreateUnitByName(BOSS_NAME, position, true, nil, nil, DOTA_TEAM_NEUTRALS)
        if not boss then
            print("[MortimerBoss] Failed to spawn debug boss")
            return
        end

        boss.spawnNumber = 1
        MortimerLevelScaling:ApplyToBoss(boss, boss.spawnNumber)
        boss.pathwayEnabled = false
        boss:RemoveModifierByName("modifier_invulnerable")
        boss:SetAngles(0, RandomFloat(0, 360), 0)

        AddFOWViewer(DOTA_TEAM_GOODGUYS, position, DEBUG_VISION_RADIUS, DEBUG_VISION_DURATION, false)
        AddFOWViewer(DOTA_TEAM_BADGUYS, position, DEBUG_VISION_RADIUS, DEBUG_VISION_DURATION, false)
        print("[MortimerBoss] Debug boss spawned: " .. DescribeUnit(boss))
    end, "Spawn Mortimer boss: spawn_mortimer_boss [x y z]", FCVAR_CHEAT)

    Convars:RegisterCommand("mortimer_attack_debug", function(_, value)
        self.attackDebugEnabled = tonumber(value) == 1
        print("[MortimerAttackDebug] " .. (self.attackDebugEnabled and "enabled" or "disabled"))
    end, "Log attack orders targeting Mortimer: mortimer_attack_debug 0|1", FCVAR_CHEAT)

    Convars:RegisterCommand("mortimer_kisses_debug", function(_, value)
        self.kissesDebugEnabled = tonumber(value) == 1
        print("[MortimerKissesDebug] " .. (self.kissesDebugEnabled and "enabled" or "disabled"))
    end, "Log Mortimer Kisses targeting: mortimer_kisses_debug 0|1", FCVAR_CHEAT)

    Convars:RegisterCommand("mortimer_spawner_debug", function(_, value)
        self.spawnerDebugEnabled = tonumber(value) == 1
        print("[MortimerSpawner] debug " .. (self.spawnerDebugEnabled and "enabled" or "disabled"))
    end, "Log Mortimer pathway spawns: mortimer_spawner_debug 0|1", FCVAR_CHEAT)
end
