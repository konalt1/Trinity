if NeutralStackReward == nil then
	NeutralStackReward = {}
end

-- Стак нейтралов в Trinity.
--
-- Стак определяет движок: когда лагерь застакан, он вешает modifier_stacked_neutral
-- на каждого крипа новой волны и указывает кастера (стакающего героя).
-- Мы перехватываем этот бафф в GameMode:ModifierGainedFilter, блокируем его,
-- собираем крипов волны в группу по кастеру и выдаём награду одной выплатой.
--
-- Награда: суммарное золото и опыт за убийство крипов новой волны, умноженные
-- на STACK_GOLD_SHARE / STACK_XP_SHARE.
--
-- Кому: кастер баффа; если его нет — первый агрессор крипов группы
-- (приказ атаки/каста или урон за последние AGGRO_MEMORY_SECONDS); иначе ближайший герой.

-- Доля от суммарной награды заспавнившихся крипов, которую получает стакающий.
local STACK_GOLD_SHARE = 0.3
local STACK_XP_SHARE = 0.3

local STACK_MODIFIER = "modifier_stacked_neutral"

-- Ждём, пока бафф получат все крипы волны, перед выплатой.
local GROUP_DELAY = 0.3
-- Крипы одной волны в группе без кастера: не дальше этого друг от друга.
local GROUP_RADIUS = 800
-- Сколько помним первого агрессора.
local AGGRO_MEMORY_SECONDS = 30
local FALLBACK_HERO_RADIUS = 1800
local SWEEP_INTERVAL = 0.5

-- Отладка (переключается в игре, см. раздел "Отладка" внизу файла):
--   DEBUG_CHAT    — итог каждого стака дублируется в чат;
--   DEBUG_VERBOSE — в консоль: каждый перехваченный бафф и каждый агр.
-- По умолчанию только в Workshop Tools: на плейтесте 2026-10-03 игроки видели отладку в чате союзников.
-- В обычной игре включается командой «-stack debug 1» (нужен sv_cheats).
local IN_TOOLS = IsInToolsMode ~= nil and IsInToolsMode() or false
local DEBUG_CHAT = IN_TOOLS
local DEBUG_VERBOSE = IN_TOOLS

NeutralStackReward.debug = NeutralStackReward.debug or { chat = DEBUG_CHAT, verbose = DEBUG_VERBOSE }
NeutralStackReward.stats = NeutralStackReward.stats or {}

local function IsValid(unit)
	return unit ~= nil and not unit:IsNull()
end

local function Chat(text)
	if GameRules and GameRules.SendCustomMessage then
		GameRules:SendCustomMessage(text, 0, 0)
	end
end

local function Log(fmt, ...)
	local text = "[NeutralStack] " .. string.format(fmt, ...)
	print(text)
	if NeutralStackReward.debug.chat then
		Chat(text)
	end
end

local function Verbose(fmt, ...)
	if not NeutralStackReward.debug.verbose then
		return
	end
	print("[NeutralStack:v] " .. string.format(fmt, ...))
end

local function Stat(name, delta)
	local stats = NeutralStackReward.stats
	stats[name] = (stats[name] or 0) + (delta or 1)
end

local function UnitLabel(unit)
	if not IsValid(unit) then
		return "nil"
	end
	return string.format("%s#%d", tostring(unit:GetUnitName()), unit:entindex())
end

local function Now()
	return GameRules:GetGameTime()
end

local function Round(value)
	return math.floor(value + 0.5)
end

-- ---------------------------------------------------------------------------
-- Юниты
-- ---------------------------------------------------------------------------

function NeutralStackReward:ResolveHero(unit)
	if not IsValid(unit) then
		return nil
	end
	if unit.IsRealHero and unit:IsRealHero() and not (unit.IsIllusion and unit:IsIllusion()) then
		return unit
	end

	local playerID = -1
	if unit.GetPlayerOwnerID then
		playerID = unit:GetPlayerOwnerID()
	end
	if playerID == nil or playerID < 0 or not PlayerResource or not PlayerResource:IsValidPlayerID(playerID) then
		return nil
	end

	local hero = PlayerResource:GetSelectedHeroEntity(playerID)
	if IsValid(hero) and hero:IsRealHero() and not hero:IsIllusion() then
		return hero
	end
	return nil
