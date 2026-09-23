-- Per-hero balance snapshots: Lua game server -> Trinity PHP API.

local Http = require("utils/http")

if TrinityAnalytics == nil then
	TrinityAnalytics = {}
end

TrinityAnalytics.SNAPSHOT_INTERVAL = 60
TrinityAnalytics.THINK_INTERVAL = 1

TrinityAnalytics.stats = TrinityAnalytics.stats or {}
TrinityAnalytics.matchId = TrinityAnalytics.matchId
TrinityAnalytics.nextMinute = TrinityAnalytics.nextMinute or 1
TrinityAnalytics.bossKills = TrinityAnalytics.bossKills or 0
TrinityAnalytics.tracking = TrinityAnalytics.tracking == true
TrinityAnalytics.ended = TrinityAnalytics.ended == true
TrinityAnalytics.debugEnabled = TrinityAnalytics.debugEnabled == true

local BOSS_UNITS = {
	npc_mortimer_boss = true,
	npc_mortimer_boss_finale = true,
	npc_primal_beast_boss = true,
	npc_caravan_aghanim = true,
	npc_dota_roshan = true,
	npc_dota_roshan_custom = true,
	npc_dota_roshan_pathway = true,
	npc_line_boss_1 = true,
	npc_dota_hero_target_dummy = true,
}

local SKIP_SKILLS = {
	mind_power = true,
	empty_ability = true,
	high_five_custom = true,
}

local function DebugEnabled()
	if TrinityAnalytics.debugEnabled then
		return true
	end
	return TrinityPlayerData and TrinityPlayerData.debugEnabled == true
end

local function DebugPrint(...)
	if DebugEnabled() then
		print("[TrinityAnalytics]", ...)
	end
end

local function Alive(entity)
	return entity ~= nil and (not entity.IsNull or not entity:IsNull())
end

local function ValidPlayerID(playerID)
	if PlayerResource == nil or playerID == nil or playerID < 0 then
		return false
	end
	return PlayerResource:IsValidPlayerID(playerID)
end

local function SteamAccountID(playerID)
	if TrinityPlayerData and TrinityPlayerData.SteamID then
		return TrinityPlayerData.SteamID(playerID)
	end
	if not ValidPlayerID(playerID) then
		return 0
	end
	if PlayerResource.IsFakeClient and PlayerResource:IsFakeClient(playerID) then
		return 0
	end
	return tonumber(PlayerResource:GetSteamAccountID(playerID)) or 0
end

local function ShouldSend()
	if IsInToolsMode and IsInToolsMode() then
		return false
	end
	if IsDedicatedServer and IsDedicatedServer() then
		return false
	end
	return true
end

local function AuthHeaders()
	if TrinityPlayerData and TrinityPlayerData.RequestHeaders then
		return TrinityPlayerData.RequestHeaders()
	end
	return {
		["X-Trinity-Key"] = "trinity-tools-local",
	}
end

local function Endpoint(path)
	if TrinityPlayerData and TrinityPlayerData.ApiUrl then
		return TrinityPlayerData.ApiUrl(path)
	end
	return "http://162.246.19.210" .. path
end

local function GameTime()
	if GameRules and GameRules.GetDOTATime then
		return tonumber(GameRules:GetDOTATime(false, false)) or 0
	end
	return 0
end

local function WarmupEnded()
	if DraftSpawn and DraftSpawn.IsWarmupEnded then
		return DraftSpawn:IsWarmupEnded() == true
	end
	local state = GameRules and GameRules.State_Get and GameRules:State_Get()
	return state == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS
end

local function IsBossUnit(unit)
	if not Alive(unit) or not unit.GetUnitName then
		return false
	end
	local name = unit:GetUnitName() or ""
	if BOSS_UNITS[name] then
		return true
	end
	return string.sub(name, 1, 12) == "npc_caravan_"
end

local function IsChenUnit(unit)
	if not Alive(unit) or not unit.GetUnitName then
		return false
	end
	return string.sub(unit:GetUnitName() or "", 1, 9) == "npc_chen_"
end

