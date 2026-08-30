local Http = require("utils/http")

if TrinityStickers == nil then
	TrinityStickers = {}
end

TrinityStickers.NET_TABLE = "trinity_stickers"
TrinityStickers.SLOT_COUNT = 8
TrinityStickers.QUALITY_NORMAL = 1
TrinityStickers.QUALITY_ELITE = 2
TrinityStickers.PRICE_NORMAL = 5
TrinityStickers.PRICE_ELITE = 20
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
		lootboxes = 0,
		currency = 0,
		prices = {
			normal = TrinityStickers.PRICE_NORMAL,
			elite = TrinityStickers.PRICE_ELITE,
		},
		loaded = false,
		last_drop = "",
		last_quality = 0,
		duplicate = false,
		converted = false,
	}
end

local function OwnedInfo(value)
	if type(value) == "table" then
		local quality = tonumber(value.quality or value.q) or 0
		if quality < TrinityStickers.QUALITY_NORMAL then
			return nil
		end
		return {
			quality = quality >= TrinityStickers.QUALITY_ELITE and TrinityStickers.QUALITY_ELITE or TrinityStickers.QUALITY_NORMAL,
			copies = tonumber(value.copies or value.n) or 0,
		}
	end
	if value == true or value == 1 then
		return { quality = TrinityStickers.QUALITY_NORMAL, copies = 1 }
	end
	local quality = tonumber(value)
	if quality and quality >= TrinityStickers.QUALITY_NORMAL then
		return {
			quality = quality >= TrinityStickers.QUALITY_ELITE and TrinityStickers.QUALITY_ELITE or TrinityStickers.QUALITY_NORMAL,
			copies = 1,
		}
	end
	return nil
end

local function OwnedMap(list)
	local owned = {}
	if type(list) ~= "table" then
		return owned
	end
	for key, value in pairs(list) do
		if type(key) == "number" and KnownKey(value) then
			owned[value] = { quality = TrinityStickers.QUALITY_NORMAL, copies = 1 }
		elseif type(key) == "string" and KnownKey(key) then
			local info = OwnedInfo(value)
			if info then
				owned[key] = info
			end
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

local function IsOwnedEntry(info)
	return type(info) == "table" and (info.quality or 0) >= TrinityStickers.QUALITY_NORMAL
end

local function Publish(playerID)
	local state = TrinityStickers.state[playerID] or EmptyState()
	local ownedNet = {}
	for key, info in pairs(state.owned) do
		if IsOwnedEntry(info) then
			ownedNet[key] = {
				quality = info.quality,
				copies = info.copies or 0,
			}
		end
	end
	local payload = {
		loaded = state.loaded and 1 or 0,
		lootboxes = tonumber(state.lootboxes) or 0,
		currency = tonumber(state.currency) or 0,
		price_normal = (state.prices and state.prices.normal) or TrinityStickers.PRICE_NORMAL,
		price_elite = (state.prices and state.prices.elite) or TrinityStickers.PRICE_ELITE,
		last_drop = state.last_drop or "",
		last_quality = tonumber(state.last_quality) or 0,
		duplicate = state.duplicate and 1 or 0,
		converted = state.converted and 1 or 0,
		owned = ownedNet,
	}
	for i = 1, TrinityStickers.SLOT_COUNT do
		payload["slot" .. (i - 1)] = state.slots[i] or ""
	end
	CustomNetTables:SetTableValue(TrinityStickers.NET_TABLE, tostring(playerID), payload)
end

local function NormalizeSlotKey(key)
	if key == nil then
		return ""
	end
	if type(key) ~= "string" then
		key = tostring(key)
	end
	if key == "" or key == "-" then
		return ""
	end
	return key
end

local function EventSlot(event, index)
	local key = event["s" .. index]
	if (key == nil or key == "") and type(event.slots) == "table" then
		key = event.slots[index] or event.slots[index + 1] or event.slots[tostring(index)]
	end
	return NormalizeSlotKey(key)
end

