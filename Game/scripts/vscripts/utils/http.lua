local json = require("utils/json")

local Http = {}

Http.BASE_URL = "http://162.246.19.210"
Http.FALLBACK_URL = "http://127.0.0.1:8080"
Http.DEFAULT_TIMEOUT_MS = 5000
Http.GAME_TIMEOUT_MS = 600 * 1000
Http.KEY_VERSION = "trinity"
Http.TOOLS_KEY = "trinity-tools-local"

local INVALID_KEY_MARKERS = {
	Invalid_NotOnDedicatedServer = true,
	Invalid_NotDedicatedServer = true,
}

local function DedicatedServer()
	return IsDedicatedServer and IsDedicatedServer()
end

local function SendRequest(factory, method, url, options, callback)
	if type(factory) ~= "function" then
		return false
	end

	local request = factory(method, url)
	if not request then
		return false
	end

	request:SetHTTPRequestAbsoluteTimeoutMS(options.timeout_ms or Http.DEFAULT_TIMEOUT_MS)
	request:SetHTTPRequestHeaderValue("Accept", "application/json")

	local headers = options.headers or {}
	for name, value in pairs(headers) do
		request:SetHTTPRequestHeaderValue(tostring(name), tostring(value))
	end

	if options.body ~= nil then
		local encoded = type(options.body) == "string" and options.body or json.encode(options.body)
		request:SetHTTPRequestHeaderValue("Content-Type", "application/json")
		request:SetHTTPRequestRawPostBody("application/json", encoded)
	end

	request:Send(function(response)
		response = response or {}
		local status = tonumber(response.StatusCode) or 0
		local body = response.Body or ""
		local decoded = nil
		if body ~= "" then
			decoded = json.decode(body)
		end
		if callback then
			callback(decoded, { status = status, body = body })
		end
	end)
	return true
end

function Http.Request(method, url, options, callback)
	options = options or {}

	local function finish(decoded, meta)
		if meta.status == 0 and not DedicatedServer() and not options._fallback and Http.Fallback then
			local fallbackOptions = {}
			for key, value in pairs(options) do
				fallbackOptions[key] = value
			end
			fallbackOptions._fallback = true
			Http.Fallback(method, url, fallbackOptions, callback)
			return
		end
		if callback then
			callback(decoded, meta)
		end
	end

	if SendRequest(CreateHTTPRequestScriptVM, method, url, options, finish) then
		return
	end
	finish(nil, { status = 0, body = "" })
end

function Http.AuthKey()
	if DedicatedServer() and GetDedicatedServerKeyV3 then
		local ok, key = pcall(GetDedicatedServerKeyV3, Http.KEY_VERSION)
		if ok and type(key) == "string" and key ~= "" and not INVALID_KEY_MARKERS[key] and string.sub(key, 1, 8) ~= "Invalid_" then
			return key
		end
	end
	return Http.TOOLS_KEY
end

local function MatchKey()
	if Http._matchKey then
		return Http._matchKey
	end
	local symbols = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	local key = ""
	for _ = 1, 32 do
		local index = RandomInt(1, #symbols)
		key = key .. string.sub(symbols, index, index)
	end
	Http._matchKey = key
	return key
end

function Http.MatchId()
	if Http._matchId and Http._matchId ~= "" and Http._matchId ~= "0" then
		return Http._matchId
	end
	local id = "0"
	if GameRules and GameRules.Script_GetMatchID then
		id = tostring(GameRules:Script_GetMatchID())
	end
	if (id == "0" or id == "") and IsInToolsMode and IsInToolsMode() then
		id = tostring(RandomInt(1, 999999))
	end
	if (id == "0" or id == "") and Convars and Convars.GetStr then
		local fromConvar = Convars:GetStr("matchId")
		if type(fromConvar) == "string" and fromConvar ~= "" and fromConvar ~= "0" then
			id = fromConvar
		end
	end
	Http._matchId = id
	return id
end

local function SequenceTable(data)
	if type(data) ~= "table" then
		return false
	end
	local count = 0
	for key in pairs(data) do
		if type(key) ~= "number" then
			return false
		end
		count = count + 1
	end
	return count == #data
end

function Http.GameRequest(path, data, callback, tries, isStats)
	if type(data) ~= "table" then
		data = {}
	end
	if not isStats and not SequenceTable(data) then
		data.matchId = Http.MatchId()
		data.matchKey = MatchKey()
	end

	local function Attempt(left)
		Http.Request("POST", Http.BASE_URL .. path, {
			headers = {
				["dedicated-key"] = Http.AuthKey(),
			},
			body = data,
			timeout_ms = Http.GAME_TIMEOUT_MS,
		}, function(decoded, meta)
			meta = meta or {}
			if meta.status == 200 then
				if callback then
					callback(decoded)
				end
				return
			end

			if path ~= "/http-errors" then
				Http.GameRequest("/http-errors", {
					Url = tostring(path),
					StatusCode = tonumber(meta.status) or 0,
					ResponseMessage = tostring(meta.body or ""),
					RequestBody = data,
				}, nil, 0, false)
			end

			if left and left > 0 and Timers then
				Timers:CreateTimer(3, function()
					Attempt(left - 1)
				end)
			end
		end)
	end

	Attempt(tries or 0)
end

return Http