local function IsIllusionOrClone(unit)
	if not Alive(unit) then
		return true
	end
	if unit.IsIllusion and unit:IsIllusion() then
		return true
	end
	if unit.IsClone and unit:IsClone() then
		return true
	end
	if unit.IsTempestDouble and unit:IsTempestDouble() then
		return true
	end
	if unit.IsMonkeyKingClone and unit:IsMonkeyKingClone() then
		return true
	end
	return false
end

local function IsRealPlayerHero(unit)
	if not Alive(unit) then
		return false
	end
	if not unit.IsRealHero or not unit:IsRealHero() then
		return false
	end
	if IsIllusionOrClone(unit) then
		return false
	end
	if DraftSpawn and DraftSpawn.IsWarmupDummyUnit and DraftSpawn:IsWarmupDummyUnit(unit) then
		return false
	end
	return true
end

local function PlayerIDOf(unit)
	if not Alive(unit) then
		return -1
	end
	if unit.GetPlayerOwnerID then
		local playerID = unit:GetPlayerOwnerID()
		if ValidPlayerID(playerID) then
			return playerID
		end
	end
	if unit.GetPlayerID then
		local playerID = unit:GetPlayerID()
		if ValidPlayerID(playerID) then
			return playerID
		end
	end
	return -1
end

local function HeroForPlayer(playerID)
	if not ValidPlayerID(playerID) then
		return nil
	end
	local hero = PlayerResource:GetSelectedHeroEntity(playerID)
	if IsRealPlayerHero(hero) then
		return hero
	end
	return nil
end

local function EnsureHeroStats(playerID, hero)
	local stats = TrinityAnalytics.stats[playerID]
	local heroName = "unknown"
	if hero and hero.GetUnitName then
		heroName = string.lower(hero:GetUnitName() or "unknown")
	end
	if stats == nil or stats.hero ~= heroName then
		stats = {
			hero = heroName,
			player_id = playerID,
			lane_creeps = 0,
			jungle_creeps = 0,
			hero_damage = 0,
			skill_damage = {},
		}
		TrinityAnalytics.stats[playerID] = stats
	end
	return stats
end

local function AddSkillDamage(stats, skillName, amount)
	if amount <= 0 or stats == nil then
		return
	end
	if skillName == nil or skillName == "" or SKIP_SKILLS[skillName] then
		return
	end
	stats.skill_damage[skillName] = (stats.skill_damage[skillName] or 0) + amount
end

local function InflictorSkillName(inflictor, hero)
	if not Alive(inflictor) then
		return "attack"
	end
	if inflictor.IsItem and inflictor:IsItem() then
		return nil
	end
	if inflictor.GetAbilityName then
		local name = inflictor:GetAbilityName()
		if type(name) == "string" and name ~= "" then
			if string.sub(name, 1, 5) == "item_" then
				return nil
			end
			if string.sub(name, 1, 14) == "special_bonus_" then
				return nil
			end
			if Alive(hero) and inflictor.GetCaster then
				local caster = inflictor:GetCaster()
				if Alive(caster) and caster ~= hero then
					local samePlayer = PlayerIDOf(caster) == PlayerIDOf(hero)
					if not samePlayer or not IsIllusionOrClone(caster) then
						return nil
					end
				end
			end
			return name
		end
	end
	return "attack"
end

local function WinningTeam()
	if GameRules == nil or GameRules.GetGameWinner == nil then
		return 0
	end
	local winner = tonumber(GameRules:GetGameWinner()) or 0
	if winner == DOTA_TEAM_GOODGUYS or winner == DOTA_TEAM_BADGUYS then
		return winner
	end
	return 0
end

local function NewMatchId()
	return string.format(
		"m%d-%d-%d",
		math.floor((Time() or 0) * 1000),
		RandomInt(10000, 99999),
		RandomInt(10000, 99999)
	)
end

