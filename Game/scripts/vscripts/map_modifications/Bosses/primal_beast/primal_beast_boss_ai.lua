local AGGRO_RADIUS = 1200
local COMBAT_TIMEOUT = 15
local PULVERIZE_RANGE = 200
local ROCK_THROW_MIN_RANGE = 550
local ROCK_THROW_MAX_RANGE = 1800
local WAYPOINT_REACH_DISTANCE = 100

local PATHWAY_POINTS = {
	"Roshan_pathway",
	"Roshan_pathway_2",
	"Roshan_pathway_final",
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
		print("[PrimalBeastBoss] Pathway waypoint is missing; stopping pathway movement.")
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

local function GetUproarStacks()
	local modifier = thisEntity:FindModifierByName("modifier_primal_beast_uproar")
	if modifier and modifier.GetStackCount then
		return modifier:GetStackCount()
	end
	return 0
end

function Spawn(entityKeyValues)
	if not IsServer() or not thisEntity or not IsValidEntity(thisEntity) then
		return
	end

	thisEntity:SetContextThink("PrimalBeastBossInit", function()
		if not thisEntity or not IsValidEntity(thisEntity) or not thisEntity:IsAlive() then
			return nil
		end
		if thisEntity.primalBeastAllied then
			return nil
		end

		if PrimalBeastBoss then
			PrimalBeastBoss:PrepareHostile(thisEntity, thisEntity.primalBeastLevel or thisEntity.spawnNumber or 1, thisEntity.pathwayEnabled == true)
			PrimalBeastBoss:SetTrampleHidden(thisEntity, true)
		end

		thisEntity.uproar = thisEntity:FindAbilityByName("primal_beast_uproar")
		thisEntity.pulverize = thisEntity:FindAbilityByName("primal_beast_pulverize")
		thisEntity.rockThrow = thisEntity:FindAbilityByName("primal_beast_rock_throw")
		thisEntity.currentWaypointIndex = 1
		thisEntity.lastHealth = thisEntity:GetHealth()
		thisEntity.lastCombatTime = 0
		thisEntity.isInCombat = false
		thisEntity.reachedFinalPoint = false
		thisEntity.nextVisibilityUpdate = 0
		thisEntity:SetContextThink("PrimalBeastBossBehavior", PrimalBeastBossBehavior, 0.25)
		return nil
	end, 0.05)
end

function PrimalBeastBossBehavior()
	if not thisEntity or not IsValidEntity(thisEntity) or not thisEntity:IsAlive() then
		return nil
	end
	if thisEntity.primalBeastAllied then
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

	local enemy = FindClosestVisibleEnemy(AGGRO_RADIUS)
	if enemy then
		thisEntity.isInCombat = true
		thisEntity.lastCombatTime = GameRules:GetGameTime()
	end

	if enemy and IsUsable(thisEntity.pulverize) then
		local distance = (enemy:GetAbsOrigin() - thisEntity:GetAbsOrigin()):Length2D()
		if distance <= PULVERIZE_RANGE then
			FacePosition(enemy:GetAbsOrigin())
			thisEntity:CastAbilityOnTarget(enemy, thisEntity.pulverize, -1)
			return 0.4
		end
	end

	if enemy and IsUsable(thisEntity.rockThrow) then
		local distance = (enemy:GetAbsOrigin() - thisEntity:GetAbsOrigin()):Length2D()
		if distance >= ROCK_THROW_MIN_RANGE and distance <= ROCK_THROW_MAX_RANGE then
			FacePosition(enemy:GetAbsOrigin())
			thisEntity:CastAbilityOnPosition(enemy:GetAbsOrigin(), thisEntity.rockThrow, -1)
			return 0.4
		end
	end

	if IsUsable(thisEntity.uproar) and GetUproarStacks() >= 1 then
		thisEntity:CastAbilityNoTarget(thisEntity.uproar, -1)
		return 0.4
	end

	if thisEntity.pathwayEnabled then
		if thisEntity.isInCombat then
			local timeSinceCombat = GameRules:GetGameTime() - thisEntity.lastCombatTime
			if not enemy or timeSinceCombat >= COMBAT_TIMEOUT then
				thisEntity.isInCombat = false
			else
				thisEntity:MoveToTargetToAttack(enemy)
				return 0.3
			end
		end

		return MoveAlongPathway()
	end

	if enemy then
		thisEntity:MoveToTargetToAttack(enemy)
	end

	return 0.35
end
