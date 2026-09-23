-- Server Lua VM profiler: heap size, timers, entities, modifiers, heavy globals.
-- Console: trinity_lua_mem [0|1], trinity_lua_mem_gc, trinity_lua_mem_diff

if LuaMemoryDebug == nil then
	LuaMemoryDebug = {}
end

LuaMemoryDebug.WATCH_INTERVAL = 10
LuaMemoryDebug.TOP_N = 15
LuaMemoryDebug.MAX_DEPTH = 6
LuaMemoryDebug.MAX_NODES = 40000
LuaMemoryDebug.watchEnabled = LuaMemoryDebug.watchEnabled == true
LuaMemoryDebug.peakKb = LuaMemoryDebug.peakKb or 0

local WATCH_TIMER = "trinity_lua_mem_watch"

local SKIP_GLOBAL_KEYS = {
	_G = true,
	_VERSION = true,
	package = true,
	string = true,
	table = true,
	math = true,
	coroutine = true,
	debug = true,
	io = true,
	os = true,
	bit = true,
	jit = true,
}

local WATCH_TABLES = {
	{ "Timers.timers", function() return Timers and Timers.timers end },
	{ "UNIT_KV_CACHE", function() return _G.UNIT_KV_CACHE end },
	{ "package.loaded", function() return package and package.loaded end },
	{ "GameMode", function() return _G.GameMode end },
	{ "GameSettings", function() return _G.GameSettings end },
	{ "DraftSpawn", function() return _G.DraftSpawn end },
	{ "TrinityAnalytics", function() return _G.TrinityAnalytics end },
	{ "TrinityAnalytics.stats", function() return _G.TrinityAnalytics and TrinityAnalytics.stats end },
	{ "TrinityPlayerData", function() return _G.TrinityPlayerData end },
	{ "TrinityStickers", function() return _G.TrinityStickers end },
	{ "KillfeedSystem", function() return _G.KillfeedSystem end },
	{ "ChenBarrackGold", function() return _G.ChenBarrackGold end },
	{ "CHEN_BARRACK_REGISTRY", function() return _G.CHEN_BARRACK_REGISTRY end },
	{ "ChenBarrackHud", function() return _G.ChenBarrackHud end },
	{ "ChenBarrackProduction", function() return _G.ChenBarrackProduction end },
	{ "CourierCaravan", function() return _G.CourierCaravan end },
	{ "PrimalBeastBoss", function() return _G.PrimalBeastBoss end },
	{ "MortimerBoss", function() return _G.MortimerBoss end },
	{ "ItemDrop", function() return _G.ItemDrop end },
	{ "CreepBountyComeback", function() return _G.CreepBountyComeback end },
	{ "CustomAbilityTooltips", function() return _G.CustomAbilityTooltips end },
	{ "MIND_POWER_MODIFIER_REGISTRY", function() return _G.MIND_POWER_MODIFIER_REGISTRY end },
	{ "lich_spark_wraith_mana_data", function() return _G.lich_spark_wraith_mana_data end },
	{ "__cod_action_throttle_states", function() return _G.__cod_action_throttle_states end },
	{ "__cod_action_throttle_fallback_source", function() return _G.__cod_action_throttle_fallback_source end },
}

local function LuaKb()
	local kb = collectgarbage("count") or 0
	if kb > (LuaMemoryDebug.peakKb or 0) then
		LuaMemoryDebug.peakKb = kb
	end
	return kb
end

local function FormatMB(kb)
	return string.format("%.2f MB", (kb or 0) / 1024)
end

local function FormatBytes(bytes)
	bytes = bytes or 0
	if bytes >= 1048576 then
		return string.format("%.2f MB", bytes / 1048576)
	end
	if bytes >= 1024 then
		return string.format("%.1f KB", bytes / 1024)
	end
	return string.format("%d B", bytes)
end

