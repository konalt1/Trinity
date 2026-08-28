-- Persistent player profile: Lua game server <-> Trinity PHP API.

local Http = require("utils/http")

if TrinityPlayerData == nil then
	TrinityPlayerData = {}
end

TrinityPlayerData.BASE_URL = "http://127.0.0.1:8080"
TrinityPlayerData.KEY_VERSION = "trinity"
TrinityPlayerData.TOOLS_KEY = "trinity-tools-local"
TrinityPlayerData.DEFAULT_RATING = 1000
TrinityPlayerData.NET_TABLE = "trinity_player_data"

TrinityPlayerData.profiles = TrinityPlayerData.profiles or {}

local INVALID_KEY_MARKERS = {
	Invalid_NotOnDedicatedServer = true,
	Invalid_NotDedicatedServer = true,
}

local function DebugEnabled()
	return TrinityPlayerData.debugEnabled == true
end

local function DebugPrint(...)
	if DebugEnabled() then
		print("[TrinityBackend]", ...)
	end
end

local function DedicatedKey()
	local ok, key = pcall(function()
		if GetDedicatedServerKeyV3 then
			return GetDedicatedServerKeyV3(TrinityPlayerData.KEY_VERSION)
		end
		if GetDedicatedServerKeyV2 then
			return GetDedicatedServerKeyV2(TrinityPlayerData.KEY_VERSION)
		end
		return nil
	end)
	if not ok or type(key) ~= "string" or key == "" then
		return nil
	end
	if INVALID_KEY_MARKERS[key] or string.sub(key, 1, 8) == "Invalid_" then
		return nil
	end
	return key
end

local function AuthKey()
	local dedicated = DedicatedKey()
	if dedicated then
		DebugPrint("auth dedicated")
		return dedicated
	end
	DebugPrint("auth tools")
	return TrinityPlayerData.TOOLS_KEY
end

local function AuthHeaders()
	return {
		["X-Trinity-Key"] = AuthKey(),
	}
end

local function Endpoint(path)
	return TrinityPlayerData.BASE_URL .. path
end

local function ValidPlayerID(playerID)
	if PlayerResource == nil or playerID == nil or playerID < 0 then
		return false
	end
	return PlayerResource:IsValidPlayerID(playerID)
end

local function SteamAccountID(playerID)
	if not ValidPlayerID(playerID) then
		return 0
	end
	if PlayerResource.IsFakeClient and PlayerResource:IsFakeClient(playerID) then
		return 0
	end
	return tonumber(PlayerResource:GetSteamAccountID(playerID)) or 0
end

local function DefaultProfile(playerID, steamid)
	return {
		player_id = playerID,
		steamid = steamid,
		games = 0,
		rating = TrinityPlayerData.DEFAULT_RATING,
		loaded = false,
	}
end

local function Publish(playerID, profile)
	TrinityPlayerData.profiles[playerID] = profile
	CustomNetTables:SetTableValue(TrinityPlayerData.NET_TABLE, tostring(playerID), {
		steamid = profile.steamid,
		games = profile.games,
		rating = profile.rating,
		loaded = profile.loaded and 1 or 0,
	})
end

local function ShouldPersist()
	if IsInToolsMode and IsInToolsMode() then
		return true
	end
	if GameRules:IsCheatMode() and IsDedicatedServer and IsDedicatedServer() then
		return false
	end
	return true
end

function TrinityPlayerData:GetProfile(playerID)
	return self.profiles[playerID]
end

function TrinityPlayerData:Ping(callback)
	Http.Request("GET", Endpoint("/v1/health"), { timeout_ms = 3000 }, function(body, meta)
		local ok = meta.status == 200 and body and body.ok == true
		DebugPrint("health", meta.status, ok and "ok" or "fail")
		if callback then
			callback(ok)
		end
	end)
end

function TrinityPlayerData:LoadPlayer(playerID)
	local steamid = SteamAccountID(playerID)
	if steamid == 0 then
		return
	end

	if self.profiles[playerID] and self.profiles[playerID].loaded then
		return
	end

	Publish(playerID, DefaultProfile(playerID, steamid))

	local url = Endpoint("/v1/players?steamid=" .. steamid)
	Http.Request("GET", url, { headers = AuthHeaders() }, function(body, meta)
		if meta.status ~= 200 or not body or body.ok ~= true or type(body.player) ~= "table" then
			DebugPrint("load failed", playerID, steamid, meta.status)
			return
		end

		local player = body.player
		Publish(playerID, {
			player_id = playerID,
			steamid = steamid,
			games = tonumber(player.games) or 0,
			rating = tonumber(player.rating) or TrinityPlayerData.DEFAULT_RATING,
			loaded = true,
		})
		if TrinityStickers and TrinityStickers.ApplyPlayerPayload then
			TrinityStickers:ApplyPlayerPayload(playerID, player)
		end
		if TrinityStickers and TrinityStickers.GrantDailyBox then
			TrinityStickers:GrantDailyBox(playerID)
		end
		DebugPrint("loaded", playerID, steamid, "games", player.games, "rating", player.rating)
	end)
