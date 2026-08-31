-- Ранний выход на карту после пика: игрок не ждёт чужой выбор.
-- Разминка длится HERO_SELECTION_TIME с часами от -1:30. В -0:30 — вайп, тик золота/опыта и FB.
-- Крипы, день и уязвимость башен — в 0:00.

if DraftSpawn == nil then
	DraftSpawn = {}
end

LinkLuaModifier("modifier_trinity_warmup_zone", "modifiers/modifier_trinity_warmup_zone", LUA_MODIFIER_MOTION_NONE)

local ORDER_PURCHASE_ITEM = DOTA_UNIT_ORDER_PURCHASE_ITEM or 16
local ORDER_SELL_ITEM = DOTA_UNIT_ORDER_SELL_ITEM or 17
local ORDER_MOVE_TO_POSITION = DOTA_UNIT_ORDER_MOVE_TO_POSITION or 1
local ORDER_ATTACK_MOVE = DOTA_UNIT_ORDER_ATTACK_MOVE or 3
local ORDER_CAST_POSITION = DOTA_UNIT_ORDER_CAST_POSITION or 5
local ORDER_CAST_TARGET = DOTA_UNIT_ORDER_CAST_TARGET or 6
local ORDER_DROP_ITEM = DOTA_UNIT_ORDER_DROP_ITEM or 12
local ORDER_MOVE_TO_DIRECTION = DOTA_UNIT_ORDER_MOVE_TO_DIRECTION or 20
local ORDER_VECTOR_TARGET_POSITION = DOTA_UNIT_ORDER_VECTOR_TARGET_POSITION or 30

local WARMUP_ZONE_ENTITY = "trinity_warmup_zone"
local WARMUP_SPAWN_ENTITY = "trinity_warmup_spawn"
local WARMUP_SPAWN_GOOD_ENTITY = "trinity_warmup_spawn_good"
local WARMUP_SPAWN_BAD_ENTITY = "trinity_warmup_spawn_bad"
local WARMUP_DUMMY_SPAWN_ENTITY = "trinity_warmup_dummy"
local WARMUP_DUMMY_UNIT = "npc_dota_hero_target_dummy"

local WARMUP_WARD_CLASSNAMES = {
	"npc_dota_ward_base",
	"npc_dota_ward_base_truesight",
	"npc_dota_observer_wards",
	"npc_dota_sentry_wards",
}

local WARMUP_WARD_UNITS = {
	npc_dota_observer_wards = true,
	npc_dota_sentry_wards = true,
}

-- ItemStockInitial из npc/Items.txt: observer 2, sentry 3.
local WARMUP_WARD_STOCK = {
	{ item = "item_ward_observer", count = 2 },
	{ item = "item_ward_sentry", count = 3 },
}

function DraftSpawn:Init()
	if self._listeners_registered then
		return
	end
	self._listeners_registered = true
	self.matchStarted = false
	self.sandboxActive = false
	self.warmupEnded = false
	self.heroKillRewardsEnabled = false
	self._matchStartQueue = {}
	self._warmupHeroNotified = {}
	self._warmupSpawned = {}
	self._startingItems = {}
	self._resettingHero = {}
	self._cameraSnapTimers = {}
	if self.debugEnabled == nil then
		self.debugEnabled = false
	end

	if not _G.DRAFT_SPAWN_DEBUG_COMMAND_REGISTERED then
		_G.DRAFT_SPAWN_DEBUG_COMMAND_REGISTERED = true
		Convars:RegisterCommand("draft_spawn_debug", function(_, value)
			if value == nil or value == "" then
				DraftSpawn.debugEnabled = not DraftSpawn.debugEnabled
			else
				local normalized = string.lower(tostring(value))
				DraftSpawn.debugEnabled = normalized == "1" or normalized == "true" or normalized == "on"
			end
			print("[DraftSpawn] debug " .. (DraftSpawn.debugEnabled and "ON" or "OFF"))
		end, "Toggle day/night debug: draft_spawn_debug [0|1]", FCVAR_CHEAT)
	end

	ListenToGameEvent("game_rules_state_change", Dynamic_Wrap(self, "OnGameRulesStateChange"), self)
	ListenToGameEvent("dota_player_pick_hero", Dynamic_Wrap(self, "OnPlayerPickHero"), self)
	ListenToGameEvent("npc_spawned", Dynamic_Wrap(self, "OnNPCSpawned"), self)
	ListenToGameEvent("player_chat", Dynamic_Wrap(self, "OnPlayerChat"), self)
	ListenToGameEvent("player_reconnected", Dynamic_Wrap(self, "OnPlayerReconnect"), self)
	CustomGameEventManager:RegisterListener("trinity_warmup_level_up", function(_, event)
		DraftSpawn:OnWarmupLevelUp(event)
	end)
	CustomGameEventManager:RegisterListener("trinity_warmup_max_level", function(_, event)
		DraftSpawn:OnWarmupMaxLevel(event)
	end)
	CustomGameEventManager:RegisterListener("trinity_warmup_refresh", function(_, event)
		DraftSpawn:OnWarmupRefresh(event)
	end)
end

local STATE_NAMES = {
	[DOTA_GAMERULES_STATE_WAIT_FOR_PLAYERS_TO_LOAD] = "WAIT_FOR_PLAYERS",
	[DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP] = "CUSTOM_GAME_SETUP",
	[DOTA_GAMERULES_STATE_HERO_SELECTION] = "HERO_SELECTION",
	[DOTA_GAMERULES_STATE_STRATEGY_TIME] = "STRATEGY_TIME",
	[DOTA_GAMERULES_STATE_TEAM_SHOWCASE] = "TEAM_SHOWCASE",
	[DOTA_GAMERULES_STATE_WAIT_FOR_MAP_TO_LOAD] = "WAIT_FOR_MAP",
	[DOTA_GAMERULES_STATE_PRE_GAME] = "PRE_GAME",
	[DOTA_GAMERULES_STATE_GAME_IN_PROGRESS] = "GAME_IN_PROGRESS",
	[DOTA_GAMERULES_STATE_POST_GAME] = "POST_GAME",
}

function DraftSpawn:DebugEnabled()
	return self.debugEnabled == true
end

function DraftSpawn:DebugDayNight(action, before)
	if not self:DebugEnabled() then
		return
	end

	local after = GameRules:GetTimeOfDay() or -1
	local remaining = self:GetRemainingUntilZeroClock()
	local want = "night(0.75)"
	if self.matchStarted then
		want = "day(0.25)"
	end
	print(string.format(
		"[DraftSpawn] daynight action=%s before=%.3f after=%.3f want=%s remaining=%.1f state=%s warmupEnded=%s matchStarted=%s",
		tostring(action),
		tonumber(before) or -1,
		after,
		want,
		remaining,
		self:StateName(),
		tostring(self.warmupEnded),
		tostring(self.matchStarted)
	))
end

function DraftSpawn:DebugDummy(...)
	if not self:DebugEnabled() then
		return
	end

	local parts = { ... }
	for i = 1, #parts do
		parts[i] = tostring(parts[i])
	end
	print("[DraftSpawn] dummy " .. table.concat(parts, " "))
end

function DraftSpawn:StateName(state)
	state = state or GameRules:State_Get()
	return STATE_NAMES[state] or tostring(state)
end

function DraftSpawn:GetPlayerStat(playerID, getterName)
	local getter = PlayerResource[getterName]
	if not getter then
		return 0
	end
	return math.max(0, tonumber(getter(PlayerResource, playerID)) or 0)
end

function DraftSpawn:SetPlayerStatToZero(playerID, getterName, incrementName, setterName)
	local current = self:GetPlayerStat(playerID, getterName)
	if current == 0 then
		return 0
	end

	local setter = setterName and PlayerResource[setterName] or nil
	if setter then
		pcall(setter, PlayerResource, playerID, 0)
		current = self:GetPlayerStat(playerID, getterName)
		if current == 0 then
			return 0
		end
	end

	local increment = PlayerResource[incrementName]
	if increment then
		pcall(increment, PlayerResource, playerID, -current)
	end

	return self:GetPlayerStat(playerID, getterName)
end

function DraftSpawn:ResetPlayersKDA()
	for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if self:IsMatchPlayer(playerID) then
			self:SetPlayerStatToZero(playerID, "GetKills", "IncrementKills", "SetKills")
			self:SetPlayerStatToZero(playerID, "GetDeaths", "IncrementDeaths", "SetDeaths")
			self:SetPlayerStatToZero(playerID, "GetAssists", "IncrementAssists", "SetAssists")
		end
	end