local function HeroNetWorth(hero, playerID)
	if PlayerResource and PlayerResource.GetNetWorth and ValidPlayerID(playerID) then
		return math.max(0, math.floor(tonumber(PlayerResource:GetNetWorth(playerID)) or 0))
	end
	if KillfeedSystem and KillfeedSystem.GetHeroNetWorth then
		return math.max(0, math.floor(tonumber(KillfeedSystem:GetHeroNetWorth(hero)) or 0))
	end
	if Alive(hero) and hero.GetGold then
		return math.max(0, math.floor(tonumber(hero:GetGold()) or 0))
	end
	return 0
end

local function HeroXP(hero, playerID)
	if PlayerResource and PlayerResource.GetTotalEarnedXP and ValidPlayerID(playerID) then
		return math.max(0, math.floor(tonumber(PlayerResource:GetTotalEarnedXP(playerID)) or 0))
	end
	if Alive(hero) and hero.GetCurrentXP then
		return math.max(0, math.floor(tonumber(hero:GetCurrentXP()) or 0))
	end
	return 0
end

local function HeroKills(playerID)
	if PlayerResource and PlayerResource.GetKills and ValidPlayerID(playerID) then
		return math.max(0, math.floor(tonumber(PlayerResource:GetKills(playerID)) or 0))
	end
	return 0
end

local function CopySkillDamage(skillDamage)
	local copy = {}
	if type(skillDamage) ~= "table" then
		return copy
	end
	for name, value in pairs(skillDamage) do
		local amount = tonumber(value) or 0
		if amount > 0 then
			copy[tostring(name)] = math.floor(amount + 0.5)
		end
	end
	return copy
end

local function BuildHeroPayload(playerID, hero, stats)
	return {
		hero = string.lower(stats.hero or (hero and hero:GetUnitName()) or "unknown"),
		player_id = playerID,
		steamid = SteamAccountID(playerID),
		team = Alive(hero) and hero:GetTeamNumber() or (PlayerResource:GetTeam(playerID) or 0),
		networth = HeroNetWorth(hero, playerID),
		xp = HeroXP(hero, playerID),
		hero_kills = HeroKills(playerID),
		lane_creeps = stats.lane_creeps or 0,
		jungle_creeps = stats.jungle_creeps or 0,
		hero_damage = math.floor(stats.hero_damage or 0),
		skill_damage = CopySkillDamage(stats.skill_damage),
	}
end