local function SlotsFromEvent(event)
	local slots = EmptySlots()
	for i = 0, TrinityStickers.SLOT_COUNT - 1 do
		slots[i + 1] = EventSlot(event, i)
	end
	return slots
end

local function WheelBody(steamid, slots)
	local body = { steamid = steamid, slots = {} }
	for i = 1, TrinityStickers.SLOT_COUNT do
		body.slots[i] = slots[i] or ""
		body["s" .. (i - 1)] = slots[i] or ""
	end
	return body
end

local function ApplyWheelSlots(playerID, slots)
	local state = TrinityStickers.state[playerID]
	if not state then
		return false
	end

	local nextSlots = EmptySlots()
	local used = {}
	for i = 1, TrinityStickers.SLOT_COUNT do
		local key = slots[i]
		if type(key) == "string" and key ~= "" and KnownKey(key) and not used[key] and IsOwnedEntry(state.owned[key]) then
			used[key] = true
			nextSlots[i] = key
		end
	end

	state.slots = nextSlots
	state.pendingSlots = nil
	TrinityStickers.state[playerID] = state
	return true
end

local Post

local function PersistWheel(playerID)
	local state = TrinityStickers.state[playerID]
	if not state then
		return
	end
	local steamid = TrinityPlayerData.SteamID(playerID)
	if steamid == 0 then
		return
	end
	Post("/v1/stickers/wheel", WheelBody(steamid, state.slots), playerID)
end

local function FlushPendingWheel(playerID)
	local state = TrinityStickers.state[playerID]
	if not state or not state.pendingSlots or not state.loaded then
		return
	end
	local pending = state.pendingSlots
	state.pendingSlots = nil
	if ApplyWheelSlots(playerID, pending) then
		Publish(playerID)
		PersistWheel(playerID)
	else
		Publish(playerID)
	end
end

local function ApplyPayload(playerID, player, extra)
	local state = TrinityStickers.state[playerID] or EmptyState()
	local pending = state.pendingSlots
	local previousSlots = state.slots
	local wasLoaded = state.loaded
	local keepWheel = extra and extra.keepWheel
	state.owned = OwnedMap(player.owned)
	if keepWheel and wasLoaded then
		state.slots = previousSlots
	else
		state.slots = WheelSlots(player.wheel)
	end
	state.lootboxes = tonumber(player.lootboxes) or 0
	state.currency = tonumber(player.currency) or 0
	if type(player.prices) == "table" then
		state.prices = {
			normal = tonumber(player.prices.normal) or TrinityStickers.PRICE_NORMAL,
			elite = tonumber(player.prices.elite) or TrinityStickers.PRICE_ELITE,
		}
	end
	state.loaded = true
	state.pendingSlots = pending
	if extra then
		state.last_drop = extra.sticker or state.last_drop or ""
		state.last_quality = tonumber(extra.quality) or state.last_quality or 0
		state.duplicate = extra.duplicate == true or extra.duplicate == 1
		state.converted = extra.converted == true or extra.converted == 1
	end
	TrinityStickers.state[playerID] = state
	Publish(playerID)
	FlushPendingWheel(playerID)
end

function TrinityStickers:ApplyPlayerPayload(playerID, player)
	if playerID == nil or type(player) ~= "table" then
		return
	end
	ApplyPayload(playerID, player)
end

function TrinityStickers:IsOwned(playerID, key)
	if not KnownKey(key) then
		return false
	end
	local state = self.state[playerID]
	if not state or not state.loaded then
		return false
	end
	return IsOwnedEntry(state.owned[key])
end

function TrinityStickers:IsElite(playerID, key)
	if not KnownKey(key) then
		return false
	end
	local state = self.state[playerID]
	if not state or not state.loaded then
		return false
	end
	local info = state.owned[key]
	return IsOwnedEntry(info) and info.quality == self.QUALITY_ELITE
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

local function RewardFlags(response, extra)
	return {
		sticker = extra and extra.sticker or (response and response.sticker),
		quality = extra and extra.quality or (response and response.quality),
		duplicate = extra and extra.duplicate or (response and response.duplicate),
		converted = extra and extra.converted or (response and response.converted),
	}
