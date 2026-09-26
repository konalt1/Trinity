local Http = require("utils/http")
local json = require("utils/json")

local CHUNK = 180

local state = _G.TRINITY_HTTP_RELAY_STATE
if type(state) ~= "table" then
	state = {
		pending = {},
		nextId = 1,
	}
	_G.TRINITY_HTTP_RELAY_STATE = state
end

local function DebugPrint(...)
	if TrinityPlayerData and TrinityPlayerData.debugEnabled then
		print("[TrinityBackend]", ...)
	end
end

local function Chunks(text)
	text = tostring(text or "")
	local parts = {}
	if text == "" then
		parts[1] = ""
		return parts
	end
	local index = 1
	while index <= #text do
		parts[#parts + 1] = string.sub(text, index, index + CHUNK - 1)
		index = index + CHUNK
	end
	return parts
end

local function HostPlayerID()
	if PlayerResource == nil then
		return nil
	end
	local maxPlayers = DOTA_MAX_TEAM_PLAYERS or 24
	for playerID = 0, maxPlayers - 1 do
		if PlayerResource:IsValidPlayerID(playerID) and GameRules and GameRules.PlayerHasCustomGameHostPrivileges then
			local player = PlayerResource:GetPlayer(playerID)
			if player then
				local ok, host = pcall(GameRules.PlayerHasCustomGameHostPrivileges, GameRules, player)
				if ok and host then
					return playerID
				end
			end
		end
	end
	for playerID = 0, maxPlayers - 1 do
		if PlayerResource:IsValidPlayerID(playerID)
			and not (PlayerResource.IsFakeClient and PlayerResource:IsFakeClient(playerID))
			and (tonumber(PlayerResource:GetSteamAccountID(playerID)) or 0) ~= 0 then
			return playerID
		end
	end
	return nil
end

local function Finish(job, decoded, status, body)
	if job == nil or job.done then
		return
	end
	job.done = true
	state.pending[job.id] = nil
	if job.callback then
		job.callback(decoded, { status = status, body = body or "" })
	end
end

local function Deliver(job, attempt)
	if job.done then
		return
	end
	local playerID = job.host
	local player = playerID and PlayerResource:GetPlayer(playerID) or nil
	if not player then
		if attempt < 10 then
			Timers:CreateTimer(0.5, function()
				Deliver(job, attempt + 1)
			end)
			return
		end
		DebugPrint("relay no host")
		Finish(job, nil, 0, "")
		return
	end

	for index, part in ipairs(job.parts) do
		CustomGameEventManager:Send_ServerToPlayer(player, "trinity_http_req", {
			id = job.id,
			seq = index - 1,
			total = #job.parts,
			part = part,
		})
	end
	DebugPrint("relay send", job.id, "parts", #job.parts, "player", playerID)
end

local function OnResponse(_, event)
	event = event or {}
	local id = tonumber(event.id)
	local job = id and state.pending[id] or nil
	if job == nil or job.done then
		return
	end

	local sender = tonumber(event.PlayerID)
	if sender ~= job.host then
		return
	end

	local total = tonumber(event.total) or 0
	local seq = tonumber(event.seq) or 0
	if total < 1 or seq < 0 or seq >= total then
		return
	end

	job.responseTotal = total
	job.responseParts = job.responseParts or {}
	if job.responseParts[seq + 1] == nil then
		job.responseParts[seq + 1] = tostring(event.part or "")
		job.responseGot = (job.responseGot or 0) + 1
	end
	if job.responseGot < total then
		return
	end

	local body = table.concat(job.responseParts, "")
	local status = tonumber(event.status) or 0
	local decoded = nil
	if body ~= "" then
		decoded = json.decode(body)
	end
	DebugPrint("relay status", status, "id", id)
	Finish(job, decoded, status, body)
end

local function EnsureListener()
	if _G.TRINITY_HTTP_RELAY_LISTENING or CustomGameEventManager == nil then
		return
	end
	local ok = pcall(function()
		CustomGameEventManager:RegisterListener("trinity_http_res", OnResponse)
	end)
	if ok then
		_G.TRINITY_HTTP_RELAY_LISTENING = true
	end
end

EnsureListener()

function Http.Fallback(method, url, options, callback)
	EnsureListener()
	options = options or {}
	local headers = options.headers or {}
	local key = headers["X-Trinity-Key"] or headers["dedicated-key"]
	if type(key) == "string" and key ~= "" and not string.find(url, "key=", 1, true) then
		local joiner = string.find(url, "?", 1, true) and "&" or "?"
		url = url .. joiner .. "key=" .. key
	end

	local encodedBody = nil
	if options.body ~= nil then
		encodedBody = type(options.body) == "string" and options.body or json.encode(options.body)
	end

	local packet = json.encode({
		method = method,
		url = url,
		timeout = options.timeout_ms or Http.DEFAULT_TIMEOUT_MS,
		body = encodedBody,
		headers = headers,
	})

	local id = state.nextId
	state.nextId = id + 1
	if state.nextId > 2000000000 then
		state.nextId = 1
	end

	local job = {
		id = id,
		host = HostPlayerID(),
		parts = Chunks(packet),
		callback = callback,
		done = false,
	}
	state.pending[id] = job
	Deliver(job, 0)
	local waitSeconds = math.min(20, math.max(8, math.floor((options.timeout_ms or Http.DEFAULT_TIMEOUT_MS) / 1000) + 2))
	Timers:CreateTimer(waitSeconds, function()
		if not job.done then
			DebugPrint("relay timeout", id)
			Finish(job, nil, 0, "")
		end
	end)
end

return Http
