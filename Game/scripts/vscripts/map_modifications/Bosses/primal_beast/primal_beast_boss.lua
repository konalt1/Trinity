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
local RIDER_ATTACH = "spine_2"
local RIDER_HEIGHT_OFFSET = 90
local MODEL_SCALE = 1.8
local MOUNT_RANGE = 250
local DEBUG_VISION_RADIUS = 800
local DEBUG_VISION_DURATION = 5
local ROLL_SPEED = 550
local ROLL_TURN_RATE = 120
local ROLL_TREE_RADIUS = 180
local ALLIED_LIFETIME = 60
local ROLL_THINK = 0.03

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

local function IsAlive(unit)
	return unit and (not unit.IsNull or not unit:IsNull()) and unit:IsAlive()
end

local function NormalizeLevel(level)
	return math.max(1, math.floor(tonumber(level) or 1))
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

local function GetRiderAttachIndex(beast)
	if not beast.ScriptLookupAttachment then
		return 0
	end
	local attach = beast:ScriptLookupAttachment(RIDER_ATTACH)
	if attach ~= 0 then
		return attach
	end
	return beast:ScriptLookupAttachment("attach_hitloc")
end

local function PlaceRiderOnSpine(hero, beast)
	if not IsAlive(hero) or not IsAlive(beast) then
		return
	end

	local attach = GetRiderAttachIndex(beast)
	local origin
	if attach and attach ~= 0 and beast.GetAttachmentOrigin then
		origin = beast:GetAttachmentOrigin(attach)
	else
		origin = beast:GetAbsOrigin()
	end
	hero:SetAbsOrigin(Vector(origin.x, origin.y, origin.z + RIDER_HEIGHT_OFFSET))

	local busy = (hero.IsAttacking and hero:IsAttacking())
		or (hero.IsChanneling and hero:IsChanneling())
		or (hero.GetAttackTarget and hero:GetAttackTarget())
		or (hero.GetCurrentActiveAbility and hero:GetCurrentActiveAbility())
	if busy then
		return
	end

	hero:SetAbsAngles(0, beast:GetAnglesAsVector().y, 0)
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
	trample:SetActivated(true)
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
		SetAbilityVisible(boss:FindAbilityByName(name), false)
	end
	self:PrepareHiddenTrample(boss)
	self:SetAttackEnabled(boss, false)
	boss.pathwayEnabled = false
	boss.primalBeastAllied = true
	boss:SetModelScale(MODEL_SCALE)
	boss:RemoveModifierByName("modifier_invulnerable")
	boss:AddNewModifier(boss, nil, "modifier_kill", { duration = ALLIED_LIFETIME })
end

function PrimalBeastBoss:TryCastTrample(boss)
	if not IsAlive(boss) then
		return
	end

	local trample = boss:FindAbilityByName(TRAMPLE_ABILITY)
	if not trample or trample:GetLevel() < 1 then
		return
	end

	trample:EndCooldown()
	if boss.SetMana and boss.GetMaxMana then
		boss:SetMana(boss:GetMaxMana())
	end
	if boss:HasModifier(TRAMPLE_MODIFIER) then
		return
	end
	if boss:IsChanneling() then
		return
	end

	boss:CastAbilityNoTarget(trample, -1)
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
		self:PrepareHiddenTrample(beast)
		self:SetAttackEnabled(beast, false)
	else
		self:SetTrampleHidden(beast, true)
	end

	if not IsAlive(rider) then
		return
	end

	local playerID = rider:GetPlayerOwnerID()
	rider:RemoveModifierByName(RIDER_MODIFIER)
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
	hero:AddNewModifier(beast, nil, RIDER_MODIFIER, {})
	PlaceRiderOnSpine(hero, beast)

	local mountable = beast:FindModifierByName(MOUNTABLE_MODIFIER)
	if mountable then
		mountable:ForceRefresh()
	end

	self:PrepareHiddenTrample(beast)
	self:SetAttackEnabled(beast, false)
	if not beast:HasModifier(ROLL_MODIFIER) then
		beast:AddNewModifier(beast, nil, ROLL_MODIFIER, {})
	end
	if beast.SetControllableByPlayer then
		beast:SetControllableByPlayer(playerID, false)
	end
	LockSelectionToHero(playerID, hero)
	self:Steer(beast, beast:GetAbsOrigin() + beast:GetForwardVector() * 200)
	self:TryCastTrample(beast)
	beast:StartGesture(ACT_DOTA_RUN)
	return true