end

Post = function(path, body, playerID, extra)
	if not TrinityPlayerData or not TrinityPlayerData.CanWrite() then
		DebugPrint("skip write", path)
		return
	end
	extra = extra or {}
	if extra.keepWheel == nil then
		extra.keepWheel = true
	end
	Http.Request("POST", TrinityPlayerData.ApiUrl(path), {
		headers = TrinityPlayerData.RequestHeaders(),
		body = body,
	}, function(response, meta)
		local player = response and response.player
		local ok = meta.status >= 200 and meta.status < 300 and response and response.ok == true

		if ok and type(player) == "table" then
			local flags = RewardFlags(response, extra)
			flags.keepWheel = extra.keepWheel
			ApplyPayload(playerID, player, flags)
			if extra and extra.event then
				local playerEntity = PlayerResource:GetPlayer(playerID)
				if playerEntity then
					CustomGameEventManager:Send_ServerToPlayer(playerEntity, extra.event, {
						sticker = response.sticker or "",
						quality = tonumber(response.quality) or 0,
						copies = tonumber(response.copies) or 0,
						duplicate = (response.duplicate == true or response.duplicate == 1) and 1 or 0,
						converted = (response.converted == true or response.converted == 1) and 1 or 0,
					})
				end
			end
			DebugPrint("post ok", path, playerID)
		else
			DebugPrint("post failed", path, meta.status, response and response.error)
			if extra and extra.event then
				local playerEntity = PlayerResource:GetPlayer(playerID)
				if playerEntity then
					CustomGameEventManager:Send_ServerToPlayer(playerEntity, extra.event, {
						sticker = "",
						failed = 1,
					})
				end
			end
		end

		if extra and extra.done then
			extra.done(ok)
		end
	end)
end

local function NotifyFailed(playerID, eventName)
	local playerEntity = PlayerResource:GetPlayer(playerID)
	if playerEntity then
		CustomGameEventManager:Send_ServerToPlayer(playerEntity, eventName, {
			sticker = "",
			failed = 1,
		})
	end
end

function TrinityStickers:OnOpen(event)
	local playerID = event and event.PlayerID
	if playerID == nil then
		return
	end
	local steamid = TrinityPlayerData.SteamID(playerID)
	if steamid == 0 or not TrinityPlayerData.CanWrite() then
		NotifyFailed(playerID, "trinity_sticker_opened")
		return
	end
	local state = self.state[playerID]
	if not state or not state.loaded or (tonumber(state.lootboxes) or 0) < 1 then
		NotifyFailed(playerID, "trinity_sticker_opened")
		return
	end
	Post("/v1/stickers/open", { steamid = steamid }, playerID, {
		event = "trinity_sticker_opened",
	})
end

function TrinityStickers:OnBuy(event)
	local playerID = event and event.PlayerID
	if playerID == nil then
		return
	end
	local steamid = TrinityPlayerData.SteamID(playerID)
	if steamid == 0 or not TrinityPlayerData.CanWrite() then
		NotifyFailed(playerID, "trinity_sticker_bought")
		return
	end
	local state = self.state[playerID]
	if not state or not state.loaded then
		NotifyFailed(playerID, "trinity_sticker_bought")
		return
	end

	local key = event.sticker
	local quality = tonumber(event.quality) or 0
	if not KnownKey(key) or (quality ~= self.QUALITY_NORMAL and quality ~= self.QUALITY_ELITE) then
		NotifyFailed(playerID, "trinity_sticker_bought")
		return
	end
	local info = state.owned[key]
	if IsOwnedEntry(info) and info.quality == self.QUALITY_ELITE then
		NotifyFailed(playerID, "trinity_sticker_bought")
		return
	end
	local cost = quality == self.QUALITY_ELITE and ((state.prices and state.prices.elite) or self.PRICE_ELITE)
		or ((state.prices and state.prices.normal) or self.PRICE_NORMAL)
	if (tonumber(state.currency) or 0) < cost then
		NotifyFailed(playerID, "trinity_sticker_bought")
		return
	end

	Post("/v1/stickers/buy", { steamid = steamid, sticker = key, quality = quality }, playerID, {
		event = "trinity_sticker_bought",
	})
