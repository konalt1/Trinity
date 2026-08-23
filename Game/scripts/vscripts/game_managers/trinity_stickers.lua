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
		local player = response and response.player
		local ok = meta.status >= 200 and meta.status < 300 and response and response.ok == true and type(player) == "table"

		if ok then
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
		else
			DebugPrint("post failed", path, meta.status, response and response.error)
		end

		if extra and extra.done then
			extra.done(ok)
		end
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

-- Ключи каталога чувствительны к регистру, в консоли это неудобно.
local function ResolveKey(value)
	if type(value) ~= "string" or value == "" then
		return nil
	end
	local lowered = string.lower(value)
	for _, key in ipairs(TrinityStickers.CATALOG) do
		if string.lower(key) == lowered then
			return key
		end
	end
	return nil
end

local function CatalogCopy()
	local keys = {}
	for _, key in ipairs(TrinityStickers.CATALOG) do
		keys[#keys + 1] = key
	end
	return keys
end

function TrinityStickers:ParseGrantArgs(args)
	if #args == 0 then
		return nil, nil
	end

	local keys = {}
	local used = {}
	for _, value in ipairs(args) do
		if string.lower(tostring(value)) == "all" then
			return CatalogCopy()
		end
		local key = ResolveKey(value)
		if not key then
			return nil, tostring(value)
		end
		if not used[key] then
			used[key] = true
			keys[#keys + 1] = key
		end
	end
	return keys
end

function TrinityStickers:GrantMany(playerID, keys)
	if type(keys) ~= "table" or #keys == 0 then
		return
	end

	if not TrinityPlayerData.CanWrite() then
		local state = self.state[playerID] or EmptyState()
		for _, key in ipairs(keys) do
			state.owned[key] = true
		end
		state.loaded = true
		state.last_drop = keys[#keys]
		self.state[playerID] = state
		Publish(playerID)
		print("[TrinityStickers] granted locally: " .. table.concat(keys, ", "))
		return
	end

	local steamid = TrinityPlayerData.SteamID(playerID)
	if steamid == 0 then
		print("[TrinityStickers] no steamid for player " .. tostring(playerID))
		return
	end

	local index = 0
	local granted = 0
	local failed = {}

	local function ApplyFallback()
		if #failed == 0 then
			return
		end
		local state = self.state[playerID] or EmptyState()
		for _, key in ipairs(failed) do
			state.owned[key] = true
		end
		state.loaded = true
		self.state[playerID] = state
		Publish(playerID)
		print("[TrinityStickers] backend unavailable, granted for this match only: " .. table.concat(failed, ", "))
	end

	-- Запросы идут по одному: параллельные ответы могут прийти не по порядку,
	-- и последний применённый payload оказался бы без части выданных стикеров.
	local function GrantNext(ok)
		if index > 0 then
			if ok then
				granted = granted + 1
			else
				failed[#failed + 1] = keys[index]
			end
		end
		index = index + 1

		local key = keys[index]
		if key == nil then
			print("[TrinityStickers] granted " .. granted .. "/" .. #keys)
			ApplyFallback()
			return
		end
		Post("/v1/stickers/grant", { steamid = steamid, sticker = key }, playerID, { done = GrantNext })
	end
	GrantNext(nil)
end

function TrinityStickers:Grant(playerID, key)
	local resolved = ResolveKey(key)
	if not resolved then
		print("[TrinityStickers] unknown sticker " .. tostring(key))
		return
	end
	self:GrantMany(playerID, { resolved })
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
		Convars:RegisterCommand("trinity_sticker_grant", function(_, ...)
			local args = { ... }
			local keys, unknown = TrinityStickers:ParseGrantArgs(args)
			if not keys then
				if unknown then
					print("[TrinityStickers] unknown sticker " .. unknown)
				end
				print("[TrinityStickers] usage: trinity_sticker_grant <all|" .. table.concat(TrinityStickers.CATALOG, "|") .. ">")
				return
			end
			TrinityStickers:GrantMany(CommandPlayerID(), keys)
		end, "Grant stickers: trinity_sticker_grant <all|key> [key2 ...]", FCVAR_CHEAT)
		Convars:RegisterCommand("trinity_sticker_reset_lootbox", function()
			TrinityStickers:ResetLootbox(CommandPlayerID())
		end, "Allow first lootbox again", FCVAR_CHEAT)
	end

	DebugPrint("init")
end

return TrinityStickers