end

function DraftSpawn:GetWarmupGold()
	return 9999
end

function DraftSpawn:GetDraftDuration()
	return HERO_SELECTION_TIME or 60
end

function DraftSpawn:GetPostWarmupPregameDuration()
	return WARMUP_POST_PREGAME_TIME or 30
end

function DraftSpawn:GetClockDuration()
	return self:GetDraftDuration() + self:GetPostWarmupPregameDuration()
end

function DraftSpawn:GetElapsedSinceDraft()
	if not self.draftStartTime then
		return 0
	end
	return GameRules:GetGameTime() - self.draftStartTime
end

function DraftSpawn:IsSandboxActive()
	return self.sandboxActive == true and self.warmupEnded ~= true and self.matchStarted ~= true
end

function DraftSpawn:IsMatchStarted()
	return self.matchStarted == true
end

function DraftSpawn:IsWarmupEnded()
	return self.warmupEnded == true
end

function DraftSpawn:GetMaxHeroLevel()
	return Max_level or 30
end

function DraftSpawn:ShouldBlockHeroKillRewards()
	return self.heroKillRewardsEnabled ~= true
end

local GOLD_REASON_HERO_KILL = DOTA_ModifyGold_HeroKill or 12
local GOLD_REASON_SHARED = DOTA_ModifyGold_SharedGold or 18
local GOLD_REASON_DEATH = DOTA_ModifyGold_Death or 1
local XP_REASON_HERO_KILL = DOTA_ModifyXP_HeroKill or 1
local XP_REASON_HERO_DENY = DOTA_ModifyXP_HeroDeny or 6

function DraftSpawn:SetEngineHeroKillRewardsEnabled(enabled)
	local mode = GameRules:GetGameModeEntity()
	if not mode then
		return
	end

	if mode.SetFirstBloodActive then
		mode:SetFirstBloodActive(enabled == true)
	end
	if mode.SetLoseGoldOnDeath then
		mode:SetLoseGoldOnDeath(enabled == true)
	end

end

function DraftSpawn:ModifyGoldFilter(data)
	if not self:ShouldBlockHeroKillRewards() or not data then
		return true
	end

	local reason = data.reason_const
	if reason == GOLD_REASON_HERO_KILL or reason == GOLD_REASON_SHARED or reason == GOLD_REASON_DEATH then
		data.gold = 0

		return false
	end

	return true
end

function DraftSpawn:ModifyExperienceFilter(data)
	if not self:ShouldBlockHeroKillRewards() or not data then
		return true
	end

	local reason = data.reason_const
	if reason == XP_REASON_HERO_KILL or reason == XP_REASON_HERO_DENY then
		data.experience = 0

		return false
	end

	return true
end

function DraftSpawn:GetRemainingUntilWarmupEnd()
	if self.warmupEnded or self.matchStarted then
		return 0
	end
	return self:GetDraftDuration() - self:GetElapsedSinceDraft()
end

function DraftSpawn:GetRemainingUntilZeroClock()
	if self.matchStarted then
		return 0
	end
	if not self.draftStartTime then
		return self:GetClockDuration()
	end
	return self:GetClockDuration() - self:GetElapsedSinceDraft()
end

function DraftSpawn:GetRemainingUntilMatchStart()
	return self:GetRemainingUntilWarmupEnd()
end

