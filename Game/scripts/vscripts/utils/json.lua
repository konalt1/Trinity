-- Compact JSON encode/decode for Trinity backend payloads (Lua 5.1).

local json = {}

local decodeValue

local function skipWhitespace(text, index)
	while index <= #text and string.match(string.sub(text, index, index), "%s") do
		index = index + 1
	end
	return index
end

local function encodeString(value)
	local replacements = {
		["\\"] = "\\\\",
		["\""] = "\\\"",
		["\b"] = "\\b",
		["\f"] = "\\f",
		["\n"] = "\\n",
		["\r"] = "\\r",
		["\t"] = "\\t",
	}
	return '"' .. string.gsub(value, '[%z\1-\31\\"]', function(char)
		return replacements[char] or string.format("\\u%04x", string.byte(char))
	end) .. '"'
end

local function isArray(value)
	local count = 0
	for key in pairs(value) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			return false
		end
		if key > count then
			count = key
		end
	end
	for index = 1, count do
		if value[index] == nil then
			return false
		end
	end
	return true
end

function json.encode(value)
	local valueType = type(value)
	if value == nil or valueType == "nil" then
		return "null"
	end
	if valueType == "boolean" then
		return value and "true" or "false"
	end
	if valueType == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return "null"
		end
		return string.format("%.14g", value)
	end
	if valueType == "string" then
		return encodeString(value)
	end
	if valueType ~= "table" then
		return "null"
	end

	if isArray(value) then
		local parts = {}
		for index = 1, #value do
			parts[index] = json.encode(value[index])
		end
		return "[" .. table.concat(parts, ",") .. "]"
	end

	local parts = {}
	for key, nested in pairs(value) do
		if type(key) == "string" or type(key) == "number" then
			parts[#parts + 1] = encodeString(tostring(key)) .. ":" .. json.encode(nested)
		end
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

local function decodeString(text, index)
	index = index + 1
	local chunks = {}
	while index <= #text do
		local char = string.sub(text, index, index)
		if char == '"' then
			return table.concat(chunks), index + 1
		end
		if char ~= "\\" then
			chunks[#chunks + 1] = char
			index = index + 1
		else
			local escaped = string.sub(text, index + 1, index + 1)
			local map = {
				['"'] = '"',
				["\\"] = "\\",
				["/"] = "/",
				b = "\b",
				f = "\f",
				n = "\n",
				r = "\r",
				t = "\t",
			}
			if map[escaped] then
				chunks[#chunks + 1] = map[escaped]
				index = index + 2
			elseif escaped == "u" then
				local hex = string.sub(text, index + 2, index + 5)
				local code = tonumber(hex, 16)
				if not code then
					return nil, index
				end
				if code < 128 then
					chunks[#chunks + 1] = string.char(code)
				elseif code < 2048 then
					chunks[#chunks + 1] = string.char(192 + math.floor(code / 64), 128 + (code % 64))
				else
					chunks[#chunks + 1] = string.char(
						224 + math.floor(code / 4096),
						128 + (math.floor(code / 64) % 64),
						128 + (code % 64)
					)
				end
				index = index + 6
			else
				return nil, index
			end
		end
	end
	return nil, index
end

local function decodeNumber(text, index)
	local raw = string.match(text, "^-?%d+%.?%d*[eE]?[+-]?%d*", index)
	if not raw then
		return nil, index
	end
	return tonumber(raw), index + #raw
end

local function decodeLiteral(text, index)
	if string.sub(text, index, index + 3) == "true" then
		return true, index + 4
	end
	if string.sub(text, index, index + 4) == "false" then
		return false, index + 5
	end
	if string.sub(text, index, index + 3) == "null" then
		return nil, index + 4
	end
	return nil, index
end

local function decodeArray(text, index)
	index = index + 1
	local values = {}
	index = skipWhitespace(text, index)
	if string.sub(text, index, index) == "]" then
		return values, index + 1
	end
	while index <= #text do
		local value
		value, index = decodeValue(text, index)
		if index == nil then
			return nil, nil
		end
		values[#values + 1] = value
		index = skipWhitespace(text, index)
		local char = string.sub(text, index, index)
		if char == "]" then
			return values, index + 1
		end
		if char ~= "," then
			return nil, nil
		end
		index = skipWhitespace(text, index + 1)
	end
	return nil, nil
end

local function decodeObject(text, index)
	index = index + 1
	local object = {}
	index = skipWhitespace(text, index)
	if string.sub(text, index, index) == "}" then
		return object, index + 1
	end
	while index <= #text do
		index = skipWhitespace(text, index)
		if string.sub(text, index, index) ~= '"' then
			return nil, nil
		end
		local key
		key, index = decodeString(text, index)
		if not key then
			return nil, nil
		end
		index = skipWhitespace(text, index)
		if string.sub(text, index, index) ~= ":" then
			return nil, nil
		end
		local value
		value, index = decodeValue(text, skipWhitespace(text, index + 1))
		if index == nil then
			return nil, nil
		end
		object[key] = value
		index = skipWhitespace(text, index)
		local char = string.sub(text, index, index)
		if char == "}" then
			return object, index + 1
		end
		if char ~= "," then
			return nil, nil
		end
		index = index + 1
	end
	return nil, nil
end

decodeValue = function(text, index)
	index = skipWhitespace(text, index)
	local char = string.sub(text, index, index)
	if char == '"' then
		return decodeString(text, index)
	end
	if char == "{" then
		return decodeObject(text, index)
	end
	if char == "[" then
		return decodeArray(text, index)
	end
	if char == "-" or string.match(char, "%d") then
		return decodeNumber(text, index)
	end
	return decodeLiteral(text, index)
end

function json.decode(text)
	if type(text) ~= "string" or text == "" then
		return nil
	end
	local value, index = decodeValue(text, 1)
	if index == nil then
		return nil
	end
	index = skipWhitespace(text, index)
	if index <= #text then
		return nil
	end
	return value
end

return json