end

-- Награда за убийство одного крипа: среднее золото и опыт.
function NeutralStackReward:CreepBounty(unit)
	local gold = 0
	if unit.GetMinimumGoldBounty and unit.GetMaximumGoldBounty then
		gold = ((unit:GetMinimumGoldBounty() or 0) + (unit:GetMaximumGoldBounty() or 0)) * 0.5
	elseif unit.GetGoldBounty then
		gold = unit:GetGoldBounty() or 0
	end
	local xp = unit.GetDeathXP and unit:GetDeathXP() or 0
	return gold, xp
end

-- ---------------------------------------------------------------------------
-- Агр (запасной способ найти стакающего)
-- ---------------------------------------------------------------------------

function NeutralStackReward:MarkAggro(creep, hero, source)
	if not hero or not IsValid(creep) or creep:GetTeamNumber() ~= DOTA_TEAM_NEUTRALS then
		return
	end
	local now = Now()
	local record = creep._trinityStackAggro
	if record and IsValid(record.hero) and now - record.last <= AGGRO_MEMORY_SECONDS then
		record.last = now
		return
	end
	creep._trinityStackAggro = { hero = hero, first = now, last = now, source = source }
	Stat("aggro_" .. tostring(source))
	Verbose("aggro %s by %s (%s)", UnitLabel(creep), hero:GetUnitName(), tostring(source))
end

function NeutralStackReward:OnOrder(data)
	if not data or not data.entindex_target or data.entindex_target == 0 then
		return
	end
	local orderType = data.order_type
	if orderType ~= DOTA_UNIT_ORDER_ATTACK_TARGET and orderType ~= DOTA_UNIT_ORDER_CAST_TARGET then
		return
	end

	local target = EntIndexToHScript(data.entindex_target)
	if not IsValid(target) or target:GetTeamNumber() ~= DOTA_TEAM_NEUTRALS then
		return
	end

	local hero = nil
	if data.units then
		for _, entindex in pairs(data.units) do
			hero = self:ResolveHero(EntIndexToHScript(entindex))
			if hero then
				break
			end
		end
	end
	if not hero and data.issuer_player_id_const and PlayerResource then
		hero = self:ResolveHero(PlayerResource:GetSelectedHeroEntity(data.issuer_player_id_const))
	end
	self:MarkAggro(target, hero, orderType == DOTA_UNIT_ORDER_ATTACK_TARGET and "attack_order" or "cast_order")
end

function NeutralStackReward:OnEntityHurt(keys)
	if not keys or not keys.entindex_killed or not keys.entindex_attacker then
		return
	end
	local victim = EntIndexToHScript(keys.entindex_killed)
	if not IsValid(victim) or victim:GetTeamNumber() ~= DOTA_TEAM_NEUTRALS then
		return
	end
	self:MarkAggro(victim, self:ResolveHero(EntIndexToHScript(keys.entindex_attacker)), "damage")
end

-- ---------------------------------------------------------------------------
-- Стак по ванильному баффу
-- ---------------------------------------------------------------------------

function NeutralStackReward:ModifierGainedFilter(data)
	if not data or data.name_const ~= STACK_MODIFIER then
		return true
	end
	local unit = data.entindex_parent_const and EntIndexToHScript(data.entindex_parent_const) or nil
	local caster = data.entindex_caster_const and EntIndexToHScript(data.entindex_caster_const) or nil
	Stat("vanilla_blocked")
	Verbose("blocked %s on %s, caster %s", STACK_MODIFIER, UnitLabel(unit), UnitLabel(caster))
	if IsValid(unit) then
		self:AddToGroup(unit, self:ResolveHero(caster))
	end
	return false
end

