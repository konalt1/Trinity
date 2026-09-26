-- Match lifecycle against the same POST procedure as 1x6 server.lua.
-- Bodies stay limited to what Trinity actually has: 3v3 result, hero, KDA, items.

local Http = require("utils/http")

if TrinityMatch == nil then
	TrinityMatch = {}
end

TrinityMatch.NET_TABLE = "trinity_match"

local function DebugPrint(...)
	if TrinityPlayerData and TrinityPlayerData.debugEnabled then
		print("[TrinityBackend]", ...)
	end
end

local function ValidPlayerID(playerID)
	if PlayerResource == nil or playerID == nil or playerID < 0 then
		return false
	end
	return PlayerResource:IsValidPlayerID(playerID)
end

local function SteamID(playerID)
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

local function EachPlayer(callback)
	local maxPlayers = DOTA_MAX_TEAM_PLAYERS or 24
	for playerID = 0, maxPlayers - 1 do
		local steamid = SteamID(playerID)
		if steamid > 0 then
			callback(playerID, steamid)
		end
	end
end

local function SteamIDs()
	local ids = {}
	EachPlayer(function(_, steamid)
		ids[#ids + 1] = tostring(steamid)
	end)
	return ids
end

local function Tries()
	if IsInToolsMode and IsInToolsMode() then
		return nil
	end
	return 50
end

local function CheatsEnabled()
	if IsInToolsMode and IsInToolsMode() then
		return false
	end
	return GameRules:IsCheatMode()
end

local function HeroItems(playerID)
	local items = {}
	local hero = PlayerResource:GetSelectedHeroEntity(playerID)
	if not hero or hero:IsNull() then
		return items
	end
	for slot = 0, 5 do
		local item = hero:GetItemInSlot(slot)
		if item and not item:IsNull() then
			items[#items + 1] = item:GetAbilityName()
		end
	end
	if hero.HasShard and hero:HasShard() then
		items[#items + 1] = "item_aghanims_shard"
	end
	if hero.HasScepter and hero:HasScepter() then
		items[#items + 1] = "item_ultimate_scepter"
	end
	return items
end

local function ApplyRating(playerID, rating)
	if not TrinityPlayerData or not TrinityPlayerData.profiles then
		return
	end
	local profile = TrinityPlayerData.profiles[playerID]
	if not profile then
		return
	end
	profile.rating = tonumber(rating) or profile.rating
	CustomNetTables:SetTableValue(TrinityPlayerData.NET_TABLE, tostring(playerID), {
		steamid = profile.steamid,
		games = profile.games,
		rating = profile.rating,
		loaded = profile.loaded and 1 or 0,
	})
end

function TrinityMatch:PublishStart(data)
	data = data or {}
	CustomNetTables:SetTableValue(self.NET_TABLE, "meta", {
		season = tostring(data.seasonName or ""),
		average_rating = tonumber(data.averageRating) or 0,
		stats_match = data.isStatsMatch and 1 or 0,
	})
	self.statsMatch = data.isStatsMatch == true
	if type(data.players) ~= "table" then
		return
	end
	for _, player in pairs(data.players) do
		if type(player) == "table" then
			local steamid = tostring(player.playerId or "")
			EachPlayer(function(playerID, account)
				if tostring(account) == steamid then
					ApplyRating(playerID, player.rating)
				end
			end)
		end
	end
end

function TrinityMatch:PublishLeaderboard(data)
	local rows = {}
	local source = data and data.solo or {}
	if type(source) == "table" then
		for _, row in pairs(source) do
			if type(row) == "table" then
				rows[#rows + 1] = {
					steamid = tostring(row.playerId or ""),
					rating = tonumber(row.rating) or 0,
					games = tonumber(row.matchCount) or 0,
					hero = tostring(row.favoriteHero or ""),
				}
			end
		end
	end
	CustomNetTables:SetTableValue(self.NET_TABLE, "leaderboard", { rows = rows })
end

function TrinityMatch:Start()
	if self._started then
		return
	end
	local players = SteamIDs()
	if #players == 0 then
		return
	end
	self._started = true
	DebugPrint("match start", Http.MatchId(), #players)

	Http.GameRequest("/unranked_stats", { players = players }, function()
	end, Tries(), false)

	Http.GameRequest("/match_details", players, function(data)
		DebugPrint("match details", data and "ok" or "empty")
	end, nil, true)

	Http.GameRequest("/match_leaderboard", players, function(data)
		self:PublishLeaderboard(data)
	end, nil, true)

	Http.GameRequest("/match_start", {
		cluster = Convars:GetInt("sv_cluster"),
		region = Convars:GetInt("sv_region"),
		players = players,
		mapName = GetMapName(),
		isCheatsMode = CheatsEnabled(),
	}, function(data)
		self:PublishStart(data)
		DebugPrint("match started", data and data.isStatsMatch)
	end, Tries(), false)
end

function TrinityMatch:PlayerEnd(playerID)
	if self._ended and self._ended[playerID] then
		return
	end
	local steamid = SteamID(playerID)
	if steamid == 0 then
		return
	end

	self._ended = self._ended or {}
	self._ended[playerID] = true

	local team = PlayerResource:GetTeam(playerID)
	local winner = GameRules:GetGameWinner()
	local place = (winner == team) and 1 or 2
	local hero = PlayerResource:GetSelectedHeroEntity(playerID)

	Http.GameRequest("/end", {
		playerId = tostring(steamid),
		playerName = PlayerResource:GetPlayerName(playerID) or "",
		heroName = PlayerResource:GetSelectedHeroName(playerID) or "",
		team = team,
		place = place,
		kills = PlayerResource:GetKills(playerID),
		deaths = PlayerResource:GetDeaths(playerID),
		assists = PlayerResource:GetAssists(playerID),
		networth = PlayerResource:GetNetWorth(playerID),
		gpm = PlayerResource:GetGoldPerMin(playerID),
		xpm = PlayerResource:GetXPPerMin(playerID),
		level = hero and hero:GetLevel() or PlayerResource:GetLevel(playerID),
		items = HeroItems(playerID),
		endTime = math.floor(GameRules:GetDOTATime(false, false)),
		isLeaver = self._left and self._left[playerID] == true,
	}, function(data)
		local change = data and tonumber(data.ratingChange) or 0
		DebugPrint("end", playerID, "change", change)
		if data and data.rating ~= nil then
			ApplyRating(playerID, data.rating)
		end
		CustomNetTables:SetTableValue(self.NET_TABLE, "end_" .. tostring(playerID), {
			place = place,
			rating_change = change,
		})
	end, Tries(), false)
end

function TrinityMatch:EndMatch()
	if self._endSent then
		return
	end
	self._endSent = true
	EachPlayer(function(playerID)
		self:PlayerEnd(playerID)
	end)
end

function TrinityMatch:PlayerLeave(playerID)
	self._left = self._left or {}
	if self._left[playerID] or not ValidPlayerID(playerID) then
		return
	end
	local steamid = SteamID(playerID)
	if steamid == 0 then
		return
	end
	self._left[playerID] = true
	local winner = GameRules:GetGameWinner()
	Http.GameRequest("/leave", {
		playerId = tostring(steamid),
		playerName = PlayerResource:GetPlayerName(playerID) or "",
		leaveTime = math.floor(GameRules:GetDOTATime(false, false)),
		isSafeToLeave = winner == DOTA_TEAM_GOODGUYS or winner == DOTA_TEAM_BADGUYS,
	}, nil, Tries(), false)
end

function TrinityMatch:Report(reporter, reported1, reported2, reportType)
	local reporterId = SteamID(reporter)
	local first = SteamID(reported1)
	local second = SteamID(reported2)
	if reporterId == 0 or first == 0 then
		return
	end
	Http.GameRequest("/report", {
		reporter = tostring(reporterId),
		reported1 = tostring(first),
		reported2 = tostring(second),
		type = tonumber(reportType) or 0,
	}, nil, 50, false)
end

function TrinityMatch:OnDisconnect(keys)
	keys = keys or {}
	local playerID = keys.PlayerID
	if playerID == nil then
		playerID = keys.playerid
	end
	self:PlayerLeave(tonumber(playerID))
end

function TrinityMatch:OnGameRulesStateChange()
	local state = GameRules:State_Get()
	if state == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		self:Start()
	elseif state == DOTA_GAMERULES_STATE_POST_GAME then
		self:EndMatch()
	end
end

function TrinityMatch:Init()
	if self._initialized then
		return
	end
	self._initialized = true
	self._started = false
	self._endSent = false
	self._ended = {}
	self._left = {}
	self.statsMatch = false

	ListenToGameEvent("player_disconnect", Dynamic_Wrap(self, "OnDisconnect"), self)
	ListenToGameEvent("game_rules_state_change", Dynamic_Wrap(self, "OnGameRulesStateChange"), self)

	local state = GameRules:State_Get()
	if state == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		self:Start()
	elseif state == DOTA_GAMERULES_STATE_POST_GAME then
		self:EndMatch()
	end
end

return TrinityMatch