local function CollectHeroes()
	local heroes = {}
	local seen = {}
	local list = HeroList and HeroList.GetAllHeroes and HeroList:GetAllHeroes() or {}
	for _, hero in pairs(list) do
		if IsRealPlayerHero(hero) then
			local playerID = PlayerIDOf(hero)
			if ValidPlayerID(playerID) and not seen[playerID] then
				seen[playerID] = true
				local stats = EnsureHeroStats(playerID, hero)
				heroes[#heroes + 1] = BuildHeroPayload(playerID, hero, stats)
			end
		end
	end
	return heroes
end

function TrinityAnalytics:BeginTracking()
	if self.tracking then
		return
	end
	self.tracking = true
	self.ended = false
	self.stats = {}
	self.nextMinute = 1
	self.bossKills = 0
	self.matchId = NewMatchId()
	DebugPrint("tracking", self.matchId)
end

function TrinityAnalytics:SendSnapshot(minute, gameTime, isFinal)
	if not ShouldSend() or self.matchId == nil then
		return
	end

	local heroes = CollectHeroes()
	if #heroes == 0 then
		DebugPrint("skip empty snapshot", minute)
		return
	end

	local payload = {
		match_id = self.matchId,
		minute = minute,
		game_time = math.max(0, math.floor(gameTime + 0.5)),
		is_final = isFinal and true or false,
		winner_team = WinningTeam(),
		boss_kills = self.bossKills or 0,
		heroes = heroes,
	}

	DebugPrint("POST minute", minute, "heroes", #heroes, isFinal and "final" or "")
	Http.Request("POST", Endpoint("/v1/analytics/snapshots"), {
		headers = AuthHeaders(),
		timeout_ms = 8000,
		body = payload,
	}, function(body, meta)
		local ok = meta.status == 200 and body and body.ok == true
		DebugPrint("snapshot", meta.status, ok and "ok" or "fail")
	end)
end

function TrinityAnalytics:Think()
	if self.ended then
		return
	end
	if not WarmupEnded() then
		return
	end
	if not ShouldSend() then
		return
	end

	self:BeginTracking()

	local state = GameRules:State_Get()
	if state == DOTA_GAMERULES_STATE_POST_GAME then
		self:FinishMatch()
		return
	end

	local gameTime = GameTime()
	local dueMinute = math.floor(gameTime / self.SNAPSHOT_INTERVAL)
	while self.nextMinute <= dueMinute do
		self:SendSnapshot(self.nextMinute, self.nextMinute * self.SNAPSHOT_INTERVAL, false)
		self.nextMinute = self.nextMinute + 1
	end
end

function TrinityAnalytics:FinishMatch()
	if self.ended or not self.tracking then
		self.ended = true
		return
	end
	self.ended = true

	local gameTime = GameTime()
	local minute = math.max(1, math.floor(gameTime / self.SNAPSHOT_INTERVAL))
	self:SendSnapshot(minute, gameTime, true)
	self.nextMinute = minute + 1
	DebugPrint("match end", self.matchId, "t", string.format("%.1f", gameTime), "winner", WinningTeam())
end

function TrinityAnalytics:AddBossKill()
	if not self.tracking or self.ended then
		return
	end
	self.bossKills = (self.bossKills or 0) + 1
	DebugPrint("boss kill", self.bossKills)
end

function TrinityAnalytics:NoteBossKill(victim)
	if not Alive(victim) or not victim.GetUnitName then
		return
	end

	local name = victim:GetUnitName() or ""
	if name == "npc_mortimer_boss" then
		if victim.reachedFinalPoint then
			return
		end
		self:AddBossKill()
		return
	end

	if name == "npc_primal_beast_boss" then
		if victim.reachedFinalPoint or victim.primalBeastAllied then
			return
		end
		self:AddBossKill()
	end
end

function TrinityAnalytics:OnEntityKilled(event)
	if not self.tracking or self.ended then
		return
	end

	local victim = EntIndexToHScript(event.entindex_killed or 0)
	self:NoteBossKill(victim)

	local attacker = EntIndexToHScript(event.entindex_attacker or 0)
	if not Alive(victim) or not Alive(attacker) then
		return
	end
	if victim:IsHero() or victim:IsBuilding() then
		return
	end
	if victim.IsCourier and victim:IsCourier() then
		return
	end
	if victim.IsOther and victim:IsOther() then
		return
	end
	if IsBossUnit(victim) or IsChenUnit(victim) then
		return
	end

	if not IsRealPlayerHero(attacker) then
		return
	end

	local playerID = PlayerIDOf(attacker)
	local hero = HeroForPlayer(playerID)
	if not IsRealPlayerHero(hero) then
		return
	end
	if victim:GetTeamNumber() == hero:GetTeamNumber() then
		return
	end

	local stats = EnsureHeroStats(playerID, hero)
	if victim.IsNeutralUnitType and victim:IsNeutralUnitType() then
		stats.jungle_creeps = stats.jungle_creeps + 1
		return
	end
	if victim:GetTeamNumber() == DOTA_TEAM_NEUTRALS then
		stats.jungle_creeps = stats.jungle_creeps + 1
		return
	end
	if victim.IsCreep and victim:IsCreep() then
		stats.lane_creeps = stats.lane_creeps + 1
	end
end

function TrinityAnalytics:OnEntityHurt(event)
	if not self.tracking or self.ended then
		return
	end

	local damage = tonumber(event.damage) or 0
	if damage <= 0 then
		return
	end

	local victim = EntIndexToHScript(event.entindex_killed or event.entindex_victim or 0)
	local attacker = EntIndexToHScript(event.entindex_attacker or 0)
	if not IsRealPlayerHero(victim) or not Alive(attacker) then
		return
	end
	if victim:GetTeamNumber() == attacker:GetTeamNumber() then
		return
	end

	local playerID = PlayerIDOf(attacker)
	local hero = HeroForPlayer(playerID)
	if not IsRealPlayerHero(hero) then
		return
	end
	if hero:GetTeamNumber() == victim:GetTeamNumber() then
		return
	end

	local stats = EnsureHeroStats(playerID, hero)
	stats.hero_damage = stats.hero_damage + damage

	local fromHeroUnit = attacker == hero
	local inflictor = EntIndexToHScript(event.entindex_inflictor or 0)
	local skillName = InflictorSkillName(inflictor, hero)
	if skillName == "attack" and not fromHeroUnit then
		return
	end
	AddSkillDamage(stats, skillName, damage)
end

function TrinityAnalytics:OnGameRulesStateChange()
	local state = GameRules:State_Get()
	if state == DOTA_GAMERULES_STATE_POST_GAME then
		self:FinishMatch()
	end
end

function TrinityAnalytics:Dump()
	local heroes = CollectHeroes()
	print("[TrinityAnalytics] match=" .. tostring(self.matchId)
		.. " tracking=" .. tostring(self.tracking)
		.. " minute=" .. tostring(self.nextMinute)
		.. " t=" .. string.format("%.1f", GameTime())
		.. " bosses=" .. tostring(self.bossKills or 0)
		.. " heroes=" .. tostring(#heroes))
	for i = 1, #heroes do
		local row = heroes[i]
		print(string.format(
			"  %s pid=%s nw=%s xp=%s kills=%s lane=%s jungle=%s dmg=%s",
			row.hero,
			tostring(row.player_id),
			tostring(row.networth),
			tostring(row.xp),
			tostring(row.hero_kills),
			tostring(row.lane_creeps),
			tostring(row.jungle_creeps),
			tostring(row.hero_damage)
		))
	end
end

function TrinityAnalytics:Init()
	if self._initialized then
		return
	end
	self._initialized = true
	if self.debugEnabled == nil then
		self.debugEnabled = false
	end

	if not _G.TRINITY_ANALYTICS_COMMANDS_REGISTERED then
		_G.TRINITY_ANALYTICS_COMMANDS_REGISTERED = true
		Convars:RegisterCommand("trinity_analytics_debug", function(_, value)
			if value == nil or value == "" then
				TrinityAnalytics.debugEnabled = not TrinityAnalytics.debugEnabled
			else
				local normalized = string.lower(tostring(value))
				TrinityAnalytics.debugEnabled = normalized == "1" or normalized == "true" or normalized == "on"
			end
			print("[TrinityAnalytics] debug " .. (TrinityAnalytics.debugEnabled and "ON" or "OFF"))
		end, "Toggle analytics HTTP debug: trinity_analytics_debug [0|1]", FCVAR_CHEAT)
		Convars:RegisterCommand("trinity_analytics_dump", function()
			TrinityAnalytics:Dump()
		end, "Print current analytics snapshot", FCVAR_CHEAT)
		Convars:RegisterCommand("trinity_analytics_snapshot", function()
			if not TrinityAnalytics.tracking then
				TrinityAnalytics:BeginTracking()
			end
			local minute = math.max(1, math.floor(GameTime() / TrinityAnalytics.SNAPSHOT_INTERVAL))
			TrinityAnalytics:SendSnapshot(minute, GameTime(), false)
			print("[TrinityAnalytics] forced snapshot minute=" .. tostring(minute))
		end, "Send current analytics snapshot now", FCVAR_CHEAT)
	end

	ListenToGameEvent("entity_killed", Dynamic_Wrap(self, "OnEntityKilled"), self)
	ListenToGameEvent("entity_hurt", Dynamic_Wrap(self, "OnEntityHurt"), self)
	ListenToGameEvent("game_rules_state_change", Dynamic_Wrap(self, "OnGameRulesStateChange"), self)

	Timers:CreateTimer(self.THINK_INTERVAL, function()
		if TrinityAnalytics and TrinityAnalytics.Think then
			TrinityAnalytics:Think()
		end
		return TrinityAnalytics.THINK_INTERVAL
	end)

	DebugPrint("init")
end

return TrinityAnalytics