-- Крипы одной волны собираются в группу: по герою-кастеру, а без кастера — по месту.
function NeutralStackReward:AddToGroup(unit, hero)
	if unit._trinityStackPaid then
		return
	end
	local position = unit:GetAbsOrigin()
	local group = nil
	for _, candidate in ipairs(self._groups) do
		if candidate.hero == hero and (candidate.origin - position):Length2D() <= GROUP_RADIUS then
			group = candidate
			break
		end
	end

	if not group then
		group = { hero = hero, origin = position, units = {}, seen = {} }
		table.insert(self._groups, group)
		Timers:CreateTimer(GROUP_DELAY, function()
			for index, entry in ipairs(NeutralStackReward._groups) do
				if entry == group then
					table.remove(NeutralStackReward._groups, index)
					break
				end
			end
			NeutralStackReward:PayGroup(group)
		end)
	end

	local index = unit:entindex()
	if not group.seen[index] then
		group.seen[index] = true
		table.insert(group.units, unit)
	end
end

function NeutralStackReward:FindFallbackHero(units)
	local now = Now()
	local best = nil
	for _, unit in ipairs(units) do
		local aggro = IsValid(unit) and unit._trinityStackAggro or nil
		if aggro and IsValid(aggro.hero) and now - aggro.last <= AGGRO_MEMORY_SECONDS + 10 then
			if not best or aggro.first < best.first then
				best = aggro
			end
		end
	end
	if best then
		return best.hero, "aggro:" .. tostring(best.source)
	end

	local anchor = nil
	for _, unit in ipairs(units) do
		if IsValid(unit) then
			anchor = unit:GetAbsOrigin()
			break
		end
	end
	if not anchor then
		return nil, nil
	end
	local heroes = FindUnitsInRadius(
		DOTA_TEAM_NEUTRALS,
		anchor,
		nil,
		FALLBACK_HERO_RADIUS,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO,
		DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_NOT_ILLUSIONS,
		FIND_CLOSEST,
		false
	)
	for _, unit in ipairs(heroes) do
		local hero = self:ResolveHero(unit)
		if hero then
			return hero, "nearest"
		end
	end
	return nil, nil
end

function NeutralStackReward:RewardFor(units)
	local totalGold, totalXP = 0, 0
	for _, unit in ipairs(units) do
		if IsValid(unit) then
			local gold, xp = self:CreepBounty(unit)
			totalGold = totalGold + gold
			totalXP = totalXP + xp
		end
	end
	return {
		gold = Round(totalGold * STACK_GOLD_SHARE),
		xp = Round(totalXP * STACK_XP_SHARE),
		totalGold = totalGold,
		totalXP = totalXP,
	}
end

