PrimalBeastBoss = PrimalBeastBoss or {}

local BOSS_NAME = "npc_primal_beast_boss"
local MOUNTABLE_MODIFIER = "modifier_primal_beast_boss_mountable_trinity"
local RIDER_MODIFIER = "modifier_primal_beast_boss_rider_trinity"
local ROLL_MODIFIER = "modifier_primal_beast_boss_roll_trinity"
local TRAMPLE_ABILITY = "primal_beast_trample"
local TRAMPLE_MODIFIER = "modifier_primal_beast_trample"
local UPROAR_ABILITY = "primal_beast_uproar"
local PULVERIZE_ABILITY = "primal_beast_pulverize"
local ROCK_THROW_ABILITY = "primal_beast_rock_throw"
local MODEL_SCALE = 1.8
local RIDER_ATTACH = "spine_2"
local RIDER_HEIGHT_OFFSET = 90
local RIDER_MIN_HEIGHT = 250
local MARKER_PARTICLE = "particles/generic_gameplay/generic_has_quest.vpcf"
local MOUNT_RANGE = 250
local DEBUG_VISION_RADIUS = 800
local DEBUG_VISION_DURATION = 5
local ROLL_SPEED = 550
local ROLL_TURN_RATE = 120
local ROLL_TREE_RADIUS = 180
local ALLIED_LIFETIME = { 20, 30, 40, 50, 60 }
local ROLL_THINK = 0.03
local TRAMPLE_STEP = 140
local TRAMPLE_RADIUS = 200
local TRAMPLE_BASE_DAMAGE = 60
local TRAMPLE_ATTACK_FACTOR = 0.35
local MARKER_MODIFIER = "modifier_primal_beast_boss_marker_trinity"
local PULVERIZE_WARN_MODIFIER = "modifier_primal_beast_boss_pulverize_warn_trinity"
local PULVERIZE_WARN_DURATION = 1.8
local PULVERIZE_RANGE = 280
local TOWER_AGGRO_RANGE = 800
local PULVERIZE_BANG_MODEL = "models/props_consumables/high_five/mh_poogie/poogie_exclamation.vmdl"
local PULVERIZE_BANG_ANIM = "wave_v1"
local PULVERIZE_BANG_SCALE = 5.0
local PULVERIZE_BANG_HEIGHT = 380
local PULVERIZE_WAVE_PARTICLE = "particles/econ/items/queen_of_pain/qop_2022_immortal/queen_2022_scream_of_pain_owner_wave_edge.vpcf"
local PULVERIZE_WARN_SOUND = "primal_beast_primal_intro_02"

local LEVEL_CONFIG = {
	health = { base = 3500, per_level = 3000 },
	armor = { base = 20, per_level = 5 },
	attack_damage = { base = 200, per_level = 100 },
}

local HOSTILE_ABILITIES = {
	UPROAR_ABILITY,
	PULVERIZE_ABILITY,
	ROCK_THROW_ABILITY,
	TRAMPLE_ABILITY,
}

local ALLIED_HIDDEN_ABILITIES = {
	UPROAR_ABILITY,
	PULVERIZE_ABILITY,
	ROCK_THROW_ABILITY,
	TRAMPLE_ABILITY,
}