local function FormatDeltaMB(kb)
	local sign = kb >= 0 and "+" or ""
	return sign .. string.format("%.2f MB", kb / 1024)
end

local function CountEntries(value)
	if type(value) ~= "table" then
		return 0
	end
	local n = 0
	for _ in pairs(value) do
		n = n + 1
	end
	return n
end

local function EstimateTable(root)
	local state = {
		bytes = 0,
		nodes = 0,
		truncated = false,
	}
	if type(root) ~= "table" then
		return state
	end

	local seen = { [_G] = true }
	local function Walk(value, depth)
		if state.nodes >= LuaMemoryDebug.MAX_NODES then
			state.truncated = true
			return
		end
		local valueType = type(value)
		if valueType == "nil" then
			return
		end
		if valueType == "boolean" or valueType == "number" then
			state.nodes = state.nodes + 1
			state.bytes = state.bytes + 16
			return
		end
		if valueType == "string" then
			state.nodes = state.nodes + 1
			state.bytes = state.bytes + 32 + #value
			return
		end
		if valueType == "function" or valueType == "userdata" or valueType == "thread" then
			state.nodes = state.nodes + 1
			state.bytes = state.bytes + 48
			return
		end
		if valueType ~= "table" then
			return
		end
		if seen[value] then
			return
		end
		seen[value] = true
		state.nodes = state.nodes + 1
		state.bytes = state.bytes + 64
		if depth >= LuaMemoryDebug.MAX_DEPTH then
			state.truncated = true
			return
		end
		for key, child in pairs(value) do
			state.bytes = state.bytes + 16
			Walk(key, depth + 1)
			Walk(child, depth + 1)
		end
	end

	Walk(root, 0)
	return state
end