end

function TrinityPlayerData:LoadAllPlayers()
	local maxPlayers = DOTA_MAX_TEAM_PLAYERS or 24
	for playerID = 0, maxPlayers - 1 do
		self:LoadPlayer(playerID)
	end
end

function TrinityPlayerData:SaveMatch()
	if self._saved then
		return
	end
	if not ShouldPersist() then
		DebugPrint("skip save")
		return
	end

	local players = {}
	for playerID, profile in pairs(self.profiles) do
		if profile.steamid and profile.steamid > 0 then
			players[#players + 1] = {
				steamid = profile.steamid,
				games = (tonumber(profile.games) or 0) + 1,
				rating = tonumber(profile.rating) or TrinityPlayerData.DEFAULT_RATING,
			}
			profile.games = (tonumber(profile.games) or 0) + 1
			Publish(playerID, profile)
		end
	end

	if #players == 0 then
		DebugPrint("save skipped: no profiles")
		return
	end

	self._saved = true
	Http.Request("POST", Endpoint("/v1/players"), {
		headers = AuthHeaders(),
		body = { players = players },
	}, function(body, meta)
		local ok = meta.status == 200 and body and body.ok == true
		DebugPrint("save", meta.status, ok and "ok" or "fail")
		if not ok then
			self._saved = false
		end
	end)
end

local function PlayerIDFromEvent(keys)
	if keys.PlayerID ~= nil then
		return keys.PlayerID
	end
	if keys.index == nil then
		return nil
	end
	local player = EntIndexToHScript(keys.index + 1)
	if not player then
		return nil
	end
	return player:GetPlayerID()
end

function TrinityPlayerData:OnConnectFull(keys)
	local playerID = PlayerIDFromEvent(keys)
	if not ValidPlayerID(playerID) then
		return
	end

	self:LoadPlayer(playerID)
	local attempts = 0
	Timers:CreateTimer(2, function()
		if SteamAccountID(playerID) ~= 0 then
			self:LoadPlayer(playerID)
			return
		end
		attempts = attempts + 1
		if attempts < 10 then
			return 2
		end
	end)
end

function TrinityPlayerData:OnGameRulesStateChange()
	local state = GameRules:State_Get()
	if state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP or state == DOTA_GAMERULES_STATE_HERO_SELECTION then
		self:LoadAllPlayers()
		if TrinityStickers then
			TrinityStickers._winGranted = false
			TrinityStickers._dailyGranted = {}
		end
	elseif state == DOTA_GAMERULES_STATE_POST_GAME then
		self:SaveMatch()
		if TrinityStickers and TrinityStickers.GrantWinBoxes then
			TrinityStickers:GrantWinBoxes()
		end
	end
end

function TrinityPlayerData:Init()
	if self._initialized then
		return
	end
	self._initialized = true
	self._saved = false
	if self.debugEnabled == nil then
		self.debugEnabled = false
	end

	if not _G.TRINITY_BACKEND_COMMANDS_REGISTERED then
		_G.TRINITY_BACKEND_COMMANDS_REGISTERED = true
		Convars:RegisterCommand("trinity_backend_debug", function(_, value)
			if value == nil or value == "" then
				TrinityPlayerData.debugEnabled = not TrinityPlayerData.debugEnabled
			else
				local normalized = string.lower(tostring(value))
				TrinityPlayerData.debugEnabled = normalized == "1" or normalized == "true" or normalized == "on"
			end
			print("[TrinityBackend] debug " .. (TrinityPlayerData.debugEnabled and "ON" or "OFF"))
		end, "Toggle backend HTTP debug: trinity_backend_debug [0|1]", FCVAR_CHEAT)
		Convars:RegisterCommand("trinity_backend_ping", function()
			TrinityPlayerData:Ping(function(ok)
				print("[TrinityBackend] ping " .. (ok and "ok" or "fail"))
			end)
		end, "Ping Trinity PHP /v1/health", FCVAR_CHEAT)
	end

	ListenToGameEvent("player_connect_full", Dynamic_Wrap(self, "OnConnectFull"), self)
	ListenToGameEvent("player_reconnected", Dynamic_Wrap(self, "OnConnectFull"), self)
	ListenToGameEvent("game_rules_state_change", Dynamic_Wrap(self, "OnGameRulesStateChange"), self)

	self:Ping()
	self:LoadAllPlayers()
	DebugPrint("init", self.BASE_URL)
end

function TrinityPlayerData.RequestHeaders()
	return AuthHeaders()
end

function TrinityPlayerData.ApiUrl(path)
	return Endpoint(path)
end

function TrinityPlayerData.SteamID(playerID)
	return SteamAccountID(playerID)
end

function TrinityPlayerData.CanWrite()
	return ShouldPersist()
end

return TrinityPlayerData
