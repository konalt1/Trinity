local Http = require("utils/http")

if TrinityStickers == nil then
	TrinityStickers = {}
end

TrinityStickers.NET_TABLE = "trinity_stickers"
TrinityStickers.SLOT_COUNT = 8
TrinityStickers.CATALOG = {
	"Gura",
	"NeuroHug",
	"Watson",
	"Anime",
	"Neurodance",
	"Choso",
	"StickerOne",
	"StickerTwo",
}
TrinityStickers.MAX_TIME = {
	Gura = 1,
	NeuroHug = 1.5,
	Watson = 1.5,
	Anime = 1.5,
	Neurodance = 1.5,
	Choso = 0.7,
	StickerOne = 1.5,
	StickerTwo = 1,
}

TrinityStickers.state = TrinityStickers.state or {}

local function DebugPrint(...)
	if TrinityPlayerData and TrinityPlayerData.debugEnabled then
		print("[TrinityStickers]", ...)
	end
end

local function KnownKey(key)
	return type(key) == "string" and TrinityStickers.MAX_TIME[key] ~= nil
end

local function EmptySlots()
	local slots = {}
	for i = 1, TrinityStickers.SLOT_COUNT do
		slots[i] = ""
	end
	return slots
end

local function EmptyState()
	return {
		owned = {},
		slots = EmptySlots(),
		lootbox_pending = false,
		loaded = false,
		last_drop = "",
		duplicate = false,
	}
end

local function OwnedSet(list)
	local owned = {}
	if type(list) ~= "table" then
		return owned
	end
	for _, key in pairs(list) do
		if KnownKey(key) then
			owned[key] = true
		end
	end
	for key, value in pairs(list) do
		if type(key) == "string" and KnownKey(key) and (value == true or value == 1) then
			owned[key] = true
		end
	end
	return owned
end

local function WheelSlots(list)
	local slots = EmptySlots()
	if type(list) ~= "table" then
		return slots
	end
	for i = 1, TrinityStickers.SLOT_COUNT do
		local key = list[i] or list[tostring(i - 1)] or list[i - 1]
		if KnownKey(key) then
			slots[i] = key
		else
			slots[i] = ""
		end
	end
	return slots
end

local function Publish(playerID)
	local state = TrinityStickers.state[playerID] or EmptyState()
	local ownedNet = {}
	for key, owned in pairs(state.owned) do
		if owned then
			ownedNet[key] = 1
		end
	end
	local payload = {
		loaded = state.loaded and 1 or 0,
		lootbox_pending = state.lootbox_pending and 1 or 0,
		last_drop = state.last_drop or "",
		duplicate = state.duplicate and 1 or 0,
		owned = ownedNet,
	}
	for i = 1, TrinityStickers.SLOT_COUNT do
		payload["slot" .. (i - 1)] = state.slots[i] or ""
	end
	CustomNetTables:SetTableValue(TrinityStickers.NET_TABLE, tostring(playerID), payload)
end

local function ApplyPayload(playerID, player, extra)
	local state = TrinityStickers.state[playerID] or EmptyState()
	state.owned = OwnedSet(player.owned)
	state.slots = WheelSlots(player.wheel)
	state.lootbox_pending = player.lootbox_pending == true or player.lootbox_pending == 1
	state.loaded = true
	if extra then
		state.last_drop = extra.sticker or state.last_drop or ""
		state.duplicate = extra.duplicate == true or extra.duplicate == 1
	end
	TrinityStickers.state[playerID] = state
	Publish(playerID)
end

function TrinityStickers:ApplyPlayerPayload(playerID, player)
	if playerID == nil or type(player) ~= "table" then
		return
	end
	ApplyPayload(playerID, player)
end

function TrinityStickers:IsEquipped(playerID, key)
	if not KnownKey(key) then
		return false
	end
	local state = self.state[playerID]
	if not state or not state.loaded then
		return false
	end
	for i = 1, self.SLOT_COUNT do
		if state.slots[i] == key then
			return true
		end
	end
	return false
end

function TrinityStickers:MaxTime(key)
	return self.MAX_TIME[key] or 1.5
end