LinkLuaModifier(MOUNTABLE_MODIFIER, "map_modifications/Bosses/primal_beast/primal_beast_boss", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier(RIDER_MODIFIER, "map_modifications/Bosses/primal_beast/primal_beast_boss", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier(ROLL_MODIFIER, "map_modifications/Bosses/primal_beast/primal_beast_boss", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier(MARKER_MODIFIER, "map_modifications/Bosses/primal_beast/primal_beast_boss", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier(PULVERIZE_WARN_MODIFIER, "map_modifications/Bosses/primal_beast/primal_beast_boss", LUA_MODIFIER_MOTION_NONE)

local function IsAlive(unit)
	return unit and (not unit.IsNull or not unit:IsNull()) and unit:IsAlive()
end

local function NormalizeLevel(level)
	return math.max(1, math.floor(tonumber(level) or 1))
end

local function GetAlliedLifetime(level)
	level = math.min(NormalizeLevel(level), #ALLIED_LIFETIME)
	return ALLIED_LIFETIME[level] or ALLIED_LIFETIME[#ALLIED_LIFETIME] or 60
end

local function ScaleFromBase(base, perLevel, level)
	return base + perLevel * (NormalizeLevel(level) - 1)
end

local function GetPlayerTeam(team)
	if team == DOTA_TEAM_GOODGUYS or team == DOTA_TEAM_BADGUYS then
		return team
	end
	return nil
end

local function SetAbilityVisible(ability, visible, level)
	if not ability then
		return
	end

	ability:SetHidden(not visible)
	ability:SetActivated(visible)
	if visible then
		ability:SetLevel(math.max(1, level or ability:GetMaxLevel()))
	end
end

local function IsFiniteVec(v)
	return v
		and v.x == v.x and v.y == v.y and v.z == v.z
		and math.abs(v.x) < 16000
		and math.abs(v.y) < 16000
		and v.z > -2000
		and v.z < 4000
end

local function IsValidHandle(entity)
	return entity and (not entity.IsNull or not entity:IsNull())
end

local function GetRiderWorldOrigin(beast)
	local base = beast:GetAbsOrigin()
	local origin = base
	if beast.ScriptLookupAttachment and beast.GetAttachmentOrigin then
		local attach = beast:ScriptLookupAttachment(RIDER_ATTACH)
		if not attach or attach == 0 then
			attach = beast:ScriptLookupAttachment("attach_hitloc")
		end
		if attach and attach ~= 0 then
			local bone = beast:GetAttachmentOrigin(attach)
			if IsFiniteVec(bone) then
				origin = bone
			end
		end
	end

	local sit = Vector(origin.x, origin.y, origin.z + RIDER_HEIGHT_OFFSET)
	local minZ = base.z + RIDER_MIN_HEIGHT
	if sit.z < minZ then
		sit.z = minZ
	end
	if not IsFiniteVec(sit) then
		return Vector(base.x, base.y, minZ)
	end
	return sit
end

local function PlaceRiderOnSpine(hero, beast)
	if not IsAlive(hero) or not IsAlive(beast) then
		return
	end

	hero:SetAbsOrigin(GetRiderWorldOrigin(beast))

	local busy = (hero.IsAttacking and hero:IsAttacking())
		or (hero.IsChanneling and hero:IsChanneling())
		or (hero.GetCurrentActiveAbility and hero:GetCurrentActiveAbility())
	if busy then
		return
	end

	hero:SetAbsAngles(0, beast:GetAnglesAsVector().y, 0)
end

local function DetachRider(hero)
	if not IsValidHandle(hero) or not hero.primalBeastMounted then
		return
	end
	hero.primalBeastMounted = nil
	if hero.SetParent then
		hero:SetParent(nil, "")
	end
	if hero.FollowEntity then
		hero:FollowEntity(hero, false)
	end
end

local function AttachRider(hero, beast)
	if not IsAlive(hero) or not IsAlive(beast) then
		return
	end
	DetachRider(hero)
	hero.primalBeastMounted = true
	PlaceRiderOnSpine(hero, beast)
end

local function RemoveMarkerDummy(dummy)
	if not IsValidHandle(dummy) then
		return
	end
	UTIL_Remove(dummy)
end

function PrimalBeastBoss:DestroyMountMarkers(beast)
	if not beast then
		return
	end
	if beast.primalBeastMarkerFx then
		ParticleManager:DestroyParticle(beast.primalBeastMarkerFx, false)
		ParticleManager:ReleaseParticleIndex(beast.primalBeastMarkerFx)
		beast.primalBeastMarkerFx = nil
	end
	RemoveMarkerDummy(beast.primalBeastSaddle)
	RemoveMarkerDummy(beast.primalBeastArrow)
	beast.primalBeastSaddle = nil
	beast.primalBeastArrow = nil
end

local function IsWalkable(position)
	if not position or not GridNav then
		return false
	end
	if GridNav.IsTraversable and not GridNav:IsTraversable(position) then
		return false
	end
	return true
end

local function YawFromVector(direction)
	return math.deg(math.atan2(direction.y, direction.x))
end

local function VectorFromYaw(yaw)
	local rad = math.rad(yaw)
	return Vector(math.cos(rad), math.sin(rad), 0)
end

local function AngleDiff(dest, src)
	local diff = dest - src
	while diff > 180 do
		diff = diff - 360
	end
	while diff < -180 do
		diff = diff + 360
	end
	return diff
end

local function Flatten(direction)
	local copy = Vector(direction.x, direction.y, 0)
	if copy:Length2D() < 0.01 then
		return Vector(1, 0, 0)
	end
	return copy:Normalized()
end

function PrimalBeastBoss:ApplyLevel(boss, level)
	if not IsServer() or not IsAlive(boss) then
		return
	end

	level = NormalizeLevel(level)
	boss.spawnNumber = level
	boss.primalBeastLevel = level

	local currentLevel = boss.GetLevel and boss:GetLevel() or 1
	if boss.CreatureLevelUp and currentLevel < level then
		boss:CreatureLevelUp(level - currentLevel)
	end

	local maxHealth = ScaleFromBase(LEVEL_CONFIG.health.base, LEVEL_CONFIG.health.per_level, level)
	boss:SetBaseMaxHealth(maxHealth)
	boss:SetMaxHealth(maxHealth)
	boss:SetHealth(maxHealth)
	boss:SetPhysicalArmorBaseValue(ScaleFromBase(LEVEL_CONFIG.armor.base, LEVEL_CONFIG.armor.per_level, level))
	boss:SetBaseDamageMin(ScaleFromBase(LEVEL_CONFIG.attack_damage.base, LEVEL_CONFIG.attack_damage.per_level, level))
	boss:SetBaseDamageMax(ScaleFromBase(LEVEL_CONFIG.attack_damage.base, LEVEL_CONFIG.attack_damage.per_level, level))
end

function PrimalBeastBoss:MaxAbilities(boss)
	if not IsAlive(boss) then
		return
	end

	for _, name in ipairs(HOSTILE_ABILITIES) do
		SetAbilityVisible(boss:FindAbilityByName(name), true)
	end
end

function PrimalBeastBoss:GiveScepter(boss)
	if not IsAlive(boss) then
		return
	end

	if boss.SetHasScepter then
		boss:SetHasScepter(true)
	end
	if not boss:HasModifier("modifier_item_ultimate_scepter_consumed") then
		boss:AddNewModifier(boss, nil, "modifier_item_ultimate_scepter_consumed", {})
	end
end

function PrimalBeastBoss:GiveShard(boss)
	if not IsAlive(boss) then
		return
	end

	if boss.SetHasAghanimsShard then
		boss:SetHasAghanimsShard(true)
	end
	if not boss:HasModifier("modifier_item_aghanims_shard") then
		boss:AddNewModifier(boss, nil, "modifier_item_aghanims_shard", {})
	end

	SetAbilityVisible(boss:FindAbilityByName(ROCK_THROW_ABILITY), true, 1)
end

function PrimalBeastBoss:SetTrampleHidden(boss, hidden)
	if not IsAlive(boss) then
		return
	end

	SetAbilityVisible(boss:FindAbilityByName(TRAMPLE_ABILITY), not hidden)
end

function PrimalBeastBoss:PrepareHiddenTrample(boss)
	if not IsAlive(boss) then
		return
	end

	local trample = boss:FindAbilityByName(TRAMPLE_ABILITY)
	if not trample then
		return
	end

	trample:SetLevel(math.max(1, trample:GetMaxLevel()))
	trample:SetHidden(true)
	trample:SetActivated(false)
	if boss.RemoveModifierByName then
		boss:RemoveModifierByName(TRAMPLE_MODIFIER)
	end
end

local function LockSelectionToHero(playerID, hero)
	if not playerID or playerID < 0 or not PlayerResource.SetOverrideSelectionEntity then
		return
	end
	PlayerResource:SetOverrideSelectionEntity(playerID, hero)
end

function PrimalBeastBoss:SetAttackEnabled(boss, enabled)
	if not IsAlive(boss) then
		return
	end

	if enabled then
		boss:SetAttackCapability(DOTA_UNIT_CAP_MELEE_ATTACK)
		if boss.SetAcquisitionRange then
			boss:SetAcquisitionRange(900)
		end
	else
		boss:SetAttackCapability(DOTA_UNIT_CAP_NO_ATTACK)
	end
end

function PrimalBeastBoss:PrepareHostile(boss, level, pathwayEnabled)
	if not IsAlive(boss) then
		return
	end

	self:ApplyLevel(boss, level)
	self:MaxAbilities(boss)
	self:GiveScepter(boss)
	self:GiveShard(boss)
	self:SetTrampleHidden(boss, true)
	self:SetAttackEnabled(boss, true)
	boss.pathwayEnabled = pathwayEnabled == true
	boss.primalBeastAllied = false
	boss:SetModelScale(MODEL_SCALE)
	boss:RemoveModifierByName("modifier_invulnerable")
end

function PrimalBeastBoss:PrepareAllied(boss, level)
	if not IsAlive(boss) then
		return
	end

	self:ApplyLevel(boss, level)
	for _, name in ipairs(ALLIED_HIDDEN_ABILITIES) do
		local ability = boss:FindAbilityByName(name)
		if ability then
			ability:SetLevel(0)
			ability:SetHidden(true)
			ability:SetActivated(false)
		end
	end
	if boss.RemoveModifierByName then
		boss:RemoveModifierByName(TRAMPLE_MODIFIER)
		boss:RemoveModifierByName("modifier_primal_beast_pulverize")
		boss:RemoveModifierByName("modifier_primal_beast_uproar")
	end
	self:SetAttackEnabled(boss, false)
	boss.pathwayEnabled = false
	boss.primalBeastAllied = true
	boss:SetModelScale(MODEL_SCALE)
	boss:RemoveModifierByName("modifier_invulnerable")
	boss:AddNewModifier(boss, nil, "modifier_kill", { duration = GetAlliedLifetime(level) })
end

local function AbilitySpecial(ability, names, fallback)
	if not ability then
		return fallback
	end
	for _, name in ipairs(names) do
		local value = ability:GetSpecialValueFor(name)
		if value and value ~= 0 then
			return value
		end
	end
	return fallback
end

function PrimalBeastBoss:ApplyTramplePulse(boss)
	if not IsAlive(boss) then
		return
	end
	if boss.HasModifier and boss:HasModifier(TRAMPLE_MODIFIER) then
		boss:RemoveModifierByName(TRAMPLE_MODIFIER)
	end

	local trample = boss:FindAbilityByName(TRAMPLE_ABILITY)
	local radius = AbilitySpecial(trample, { "effect_radius" }, TRAMPLE_RADIUS)
	local baseDamage = AbilitySpecial(trample, { "base_damage", "damage" }, TRAMPLE_BASE_DAMAGE)
	local factor = AbilitySpecial(trample, { "attack_damage", "attack_factor" }, TRAMPLE_ATTACK_FACTOR)
	if factor > 1 then
		factor = factor / 100
	end

	local attack = 0
	if boss.GetAverageTrueAttackDamage then
		attack = boss:GetAverageTrueAttackDamage(nil) or 0
	end

	local enemies = FindUnitsInRadius(
		boss:GetTeamNumber(),
		boss:GetAbsOrigin(),
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	local rider = boss.primalBeastRider
	local damage = baseDamage + attack * factor
	for _, enemy in ipairs(enemies) do
		if IsAlive(enemy) and enemy ~= boss and enemy ~= rider then
			ApplyDamage({
				victim = enemy,
				attacker = boss,
				damage = damage,
				damage_type = DAMAGE_TYPE_MAGICAL,
				ability = trample,
			})
		end
	end
end

function PrimalBeastBoss:TryCastPulverize(boss, target)
	if not IsAlive(boss) or boss.primalBeastAllied then
		return false
	end

	local pulverize = boss:FindAbilityByName(PULVERIZE_ABILITY)
	if not pulverize or pulverize:GetLevel() < 1 or not pulverize:IsFullyCastable() then
		return false
	end

	if not IsAlive(target) or (target:GetAbsOrigin() - boss:GetAbsOrigin()):Length2D() > PULVERIZE_RANGE then
		local enemies = FindUnitsInRadius(
			boss:GetTeamNumber(),
			boss:GetAbsOrigin(),
			nil,
			PULVERIZE_RANGE,
			DOTA_UNIT_TARGET_TEAM_ENEMY,
			DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
			DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
			FIND_CLOSEST,
			false
		)
		target = nil
		for _, enemy in ipairs(enemies) do
			if IsAlive(enemy) and boss:CanEntityBeSeenByMyTeam(enemy) then
				target = enemy
				break
			end
		end
	end
	if not IsAlive(target) then
		return false
	end

	local direction = target:GetAbsOrigin() - boss:GetAbsOrigin()
	direction.z = 0
	if direction:Length2D() > 0 then
		boss:SetForwardVector(direction:Normalized())
	end
	boss:CastAbilityOnTarget(target, pulverize, -1)
	return true
end

function PrimalBeastBoss:StartPulverizeTelegraph(boss, target)
	if not IsAlive(boss) or boss.primalBeastAllied then
		return false
	end
	if boss:HasModifier(PULVERIZE_WARN_MODIFIER) then
		return false
	end
	if not IsAlive(target) then
		return false
	end

	local pulverize = boss:FindAbilityByName(PULVERIZE_ABILITY)
	if not pulverize or pulverize:GetLevel() < 1 or not pulverize:IsFullyCastable() then
		return false
	end

	boss:Stop()
	boss.primalBeastPulverizeTarget = target
	local direction = target:GetAbsOrigin() - boss:GetAbsOrigin()
	direction.z = 0
	if direction:Length2D() > 0 then
		boss:SetForwardVector(direction:Normalized())
	end
	boss:AddNewModifier(boss, nil, PULVERIZE_WARN_MODIFIER, {
		duration = PULVERIZE_WARN_DURATION,
	})
	return true
end

function PrimalBeastBoss:ClearTowerAggro(boss)
	local forced = boss and boss.primalBeastTowerAggro
	if not forced then
		return
	end
	for _, tower in pairs(forced) do
		if IsValidHandle(tower) and tower.SetForceAttackTarget then
			tower:SetForceAttackTarget(nil)
		end
	end
	boss.primalBeastTowerAggro = nil
end

function PrimalBeastBoss:ReleaseParentedUnits(boss)
	if not IsValidHandle(boss) then
		return
	end

	local origin = boss:GetAbsOrigin()
	local flags = DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_INVULNERABLE
	for _, team in ipairs({ DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS, DOTA_TEAM_NEUTRALS }) do
		local units = FindUnitsInRadius(
			team,
			origin,
			nil,
			600,
			DOTA_UNIT_TARGET_TEAM_BOTH,
			DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
			flags,
			FIND_ANY_ORDER,
			false
		)
		for _, unit in ipairs(units) do
			if IsValidHandle(unit) and unit ~= boss and unit.GetMoveParent and unit:GetMoveParent() == boss then
				if unit.SetParent then
					unit:SetParent(nil, "")
				end
				if unit.FollowEntity then
					unit:FollowEntity(unit, false)
				end
				FindClearSpaceForUnit(unit, unit:GetAbsOrigin(), false)
			end
		end
	end
end

function PrimalBeastBoss:CleanupCombat(boss)
	if not IsValidHandle(boss) then
		return
	end

	self:ClearTowerAggro(boss)
	self:DestroyMountMarkers(boss)
	if boss.Stop then
		boss:Stop()
	end
	if boss.Interrupt then
		boss:Interrupt()
	end
	if boss.RemoveModifierByName then
		boss:RemoveModifierByName(PULVERIZE_WARN_MODIFIER)
		boss:RemoveModifierByName("modifier_primal_beast_pulverize")
		boss:RemoveModifierByName(TRAMPLE_MODIFIER)
	end
	self:ReleaseParentedUnits(boss)
end

function PrimalBeastBoss:AggroTowers(boss)
	if not IsAlive(boss) or boss.primalBeastAllied then
		self:ClearTowerAggro(boss)
		return
	end

	boss.primalBeastTowerAggro = boss.primalBeastTowerAggro or {}
	local seen = {}
	local towers = {}
	for _, team in ipairs({ DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS }) do
		local found = FindUnitsInRadius(
			team,
			boss:GetAbsOrigin(),
			nil,
			TOWER_AGGRO_RANGE,
			DOTA_UNIT_TARGET_TEAM_FRIENDLY,
			DOTA_UNIT_TARGET_BUILDING,
			DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
			FIND_ANY_ORDER,
			false
		)
		for _, unit in ipairs(found) do
			towers[#towers + 1] = unit
		end
	end

	for _, tower in ipairs(towers) do
		if IsAlive(tower) and tower.IsTower and tower:IsTower() then
			seen[tower:entindex()] = true
			local attackTarget = tower.GetAttackTarget and tower:GetAttackTarget() or nil
			if IsAlive(attackTarget) and attackTarget.IsRealHero and attackTarget:IsRealHero() then
				if tower.SetForceAttackTarget then
					tower:SetForceAttackTarget(nil)
				end
				boss.primalBeastTowerAggro[tower:entindex()] = nil
			else
				if tower.SetForceAttackTarget then
					tower:SetForceAttackTarget(boss)
				end
				tower:MoveToTargetToAttack(boss)
				boss.primalBeastTowerAggro[tower:entindex()] = tower
			end
		end
	end

	for index, tower in pairs(boss.primalBeastTowerAggro) do
		if not seen[index] then
			if IsValidHandle(tower) and tower.SetForceAttackTarget then
				tower:SetForceAttackTarget(nil)
			end
			boss.primalBeastTowerAggro[index] = nil
		end
	end
end

function PrimalBeastBoss:Steer(beast, position)
	if not IsAlive(beast) or not position then
		return
	end

	local roll = beast:FindModifierByName(ROLL_MODIFIER)
	if not roll then
		return
	end

	local origin = beast:GetAbsOrigin()
	local direction = Flatten(position - origin)
	roll.desiredDir = direction
end

function PrimalBeastBoss:Dismount(beast)
	if not beast or (beast.IsNull and beast:IsNull()) then
		return
	end

	local rider = beast.primalBeastRider
	beast.primalBeastRider = nil
	beast:RemoveModifierByName(ROLL_MODIFIER)
	if beast.primalBeastAllied then
		self:SetAttackEnabled(beast, false)
	else
		self:SetTrampleHidden(beast, true)
	end

	if not IsAlive(rider) then
		return
	end

	local playerID = rider:GetPlayerOwnerID()
	rider:RemoveModifierByName(RIDER_MODIFIER)
	DetachRider(rider)
	FindClearSpaceForUnit(rider, beast:GetAbsOrigin(), true)
	rider:Stop()

	if playerID and playerID >= 0 then
		if beast.SetControllableByPlayer then
			beast:SetControllableByPlayer(playerID, false)
		end
		LockSelectionToHero(playerID, nil)
	end
end

function PrimalBeastBoss:Mount(hero, beast)
	if not IsAlive(hero) or not IsAlive(beast) then
		return false
	end
	if not hero:IsRealHero() or hero:IsIllusion() then
		return false
	end
	if hero:GetTeamNumber() ~= beast:GetTeamNumber() then
		return false
	end
	if beast.primalBeastRider and IsAlive(beast.primalBeastRider) then
		return false
	end
	if hero:HasModifier(RIDER_MODIFIER) then
		return false
	end
	if (hero:GetAbsOrigin() - beast:GetAbsOrigin()):Length2D() > MOUNT_RANGE then
		return false
	end

	local playerID = hero:GetPlayerOwnerID()
	if not playerID or playerID < 0 then
		return false
	end

	beast.primalBeastRider = hero
	hero.primalBeastMount = beast
	hero:Interrupt()
	hero:Stop()
	self:DestroyMountMarkers(beast)
	hero:AddNewModifier(beast, nil, RIDER_MODIFIER, {})
	AttachRider(hero, beast)

	self:SetAttackEnabled(beast, false)
	if not beast:HasModifier(ROLL_MODIFIER) then
		beast:AddNewModifier(beast, nil, ROLL_MODIFIER, {})
	end
	if beast.SetControllableByPlayer then
		beast:SetControllableByPlayer(playerID, false)
	end
	LockSelectionToHero(playerID, hero)
	self:Steer(beast, beast:GetAbsOrigin() + beast:GetForwardVector() * 200)
	return true
end

function PrimalBeastBoss:ConvertToAlly(killedBoss, team)
	if not IsValidHandle(killedBoss) then
		return
	end
	if not GetPlayerTeam(team) then
		return
	end
	if killedBoss.primalBeastConverting then
		return
	end
	killedBoss.primalBeastConverting = true

	local position = killedBoss:GetAbsOrigin()
	local forward = killedBoss:GetForwardVector()
	local level = killedBoss.primalBeastLevel or killedBoss.spawnNumber or 1
	self:CleanupCombat(killedBoss)
	if killedBoss.AddNoDraw then
		killedBoss:AddNoDraw()
	end

	Timers:CreateTimer(0.35, function()
		local ally = CreateUnitByName(BOSS_NAME, position, false, nil, nil, team)
		if not ally then
			print("[PrimalBeastBoss] Failed to create allied mount")
			return nil
		end

		ally:SetAbsOrigin(GetGroundPosition(position, ally))
		ally:SetForwardVector(forward)
		PrimalBeastBoss:PrepareAllied(ally, level)
		ally:AddNewModifier(ally, nil, MOUNTABLE_MODIFIER, {})
		return nil
	end)
end

function PrimalBeastBoss:OnEntityKilled(unit, event)
	if not unit or (unit.IsNull and unit:IsNull()) then
		return
	end
	if unit:GetUnitName() ~= BOSS_NAME then
		return
	end
	if unit.reachedFinalPoint then
		self:CleanupCombat(unit)
		return
	end

	if unit.primalBeastAllied then
		self:CleanupCombat(unit)
		self:Dismount(unit)
		return
	end

	self:CleanupCombat(unit)

	local attackerIndex = event and (event.entindex_attacker or event.entindex_attacker_const)
	local attacker = attackerIndex and EntIndexToHScript(attackerIndex) or nil
	local team = attacker and not attacker:IsNull() and attacker:GetTeamNumber() or nil
	self:ConvertToAlly(unit, team)
end

local STEER_AND_BLOCK_ORDERS = {
	[DOTA_UNIT_ORDER_MOVE_TO_POSITION or 1] = true,
	[DOTA_UNIT_ORDER_MOVE_TO_TARGET or 2] = true,
	[DOTA_UNIT_ORDER_ATTACK_MOVE or 3] = true,
}

local function OrderPosition(data)
	if data.position_x ~= nil then
		return Vector(data.position_x, data.position_y, data.position_z)
	end
	return nil
end

function PrimalBeastBossHandleOrder(data)
	if not data then
		return true
	end

	local order = data.order_type
	local targetIndex = tonumber(data.entindex_target)
	local target = targetIndex and EntIndexToHScript(targetIndex) or nil

	if order == DOTA_UNIT_ORDER_MOVE_TO_TARGET or order == DOTA_UNIT_ORDER_ATTACK_TARGET then
		if IsAlive(target) and target:GetUnitName() == BOSS_NAME and target:HasModifier(MOUNTABLE_MODIFIER) then
			if not (target.primalBeastRider and IsAlive(target.primalBeastRider)) then
				for _, unitIndex in pairs(data.units or {}) do
					local hero = EntIndexToHScript(tonumber(unitIndex))
					if IsAlive(hero) and hero:IsRealHero() then
						if PrimalBeastBoss:Mount(hero, target) then
							return false
						end
					end
				end
			end
		end
	end

	local function SteerFromOrder(beast)
		local position = OrderPosition(data)
		if (order == DOTA_UNIT_ORDER_MOVE_TO_TARGET or order == DOTA_UNIT_ORDER_ATTACK_TARGET) and IsAlive(target) then
			position = target:GetAbsOrigin()
		end
		if position then
			PrimalBeastBoss:Steer(beast, position)
		end
	end

	for _, unitIndex in pairs(data.units or {}) do
		local unit = EntIndexToHScript(tonumber(unitIndex))
		if IsAlive(unit) then
			if unit:GetUnitName() == BOSS_NAME and unit.primalBeastAllied then
				if IsAlive(unit.primalBeastRider) and (STEER_AND_BLOCK_ORDERS[order] or order == DOTA_UNIT_ORDER_ATTACK_TARGET) then
					SteerFromOrder(unit)
				end
				return false
			end

			local beast = unit.primalBeastMount
			if unit:HasModifier(RIDER_MODIFIER) and IsAlive(beast) then
				if STEER_AND_BLOCK_ORDERS[order] then
					SteerFromOrder(beast)
					return false
				end

				if order == DOTA_UNIT_ORDER_ATTACK_TARGET and IsAlive(target) then
					if target ~= beast then
						PrimalBeastBoss:Steer(beast, target:GetAbsOrigin())
					end
					return true
				end
			end
		end
	end

	local playerID = data.issuer_player_id_const
	if playerID and playerID >= 0 then
		local hero = PlayerResource:GetSelectedHeroEntity(playerID)
		local beast = hero and hero.primalBeastMount
		if IsAlive(hero) and hero:HasModifier(RIDER_MODIFIER) and IsAlive(beast) then
			if STEER_AND_BLOCK_ORDERS[order] then
				SteerFromOrder(beast)
				return false
			end
			if order == DOTA_UNIT_ORDER_ATTACK_TARGET and IsAlive(target) and target ~= beast then
				PrimalBeastBoss:Steer(beast, target:GetAbsOrigin())
			end
		end
	end

	return true
end

function PrimalBeastBoss:Init()
	if self.commandsRegistered then
		return
	end
	self.commandsRegistered = true

	Convars:RegisterCommand("spawn_primal_beast_boss", function(_, x, y, z)
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
			print("[PrimalBeastBoss] Failed to spawn debug boss")
			return
		end

		self:PrepareHostile(boss, 1, false)
		boss:SetAngles(0, RandomFloat(0, 360), 0)
		AddFOWViewer(DOTA_TEAM_GOODGUYS, position, DEBUG_VISION_RADIUS, DEBUG_VISION_DURATION, false)
		AddFOWViewer(DOTA_TEAM_BADGUYS, position, DEBUG_VISION_RADIUS, DEBUG_VISION_DURATION, false)
		print("[PrimalBeastBoss] Debug boss spawned")
	end, "Spawn hostile Primal Beast: spawn_primal_beast_boss [x y z]", FCVAR_CHEAT)
end

modifier_primal_beast_boss_mountable_trinity = class({})

function modifier_primal_beast_boss_mountable_trinity:IsHidden()
	return false
end

function modifier_primal_beast_boss_mountable_trinity:IsPurgable()
	return false
end

function modifier_primal_beast_boss_mountable_trinity:GetTexture()
	return "primal_beast_trample"
end

function modifier_primal_beast_boss_mountable_trinity:GetEffectName()
	return MARKER_PARTICLE
end

function modifier_primal_beast_boss_mountable_trinity:GetEffectAttachType()
	return PATTACH_OVERHEAD_FOLLOW
end

function modifier_primal_beast_boss_mountable_trinity:OnCreated()
	if not IsServer() then
		return
	end
	PrimalBeastBoss:DestroyMountMarkers(self:GetParent())
end

function modifier_primal_beast_boss_mountable_trinity:CheckState()
	return {
		[MODIFIER_STATE_ROOTED] = true,
		[MODIFIER_STATE_DISARMED] = true,
	}
end

function modifier_primal_beast_boss_mountable_trinity:OnDestroy()
	if not IsServer() then
		return
	end
	local parent = self:GetParent()
	PrimalBeastBoss:DestroyMountMarkers(parent)
	PrimalBeastBoss:Dismount(parent)
end

modifier_primal_beast_boss_rider_trinity = class({})

function modifier_primal_beast_boss_rider_trinity:IsHidden()
	return false
end

function modifier_primal_beast_boss_rider_trinity:IsPurgable()
	return false
end

function modifier_primal_beast_boss_rider_trinity:GetTexture()
	return "primal_beast_pulverize"
end

function modifier_primal_beast_boss_rider_trinity:CheckState()
	return {
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_FLYING] = true,
	}
end

function modifier_primal_beast_boss_rider_trinity:OnCreated()
	if not IsServer() then
		return
	end
	self:StartIntervalThink(0.25)
end

function modifier_primal_beast_boss_rider_trinity:OnIntervalThink()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if not IsAlive(parent) then
		return
	end

	local beast = parent.primalBeastMount
	if not IsAlive(beast) then
		self:Destroy()
	end
end

function modifier_primal_beast_boss_rider_trinity:OnDestroy()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if not parent or (parent.IsNull and parent:IsNull()) then
		return
	end

	parent.primalBeastMount = nil
	DetachRider(parent)
end

modifier_primal_beast_boss_roll_trinity = class({})

function modifier_primal_beast_boss_roll_trinity:IsHidden()
	return true
end

function modifier_primal_beast_boss_roll_trinity:IsPurgable()
	return false
end

function modifier_primal_beast_boss_roll_trinity:OnCreated()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	self.desiredDir = Flatten(parent:GetForwardVector())
	self.trampleDist = 0
	parent:Stop()
	if parent.HasModifier and parent:HasModifier(TRAMPLE_MODIFIER) then
		parent:RemoveModifierByName(TRAMPLE_MODIFIER)
	end
	self:StartIntervalThink(ROLL_THINK)
end

function modifier_primal_beast_boss_roll_trinity:OnDestroy()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if IsAlive(parent) then
		parent:FadeGesture(ACT_DOTA_RUN)
		FindClearSpaceForUnit(parent, parent:GetAbsOrigin(), false)
	end
end

function modifier_primal_beast_boss_roll_trinity:GetPriority()
	return MODIFIER_PRIORITY_ULTRA
end

function modifier_primal_beast_boss_roll_trinity:CheckState()
	return {
		[MODIFIER_STATE_ROOTED] = true,
		[MODIFIER_STATE_DISARMED] = true,
	}
end

function modifier_primal_beast_boss_roll_trinity:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_IGNORE_MOVESPEED_LIMIT,
		MODIFIER_PROPERTY_MOVESPEED_ABSOLUTE,
		MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE,
		MODIFIER_PROPERTY_MANACOST_PERCENTAGE_STACKING,
		MODIFIER_PROPERTY_OVERRIDE_ANIMATION,
	}
end

function modifier_primal_beast_boss_roll_trinity:GetOverrideAnimation()
	return ACT_DOTA_RUN
end

function modifier_primal_beast_boss_roll_trinity:GetModifierIgnoreMovespeedLimit()
	return 1
end

function modifier_primal_beast_boss_roll_trinity:GetModifierMoveSpeed_Absolute()
	return ROLL_SPEED
end

function modifier_primal_beast_boss_roll_trinity:GetModifierPercentageCooldown()
	return 100
end

function modifier_primal_beast_boss_roll_trinity:GetModifierPercentageManacostStacking()
	return 100
end

function modifier_primal_beast_boss_roll_trinity:OnIntervalThink()
	self:UpdateHorizontalMotion(self:GetParent(), ROLL_THINK)
end

function modifier_primal_beast_boss_roll_trinity:UpdateHorizontalMotion(me, dt)
	if not IsAlive(me) then
		self:Destroy()
		return
	end

	local forward = Flatten(me:GetForwardVector())
	local desired = self.desiredDir and Flatten(self.desiredDir) or forward
	local currentYaw = YawFromVector(forward)
	local desiredYaw = YawFromVector(desired)
	local diff = AngleDiff(desiredYaw, currentYaw)
	local maxTurn = ROLL_TURN_RATE * dt
	if math.abs(diff) > maxTurn then
		diff = (diff > 0 and 1 or -1) * maxTurn
	end

	local newForward = VectorFromYaw(currentYaw + diff)
	me:SetForwardVector(newForward)

	local origin = me:GetAbsOrigin()
	local nextPos = GetGroundPosition(origin + newForward * ROLL_SPEED * dt, me)
	if IsFiniteVec(nextPos) and IsWalkable(nextPos) then
		me:SetAbsOrigin(nextPos)
		if IsAlive(me.primalBeastRider) then
			self.trampleDist = (self.trampleDist or 0) + ROLL_SPEED * dt
		end
	end

	if GridNav and GridNav.DestroyTreesAroundPoint then
		GridNav:DestroyTreesAroundPoint(me:GetAbsOrigin(), ROLL_TREE_RADIUS, false)
	end

	local rider = me.primalBeastRider
	if IsAlive(rider) then
		PlaceRiderOnSpine(rider, me)
	end

	if IsAlive(rider) and (self.trampleDist or 0) >= TRAMPLE_STEP then
		self.trampleDist = 0
		PrimalBeastBoss:ApplyTramplePulse(me)
	end
end

modifier_primal_beast_boss_marker_trinity = class({})

function modifier_primal_beast_boss_marker_trinity:IsHidden()
	return true
end

function modifier_primal_beast_boss_marker_trinity:IsPurgable()
	return false
end

function modifier_primal_beast_boss_marker_trinity:CheckState()
	return {
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_UNSELECTABLE] = true,
		[MODIFIER_STATE_NOT_ON_MINIMAP] = true,
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_NO_TEAM_MOVE_TO] = true,
		[MODIFIER_STATE_NO_TEAM_SELECT] = true,
		[MODIFIER_STATE_ATTACK_IMMUNE] = true,
		[MODIFIER_STATE_MAGIC_IMMUNE] = true,
		[MODIFIER_STATE_COMMAND_RESTRICTED] = true,
		[MODIFIER_STATE_ROOTED] = true,
		[MODIFIER_STATE_DISARMED] = true,
	}
end

modifier_primal_beast_boss_pulverize_warn_trinity = class({})

function modifier_primal_beast_boss_pulverize_warn_trinity:IsHidden()
	return true
end

function modifier_primal_beast_boss_pulverize_warn_trinity:IsPurgable()
	return false
end

function modifier_primal_beast_boss_pulverize_warn_trinity:GetPriority()
	return MODIFIER_PRIORITY_ULTRA
end

function modifier_primal_beast_boss_pulverize_warn_trinity:CheckState()
	return {
		[MODIFIER_STATE_ROOTED] = true,
		[MODIFIER_STATE_DISARMED] = true,
	}
end

function modifier_primal_beast_boss_pulverize_warn_trinity:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_OVERRIDE_ANIMATION,
		MODIFIER_PROPERTY_TRANSLATE_ACTIVITY_MODIFIERS,
	}
end

function modifier_primal_beast_boss_pulverize_warn_trinity:GetOverrideAnimation()
	return ACT_DOTA_CAST_ABILITY_1
end

function modifier_primal_beast_boss_pulverize_warn_trinity:GetActivityTranslationModifiers()
	return "effigy"
end

function modifier_primal_beast_boss_pulverize_warn_trinity:OnCreated(kv)
	if not IsServer() then
		return
	end

	self.targetIndex = kv and tonumber(kv.target) or nil
	local parent = self:GetParent()
	parent:Stop()
	parent:AddActivityModifier("effigy")
	if parent.LookupSequence and parent.ResetSequence then
		local seq = parent:LookupSequence("pb_cast_onslaught_effigy")
		if seq and seq >= 0 then
			parent:ResetSequence(seq)
		end
	end
	parent:StartGesture(ACT_DOTA_CAST_ABILITY_1)
	parent:EmitSound(PULVERIZE_WARN_SOUND)

	local origin = parent:GetAbsOrigin()
	self.waveFx = ParticleManager:CreateParticle(PULVERIZE_WAVE_PARTICLE, PATTACH_ABSORIGIN_FOLLOW, parent)
	ParticleManager:SetParticleControl(self.waveFx, 0, origin)
	ParticleManager:SetParticleControl(self.waveFx, 1, Vector(700, 0, 0))
	ParticleManager:SetParticleControl(self.waveFx, 2, Vector(700, 0, 0))

	self.bang = SpawnEntityFromTableSynchronous("prop_dynamic", {
		origin = origin,
		model = PULVERIZE_BANG_MODEL,
		DefaultAnim = PULVERIZE_BANG_ANIM,
		HoldAnimation = "1",
	})
	if IsValidHandle(self.bang) then
		if self.bang.SetModelScale then
			self.bang:SetModelScale(PULVERIZE_BANG_SCALE)
		end
		if DoEntFireByInstanceHandle then
			DoEntFireByInstanceHandle(self.bang, "SetAnimation", PULVERIZE_BANG_ANIM, 0, nil, nil)
		end
	end

	self:StartIntervalThink(0.03)
	self:OnIntervalThink()
end

function modifier_primal_beast_boss_pulverize_warn_trinity:OnIntervalThink()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	local bang = self.bang
	if not IsAlive(parent) or not IsValidHandle(bang) then
		return
	end

	local origin
	if parent.ScriptLookupAttachment and parent.GetAttachmentOrigin then
		local attach = parent:ScriptLookupAttachment("attach_hitloc")
		if attach and attach ~= 0 then
			origin = parent:GetAttachmentOrigin(attach)
		end
	end
	if not origin then
		origin = parent:GetAbsOrigin() + Vector(0, 0, 280)
	end
	bang:SetAbsOrigin(Vector(origin.x, origin.y, origin.z + PULVERIZE_BANG_HEIGHT))
end

function modifier_primal_beast_boss_pulverize_warn_trinity:OnDestroy()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if IsValidHandle(parent) then
		parent:FadeGesture(ACT_DOTA_CAST_ABILITY_1)
		if parent.ClearActivityModifiers then
			parent:ClearActivityModifiers()
		end
	end

	if self.waveFx then
		ParticleManager:DestroyParticle(self.waveFx, false)
		ParticleManager:ReleaseParticleIndex(self.waveFx)
		self.waveFx = nil
	end
	if IsValidHandle(self.bang) then
		UTIL_Remove(self.bang)
	end
	self.bang = nil

	if not IsAlive(parent) or parent.primalBeastAllied then
		return
	end

	local target = parent.primalBeastPulverizeTarget
	Timers:CreateTimer(0.05, function()
		if not IsAlive(parent) then
			return nil
		end
		PrimalBeastBoss:TryCastPulverize(parent, target or parent.primalBeastPulverizeTarget)
		parent.primalBeastPulverizeTarget = nil
		return nil
	end)
end