local function SortedTop(counts, limit, valueKey)
	local items = {}
	for name, value in pairs(counts) do
		items[#items + 1] = { name = tostring(name), value = value }
	end
	table.sort(items, function(a, b)
		if a.value == b.value then
			return a.name < b.name
		end
		return a.value > b.value
	end)
	local result = {}
	local n = math.min(limit or LuaMemoryDebug.TOP_N, #items)
	for i = 1, n do
		result[i] = items[i]
	end
	return result, #items
end

local function PrintTop(title, counts, formatValue)
	local items, total = SortedTop(counts, LuaMemoryDebug.TOP_N)
	print(string.format("[LuaMem] -- %s (%d) --", title, total))
	if #items == 0 then
		print("[LuaMem]   (empty)")
		return
	end
	for i = 1, #items do
		local item = items[i]
		print(string.format("[LuaMem]   %10s  %s", formatValue(item.value), item.name))
	end
end

local function Alive(entity)
	return entity ~= nil and (not entity.IsNull or not entity:IsNull())
end

local function ForEachEntity(fn)
	if Entities == nil then
		return
	end
	if Entities.First and Entities.Next then
		local entity = Entities:First()
		while entity do
			if Alive(entity) then
				fn(entity)
			end
			entity = Entities:Next(entity)
		end
		return
	end
	if Entities.FindAllInSphere then
		local list = Entities:FindAllInSphere(Vector(0, 0, 0), 99999) or {}
		for _, entity in pairs(list) do
			if Alive(entity) then
				fn(entity)
			end
		end
	end
end

local function EachModifierName(unit, fn)
	if unit.GetModifierCount and unit.GetModifierNameByIndex then
		local count = unit:GetModifierCount() or 0
		for i = 0, count - 1 do
			local name = unit:GetModifierNameByIndex(i)
			if name and name ~= "" then
				fn(name)
			end
		end
		return
	end
	if not unit.FindAllModifiers then
		return
	end
	local modifiers = unit:FindAllModifiers() or {}
	for _, modifier in pairs(modifiers) do
		if modifier and (not modifier.IsNull or not modifier:IsNull()) and modifier.GetName then
			fn(modifier:GetName())
		end
	end
end

local function ShouldScanModifiers(entity, className)
	if entity.GetModifierCount == nil then
		return false
	end
	if entity.GetUnitName ~= nil then
		return true
	end
	return string.sub(className, 1, 4) == "npc_"
end

local function GameClock()
	if GameRules and GameRules.GetDOTATime then
		return tonumber(GameRules:GetDOTATime(false, false)) or 0
	end
	return 0
end

local function HostTimescale()
	if Convars and Convars.GetFloat then
		return tonumber(Convars:GetFloat("host_timescale")) or 1
	end
	return 1
end

function LuaMemoryDebug:CollectWorld()
	local data = {
		entities = 0,
		units = 0,
		thinkers = 0,
		modifiers = 0,
		classNames = {},
		unitNames = {},
		modifierNames = {},
	}

	ForEachEntity(function(entity)
		data.entities = data.entities + 1
		local className = "?"
		if entity.GetClassname then
			className = entity:GetClassname() or "?"
		end
		data.classNames[className] = (data.classNames[className] or 0) + 1
		if className == "npc_dota_thinker" then
			data.thinkers = data.thinkers + 1
		end

		local unitName = nil
		if entity.GetUnitName then
			unitName = entity:GetUnitName()
		end
		if unitName and unitName ~= "" then
			data.units = data.units + 1
			data.unitNames[unitName] = (data.unitNames[unitName] or 0) + 1
		end

		if ShouldScanModifiers(entity, className) then
			EachModifierName(entity, function(name)
				data.modifiers = data.modifiers + 1
				data.modifierNames[name] = (data.modifierNames[name] or 0) + 1
			end)
		end
	end)

	return data
end

function LuaMemoryDebug:TimerCount()
	return CountEntries(Timers and Timers.timers)
end

function LuaMemoryDebug:CollectGlobals()
	local rows = {}
	for i = 1, #WATCH_TABLES do
		local spec = WATCH_TABLES[i]
		local ok, value = pcall(spec[2])
		if ok and type(value) == "table" then
			local estimate = EstimateTable(value)
			rows[#rows + 1] = {
				name = spec[1],
				entries = CountEntries(value),
				bytes = estimate.bytes,
				truncated = estimate.truncated,
			}
		end
	end
	table.sort(rows, function(a, b)
		if a.bytes == b.bytes then
			return a.name < b.name
		end
		return a.bytes > b.bytes
	end)
	return rows
end

function LuaMemoryDebug:CollectGlobalKeySizes()
	local counts = {}
	for key, value in pairs(_G) do
		if type(key) == "string" and not SKIP_GLOBAL_KEYS[key] and type(value) == "table" then
			local estimate = EstimateTable(value)
			counts[key] = estimate.bytes
		end
	end
	return counts
end

function LuaMemoryDebug:LiteSnapshot()
	return {
		luaKb = LuaKb(),
		wall = Time and Time() or 0,
		game = GameClock(),
		timescale = HostTimescale(),
		timers = self:TimerCount(),
	}
end

function LuaMemoryDebug:PrintHeader(kind, luaKb)
	print(string.format(
		"[LuaMem] ===== %s lua=%s peak=%s wall=%.1f game=%.1f timescale=%.2f =====",
		kind,
		FormatMB(luaKb),
		FormatMB(self.peakKb),
		Time and Time() or 0,
		GameClock(),
		HostTimescale()
	))
end

function LuaMemoryDebug:PrintWorld(world)
	print(string.format(
		"[LuaMem] timers=%d ents=%d units=%d thinkers=%d mods=%d",
		self:TimerCount(),
		world.entities,
		world.units,
		world.thinkers,
		world.modifiers
	))
	PrintTop("classnames", world.classNames, tostring)
	PrintTop("unit names", world.unitNames, tostring)
	PrintTop("modifiers", world.modifierNames, tostring)
end

function LuaMemoryDebug:PrintGlobals(rows)
	print("[LuaMem] -- watched tables --")
	if #rows == 0 then
		print("[LuaMem]   (empty)")
		return
	end
	for i = 1, #rows do
		local row = rows[i]
		local mark = row.truncated and " ~" or ""
		print(string.format(
			"[LuaMem]   %10s  entries=%-6d  %s%s",
			FormatBytes(row.bytes),
			row.entries,
			row.name,
			mark
		))
	end
end

function LuaMemoryDebug:DumpHeavyGlobals()
	local rows = self:CollectGlobals()
	self:PrintGlobals(rows)
	PrintTop("_G tables by est. size", self:CollectGlobalKeySizes(), FormatBytes)
end

function LuaMemoryDebug:StoreFull(luaKb, world, globals)
	self.lastFull = {
		luaKb = luaKb,
		timers = self:TimerCount(),
		entities = world.entities,
		units = world.units,
		thinkers = world.thinkers,
		modifiers = world.modifiers,
		classNames = world.classNames,
		unitNames = world.unitNames,
		modifierNames = world.modifierNames,
		globals = {},
	}
	for i = 1, #globals do
		local row = globals[i]
		self.lastFull.globals[row.name] = row.bytes
	end
end

function LuaMemoryDebug:Dump(kind)
	local luaBefore = LuaKb()
	self:PrintHeader(kind or "dump", luaBefore)

	local world = self:CollectWorld()
	self:PrintWorld(world)

	local globals = self:CollectGlobals()
	self:PrintGlobals(globals)
	PrintTop("_G tables by est. size", self:CollectGlobalKeySizes(), FormatBytes)

	local luaAfter = LuaKb()
	print(string.format("[LuaMem] lua_after_dump=%s overhead=%s", FormatMB(luaAfter), FormatDeltaMB(luaAfter - luaBefore)))
	self:StoreFull(luaBefore, world, globals)
	self.lastLite = {
		luaKb = luaBefore,
		timers = self.lastFull.timers,
	}
end

local function DiffMap(title, before, after, formatValue)
	local grew = {}
	after = after or {}
	before = before or {}
	for name, value in pairs(after) do
		local delta = (value or 0) - (before[name] or 0)
		if delta > 0 then
			grew[name] = delta
		end
	end
	PrintTop(title .. " grew", grew, formatValue)
end

function LuaMemoryDebug:Diff()
	local previous = self.lastFull
	if previous == nil then
		print("[LuaMem] no previous dump; take trinity_lua_mem first")
		self:Dump("dump")
		return
	end

	local luaNow = LuaKb()
	self:PrintHeader("diff", luaNow)
	print(string.format(
		"[LuaMem] lua %s -> %s (%s)",
		FormatMB(previous.luaKb),
		FormatMB(luaNow),
		FormatDeltaMB(luaNow - previous.luaKb)
	))

	local world = self:CollectWorld()
	print(string.format(
		"[LuaMem] timers %d -> %d | ents %d -> %d | units %d -> %d | thinkers %d -> %d | mods %d -> %d",
		previous.timers, self:TimerCount(),
		previous.entities, world.entities,
		previous.units, world.units,
		previous.thinkers, world.thinkers,
		previous.modifiers, world.modifiers
	))
	DiffMap("classnames", previous.classNames, world.classNames, tostring)
	DiffMap("unit names", previous.unitNames, world.unitNames, tostring)
	DiffMap("modifiers", previous.modifierNames, world.modifierNames, tostring)

	local globals = self:CollectGlobals()
	local grewGlobals = {}
	for i = 1, #globals do
		local row = globals[i]
		local delta = row.bytes - (previous.globals[row.name] or 0)
		if delta > 0 then
			grewGlobals[row.name] = delta
		end
	end
	PrintTop("watched tables grew", grewGlobals, FormatBytes)
	self:StoreFull(luaNow, world, globals)
end

function LuaMemoryDebug:CollectAndPrintLite()
	local snap = self:LiteSnapshot()
	local previous = self.lastLite
	local deltaKb = 0
	if previous then
		deltaKb = snap.luaKb - previous.luaKb
	end
	print(string.format(
		"[LuaMem] wall=%.1f game=%.1f ts=%.2f lua=%s peak=%s d=%s timers=%d",
		snap.wall,
		snap.game,
		snap.timescale,
		FormatMB(snap.luaKb),
		FormatMB(self.peakKb),
		FormatDeltaMB(deltaKb),
		snap.timers
	))
	self.lastLite = snap
	return snap
end

function LuaMemoryDebug:WatchTick()
	if not self.watchEnabled then
		return nil
	end
	self:CollectAndPrintLite()
	return self.WATCH_INTERVAL
end

function LuaMemoryDebug:StartWatch()
	self.watchEnabled = true
	print("[LuaMem] watch ON every " .. tostring(self.WATCH_INTERVAL) .. "s wall-clock (lua+timers only; trinity_lua_mem for full dump)")
	self:CollectAndPrintLite()
	if Timers and Timers.CreateTimer then
		Timers:CreateTimer(WATCH_TIMER, {
			useGameTime = false,
			endTime = self.WATCH_INTERVAL,
			persist = true,
			callback = function()
				if LuaMemoryDebug and LuaMemoryDebug.WatchTick then
					return LuaMemoryDebug:WatchTick()
				end
				return LuaMemoryDebug.WATCH_INTERVAL
			end,
		})
	end
end

function LuaMemoryDebug:StopWatch()
	self.watchEnabled = false
	if Timers and Timers.RemoveTimer then
		Timers:RemoveTimer(WATCH_TIMER)
	end
	print("[LuaMem] watch OFF")
end

function LuaMemoryDebug:OnMemCommand(value)
	if value == nil or value == "" then
		self:Dump("dump")
		return
	end
	local normalized = string.lower(tostring(value))
	if normalized == "1" or normalized == "true" or normalized == "on" then
		self:StartWatch()
		return
	end
	if normalized == "0" or normalized == "false" or normalized == "off" then
		self:StopWatch()
		return
	end
	print("[LuaMem] usage: trinity_lua_mem [0|1]")
end

function LuaMemoryDebug:CollectGarbage()
	local before = LuaKb()
	collectgarbage("collect")
	local after = LuaKb()
	print(string.format(
		"[LuaMem] gc %s -> %s (%s)",
		FormatMB(before),
		FormatMB(after),
		FormatDeltaMB(after - before)
	))
	self:Dump("after gc")
end

local function RegisterCommands()
	if _G.TRINITY_LUA_MEM_COMMANDS_REGISTERED then
		return
	end
	_G.TRINITY_LUA_MEM_COMMANDS_REGISTERED = true

	Convars:RegisterCommand("trinity_lua_mem", function(_, value)
		if LuaMemoryDebug and LuaMemoryDebug.OnMemCommand then
			LuaMemoryDebug:OnMemCommand(value)
		end
	end, "Lua VM dump, or watch: trinity_lua_mem [0|1]", FCVAR_CHEAT)

	Convars:RegisterCommand("trinity_lua_mem_gc", function()
		if LuaMemoryDebug and LuaMemoryDebug.CollectGarbage then
			LuaMemoryDebug:CollectGarbage()
		end
	end, "Force Lua GC and dump VM usage", FCVAR_CHEAT)

	Convars:RegisterCommand("trinity_lua_mem_diff", function()
		if LuaMemoryDebug and LuaMemoryDebug.Diff then
			LuaMemoryDebug:Diff()
		end
	end, "Diff Lua VM usage against the last dump", FCVAR_CHEAT)
end

function LuaMemoryDebug.Init()
	if not IsServer() then
		return
	end
	RegisterCommands()
	if LuaMemoryDebug.watchEnabled then
		LuaMemoryDebug:StartWatch()
	end
end

if IsServer() then
	RegisterCommands()
end