end

function TrinityStickers:OnSaveWheel(event)
	local playerID = event and (event.PlayerID or event.pid or event.player_id)
	playerID = tonumber(playerID)
	if playerID == nil then
		return
	end
	local steamid = TrinityPlayerData.SteamID(playerID)
	if steamid == 0 then
		return
	end
	local state = self.state[playerID] or EmptyState()
	self.state[playerID] = state

	local slots = SlotsFromEvent(event)

	if not state.loaded then
		state.pendingSlots = slots
		state.slots = slots
		Publish(playerID)
		return
	end

	ApplyWheelSlots(playerID, slots)
	Publish(playerID)
	PersistWheel(playerID)
end

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
			state.owned[key] = { quality = self.QUALITY_ELITE, copies = 0 }
		end
		state.loaded = true
		state.last_drop = keys[#keys]
		state.last_quality = self.QUALITY_ELITE
		self.state[playerID] = state
		Publish(playerID)
		DebugPrint("granted elite locally: " .. table.concat(keys, ", "))
		return
	end

	local steamid = TrinityPlayerData.SteamID(playerID)
	if steamid == 0 then
		DebugPrint("no steamid for player " .. tostring(playerID))
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
			state.owned[key] = { quality = self.QUALITY_ELITE, copies = 0 }
		end
		state.loaded = true
		self.state[playerID] = state
		Publish(playerID)
		DebugPrint("backend unavailable, granted elite for this match only: " .. table.concat(failed, ", "))
	end

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
			DebugPrint("granted " .. granted .. "/" .. #keys)
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
		DebugPrint("unknown sticker " .. tostring(key))
		return
	end
	self:GrantMany(playerID, { resolved })
end

function TrinityStickers:GrantLootbox(playerID)
	local steamid = TrinityPlayerData.SteamID(playerID)
	if steamid == 0 then
		return
	end
	if TrinityPlayerData.CanWrite() then
		Post("/v1/stickers/grant-lootbox", { steamid = steamid }, playerID)
		return
	end
	local state = self.state[playerID] or EmptyState()
	state.lootboxes = (tonumber(state.lootboxes) or 0) + 1
	state.loaded = true
	self.state[playerID] = state
	Publish(playerID)
end

function TrinityStickers:GrantDailyBox(playerID)
	self._dailyGranted = self._dailyGranted or {}
	if self._dailyGranted[playerID] then
		return
	end
	if not TrinityPlayerData or not TrinityPlayerData.CanWrite() then
		return
	end
	local steamid = TrinityPlayerData.SteamID(playerID)
	if steamid == 0 then
		return
	end
	self._dailyGranted[playerID] = true
	Post("/v1/stickers/grant-daily", { steamid = steamid }, playerID, {
		done = function(ok)
			if not ok then
				TrinityStickers._dailyGranted[playerID] = nil
			end
		end,
	})
end

function TrinityStickers:GrantWinBoxes()
	if self._winGranted then
		return
	end
	if not TrinityPlayerData or not TrinityPlayerData.CanWrite() then
		DebugPrint("skip win lootboxes")
		return
	end

	local winner = GameRules:GetGameWinner()
	if winner ~= DOTA_TEAM_GOODGUYS and winner ~= DOTA_TEAM_BADGUYS then
		DebugPrint("no winning team for lootboxes", winner)
		return
	end

	local steamids = {}
	local bySteamid = {}
	local maxPlayers = DOTA_MAX_TEAM_PLAYERS or 24
	for playerID = 0, maxPlayers - 1 do
		if PlayerResource:IsValidPlayerID(playerID) and PlayerResource:GetTeam(playerID) == winner then
			local steamid = TrinityPlayerData.SteamID(playerID)
			if steamid > 0 then
				steamids[#steamids + 1] = steamid
				bySteamid[tostring(steamid)] = playerID
			end
		end
	end
	if #steamids == 0 then
		return
	end

	self._winGranted = true
	Http.Request("POST", TrinityPlayerData.ApiUrl("/v1/stickers/grant-win"), {
		headers = TrinityPlayerData.RequestHeaders(),
		body = { steamids = steamids },
	}, function(response, meta)
		local ok = meta.status >= 200 and meta.status < 300 and response and response.ok == true
		if not ok then
			self._winGranted = false
			DebugPrint("grant-win failed", meta.status, response and response.error)
			return
		end
		if type(response.players) == "table" then
			for steamid, player in pairs(response.players) do
				local playerID = bySteamid[tostring(steamid)]
				if playerID and type(player) == "table" then
					ApplyPayload(playerID, player, { keepWheel = true })
				end
			end
		end
		DebugPrint("grant-win ok")
	end)
end

local function ResolvePlayerID(player)
	if player == nil then
		return nil
	end
	local ok, playerID = pcall(function()
		return player:GetPlayerID()
	end)
	if not ok or type(playerID) ~= "number" or playerID < 0 then
		return nil
	end
	return playerID
end

local function CommandPlayerID()
	local ok, dotaPlayer = pcall(function()
		return Convars:GetDOTACommandClient()
	end)
	if ok then
		local playerID = ResolvePlayerID(dotaPlayer)
		if playerID then
			return playerID
		end
	end

	local okBase, basePlayer = pcall(function()
		return Convars:GetCommandClient()
	end)
	if okBase then
		local playerID = ResolvePlayerID(basePlayer)
		if playerID then
			return playerID
		end
	end

	if PlayerResource and PlayerResource:IsValidPlayerID(0) then
		return 0
	end
	return -1
end

function TrinityStickers:Init()
	if self._initialized then
		return
	end
	self._initialized = true
	self._winGranted = false
	self._dailyGranted = {}

	CustomGameEventManager:RegisterListener("trinity_sticker_open", function(_, event)
		TrinityStickers:OnOpen(event)
	end)
	CustomGameEventManager:RegisterListener("trinity_sticker_buy", function(_, event)
		TrinityStickers:OnBuy(event)
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
			local playerID = CommandPlayerID()
			if playerID < 0 then
				print("[TrinityStickers] no player for this console command")
				return
			end
			TrinityStickers:GrantMany(playerID, keys)
		end, "Grant elite stickers: trinity_sticker_grant <all|key> [key2 ...]", FCVAR_CHEAT)
		Convars:RegisterCommand("trinity_sticker_grant_lootbox", function()
			local playerID = CommandPlayerID()
			if playerID < 0 then
				print("[TrinityStickers] no player for this console command")
				return
			end
			TrinityStickers:GrantLootbox(playerID)
		end, "Give one unopened lootbox", FCVAR_CHEAT)
	end

	if not _G.TRINITY_STICKER_UI_COMMAND_REGISTERED then
		_G.TRINITY_STICKER_UI_COMMAND_REGISTERED = true
		Convars:RegisterCommand("trinity_sticker_ui", function(_, value)
			local enabled = tonumber(value)
			if enabled ~= 0 and enabled ~= 1 then
				print("[TrinityStickers] usage: trinity_sticker_ui <0|1>")
				return
			end

			local playerID = CommandPlayerID()
			if playerID < 0 then
				print("[TrinityStickers] no player for this console command")
				return
			end

			local playerEntity = PlayerResource:GetPlayer(playerID)
			if not playerEntity then
				print("[TrinityStickers] no player entity for player " .. tostring(playerID))
				return
			end

			CustomGameEventManager:Send_ServerToPlayer(playerEntity, "trinity_sticker_ui_override", {
				enabled = enabled == 1,
			})
			DebugPrint("sticker UI " .. (enabled == 1 and "enabled" or "disabled")
				.. " for player " .. tostring(playerID))
		end, "Show sticker and lootbox UI after warmup: trinity_sticker_ui <0|1>", FCVAR_CHEAT)
	end

	DebugPrint("init")
end

return TrinityStickers