end

function PrimalBeastBoss:ConvertToAlly(killedBoss, team)
	if not killedBoss or (killedBoss.IsNull and killedBoss:IsNull()) then
		return
	end
	if not GetPlayerTeam(team) then
		return
	end

	local position = killedBoss:GetAbsOrigin()
	local forward = killedBoss:GetForwardVector()
	local level = killedBoss.primalBeastLevel or killedBoss.spawnNumber or 1
	killedBoss:AddNoDraw()

	local ally = CreateUnitByName(BOSS_NAME, position, true, nil, nil, team)
	if not ally then
		print("[PrimalBeastBoss] Failed to create allied mount")
		return
	end

	ally:SetForwardVector(forward)
	self:PrepareAllied(ally, level)
	ally:AddNewModifier(ally, nil, MOUNTABLE_MODIFIER, {})

	Timers:CreateTimer(0.05, function()
		if killedBoss and not killedBoss:IsNull() then
			UTIL_Remove(killedBoss)
		end
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
		return
	end

	if unit.primalBeastAllied then
		self:Dismount(unit)
		return
	end

	local attackerIndex = event and (event.entindex_attacker or event.entindex_attacker_const)
	local attacker = attackerIndex and EntIndexToHScript(attackerIndex) or nil
	local team = attacker and not attacker:IsNull() and attacker:GetTeamNumber() or nil
	self:ConvertToAlly(unit, team)
end

local STEER_AND_BLOCK_ORDERS = {
	[DOTA_UNIT_ORDER_MOVE_TO_POSITION] = true,
	[DOTA_UNIT_ORDER_MOVE_TO_TARGET] = true,
	[DOTA_UNIT_ORDER_ATTACK_MOVE] = true,
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

function modifier_primal_beast_boss_mountable_trinity:OnCreated()
	if not IsServer() then
		return
	end
	self:StartIntervalThink(0.2)
end

function modifier_primal_beast_boss_mountable_trinity:OnIntervalThink()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if not IsAlive(parent) then
		return
	end

	local rider = parent.primalBeastRider
	if not IsAlive(rider) then
		return
	end
	PrimalBeastBoss:TryCastTrample(parent)
end

function modifier_primal_beast_boss_mountable_trinity:CheckState()
	local parent = self:GetParent()
	local hasRider = parent and parent.primalBeastRider and IsAlive(parent.primalBeastRider)
	return {
		[MODIFIER_STATE_ROOTED] = not hasRider,
		[MODIFIER_STATE_DISARMED] = true,
		[MODIFIER_STATE_UNSELECTABLE] = hasRider,
	}
end

function modifier_primal_beast_boss_mountable_trinity:OnDestroy()
	if not IsServer() then
		return
	end
	PrimalBeastBoss:Dismount(self:GetParent())
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
		[MODIFIER_STATE_ROOTED] = true,
	}
end

function modifier_primal_beast_boss_rider_trinity:OnCreated()
	if not IsServer() then
		return
	end
	self:StartIntervalThink(ROLL_THINK)
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
		return
	end

	PlaceRiderOnSpine(parent, beast)
	LockSelectionToHero(parent:GetPlayerOwnerID(), parent)
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
	parent:Stop()
	parent:FadeGesture(ACT_DOTA_IDLE)
	parent:StartGesture(ACT_DOTA_RUN)
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
		MODIFIER_PROPERTY_TRANSLATE_ACTIVITY_MODIFIERS,
	}
end

function modifier_primal_beast_boss_roll_trinity:GetOverrideAnimation()
	return ACT_DOTA_RUN
end

function modifier_primal_beast_boss_roll_trinity:GetActivityTranslationModifiers()
	return "haste"
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
	if IsWalkable(nextPos) then
		me:SetAbsOrigin(nextPos)
	end

	if GridNav and GridNav.DestroyTreesAroundPoint then
		GridNav:DestroyTreesAroundPoint(me:GetAbsOrigin(), ROLL_TREE_RADIUS, false)
	end

	local rider = me.primalBeastRider
	if IsAlive(rider) then
		PlaceRiderOnSpine(rider, me)
	end
end