function NeutralStackReward:PayGroup(group)
	local units = {}
	local names = {}
	for _, unit in ipairs(group.units) do
		if IsValid(unit) and not unit._trinityStackPaid then
			unit._trinityStackPaid = true
			table.insert(units, unit)
			table.insert(names, UnitLabel(unit))
		end
	end
	if #units == 0 then
		return
	end
	Stat("stacks_detected")
	self:RegisterWave(group.origin, units)

	local hero, source = group.hero, "vanilla_caster"
	if not IsValid(hero) then
		hero, source = self:FindFallbackHero(units)
	end
	local reward = self:RewardFor(units)
	local where = string.format("(%d, %d)", group.origin.x, group.origin.y)

	if not hero then
		Stat("stacks_no_hero")
		Log("stack at %s: no hero found, skip (would be +%d gold +%d xp)", where, reward.gold, reward.xp)
		return
	end
	if reward.gold <= 0 and reward.xp <= 0 then
		Stat("stacks_zero_reward")
		Log("stack at %s by %s: new creeps have no bounty (%d creeps)", where, hero:GetUnitName(), #units)
		return
	end

	Stat("stacks_paid")
	self:Grant(hero, reward)
	Verbose("stack at %s creeps: %s", where, table.concat(names, ", "))
	Log(
		"stack at %s -> %s +%d gold +%d xp (%d new creeps worth %.0f gold / %.0f xp, share %d%%/%d%%, %s)",
		where,
		hero:GetUnitName(),
		reward.gold,
		reward.xp,
		#units,
		reward.totalGold,
		reward.totalXP,
		Round(STACK_GOLD_SHARE * 100),
		Round(STACK_XP_SHARE * 100),
		tostring(source)
	)
end

function NeutralStackReward:Grant(hero, reward)
	local player = hero:GetPlayerOwner()
	if reward.gold > 0 then
		hero:ModifyGold(reward.gold, false, DOTA_ModifyGold_Unspecified)
		SendOverheadEventMessage(player, OVERHEAD_ALERT_GOLD, hero, reward.gold, nil)
	end
	if reward.xp > 0 then
		hero:AddExperience(reward.xp, DOTA_ModifyXP_Unspecified, false, true)
		SendOverheadEventMessage(player, OVERHEAD_ALERT_XP or 3, hero, reward.xp, nil)
	end
end

-- Страховка: если бафф всё же повис (фильтр не сработал), снимаем его и платим.
function NeutralStackReward:Sweep()
	local units = FindUnitsInRadius(
		DOTA_TEAM_NEUTRALS,
		Vector(0, 0, 0),
		nil,
		FIND_UNITS_EVERYWHERE,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY,
		DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_OUT_OF_WORLD,
		FIND_ANY_ORDER,
		false
	)
	for _, unit in ipairs(units) do
		local modifier = unit:FindModifierByName(STACK_MODIFIER)
		if modifier then
			local caster = modifier.GetCaster and modifier:GetCaster() or nil
			unit:RemoveModifierByName(STACK_MODIFIER)
			Stat("vanilla_swept")
			Verbose("swept %s from %s, caster %s", STACK_MODIFIER, UnitLabel(unit), UnitLabel(caster))
			self:AddToGroup(unit, self:ResolveHero(caster))
		end
	end
end

-- ---------------------------------------------------------------------------
-- Шум застаканного лагеря
--
-- Каждая застаканная волна запоминается. Волна жива, пока жив хотя бы один её крип
-- (и он всё ещё нейтрал). Волны с точками появления ближе NOISE_CAMP_RADIUS — один лагерь.
-- Лагерь шумит уже с NOISE_MIN_STACKS (1) стака: толпа гудит тихо, с каждым стаком громче.
--
-- Звук трёхмерный и звучит в точке лагеря. Он отправляется каждому игроку
-- (EmitSoundOnLocationForPlayer), поэтому не зависит от тумана войны и положения героя:
-- громкость определяет только расстояние от камеры игрока до лагеря.
--
-- Клип нарезан на куски по 8 сек с вшитыми затуханиями 2 сек
-- (content/sounds/stacked_camp/crowd_01..08.mp3). Каждые NOISE_INTERVAL сек
-- запускается новый случайный кусок, соседние куски плавно перекрываются.
-- Куски по очереди идут через CrowdN и CrowdN.Alt: новый экземпляр того же события
-- может оборвать предыдущий, пока тот ещё затухает.
-- Смена числа стаков вступает в силу со следующего куска, после зачистки лагеря
-- последний кусок плавно затихает. Громкость ступеней — в
-- soundevents/Trinity_sounds.vsndevts (Trinity.StackedCamp.CrowdN).
-- ---------------------------------------------------------------------------

local NOISE_MIN_STACKS = 1
local NOISE_CAMP_RADIUS = 600
local NOISE_THINK = 0.25
-- Длина куска 8 сек, затухания по 2 сек: новый кусок через 6 сек.
local NOISE_INTERVAL = 6
-- Индекс = число стаков; больше последнего — последняя (самая громкая) ступень.
local NOISE_LEVELS = {
	"Trinity.StackedCamp.Crowd1",
	"Trinity.StackedCamp.Crowd2",
	"Trinity.StackedCamp.Crowd3",
	"Trinity.StackedCamp.Crowd4",
	"Trinity.StackedCamp.Crowd5",
	"Trinity.StackedCamp.Crowd6",
}

function NeutralStackReward:RegisterWave(origin, units)
	table.insert(self._waves, { origin = origin, units = units })
end

local function WaveAlive(wave)
	for _, unit in ipairs(wave.units) do
		if IsValid(unit) and unit:IsAlive() and unit:GetTeamNumber() == DOTA_TEAM_NEUTRALS then
			return true
		end
	end
	return false
end

local function NoiseSound(stacks)
	if stacks < NOISE_MIN_STACKS then
		return nil
	end
	return NOISE_LEVELS[math.min(stacks, #NOISE_LEVELS)]
end

-- Живые волны, сгруппированные по лагерям.
function NeutralStackReward:NoisyCamps()
	local alive = {}
	for _, wave in ipairs(self._waves) do
		if WaveAlive(wave) then
			table.insert(alive, wave)
		end
	end
	self._waves = alive

	local camps = {}
	for _, wave in ipairs(alive) do
		local camp = nil
		for _, candidate in ipairs(camps) do
			if (candidate.origin - wave.origin):Length2D() <= NOISE_CAMP_RADIUS then
				camp = candidate
				break
			end
		end
		if not camp then
			camp = { origin = wave.origin, stacks = 0 }
			table.insert(camps, camp)
		end
		camp.stacks = camp.stacks + 1
	end
	return camps
end

-- Звук в точке для каждого игрока: слышен независимо от тумана и героя,
-- громкость движок считает от камеры.
function NeutralStackReward:EmitNoise(origin, sound)
	if not PlayerResource then
		return 0
	end
	local heard = 0
	for playerID = 0, 23 do
		if PlayerResource:IsValidPlayerID(playerID) then
			EmitSoundOnLocationForPlayer(sound, origin, playerID)
			heard = heard + 1
		end
	end
	return heard
end

-- Состояние шума хранится по ключу лагеря (округлённая точка), чтобы не терять таймер.
function NeutralStackReward:NoiseThink()
	local now = Now()
	local state = {}
	for _, camp in ipairs(self:NoisyCamps()) do
		local key = string.format("%d:%d", Round(camp.origin.x / 100), Round(camp.origin.y / 100))
		local previous = self._noise[key]
		local sound = NoiseSound(camp.stacks)
		if sound then
			local entry = previous or { next = now }
			if not previous or previous.stacks ~= camp.stacks then
				Log("camp at (%d, %d) noise: %d stacks -> %s", camp.origin.x, camp.origin.y, camp.stacks, sound)
			end
			if now >= (entry.next or now) then
				entry.alt = not entry.alt
				if entry.alt then
					sound = sound .. ".Alt"
				end
				local heard = self:EmitNoise(camp.origin, sound)
				Verbose("noise %s at (%d, %d): %d stacks, players %d", sound, camp.origin.x, camp.origin.y, camp.stacks, heard)
				entry.next = now + NOISE_INTERVAL
			end
			entry.stacks = camp.stacks
			state[key] = entry
		end
	end
	for key in pairs(self._noise) do
		if not state[key] then
			Log("camp %s is quiet again", key)
		end
	end
	self._noise = state
end

-- ---------------------------------------------------------------------------
-- Инициализация
-- ---------------------------------------------------------------------------

function NeutralStackReward:Init()
	if self._initialized then
		return
	end
	self._initialized = true
	self._groups = self._groups or {}
	self._waves = self._waves or {}
	self._noise = self._noise or {}

	Timers:CreateTimer(NOISE_THINK, function()
		local ok, err = pcall(NeutralStackReward.NoiseThink, NeutralStackReward)
		if not ok then
			print("[NeutralStack] noise think failed: " .. tostring(err))
		end
		return NOISE_THINK
	end)

	ListenToGameEvent("entity_hurt", function(keys)
		NeutralStackReward:OnEntityHurt(keys)
	end, nil)

	Timers:CreateTimer(SWEEP_INTERVAL, function()
		NeutralStackReward:Sweep()
		return SWEEP_INTERVAL
	end)

	self:RegisterDebugCommands()
	print("[NeutralStack] initialized (debug chat=" .. tostring(self.debug.chat) .. ", verbose=" .. tostring(self.debug.verbose) .. "). Commands: trinity_stack_help")
end

-- ---------------------------------------------------------------------------
-- Отладка
--
-- Консоль (или чат: "-stack <команда> [аргумент]", только в Tools mode / sv_cheats):
--   trinity_stack_help            список команд
--   trinity_stack_debug [0|1]     итог стаков в чат вкл/выкл
--   trinity_stack_verbose [0|1]   подробный лог: перехваченные баффы, агры
--   trinity_stack_status          счётчики и состояние модуля
--   trinity_stack_creeps [радиус] нейтралы рядом с героем и их баунти
--   trinity_stack_noise           шумящие лагеря и играющие звуки
--   trinity_stack_noisetest [N]   кусок шума для N стаков в точке героя (8 сек)
--   trinity_stack_test [радиус]   выдать своему герою награду как за стак нейтралов рядом
-- ---------------------------------------------------------------------------

local function DebugAllowed()
	if IsInToolsMode and IsInToolsMode() then
		return true
	end
	if GameRules and GameRules.IsCheatMode and GameRules:IsCheatMode() then
		return true
	end
	return false
end

function NeutralStackReward:DebugOut(ctx, fmt, ...)
	local text = "[NeutralStack] " .. string.format(fmt, ...)
	print(text)
	if ctx and ctx.chat then
		Chat(text)
	end
end

function NeutralStackReward:DebugHero(ctx)
	local playerID = ctx and ctx.playerID
	if playerID == nil or playerID < 0 then
		local player = Convars and Convars.GetCommandClient and Convars:GetCommandClient() or nil
		if player and player.GetPlayerID then
			playerID = player:GetPlayerID()
		end
	end
	if (playerID == nil or playerID < 0) and PlayerResource then
		for id = 0, 23 do
			if PlayerResource:IsValidPlayerID(id) and PlayerResource:GetSelectedHeroEntity(id) then
				playerID = id
				break
			end
		end
	end
	if playerID == nil or playerID < 0 or not PlayerResource then
		return nil
	end
	return self:ResolveHero(PlayerResource:GetSelectedHeroEntity(playerID))
end

function NeutralStackReward:DebugNeutralsNear(hero, radius)
	return FindUnitsInRadius(
		DOTA_TEAM_NEUTRALS,
		hero:GetAbsOrigin(),
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY,
		DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_INVULNERABLE,
		FIND_CLOSEST,
		false
	)
end

local function ParseToggle(value, current)
	if value == nil or value == "" then
		return not current
	end
	return value == "1" or value == "on" or value == "true"
end

NeutralStackReward.DebugCommands = {}
local Commands = NeutralStackReward.DebugCommands

Commands.help = function(self, ctx)
	self:DebugOut(ctx, "commands: debug [0|1], verbose [0|1], status, creeps [radius], noise, noisetest [stacks], test [radius]")
	self:DebugOut(ctx, "console: trinity_stack_<command>; chat: -stack <command>. dota_spawn_neutrals spawns camps now (cheats).")
	self:DebugOut(ctx, "stack = engine's %s on the new wave; reward = %d%% gold / %d%% xp of that wave's bounty",
		STACK_MODIFIER, Round(STACK_GOLD_SHARE * 100), Round(STACK_XP_SHARE * 100))
end

Commands.debug = function(self, ctx, arg)
	self.debug.chat = ParseToggle(arg, self.debug.chat)
	self:DebugOut(ctx, "chat output: %s", tostring(self.debug.chat))
end

Commands.verbose = function(self, ctx, arg)
	self.debug.verbose = ParseToggle(arg, self.debug.verbose)
	self:DebugOut(ctx, "verbose: %s", tostring(self.debug.verbose))
end

Commands.status = function(self, ctx)
	self:DebugOut(ctx, "init=%s time=%.1f dota_time=%.1f chat=%s verbose=%s share=%d%%/%d%% pending groups=%d",
		tostring(self._initialized), Now(), GameRules:GetDOTATime(false, false),
		tostring(self.debug.chat), tostring(self.debug.verbose),
		Round(STACK_GOLD_SHARE * 100), Round(STACK_XP_SHARE * 100), #(self._groups or {}))

	local keys = {}
	for key in pairs(self.stats) do
		table.insert(keys, key)
	end
	table.sort(keys)
	local parts = {}
	for _, key in ipairs(keys) do
		table.insert(parts, key .. "=" .. tostring(self.stats[key]))
	end
	self:DebugOut(ctx, "stats: %s", #parts > 0 and table.concat(parts, ", ") or "(empty)")
end

Commands.creeps = function(self, ctx, arg)
	local hero = self:DebugHero(ctx)
	if not hero then
		self:DebugOut(ctx, "creeps: no hero")
		return
	end
	local radius = tonumber(arg) or 1500
	local now = Now()
	local units = self:DebugNeutralsNear(hero, radius)
	for _, unit in ipairs(units) do
		local gold, xp = self:CreepBounty(unit)
		local aggro = unit._trinityStackAggro
		self:DebugOut(ctx, "%s bounty=%.0fg/%.0fxp aggro=%s paid=%s",
			UnitLabel(unit), gold, xp,
			aggro and string.format("%s via %s %.0fs ago", IsValid(aggro.hero) and aggro.hero:GetUnitName() or "?",
				tostring(aggro.source), now - aggro.first) or "none",
			tostring(unit._trinityStackPaid == true))
	end
	self:DebugOut(ctx, "neutrals shown %d (radius %d)", #units, radius)
end

Commands.noise = function(self, ctx)
	local camps = self:NoisyCamps()
	for _, camp in ipairs(camps) do
		local sound = NoiseSound(camp.stacks)
		self:DebugOut(ctx, "camp (%d, %d): %d stacks alive, %s", camp.origin.x, camp.origin.y, camp.stacks,
			sound and ("NOISY " .. sound) or "quiet")
	end
	self:DebugOut(ctx, "stacked camps: %d (noise from %d stack, every %ds, volume by camera distance)",
		#camps, NOISE_MIN_STACKS, NOISE_INTERVAL)
end

-- Послушать ступень громкости: noisetest <стаки 1..6> — один кусок (8 сек) в точке героя.
Commands.noisetest = function(self, ctx, arg)
	local hero = self:DebugHero(ctx)
	if not hero then
		self:DebugOut(ctx, "noisetest: no hero")
		return
	end
	local stacks = math.max(1, tonumber(arg) or 1)
	local sound = NoiseSound(stacks)
	self:EmitNoise(hero:GetAbsOrigin(), sound)
	self:DebugOut(ctx, "noisetest: %s (%d stacks) at %s", sound, stacks, hero:GetUnitName())
end

Commands.test = function(self, ctx, arg)
	if not DebugAllowed() then
		self:DebugOut(ctx, "test: only in Tools mode or with sv_cheats")
		return
	end
	local hero = self:DebugHero(ctx)
	if not hero then
		self:DebugOut(ctx, "test: no hero")
		return
	end
	local units = self:DebugNeutralsNear(hero, tonumber(arg) or 800)
	local reward = self:RewardFor(units)
	if reward.gold <= 0 and reward.xp <= 0 then
		reward = { gold = 50, xp = 50, totalGold = 0, totalXP = 0 }
	end
	local goldBefore = PlayerResource:GetGold(hero:GetPlayerOwnerID())
	local xpBefore = hero:GetCurrentXP()
	self:Grant(hero, reward)
	self:DebugOut(ctx, "test: %d neutrals, %s gold %d -> %d, xp %d -> %d",
		#units, hero:GetUnitName(), goldBefore, PlayerResource:GetGold(hero:GetPlayerOwnerID()),
		xpBefore, hero:GetCurrentXP())
end

function NeutralStackReward:RunDebugCommand(ctx, name, arg)
	local command = self.DebugCommands[name or "help"]
	if not command then
		self:DebugOut(ctx, "unknown command '%s'", tostring(name))
		command = self.DebugCommands.help
	end
	local ok, err = pcall(command, self, ctx, arg)
	if not ok then
		self:DebugOut(ctx, "command '%s' failed: %s", tostring(name), tostring(err))
	end
end

function NeutralStackReward:OnPlayerChat(keys)
	local text = keys and keys.text
	if type(text) ~= "string" then
		return
	end
	local name, arg = string.match(text, "^%-stack%s*(%S*)%s*(%S*)")
	if name == nil or not DebugAllowed() then
		return
	end
	if name == "" then
		name = "help"
	end
	self:RunDebugCommand({ chat = true, playerID = keys.playerid }, name, arg)
end

function NeutralStackReward:RegisterDebugCommands()
	if self._debugCommandsRegistered then
		return
	end
	self._debugCommandsRegistered = true

	for name in pairs(self.DebugCommands) do
		Convars:RegisterCommand("trinity_stack_" .. name, function(_, arg)
			NeutralStackReward:RunDebugCommand({ chat = false }, name, arg)
		end, "Trinity neutral stack debug: " .. name, 0)
	end

	ListenToGameEvent("player_chat", function(keys)
		NeutralStackReward:OnPlayerChat(keys)
	end, nil)
end

return NeutralStackReward