function DraftSpawn:WhenMatchStarts(callback)
	if type(callback) ~= "function" then
		return
	end
	if self.matchStarted then
		callback()

		return
	end
	self._matchStartQueue = self._matchStartQueue or {}
	self._matchStartQueue[#self._matchStartQueue + 1] = callback

	self:EnsureMatchStartTimer()
end

function DraftSpawn:OnGameRulesStateChange()
	local newState = GameRules:State_Get()

	if newState == DOTA_GAMERULES_STATE_HERO_SELECTION then
		self:OnHeroSelectionStarted()
	elseif newState == DOTA_GAMERULES_STATE_STRATEGY_TIME or newState == DOTA_GAMERULES_STATE_PRE_GAME then
		self:SyncPreGameTime()
		self:RandomUnpickedHeroes()
		self:EnsureWarmupZone()
		self:LockNightUntilLanePhase()
		if self:GetRemainingUntilWarmupEnd() <= 0.05 then
			self:EndWarmup()
		end
	elseif newState == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		self:EnsureMatchStartTimer()
		if self:GetRemainingUntilZeroClock() <= 0.05 then
			self:StartLanePhase()
		else
			self:LockNightUntilLanePhase()
		end
	end
end

function DraftSpawn:OnHeroSelectionStarted()
	if self.draftStartTime then
		return
	end

	self.draftStartTime = GameRules:GetGameTime()
	self.sandboxActive = true
	self.warmupEnded = false
	self.matchStarted = false
	self:FreezeEngineMatchSystems()
	self:EnableSandboxEconomy()
	self:EnsureWarmupZone()
	self:SyncPreGameTime()
	self:EnsureSelectionThink()
	self:EnsureMatchStartTimer()

end

function DraftSpawn:EnsureSelectionThink()
	if self._selectionThinkArmed then
		return
	end
	self._selectionThinkArmed = true

	Timers:CreateTimer(function()
		local state = GameRules:State_Get()
		if state ~= DOTA_GAMERULES_STATE_HERO_SELECTION then
			self._selectionThinkArmed = false

			return nil
		end

		self:SyncPreGameTime()

		if self:GetRemainingUntilMatchStart() <= 0 then
			self:RandomUnpickedHeroes()
		end

		return 0.1
	end)
end

function DraftSpawn:SyncPreGameTime()
	if self.matchStarted then
		return
	end
	local remaining = math.max(0, self:GetRemainingUntilZeroClock())
	GameRules:SetPreGameTime(remaining)
end

function DraftSpawn:EnsureMatchStartTimer()
	if self._matchTimerArmed or self.matchStarted then
		return
	end
	self._matchTimerArmed = true


	Timers:CreateTimer(function()
		if self.matchStarted then
			return nil
		end

		local remainingWarmup = self:GetRemainingUntilWarmupEnd()
		local remainingZero = self:GetRemainingUntilZeroClock()
		local state = GameRules:State_Get()

		if remainingWarmup > 0.05 then
			self:SyncPreGameTime()
			self:LockNightUntilLanePhase()
			if state == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
				self:FreezeEngineMatchSystems()
			end
			return 0.1
		end

		if not self.warmupEnded then
			self:EndWarmup()
			return 0.1
		end

		if remainingZero > 0.05 then
			self:SyncPreGameTime()
			self:LockNightUntilLanePhase()
			return 0.1
		end

		if state == DOTA_GAMERULES_STATE_HERO_SELECTION then
			GameRules:SetPreGameTime(0)
			return 0.1
		end

		if state == DOTA_GAMERULES_STATE_STRATEGY_TIME or state == DOTA_GAMERULES_STATE_PRE_GAME then
			GameRules:SetPreGameTime(0)
			pcall(function()
				GameRules:ForceGameStart()
			end)
			return 0.1
		end

		if state == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
			self:StartLanePhase()
			return nil
		end

		return 0.1
	end)
end

function DraftSpawn:SetDaynightCycleDisabled(disabled)
	local mode = GameRules:GetGameModeEntity()
	if mode and mode.SetDaynightCycleDisabled then
		mode:SetDaynightCycleDisabled(disabled)
	end
end

function DraftSpawn:ApplyNightLighting()
	-- Цикл должен быть включён в кадр смены времени: иначе клиент
	-- замораживает текущий (дневной) свет и GetTimeOfDay расходится с картинкой.
	self:SetDaynightCycleDisabled(false)
	GameRules:SetTimeOfDay(0.75)
	self:SetDaynightCycleDisabled(true)
	self._daynightCycleLocked = true
end

function DraftSpawn:ScheduleNightLightingFollowup()
	if self._nightFollowupArmed or self.matchStarted then
		return
	end
	self._nightFollowupArmed = true
	Timers:CreateTimer(0.25, function()
		if self.matchStarted then
			return nil
		end
		local before = GameRules:GetTimeOfDay()
		self:ApplyNightLighting()
		self:DebugDayNight("night-followup", before)
		return nil
	end)
end

function DraftSpawn:LockNightUntilLanePhase(forceClientPush)
	if self.matchStarted then
		return
	end

	local before = GameRules:GetTimeOfDay()
	local drifted = math.abs((before or 0) - 0.75) > 0.02
	local key = self:StateName() .. ":" .. tostring(self.warmupEnded)
	local stateChanged = self._lastNightApplyKey ~= key
	local state = GameRules:State_Get()
	local worldVisible = forceClientPush == true
		or state == DOTA_GAMERULES_STATE_PRE_GAME
		or state == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS

	-- Тик 0.1 с без дрейфа движок не трогает — иначе снова копится ночной эмбиент.
	-- Смена стейта и вход игрока на карту обязаны повторно слать SetTimeOfDay:
	-- первый вызов в HERO_SELECTION обновляет только сервер, клиент ещё не рисует мир.
	local shouldApply = drifted or stateChanged or forceClientPush or not self._daynightCycleLocked
	if worldVisible and not self._nightClientPushed then
		shouldApply = true
	end

	if shouldApply then
		self:ApplyNightLighting()
		self._lastNightApplyKey = key
		if worldVisible then
			self._nightClientPushed = true
			self:ScheduleNightLightingFollowup()
		end
	end

	if drifted or stateChanged or forceClientPush then
		self._lastNightDebugKey = key
		local action = "night-hold"
		if drifted then
			action = "night-restore"
		elseif forceClientPush or (worldVisible and shouldApply) then
			action = "night-push"
		elseif stateChanged then
			action = "night-sync"
		end
		self:DebugDayNight(action, before)
	end
end

function DraftSpawn:FreezeEngineMatchSystems()
	GameRules:SetGoldPerTick(0)
	self:LockNightUntilLanePhase()
	self:SetEngineHeroKillRewardsEnabled(false)
end

function DraftSpawn:EnableWarmupEndSystems()
	GameRules:SetGoldTickTime(1)
	GameRules:SetGoldPerTick(2)
	self:SetEngineHeroKillRewardsEnabled(true)
	self:LockNightUntilLanePhase()
end

function DraftSpawn:EnableLanePhaseSystems()
	local before = GameRules:GetTimeOfDay()
	self:SetDaynightCycleDisabled(false)
	self._daynightCycleLocked = false
	self._nightClientPushed = false
	self._nightFollowupArmed = false
	self._lastNightApplyKey = nil
	self._nightPushedPlayers = {}
	GameRules:SetTimeOfDay(0.25)
	self:DebugDayNight("day-start", before)
end

function DraftSpawn:HoldEngineMatchStart()
	self:FreezeEngineMatchSystems()
end

function DraftSpawn:CollectNamedEntities(name)
	local found = Entities:FindAllByName(name) or {}
	local unique = {}
	local list = {}
	for i = 1, #found do
		local ent = found[i]
		if ent and not ent:IsNull() then
			unique[ent:entindex()] = ent
		end
	end

	local byName = Entities:FindByName(nil, name)
	if byName and not byName:IsNull() then
		unique[byName:entindex()] = byName
	end

	for _, ent in pairs(unique) do
		list[#list + 1] = ent
	end
	return list
end

function DraftSpawn:GetEntityWorldBounds(entity)
	if not entity or entity:IsNull() then
		return nil
	end

	local origin = entity:GetAbsOrigin()
	local mins = entity.GetBoundingMins and entity:GetBoundingMins() or Vector(-64, -64, -64)
	local maxs = entity.GetBoundingMaxs and entity:GetBoundingMaxs() or Vector(64, 64, 128)
	return {
		minx = origin.x + mins.x,
		maxx = origin.x + maxs.x,
		miny = origin.y + mins.y,
		maxy = origin.y + maxs.y,
		minz = origin.z + mins.z,
		maxz = origin.z + maxs.z,
	}
end

function DraftSpawn:IsPointInBounds(point, bounds, padding)
	if not point or not bounds then
		return false
	end
	padding = padding or 0
	return point.x >= bounds.minx - padding
		and point.x <= bounds.maxx + padding
		and point.y >= bounds.miny - padding
		and point.y <= bounds.maxy + padding
		and point.z >= bounds.minz - math.max(padding, 64)
		and point.z <= bounds.maxz + math.max(padding, 64)
end

function DraftSpawn:IsWarmupDummyUnit(npc)
	if not npc or npc:IsNull() then
		return false
	end
	if npc.trinityWarmupDummy or npc == self._warmupDummy then
		return true
	end
	return npc.GetUnitName and npc:GetUnitName() == WARMUP_DUMMY_UNIT
end

function DraftSpawn:GetWarmupDummyOrigin()
	local list = self:CollectNamedEntities(WARMUP_DUMMY_SPAWN_ENTITY)
	local spawn = list[1]
	if not spawn or spawn:IsNull() then
		return nil
	end
	return spawn:GetAbsOrigin()
end

function DraftSpawn:SpawnWarmupDummy()
	if not self:IsSandboxActive() then
		return
	end

	local dummy = self._warmupDummy
	if dummy and not dummy:IsNull() and dummy:IsAlive() then
		return
	end

	local origin = self:GetWarmupDummyOrigin()
	if not origin then
		if not self._warmupDummyMissingLogged then
			self._warmupDummyMissingLogged = true
			self:DebugDummy("spawn failed: no entity", WARMUP_DUMMY_SPAWN_ENTITY)
		end
		self:RetryWarmupDummy()
		return
	end

	dummy = CreateUnitByName(WARMUP_DUMMY_UNIT, origin, false, nil, nil, DOTA_TEAM_NEUTRALS)
	if not dummy or dummy:IsNull() then
		self:DebugDummy("spawn failed: CreateUnitByName", WARMUP_DUMMY_UNIT, string.format("%.0f %.0f %.0f", origin.x, origin.y, origin.z))
		self:RetryWarmupDummy()
		return
	end

	dummy:SetAbsOrigin(origin)
	dummy.trinityWarmupDummy = true
	if dummy.SetControllableByPlayer then
		dummy:SetControllableByPlayer(-1, false)
	end
	dummy:SetIdleAcquire(false)
	dummy:SetDeathXP(0)
	dummy:SetMinimumGoldBounty(0)
	dummy:SetMaximumGoldBounty(0)
	if dummy.SetUnitCanRespawn then
		dummy:SetUnitCanRespawn(false)
	end
	dummy:AddNewModifier(dummy, nil, "modifier_rooted", {})
	self._warmupDummy = dummy
	self._warmupDummyMissingLogged = nil
	self:RevealWarmupDummy(dummy)

	local pos = dummy:GetAbsOrigin()
	self:DebugDummy(
		"spawned",
		WARMUP_DUMMY_UNIT,
		"at",
		string.format("%.0f %.0f %.0f", pos.x, pos.y, pos.z),
		"target",
		string.format("%.0f %.0f %.0f", origin.x, origin.y, origin.z),
		"from",
		WARMUP_DUMMY_SPAWN_ENTITY
	)
end

function DraftSpawn:RetryWarmupDummy()
	if self._warmupDummyRetryArmed or not self:IsSandboxActive() then
		return
	end
	self._warmupDummyRetryArmed = true
	Timers:CreateTimer(0.5, function()
		self._warmupDummyRetryArmed = false
		if self:IsSandboxActive() then
			self:SpawnWarmupDummy()
		end
		return nil
	end)
end

function DraftSpawn:RevealWarmupDummy(dummy)
	if not dummy or dummy:IsNull() then
		return
	end
	local origin = dummy:GetAbsOrigin()
	local duration = math.max(1, self:GetRemainingUntilWarmupEnd() + 2)
	AddFOWViewer(DOTA_TEAM_GOODGUYS, origin, 1200, duration, false)
	AddFOWViewer(DOTA_TEAM_BADGUYS, origin, 1200, duration, false)
end

function DraftSpawn:RemoveWarmupDummy()
	local dummy = self._warmupDummy
	self._warmupDummy = nil
	if dummy and not dummy:IsNull() then
		dummy:ForceKill(false)
		UTIL_Remove(dummy)
	end
end

function DraftSpawn:IsPointTouchingWarmupTrigger(point, padding)
	local triggers = self._warmupTriggers or {}
	for i = 1, #triggers do
		local bounds = self:GetEntityWorldBounds(triggers[i])
		if self:IsPointInBounds(point, bounds, padding) then
			return true
		end
	end
	return false
end

function DraftSpawn:EnsureWarmupZone()
	if self._warmupZoneReady then
		return true
	end

	self._warmupTriggers = self:CollectNamedEntities(WARMUP_ZONE_ENTITY)
	self._warmupSpawns = {
		any = self:CollectNamedEntities(WARMUP_SPAWN_ENTITY),
		good = self:CollectNamedEntities(WARMUP_SPAWN_GOOD_ENTITY),
		bad = self:CollectNamedEntities(WARMUP_SPAWN_BAD_ENTITY),
	}

	if #self._warmupSpawns.any == 0 and #self._warmupSpawns.good == 0 and #self._warmupSpawns.bad == 0 then
		self:RetryWarmupZone()
		return false
	end

	if #self._warmupTriggers == 0 then
		self:RetryWarmupZone()
		return false
	end

	local sampleSpawn = self._warmupSpawns.good[1] or self._warmupSpawns.bad[1] or self._warmupSpawns.any[1]
	local spawnOrigin = sampleSpawn:GetAbsOrigin()
	self._warmupTriggerIsInterior = self:IsPointTouchingWarmupTrigger(spawnOrigin, 8)
	self._warmupZoneReady = true
	self._warmupZoneActive = true
	self:PlaceAllHeroesInWarmupZone()
	self:SpawnWarmupDummy()
	return true
end

function DraftSpawn:PlaceAllHeroesInWarmupZone()
	if not self:IsSandboxActive() then
		return
	end
	for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if self:IsMatchPlayer(playerID) then
			local hero = PlayerResource:GetSelectedHeroEntity(playerID)
			if hero and not hero:IsNull() then
				self:PlaceHeroInWarmupZone(hero)
			end
		end
	end
end

function DraftSpawn:RetryWarmupZone()
	if self._warmupZoneRetryArmed or self.warmupEnded then
		return
	end
	self._warmupZoneRetryArmed = true
	Timers:CreateTimer(0.5, function()
		self._warmupZoneRetryArmed = false
		if self:IsSandboxActive() then
			self:EnsureWarmupZone()
		end
		return nil
	end)
end

function DraftSpawn:GetWarmupSpawnList(hero)
	local spawns = self._warmupSpawns or { any = {}, good = {}, bad = {} }
	local team = hero and hero.GetTeamNumber and hero:GetTeamNumber() or nil
	if team == DOTA_TEAM_GOODGUYS and #spawns.good > 0 then
		return spawns.good
	end
	if team == DOTA_TEAM_BADGUYS and #spawns.bad > 0 then
		return spawns.bad
	end
	if #spawns.any > 0 then
		return spawns.any
	end
	if #spawns.good > 0 then
		return spawns.good
	end
	return spawns.bad
end

function DraftSpawn:GetWarmupSpawnOrigin(hero)
	if not self:EnsureWarmupZone() then
		return nil
	end

	local list = self:GetWarmupSpawnList(hero)
	if #list == 0 then
		return nil
	end

	local playerID = hero and hero.GetPlayerOwnerID and hero:GetPlayerOwnerID() or 0
	local spawn = list[(playerID % #list) + 1]
	if not spawn or spawn:IsNull() then
		return nil
	end

	local origin = spawn:GetAbsOrigin()
	return GetGroundPosition(origin, hero)
end

function DraftSpawn:ShouldReturnHeroFromWarmupTrigger(hero)
	if not hero or hero:IsNull() or not hero:IsAlive() then
		return false
	end
	if not self:IsSandboxActive() or not self._warmupZoneActive then
		return false
	end
	if not self:EnsureWarmupZone() then
		return false
	end

	local origin = hero:GetAbsOrigin()
	local touching = self:IsPointTouchingWarmupTrigger(origin, 8)
	if self._warmupTriggerIsInterior then
		return not touching
	end
	return touching
end

function DraftSpawn:PlaceHeroInWarmupZone(hero)
	if not hero or hero:IsNull() or not self:IsSandboxActive() then
		return
	end
	if not self:EnsureWarmupZone() then
		return
	end

	local origin = self:GetWarmupSpawnOrigin(hero)
	if not origin then

		return
	end

	FindClearSpaceForUnit(hero, origin, true)
	hero:SetAbsOrigin(origin)
	if hero.Stop then
		hero:Stop()
	end
	if hero.SetRespawnPosition then
		hero:SetRespawnPosition(origin)
	end
	hero:AddNewModifier(hero, nil, "modifier_trinity_warmup_zone", {})
	self._warmupIgnoreUntil = self._warmupIgnoreUntil or {}
	self._warmupIgnoreUntil[hero:entindex()] = GameRules:GetGameTime() + 0.25

end

function DraftSpawn:SnapCameraToHero(hero, origin)
	if not hero or hero:IsNull() then
		return
	end

	local playerID = hero:GetPlayerOwnerID()
	if not PlayerResource:IsValidPlayerID(playerID) then
		return
	end

	origin = origin or hero:GetAbsOrigin()
	-- Не вешаем SetCameraTarget: камера тогда едет со спавна фонтана за героем.
	if PlayerResource.SetCameraTarget then
		PlayerResource:SetCameraTarget(playerID, nil)
	end
	if PlayerResource.SetCameraTargetPositionTime then
		PlayerResource:SetCameraTargetPositionTime(playerID, origin, 0, 0, 0)
	elseif PlayerResource.SetCameraTargetPosition then
		PlayerResource:SetCameraTargetPosition(playerID, origin, 0)
	end

	local player = PlayerResource:GetPlayer(playerID)
	if player then
		CustomGameEventManager:Send_ServerToPlayer(player, "trinity_player_entered_map", {
			player_id = playerID,
			x = origin.x,
			y = origin.y,
			z = origin.z,
		})
	end
end

function DraftSpawn:CollectTeamSpawnEntities(playerID)
	local team = PlayerResource:IsValidPlayerID(playerID) and PlayerResource:GetTeam(playerID) or nil
	local list = {}

	local function appendMatching(entities, requireTeam)
		for i = 1, #(entities or {}) do
			local ent = entities[i]
			if ent and not ent:IsNull() then
				if not requireTeam or not team or not ent.GetTeamNumber or ent:GetTeamNumber() == 0 or ent:GetTeamNumber() == team then
					list[#list + 1] = ent
				end
			end
		end
	end

	appendMatching(Entities:FindAllByClassname("info_player_start_dota"), true)
	if #list > 0 then
		return list
	end

	local className = nil
	if team == DOTA_TEAM_GOODGUYS then
		className = "info_player_start_goodguys"
	elseif team == DOTA_TEAM_BADGUYS then
		className = "info_player_start_badguys"
	end
	if className then
		appendMatching(Entities:FindAllByClassname(className), false)
		if #list > 0 then
			return list
		end
		appendMatching(self:CollectNamedEntities(className), false)
		if #list > 0 then
			return list
		end
	end

	appendMatching(Entities:FindAllByClassname("ent_dota_fountain"), true)
	return list
end

function DraftSpawn:GetFountainSpawnOrigin(playerID)
	local list = self:CollectTeamSpawnEntities(playerID)
	if #list == 0 then
		return nil
	end

	local spawn = list[(math.max(playerID, 0) % #list) + 1]
	if not spawn or spawn:IsNull() then
		return nil
	end

	return GetGroundPosition(spawn:GetAbsOrigin(), nil)
end

function DraftSpawn:PlaceHeroAtFountain(hero, snapCamera)
	if not hero or hero:IsNull() then
		return
	end

	local playerID = hero:GetPlayerOwnerID()
	local origin = self:GetFountainSpawnOrigin(playerID)
	if not origin then

		return
	end

	FindClearSpaceForUnit(hero, origin, true)
	hero:SetAbsOrigin(origin)
	if hero.Stop then
		hero:Stop()
	end
	if hero.SetRespawnPosition then
		hero:SetRespawnPosition(origin)
	end
	if snapCamera ~= false then
		self:SnapCameraToHero(hero, origin)
	end

end

function DraftSpawn:PlaceAllHeroesAtFountain(snapCamera)
	for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if self:IsMatchPlayer(playerID) then
			local hero = PlayerResource:GetSelectedHeroEntity(playerID)
			if hero and not hero:IsNull() then
				self:PlaceHeroAtFountain(hero, snapCamera)
			end
		end
	end
end

function DraftSpawn:OnNPCSpawned(keys)
	local npc = keys and keys.entindex and EntIndexToHScript(keys.entindex) or nil
	if not npc or npc:IsNull() or not npc.IsRealHero or not npc:IsRealHero() then
		return
	end
	if self:IsWarmupDummyUnit(npc) then
		return
	end
	if npc.IsIllusion and npc:IsIllusion() then
		return
	end
	if npc.IsClone and npc:IsClone() then
		return
	end
	if npc.IsTempestDouble and npc:IsTempestDouble() then
		return
	end

	local playerID = npc:GetPlayerOwnerID()
	if self:IsResettingHero(playerID) then
		return
	end

	if self:IsSandboxActive() then
		self._warmupSpawned = self._warmupSpawned or {}
		local firstSpawn = self._warmupSpawned[playerID] ~= true
		if firstSpawn and npc.AddNoDraw then
			npc:AddNoDraw()
		end
		self:PlaceHeroInWarmupZone(npc)
		if firstSpawn then
			self._warmupSpawned[playerID] = true
			self:SnapCameraToHero(npc, npc:GetAbsOrigin())
			Timers:CreateTimer(0.05, function()
				if npc and not npc:IsNull() and npc.RemoveNoDraw then
					npc:RemoveNoDraw()
				end
				return nil
			end)
		end
	elseif self.warmupEnded and not self.matchStarted then
		self:PlaceHeroAtFountain(npc)
	end
end

function DraftSpawn:KeepHeroInWarmupZone(hero)
	if not hero or hero:IsNull() then
		return
	end
	if not self:IsSandboxActive() or not self._warmupZoneActive then
		hero:RemoveModifierByName("modifier_trinity_warmup_zone")
		return
	end
	if not hero:IsAlive() then
		return
	end

	local ignoreUntil = self._warmupIgnoreUntil and self._warmupIgnoreUntil[hero:entindex()] or 0
	if GameRules:GetGameTime() < ignoreUntil then
		return
	end

	if self:ShouldReturnHeroFromWarmupTrigger(hero) then

		self:PlaceHeroInWarmupZone(hero)
	end
end

function DraftSpawn:IsWarmupEscapePosition(hero, position)
	if not position or not self:EnsureWarmupZone() then
		return false
	end
	local touching = self:IsPointTouchingWarmupTrigger(position, 8)
	if self._warmupTriggerIsInterior then
		return not touching
	end
	return touching
end

function DraftSpawn:GetOrderTarget(data)
	if not data then
		return nil
	end
	local targetIndex = data.entindex_target
	if not targetIndex or targetIndex <= 0 then
		return nil
	end
	local target = EntIndexToHScript(targetIndex)
	if not target or target:IsNull() then
		return nil
	end
	return target
end

function DraftSpawn:GetOrderPosition(data)
	if not data then
		return nil
	end
	if data.position_x ~= nil and data.position_y ~= nil then
		return Vector(data.position_x, data.position_y, data.position_z or 0)
	end
	local target = self:GetOrderTarget(data)
	if target and target.GetAbsOrigin then
		return target:GetAbsOrigin()
	end
	return nil
end

function DraftSpawn:ShouldBlockWarmupEscapeOrder(data)
	if not self:IsSandboxActive() or not self._warmupZoneActive then
		return false
	end

	local orderType = data.order_type
	if orderType == ORDER_PURCHASE_ITEM or orderType == ORDER_SELL_ITEM then
		return false
	end

	-- CAST_TARGET: у приказа часто position = 0,0,0. Нельзя считать это побегом из зоны.
	if orderType == ORDER_CAST_TARGET then
		local target = self:GetOrderTarget(data)
		if target and self:IsWarmupDummyUnit(target) then
			return false
		end
		if target and target.GetAbsOrigin then
			return self:IsWarmupEscapePosition(nil, target:GetAbsOrigin())
		end
		return false
	end

	local position = self:GetOrderPosition(data)
	if not position then
		return false
	end

	if orderType == ORDER_MOVE_TO_POSITION or orderType == ORDER_ATTACK_MOVE or orderType == ORDER_MOVE_TO_DIRECTION or orderType == ORDER_DROP_ITEM then
		if self:IsWarmupEscapePosition(nil, position) then
			local spawn = self._warmupSpawns and (self._warmupSpawns.any[1] or self._warmupSpawns.good[1] or self._warmupSpawns.bad[1])
			if spawn and not spawn:IsNull() then
				local origin = spawn:GetAbsOrigin()
				data.position_x = origin.x
				data.position_y = origin.y
				data.position_z = origin.z
			end
			return false
		end
		return false
	end

	if orderType == ORDER_CAST_POSITION or orderType == ORDER_VECTOR_TARGET_POSITION then
		return self:IsWarmupEscapePosition(nil, position)
	end

	return false
end

function DraftSpawn:DisableWarmupZone()
	self._warmupZoneActive = false
	self._warmupZoneReady = false
	self._warmupIgnoreUntil = {}

	for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if self:IsMatchPlayer(playerID) then
			local hero = PlayerResource:GetSelectedHeroEntity(playerID)
			if hero and not hero:IsNull() then
				hero:RemoveModifierByName("modifier_trinity_warmup_zone")
			end
		end
	end

	self:RemoveWarmupDummy()
end

function DraftSpawn:EndWarmup()
	if self.warmupEnded then
		return
	end

	self.warmupEnded = true
	self.sandboxActive = false

	self:DisableWarmupZone()
	self:RandomUnpickedHeroes()
	self:DisableSandboxEconomy()
	self:ResetWarmupHeroes()
	self:PlaceAllHeroesAtFountain()
	self:ResetPlayersGold()
	self:ResetPlayersKDA()
	self:StripWarmupItems()
	self:RemoveWarmupWards()
	self:RegrowWarmupTrees()
	self:RestoreWardShopStock()

	self.heroKillRewardsEnabled = true
	if KillfeedSystem and KillfeedSystem.RefreshHeroKillBounties then
		KillfeedSystem:RefreshHeroKillBounties()
	end
	self:EnableWarmupEndSystems()
	self:NotifyWarmupEnded()
	self:SyncPreGameTime()

	Timers:CreateTimer(0, function()
		self:PlaceAllHeroesAtFountain(false)
		self:ResetPlayersGold()
		self:ResetPlayersKDA()
		self:StripWarmupItems()
		self:RemoveWarmupWards()
		self:RegrowWarmupTrees()

		return nil
	end)
	Timers:CreateTimer(0.1, function()
		self:PlaceAllHeroesAtFountain(false)
		self:ResetPlayersGold()
		self:ResetPlayersKDA()
		self:StripWarmupItems()
		self:RemoveWarmupWards()
		self:RegrowWarmupTrees()

		return nil
	end)
end

function DraftSpawn:StartLanePhase()
	if self.matchStarted then
		return
	end

	if not self.warmupEnded then
		self:EndWarmup()
	end

	self.matchStarted = true
	self.sandboxActive = false
	self:EnableLanePhaseSystems()

	local queue = self._matchStartQueue or {}
	self._matchStartQueue = {}
	for i = 1, #queue do
		local ok, err = pcall(queue[i])
		if not ok then
			print("[DraftSpawn] match start callback failed: " .. tostring(err))
		end
	end
end

function DraftSpawn:StartMatch()
	self:StartLanePhase()
end

function DraftSpawn:EnableSandboxEconomy()
	GameRules:SetUseUniversalShopMode(true)
	pcall(function()
		SendToServerConsole("dota_easybuy 1")
		SendToServerConsole("dota_max_physical_items_purchase_limit 9999")
	end)
	pcall(function()
		Convars:SetInt("dota_easybuy", 1)
	end)

end

function DraftSpawn:DisableSandboxEconomy()
	GameRules:SetUseUniversalShopMode(UNIVERSAL_SHOP_MODE == true)
	pcall(function()
		SendToServerConsole("dota_easybuy 0")
	end)
	pcall(function()
		Convars:SetInt("dota_easybuy", 0)
	end)

end

function DraftSpawn:GiveWarmupGold(playerID)
	if not self:IsSandboxActive() or not self:IsMatchPlayer(playerID) then

		return
	end

	self:SetExactGold(playerID, self:GetWarmupGold())

end

function DraftSpawn:SetExactGold(playerID, amount)
	if not PlayerResource:IsValidPlayerID(playerID) then
		return
	end

	amount = math.max(0, math.floor(tonumber(amount) or 0))
	PlayerResource:SetGold(playerID, amount, true)
	PlayerResource:SetGold(playerID, 0, false)

	local total = (PlayerResource:GetReliableGold(playerID) or 0) + (PlayerResource:GetUnreliableGold(playerID) or 0)
	if total ~= amount then
		PlayerResource:ModifyGold(playerID, amount - total, true, DOTA_ModifyGold_Unspecified)
		PlayerResource:SetGold(playerID, 0, false)
		PlayerResource:SetGold(playerID, amount, true)
	end
end

function DraftSpawn:NotifyWarmupStarted(playerID)
	local player = PlayerResource:GetPlayer(playerID)
	if not player then
		return
	end

	local remaining = math.max(0, self:GetRemainingUntilMatchStart())
	local hero = PlayerResource:GetSelectedHeroEntity(playerID)
	local origin = hero and not hero:IsNull() and hero:GetAbsOrigin() or self:GetWarmupSpawnOrigin(hero)
	local payload = {
		player_id = playerID,
		gold = self:GetWarmupGold(),
		remaining = remaining,
	}
	if origin then
		payload.x = origin.x
		payload.y = origin.y
		payload.z = origin.z
	end

	CustomGameEventManager:Send_ServerToPlayer(player, "trinity_warmup_started", payload)
	CustomGameEventManager:Send_ServerToPlayer(player, "draw_game_event", {
		color = "#f0d78c",
		duration = 3,
		sound_event = "",
		text_token = "#trinity_warmup_started",
	})

end

function DraftSpawn:NotifyWarmupEnded()
	CustomGameEventManager:Send_ServerToAllClients("trinity_warmup_ended", {
		ended = 1,
	})
	CustomGameEventManager:Send_ServerToAllClients("draw_game_event", {
		color = "#f0d78c",
		duration = 3,
		sound_event = "",
		text_token = "#trinity_warmup_ended",
	})

end

function DraftSpawn:GetHeroStartLevel()
	return HERO_START_LEVEL or 1
end

function DraftSpawn:GetStartAbilityPoints()
	local startLevel = self:GetHeroStartLevel()
	local points = startLevel
	local extraPointLevels = {
		[17] = true,
		[19] = true,
		[21] = true,
		[22] = true,
		[23] = true,
		[24] = true,
	}
	for level = 1, startLevel do
		if extraPointLevels[level] or level >= 20 then
			points = points + 1
		end
	end
	return points
end

function DraftSpawn:AbilityHasBehavior(ability, behavior)
	if not ability or ability:IsNull() or not behavior then
		return false
	end

	local behaviorInt = ability.GetBehaviorInt and ability:GetBehaviorInt() or ability:GetBehavior()
	if not behaviorInt then
		return false
	end
	return bit.band(behaviorInt, behavior) == behavior
end

function DraftSpawn:AbilityKvHasBehavior(ability, flag)
	if not ability or ability:IsNull() or not flag then
		return false
	end

	local kv = ability.GetAbilityKeyValues and ability:GetAbilityKeyValues() or nil
	if not kv then
		return false
	end

	local behavior = kv.AbilityBehavior or kv.abilitybehavior
	if type(behavior) ~= "string" then
		return false
	end

	return string.find(behavior, flag, 1, true) ~= nil
end

function DraftSpawn:AbilityKvFlagEnabled(ability, key)
	if not ability or ability:IsNull() or not key then
		return false
	end

	local kv = ability.GetAbilityKeyValues and ability:GetAbilityKeyValues() or nil
	if not kv then
		return false
	end

	local value = kv[key]
	if value == nil then
		value = kv[string.lower(key)]
	end
	return value == "1" or value == 1 or value == true or value == "true"
end

function DraftSpawn:ShouldShowGrantedAbility(hero, ability)
	if not hero or hero:IsNull() or not ability or ability:IsNull() then
		return false
	end

	if self:AbilityKvFlagEnabled(ability, "IsGrantedByShard") then
		return HasShard and HasShard(hero) or false
	end
	if self:AbilityKvFlagEnabled(ability, "IsGrantedByScepter") then
		return hero.HasScepter and hero:HasScepter() or false
	end

	return true
end

function DraftSpawn:IsItemGrantedAbility(ability)
	return self:AbilityKvFlagEnabled(ability, "IsGrantedByShard")
		or self:AbilityKvFlagEnabled(ability, "IsGrantedByScepter")
end

function DraftSpawn:ShouldResetAbilityToUnskilled(ability)
	if not ability or ability:IsNull() then
		return false
	end

	local name = ability:GetAbilityName() or ""
	if name == "" or name == "generic_hidden" then
		return false
	end
	if name == "mind_power" or name == "empty_ability" or name == "high_five_custom" then
		return false
	end
	if string.find(name, "special_bonus_", 1, true) == 1 then
		return false
	end
	if ability.IsAttributeBonus and ability:IsAttributeBonus() then
		return false
	end
	if ability.IsInnateAbility and ability:IsInnateAbility() then
		return false
	end
	if ability.IsInnate and ability:IsInnate() then
		return false
	end
	if self:IsItemGrantedAbility(ability) then
		return false
	end

	local kv = ability.GetAbilityKeyValues and ability:GetAbilityKeyValues() or nil
	local kvType = kv and (kv.AbilityType or kv.abilitytype) or nil
	local kvIsUltimate = kvType == "DOTA_ABILITY_TYPE_ULTIMATE"
	local kvHidden = self:AbilityKvHasBehavior(ability, "DOTA_ABILITY_BEHAVIOR_HIDDEN")
	local kvNotLearnable = self:AbilityKvHasBehavior(ability, "DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE")
	local kvInnate = self:AbilityKvHasBehavior(ability, "DOTA_ABILITY_BEHAVIOR_INNATE")

	local abilityType = ability.GetAbilityType and ability:GetAbilityType() or nil
	if abilityType == ABILITY_TYPE_ATTRIBUTES or abilityType == DOTA_ABILITY_TYPE_ATTRIBUTES then
		return false
	end
	if (abilityType == ABILITY_TYPE_HIDDEN or abilityType == DOTA_ABILITY_TYPE_HIDDEN) and not kvIsUltimate then
		return false
	end

	if kvNotLearnable or kvInnate then
		return false
	end

	if self:AbilityHasBehavior(ability, DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE)
		or self:AbilityHasBehavior(ability, DOTA_ABILITY_BEHAVIOR_INNATE) then
		return false
	end

	-- Live HIDDEN can be a leftover SwapAbilities from warmup. Skip only if KV is hidden too.
	if self:AbilityHasBehavior(ability, DOTA_ABILITY_BEHAVIOR_HIDDEN) and kvHidden then
		return false
	end

	if kv then
		local innate = kv.Innate or kv.innate
		if innate == "1" or innate == 1 then
			return false
		end
	end

	return true
end

function DraftSpawn:RestoreAbilityHiddenState(hero)
	if not hero or hero:IsNull() or not hero.GetAbilityCount then
		return
	end

	for slot = 0, hero:GetAbilityCount() - 1 do
		local ability = hero:GetAbilityByIndex(slot)
		if ability and not ability:IsNull() then
			local grantedByItem = self:IsItemGrantedAbility(ability)
			if grantedByItem then
				local show = self:ShouldShowGrantedAbility(hero, ability)
				if show then
					if ability:IsHidden() then
						ability:SetHidden(false)
					end
					if ability:GetLevel() < 1 then
						ability:SetLevel(1)
					end
				else
					if ability:GetLevel() ~= 0 then
						ability:SetLevel(0)
					end
					if not ability:IsHidden() then
						ability:SetHidden(true)
					end
				end
			elseif self:AbilityKvHasBehavior(ability, "DOTA_ABILITY_BEHAVIOR_HIDDEN") then
				if not ability:IsHidden() then
					ability:SetHidden(true)
				end
			elseif self:ShouldResetAbilityToUnskilled(ability) and ability:IsHidden() then
				ability:SetHidden(false)
			end
		end
	end
end

function DraftSpawn:ResetHeroAbilitiesToStart(hero)
	if not hero or hero:IsNull() or not hero.GetAbilityCount then
		return
	end

	for slot = 0, hero:GetAbilityCount() - 1 do
		local ability = hero:GetAbilityByIndex(slot)
		if ability and not ability:IsNull() and self:ShouldResetAbilityToUnskilled(ability) then
			if ability:IsHidden() then
				ability:SetHidden(false)
			end
			if ability:GetLevel() ~= 0 then
				ability:SetLevel(0)
			end
			if ability.EndCooldown then
				ability:EndCooldown()
			end
		end
	end

	if hero.SetAbilityPoints then
		hero:SetAbilityPoints(self:GetStartAbilityPoints())
	end

end

function DraftSpawn:RestoreAbilityCastLayouts(hero)
	if not hero or hero:IsNull() or not hero.GetAbilityCount then
		return
	end

	for slot = 0, hero:GetAbilityCount() - 1 do
		local ability = hero:GetAbilityByIndex(slot)
		if ability and not ability:IsNull() and ability.RestoreCastLayout then
			ability:RestoreCastLayout()
		end
	end
end

function DraftSpawn:ApplyMatchStartHeroState(hero)
	if not hero or hero:IsNull() then
		return
	end

	self:RestoreAbilityHiddenState(hero)
	self:RestoreAbilityCastLayouts(hero)
	self:ResetHeroAbilitiesToStart(hero)
	self:RestoreAbilityHiddenState(hero)
	self:RestoreAbilityCastLayouts(hero)
	if ChenBarrackRestoreMatchStartAbilities then
		ChenBarrackRestoreMatchStartAbilities(hero)
	end
	self:EnsureTownPortalScroll(hero)
end

function DraftSpawn:PrepareHeroForMatchStart(hero, playerID)
	if not hero or hero:IsNull() then
		return
	end

	self:StripUnitWarmupItems(hero, {})
	while hero:GetLevel() < self:GetHeroStartLevel() do
		hero:HeroLevelUp(false)
	end
	self:ApplyMatchStartHeroState(hero)

	self._startingItems = self._startingItems or {}
	self._startingItems[playerID] = nil
	self:CaptureStartingItems(hero)
end

function DraftSpawn:ResetWarmupHeroes()
	local gold = STARTING_GOLD or 600
	self._resettingHero = self._resettingHero or {}

	for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if self:IsMatchPlayer(playerID) then
			local hero = PlayerResource:GetSelectedHeroEntity(playerID)
			if hero and not hero:IsNull() then
				local heroName = hero:GetUnitName()
				self._resettingHero[playerID] = true
				self:StripUnitWarmupItems(hero, {})
				self:PlaceHeroAtFountain(hero, false)

				if ChenBarrackWipeForHero then
					ChenBarrackWipeForHero(hero)
				end

				local newHero = PlayerResource:ReplaceHeroWith(playerID, heroName, gold, 0)
				newHero = newHero or PlayerResource:GetSelectedHeroEntity(playerID)
				if newHero and not newHero:IsNull() then
					self:PrepareHeroForMatchStart(newHero, playerID)
					self:PlaceHeroAtFountain(newHero, false)
				end
				self._resettingHero[playerID] = nil
			end
		end
	end
end

function DraftSpawn:ResetPlayersGold()
	local gold = STARTING_GOLD or 600
	for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if self:IsMatchPlayer(playerID) then
			self:SetExactGold(playerID, gold)

		end
	end
end

local ITEM_SLOT_MAX = 20

function DraftSpawn:ForEachItemOnUnit(unit, callback)
	if not unit or unit:IsNull() then
		return
	end

	for slot = 0, ITEM_SLOT_MAX do
		local item = unit:GetItemInSlot(slot)
		if item and not item:IsNull() then
			callback(item, slot)
		end
	end
end

function DraftSpawn:CaptureStartingItems(hero)
	if not hero or hero:IsNull() then
		return
	end

	local playerID = hero:GetPlayerOwnerID()
	self._startingItems = self._startingItems or {}
	if self._startingItems[playerID] then
		return
	end

	local ids = {}
	self:ForEachItemOnUnit(hero, function(item)
		ids[item:entindex()] = true
	end)
	self._startingItems[playerID] = ids

end

function DraftSpawn:StripUnitWarmupItems(unit, keep)
	if not unit or unit:IsNull() then
		return
	end

	keep = keep or {}
	local toRemove = {}
	self:ForEachItemOnUnit(unit, function(item)
		if not keep[item:entindex()] then
			toRemove[#toRemove + 1] = item
		end
	end)

	for i = 1, #toRemove do
		local item = toRemove[i]
		if item and not item:IsNull() then

			unit:RemoveItem(item)
			if item and not item:IsNull() then
				UTIL_Remove(item)
			end
		end
	end
end

function DraftSpawn:RefreshTownPortalScroll(item)
	if not item or item:IsNull() then
		return
	end

	if item.EndCooldown then
		item:EndCooldown()
	end
	if item.RefreshCharges then
		item:RefreshCharges()
	end
	if item.SetCurrentCharges and item.GetInitialCharges then
		local charges = item:GetInitialCharges()
		if charges and charges > 0 then
			item:SetCurrentCharges(charges)
		end
	end
end

function DraftSpawn:EnsureTownPortalScroll(hero)
	if not hero or hero:IsNull() then
		return
	end

	local hasTP = false
	self:ForEachItemOnUnit(hero, function(item)
		if item:GetAbilityName() == "item_tpscroll" then
			hasTP = true
			self:RefreshTownPortalScroll(item)
		end
	end)

	if not hasTP then
		hero:AddItemByName("item_tpscroll")

		self:ForEachItemOnUnit(hero, function(item)
			if item:GetAbilityName() == "item_tpscroll" then
				self:RefreshTownPortalScroll(item)
			end
		end)
	end
end

function DraftSpawn:RemoveWarmupWards()
	for i = 1, #WARMUP_WARD_CLASSNAMES do
		local wards = Entities:FindAllByClassname(WARMUP_WARD_CLASSNAMES[i]) or {}
		for j = 1, #wards do
			local ward = wards[j]
			if ward and not ward:IsNull() then
				local unitName = ward.GetUnitName and ward:GetUnitName() or ""
				if WARMUP_WARD_UNITS[unitName] then
					UTIL_Remove(ward)
				end
			end
		end
	end
end

function DraftSpawn:RegrowWarmupTrees()
	local ok = pcall(function()
		GridNav:RegrowAllTrees()
	end)
	if ok then
		return
	end

	local trees = Entities:FindAllByClassname("ent_dota_tree") or {}
	for i = 1, #trees do
		local tree = trees[i]
		if tree and not tree:IsNull() and tree.GrowBack then
			pcall(function()
				tree:GrowBack()
			end)
		end
	end
end

function DraftSpawn:RestoreWardShopStock()
	local teams = { DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS }
	for i = 1, #WARMUP_WARD_STOCK do
		local entry = WARMUP_WARD_STOCK[i]
		for j = 1, #teams do
			pcall(function()
				GameRules:SetItemStockCount(entry.count, teams[j], entry.item, -1)
			end)
		end
	end
end

function DraftSpawn:StripWarmupGroundItems()
	local drops = Entities:FindAllByClassname("dota_item_drop") or {}
	for i = 1, #drops do
		local drop = drops[i]
		if drop and not drop:IsNull() then
			local contained = drop.GetContainedItem and drop:GetContainedItem() or nil
			UTIL_Remove(drop)
			if contained and not contained:IsNull() then

				UTIL_Remove(contained)
			end
		end
	end
end

function DraftSpawn:StripWarmupItems()
	self._startingItems = self._startingItems or {}

	for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if self:IsMatchPlayer(playerID) then
			local hero = PlayerResource:GetSelectedHeroEntity(playerID)
			self:StripUnitWarmupItems(hero, self._startingItems[playerID])
			self:ApplyMatchStartHeroState(hero)
		end
	end

	local couriers = Entities:FindAllByClassname("npc_dota_courier") or {}
	for i = 1, #couriers do
		self:StripUnitWarmupItems(couriers[i], {})
	end

	self:StripWarmupGroundItems()

end

function DraftSpawn:IsMatchPlayer(playerID)
	if playerID == nil or not PlayerResource:IsValidPlayerID(playerID) then
		return false
	end
	if PlayerResource:IsBroadcaster(playerID) then
		return false
	end
	local team = PlayerResource:GetTeam(playerID)
	return team == DOTA_TEAM_GOODGUYS or team == DOTA_TEAM_BADGUYS
end

function DraftSpawn:RandomUnpickedHeroes()
	for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if self:IsMatchPlayer(playerID) and not PlayerResource:HasSelectedHero(playerID) then
			local player = PlayerResource:GetPlayer(playerID)
			if player then

				player:MakeRandomHeroSelection()
			end
		end
	end
end

function DraftSpawn:IsResettingHero(playerID)
	return self._resettingHero ~= nil and self._resettingHero[playerID] == true
end

function DraftSpawn:OnPlayerPickHero(keys)
	local player = keys.player and EntIndexToHScript(keys.player) or nil
	local hero = keys.heroindex and EntIndexToHScript(keys.heroindex) or nil
	local playerID = nil

	if player and player.GetPlayerID then
		playerID = player:GetPlayerID()
	elseif hero and not hero:IsNull() and hero.GetPlayerOwnerID then
		playerID = hero:GetPlayerOwnerID()
	end

	if playerID == nil or not self:IsMatchPlayer(playerID) then

		return
	end

	if self.matchStarted or self:IsResettingHero(playerID) then

		return
	end


	self:SyncPreGameTime()
	self:EnterMapForPlayer(playerID, hero)
end

function DraftSpawn:EnterMapForPlayer(playerID, hero)
	if self.matchStarted or self:IsResettingHero(playerID) then

		return
	end

	hero = hero or PlayerResource:GetSelectedHeroEntity(playerID)
	if not hero or hero:IsNull() then

		Timers:CreateTimer(0.03, function()
			local spawned = PlayerResource:GetSelectedHeroEntity(playerID)
			if spawned and not spawned:IsNull() then
				self:EnterMapForPlayer(playerID, spawned)
				return nil
			end
			return 0.03
		end)
		return
	end

	hero:SetControllableByPlayer(playerID, true)

	if self:IsSandboxActive() then
		if hero.AddNoDraw then
			hero:AddNoDraw()
		end
		self:PlaceHeroInWarmupZone(hero)
		self:SnapCameraToHero(hero, hero:GetAbsOrigin())
		Timers:CreateTimer(0.05, function()
			if hero and not hero:IsNull() and hero.RemoveNoDraw then
				hero:RemoveNoDraw()
			end
			return nil
		end)
	elseif self.warmupEnded then
		self:PlaceHeroAtFountain(hero)
	else
		self:SnapCameraToHero(hero, hero:GetAbsOrigin())
	end

	self._nightPushedPlayers = self._nightPushedPlayers or {}
	if not self._nightPushedPlayers[playerID] then
		self._nightPushedPlayers[playerID] = true
		self:LockNightUntilLanePhase(true)
	end

	self:GiveWarmupGold(playerID)
	if self.warmupEnded then
		self:PrepareHeroForMatchStart(hero, playerID)
		self:SetExactGold(playerID, STARTING_GOLD or 600)
	else
		self:CaptureStartingItems(hero)
	end

	if not self.warmupEnded and not self._warmupHeroNotified[playerID] then
		self._warmupHeroNotified[playerID] = true
		self:NotifyWarmupStarted(playerID)
	end
end

function DraftSpawn:OnPlayerReconnect(keys)
	local playerID = keys.PlayerID or keys.player_id
	if playerID == nil then
		return
	end
	if not self:IsMatchPlayer(playerID) then
		return
	end
	if not PlayerResource:HasSelectedHero(playerID) then
		return
	end

	local state = GameRules:State_Get()
	if self:IsSandboxActive() or state == DOTA_GAMERULES_STATE_HERO_SELECTION or state == DOTA_GAMERULES_STATE_STRATEGY_TIME then
		self._warmupHeroNotified[playerID] = nil
		if self._nightPushedPlayers then
			self._nightPushedPlayers[playerID] = nil
		end
		self:EnterMapForPlayer(playerID)
	end
end

function DraftSpawn:ExecuteOrderFilter(data)
	if not self:IsSandboxActive() or not data then
		return true
	end

	if self:ShouldBlockWarmupEscapeOrder(data) then

		return false
	end

	local orderType = data.order_type
	if orderType ~= ORDER_PURCHASE_ITEM and orderType ~= ORDER_SELL_ITEM then
		return true
	end

	local playerID = data.issuer_player_id_const
	if not self:IsMatchPlayer(playerID) then
		return true
	end

	if orderType == ORDER_PURCHASE_ITEM then
		PlayerResource:ModifyGold(playerID, 99999, false, DOTA_ModifyGold_Unspecified)
	end

	Timers:CreateTimer(0, function()
		if self:IsSandboxActive() and PlayerResource:IsValidPlayerID(playerID) then
			self:GiveWarmupGold(playerID)
		end
		return nil
	end)
	return true
end

function DraftSpawn:OnHeroKilled(unit)
	if not unit or unit:IsNull() then
		return
	end

	if unit.trinityWarmupDummy or unit == self._warmupDummy or (unit.GetUnitName and unit:GetUnitName() == WARMUP_DUMMY_UNIT) then
		if self:IsSandboxActive() then
			self._warmupDummy = nil
			Timers:CreateTimer(0.5, function()
				self:SpawnWarmupDummy()
				return nil
			end)
		end
		return
	end

	if not self:IsSandboxActive() then
		return
	end
	if not unit:IsRealHero() or unit:IsIllusion() then
		return
	end
	if unit.IsClone and unit:IsClone() then
		return
	end
	if unit.IsTempestDouble and unit:IsTempestDouble() then
		return
	end

	Timers:CreateTimer(0.03, function()
		if not unit or unit:IsNull() then
			return nil
		end
		if unit:IsAlive() then
			return nil
		end
		unit:RespawnHero(false, false)
		self:PlaceHeroInWarmupZone(unit)

		return nil
	end)
end

function DraftSpawn:OnPlayerChat(event)
	if not self:IsSandboxActive() then
		return
	end

	local text = event.text
	if not text then
		return
	end

	local playerID = event.playerid
	if playerID == nil then
		playerID = event.PlayerID
	end
	if playerID == nil and event.userid and GameSettings and GameSettings.vUserIds then
		local ply = GameSettings.vUserIds[event.userid]
		if ply and ply.GetPlayerID then
			playerID = ply:GetPlayerID()
		end
	end
	if not self:IsMatchPlayer(playerID) then
		return
	end

	local hero = PlayerResource:GetSelectedHeroEntity(playerID)
	if not hero or hero:IsNull() then
		return
	end

	local command = string.lower(text)
	local level = string.match(command, "^[-/]level%s+(%d+)%s*$")
		or string.match(command, "^[-/]lvl%s+(%d+)%s*$")
	if level then

		self:SetHeroLevel(hero, tonumber(level))
		return
	end
	if command == "-lvlup" or command == "-levelup" or command == "/lvlup" or command == "/levelup" then

		self:SetHeroLevel(hero, hero:GetLevel() + 1)
	end
end

function DraftSpawn:SetHeroLevel(hero, targetLevel)
	if not hero or hero:IsNull() then
		return
	end

	targetLevel = math.floor(tonumber(targetLevel) or hero:GetLevel())
	targetLevel = math.max(1, math.min(self:GetMaxHeroLevel(), targetLevel))

	local current = hero:GetLevel()
	if targetLevel <= current then
		return
	end

	for _ = current, targetLevel - 1 do
		hero:HeroLevelUp(false)
	end
end

function DraftSpawn:GetWarmupWidgetHero(event)
	if not self:IsSandboxActive() or not event then
		return nil
	end

	local playerID = event.PlayerID
	if playerID == nil then
		playerID = event.player_id
	end
	if not self:IsMatchPlayer(playerID) then
		return nil
	end

	local hero = PlayerResource:GetSelectedHeroEntity(playerID)
	if not hero or hero:IsNull() then
		return nil
	end
	return hero, playerID
end

function DraftSpawn:OnWarmupLevelUp(event)
	local hero = self:GetWarmupWidgetHero(event)
	if not hero then
		return
	end
	self:SetHeroLevel(hero, hero:GetLevel() + 1)
end

function DraftSpawn:OnWarmupMaxLevel(event)
	local hero = self:GetWarmupWidgetHero(event)
	if not hero then
		return
	end
	self:SetHeroLevel(hero, self:GetMaxHeroLevel())
end

function DraftSpawn:RefreshWarmupAbility(ability)
	if not ability or ability:IsNull() then
		return
	end
	if ability.EndCooldown then
		ability:EndCooldown()
	end
	if ability.RefreshCharges then
		ability:RefreshCharges()
	end
end

function DraftSpawn:OnWarmupRefresh(event)
	local hero, playerID = self:GetWarmupWidgetHero(event)
	if not hero then
		return
	end

	hero:SetHealth(hero:GetMaxHealth())
	if hero.SetMana then
		hero:SetMana(hero:GetMaxMana())
	end

	if hero.GetAbilityCount then
		for slot = 0, hero:GetAbilityCount() - 1 do
			self:RefreshWarmupAbility(hero:GetAbilityByIndex(slot))
		end
	end

	self:ForEachItemOnUnit(hero, function(item)
		self:RefreshWarmupAbility(item)
	end)

	self:GiveWarmupGold(playerID)
end