local function Post(path, body, playerID, extra)
	if not TrinityPlayerData or not TrinityPlayerData.CanWrite() then
		DebugPrint("skip write", path)
		return
	end
	Http.Request("POST", TrinityPlayerData.ApiUrl(path), {
		headers = TrinityPlayerData.RequestHeaders(),
		body = body,
	}, function(response, meta)
		if meta.status < 200 or meta.status >= 300 or not response or response.ok ~= true then
			DebugPrint("post failed", path, meta.status, response and response.error)
			return
		end
		local player = response.player
		if type(player) ~= "table" then
			return
		end
		ApplyPayload(playerID, player, {
			sticker = extra and extra.sticker or response.sticker,
			duplicate = extra and extra.duplicate or response.duplicate,
		})
		if extra and extra.event then
			local playerEntity = PlayerResource:GetPlayer(playerID)
			if playerEntity then
				CustomGameEventManager:Send_ServerToPlayer(playerEntity, extra.event, {
					sticker = response.sticker or "",
					duplicate = (response.duplicate == true or response.duplicate == 1) and 1 or 0,
				})
			end
		end
		DebugPrint("post ok", path, playerID)
	end)
end

function TrinityStickers:OnOpen(event)
	local playerID = event and event.PlayerID
	if playerID == nil then
		return
	end
	local steamid = TrinityPlayerData.SteamID(playerID)
	if steamid == 0 then
		return
	end
	local state = self.state[playerID]
	if not state or not state.loaded or not state.lootbox_pending then
		return
	end
	Post("/v1/stickers/open", { steamid = steamid }, playerID, {
		event = "trinity_sticker_opened",
	})
end

function TrinityStickers:OnSaveWheel(event)
	local playerID = event and event.PlayerID
	if playerID == nil then
		return
	end
	local steamid = TrinityPlayerData.SteamID(playerID)
	if steamid == 0 then
		return
	end
	local state = self.state[playerID]
	if not state or not state.loaded then
		return
	end

	local slots = {}
	local used = {}
	for i = 0, self.SLOT_COUNT - 1 do
		local key = event["s" .. i]
		if type(key) == "string" and key ~= "" then
			if not state.owned[key] or used[key] or not KnownKey(key) then
				DebugPrint("reject wheel", playerID, key)
				Publish(playerID)
				return
			end
			used[key] = true
			slots[i + 1] = key
		else
			slots[i + 1] = ""
		end
	end

	state.slots = slots
	self.state[playerID] = state
	Publish(playerID)
	Post("/v1/stickers/wheel", { steamid = steamid, slots = slots }, playerID)
end

function TrinityStickers:Grant(playerID, key)
	if not KnownKey(key) then
		print("[TrinityStickers] unknown sticker " .. tostring(key))
		return
	end
	local steamid = TrinityPlayerData.SteamID(playerID)
	if steamid == 0 then
		return
	end
	if TrinityPlayerData.CanWrite() then
		Post("/v1/stickers/grant", { steamid = steamid, sticker = key }, playerID)
		return
	end
	local state = self.state[playerID] or EmptyState()
	state.owned[key] = true
	state.loaded = true
	state.last_drop = key
	self.state[playerID] = state
	Publish(playerID)
end

function TrinityStickers:ResetLootbox(playerID)
	local steamid = TrinityPlayerData.SteamID(playerID)
	if steamid == 0 then
		return
	end
	if TrinityPlayerData.CanWrite() then
		Post("/v1/stickers/reset-lootbox", { steamid = steamid }, playerID)
		return
	end
	local state = self.state[playerID] or EmptyState()
	state.lootbox_pending = true
	state.loaded = true
	self.state[playerID] = state
	Publish(playerID)
end

local function CommandPlayerID()
	local player = Convars:GetCommandClient()
	if player then
		return player:GetPlayerID()
	end
	return 0
end

function TrinityStickers:Init()
	if self._initialized then
		return
	end
	self._initialized = true

	CustomGameEventManager:RegisterListener("trinity_sticker_open", function(_, event)
		TrinityStickers:OnOpen(event)
	end)
	CustomGameEventManager:RegisterListener("trinity_sticker_save_wheel", function(_, event)
		TrinityStickers:OnSaveWheel(event)
	end)

	if not _G.TRINITY_STICKER_COMMANDS_REGISTERED then
		_G.TRINITY_STICKER_COMMANDS_REGISTERED = true
		Convars:RegisterCommand("trinity_sticker_grant", function(_, key)
			TrinityStickers:Grant(CommandPlayerID(), key)
		end, "Grant sticker: trinity_sticker_grant Gura", FCVAR_CHEAT)
		Convars:RegisterCommand("trinity_sticker_reset_lootbox", function()
			TrinityStickers:ResetLootbox(CommandPlayerID())
		end, "Allow first lootbox again", FCVAR_CHEAT)
	end

	DebugPrint("init")
end

return TrinityStickers
