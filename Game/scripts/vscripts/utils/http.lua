local json = require("utils/json")

local Http = {}

Http.DEFAULT_TIMEOUT_MS = 5000

function Http.Request(method, url, options, callback)
	options = options or {}
	local request = CreateHTTPRequestScriptVM(method, url)
	if not request then
		if callback then
			callback(nil, { status = 0, body = "" })
		end
		return
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
end

return Http
