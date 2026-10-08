BuybackStatues = BuybackStatues or {}

local MODIFIER_NAME = "modifier_trinity_buyback_statue"
local FROZEN_MODIFIER = "modifier_trinity_buyback_statue_frozen"
local STONE_MODIFIER = "modifier_trinity_buyback_statue_stone"
local STONE_EFFECT = "particles/status_fx/status_effect_medusa_stone_gaze.vpcf"
local REPAIR_PARTICLE = "particles/items5_fx/repair_kit.vpcf"
local REPAIR_RING_PARTICLE = "particles/generic_gameplay/launchpad_progress_ring.vpcf"
local LEGACY_BUILDING = "npc_trinity_buyback_statue"
local STATUE_CODE_VERSION = 4
-- Приоритет статус-эффекта камня. Энумы MODIFIER_PRIORITY_* (0..4) ниже, чем у ванильных
-- статус-эффектов (в т.ч. у эффекта иллюзии), поэтому камень перебивался. Берём заведомо больше.
local STONE_EFFECT_PRIORITY = 1000
local STATUE_HEALTH = 1000
local STATUE_ARMOR = 5
-- Фиксированный откат байбека: столько чинится статуя после байбека или уничтожения.
-- Берётся из Game_settings.lua (CUSTOM_BUYBACK_COOLDOWN), тот же кулдаун ставит движок после байбека.
local BUYBACK_COOLDOWN = tonumber(CUSTOM_BUYBACK_COOLDOWN) or 60
-- Сразу после спавна модель ещё в bind-позе.
local POSE_DELAY = 0.4
local ILLUSION_DURATION = 36000

LinkLuaModifier(MODIFIER_NAME, "game_managers/buyback_statues", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier(FROZEN_MODIFIER, "game_managers/buyback_statues", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier(STONE_MODIFIER, "game_managers/buyback_statues", LUA_MODIFIER_MOTION_NONE)

local KEEP_MODIFIERS = {
	[MODIFIER_NAME] = true,
	[FROZEN_MODIFIER] = true,
	[STONE_MODIFIER] = true,
}

local function IsAliveEntity(entity)
	return entity and not entity:IsNull()
end

-- Движок хранит кулдаун байбека как игровое время его окончания (GameRules:GetGameTime()),
-- а не как оставшиеся секунды. Снаружи эти функции работают с оставшимися секундами.
local function SetBuybackCooldown(playerID, hero, remaining)
	local value = 0
	if remaining and remaining > 0 then
		value = GameRules:GetGameTime() + remaining
	end
	if IsAliveEntity(hero) and hero.SetBuybackCooldownTime then
		hero:SetBuybackCooldownTime(value)
	end
	if PlayerResource.SetBuybackCooldownTime then
		PlayerResource:SetBuybackCooldownTime(playerID, value)
	end
end

local function GetBuybackCooldownRaw(hero)
	if not IsAliveEntity(hero) or not hero.GetBuybackCooldownTime then
		return 0
	end
	return hero:GetBuybackCooldownTime() or 0
end

-- Оставшиеся секунды кулдауна.
local function GetBuybackCooldown(hero)
	return math.max(0, GetBuybackCooldownRaw(hero) - GameRules:GetGameTime())
end

local function RemoveEntity(entity)
	if IsAliveEntity(entity) then
		UTIL_Remove(entity)
	end
end

local function ApplyStatueHealth(unit, fill)
	unit:SetBaseMaxHealth(STATUE_HEALTH)
	unit:SetMaxHealth(STATUE_HEALTH)
	if fill then
		unit:SetHealth(STATUE_HEALTH)
	end
end

-- Отладка ----------------------------------------------------------------
-- BuybackStatues.debug.chat    — события статуй дублируются в чат;
-- BuybackStatues.debug.verbose — подробный лог: каждый удар по статуе, синхронизация кулдауна.
-- Команды: buyback_statue_help (консоль) или "-bb <команда>" в чате (Tools mode / sv_cheats).
local DEBUG_CHAT = false
local DEBUG_VERBOSE = false

BuybackStatues.debug = BuybackStatues.debug or { chat = DEBUG_CHAT, verbose = DEBUG_VERBOSE }
BuybackStatues.stats = BuybackStatues.stats or {}

local function Chat(text)
	if GameRules and GameRules.SendCustomMessage then
		GameRules:SendCustomMessage(text, 0, 0)
	end
end

-- События статуй: в консоль всегда, в чат при debug.chat.
local function Log(fmt, ...)
	local text = "[BuybackStatues] " .. string.format(fmt, ...)
	print(text)
	if BuybackStatues.debug.chat then
		Chat(text)
	end
end

local function Verbose(fmt, ...)
	if not BuybackStatues.debug.verbose then
		return
	end
	local text = "[BuybackStatues:v] " .. string.format(fmt, ...)
	print(text)
	if BuybackStatues.debug.chat then
		Chat(text)
	end
end

local function Stat(name)
	BuybackStatues.stats[name] = (BuybackStatues.stats[name] or 0) + 1
end

local function EntLabel(entity)
	if not IsAliveEntity(entity) then
		return "nil"
	end
	local name = entity.GetUnitName and entity:GetUnitName() or entity:GetClassname()
	return string.format("%s#%d", tostring(name), entity:entindex())
end

function BuybackStatues:Init()
	if self._initialized then
		return
	end
	self._initialized = true
	self.players = self.players or {}
	self.missingPoints = self.missingPoints or {}
	self.cooldownLength = BUYBACK_COOLDOWN

	self:RegisterDebugCommands()

	ListenToGameEvent("dota_buyback", function(event)
		self:OnBuybackEvent(event)
	end, nil)

	-- Timers не перезапускает таймер после ошибки, поэтому Think ловит ошибки сам.
	Timers:CreateTimer(0.5, function()
		local ok, err = pcall(self.Think, self)
		if not ok then
			self:ReportError("Think", err)
		end
		return 0.5
	end)
end

function BuybackStatues:InstallDamageFilter()
	local gm = GameRules and GameRules:GetGameModeEntity()
	if not gm or not gm.SetDamageFilter then
		return false
	end
	-- У движка один DamageFilter. Статуя обрабатывается здесь, остальной урон уходит в Mage Slayer.
	gm:SetDamageFilter(function(event)
		local victimIndex = event.entindex_victim_const or event.entindex_victim
		local victim = victimIndex and EntIndexToHScript(victimIndex) or nil
		if IsAliveEntity(victim) and victim._buybackPlayerID ~= nil then
			return self:DamageFilter(event)
		end
		if MageSlayer_DamageFilter then
			return MageSlayer_DamageFilter(event)
		end
		return true
	end, nil)
	return true
end

function BuybackStatues:Think()
	if not PlayerResource then
		return
	end
	if self._statueVersion ~= STATUE_CODE_VERSION then
		self:DiscardOldStatues()
		self._statueVersion = STATUE_CODE_VERSION
	end

	for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if self:IsMatchPlayer(playerID) then
			local hero = PlayerResource:GetSelectedHeroEntity(playerID)
			if IsAliveEntity(hero) and hero:IsRealHero() and not hero:IsIllusion() then
				local ok, err = pcall(self.EnsureStatue, self, playerID, hero)
				if not ok then
					self:ReportError("EnsureStatue P" .. playerID, err)
				end
				ok, err = pcall(self.SyncBuyback, self, playerID, hero)
				if not ok then
					self:ReportError("SyncBuyback P" .. playerID, err)
				end
			end
		end
	end
end

function BuybackStatues:DiscardOldStatues()
	local ent = Entities:First()
	while ent do
		local nextEnt = Entities:Next(ent)
		local legacyBuilding = ent.GetUnitName and ent:GetUnitName() == LEGACY_BUILDING
		local oldStatue = ent._buybackPlayerID ~= nil or ent._buybackStatue ~= nil or ent._buybackFigure ~= nil
		if legacyBuilding or oldStatue then
			UTIL_Remove(ent)
		end
		ent = nextEnt
	end
	self.players = {}
end

function BuybackStatues:ReportError(where, err)
	self.reportedErrors = self.reportedErrors or {}
	local key = where .. tostring(err)
	if self.reportedErrors[key] then
		return
	end
	self.reportedErrors[key] = true
	Stat("errors")
	Log("Ошибка в %s: %s", where, tostring(err))
end

function BuybackStatues:IsMatchPlayer(playerID)
	if DraftSpawn and DraftSpawn.IsMatchPlayer then
		return DraftSpawn:IsMatchPlayer(playerID)
	end
	if playerID == nil or not PlayerResource:IsValidPlayerID(playerID) then
		return false
	end
	local team = PlayerResource:GetTeam(playerID)
	return team == DOTA_TEAM_GOODGUYS or team == DOTA_TEAM_BADGUYS
end

function BuybackStatues:IsWarmup()
	return not (DraftSpawn and DraftSpawn.warmupEnded)
end

function BuybackStatues:TeamSlot(playerID)
	local team = PlayerResource:GetTeam(playerID)
	local ids = {}
	for id = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if self:IsMatchPlayer(id) and PlayerResource:GetTeam(id) == team then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	for slot, id in ipairs(ids) do
		if id == playerID then
			return slot
		end
	end
	return nil
end

function BuybackStatues:PointName(playerID)
	local slot = self:TeamSlot(playerID)
	if not slot or slot > 3 then
		return nil
	end
	local side = PlayerResource:GetTeam(playerID) == DOTA_TEAM_GOODGUYS and "good" or "bad"
	return string.format("trinity_buyback_statue_%s_%d", side, slot)
end

-- Точки статуй стороны по слотам 1..3. В Hammer точку легко скопировать без переименования:
-- тогда FindByName находит одну и ту же точку для всех, и статуя появляется только у первого игрока.
-- Поэтому каждый слот сначала берёт точку со своим именем, а свободные слоты получают лишние дубликаты.
function BuybackStatues:SidePoints(side)
	local assigned, extras = {}, {}
	for slot = 1, 3 do
		local name = string.format("trinity_buyback_statue_%s_%d", side, slot)
		local found = {}
		for _, ent in ipairs(Entities:FindAllByName(name) or {}) do
			if IsAliveEntity(ent) then
				found[#found + 1] = ent
			end
		end
		table.sort(found, function(a, b)
			return a:entindex() < b:entindex()
		end)
		if #found > 1 then
			self.duplicatePoints = self.duplicatePoints or {}
			if not self.duplicatePoints[name] then
				self.duplicatePoints[name] = true
				print(string.format("[BuybackStatues] На карте %d точки с именем %s — переименуй их в Hammer (_1, _2, _3). Пока раздаю их по свободным слотам.", #found, name))
			end
		end
		for index, ent in ipairs(found) do
			if index == 1 then
				assigned[slot] = ent
			else
				extras[#extras + 1] = ent
			end
		end
	end
	for slot = 1, 3 do
		if not assigned[slot] and #extras > 0 then
			assigned[slot] = table.remove(extras, 1)
		end
	end
	return assigned
end

function BuybackStatues:FindPoint(playerID)
	local slot = self:TeamSlot(playerID)
	if not slot or slot > 3 then
		return nil
	end
	local side = PlayerResource:GetTeam(playerID) == DOTA_TEAM_GOODGUYS and "good" or "bad"
	return self:SidePoints(side)[slot]
end

function BuybackStatues:EnsureStatue(playerID, hero)
	local state = self.players[playerID]
	local heroName = hero:GetUnitName()
	if state and IsAliveEntity(state.unit) and state.heroName == heroName then
		local modifier = state.unit:FindModifierByName(MODIFIER_NAME)
		if not modifier then
			-- Модификатор статуи кто-то снял (очистка, чужой скрипт) — возвращаем, иначе статуя становится обычной иллюзией.
			modifier = state.unit:AddNewModifier(state.unit, nil, MODIFIER_NAME, {})
			Log("P%d: модификатор статуи восстановлен", playerID)
		end
		if modifier then
			modifier.playerID = playerID
			modifier.broken = state.broken
		end
		if not state.unit:HasModifier(STONE_MODIFIER) then
			state.unit:AddNewModifier(state.unit, nil, STONE_MODIFIER, {})
			Log("P%d: эффект камня восстановлен", playerID)
		end
		return
	end
	if not hero:IsAlive() then
		return
	end

	local now = GameRules:GetGameTime()
	if state and state.nextTry and now < state.nextTry then
		return
	end

	local pointName = self:PointName(playerID)
	if not pointName then
		return
	end
	local point = self:FindPoint(playerID)
	if not IsAliveEntity(point) then
		if not self.missingPoints[pointName] then
			self.missingPoints[pointName] = true
			print("[BuybackStatues] Нет точки Hammer: " .. pointName)
		end
		return
	end

	local broken = state and state.broken
	local repairEnd = state and state.repairEnd
	if state then
		RemoveEntity(state.unit)
	end

	local unit = self:CreateStatue(playerID, hero, point)
	if not unit then
		self.players[playerID] = {
			unit = nil,
			heroName = nil,
			broken = broken or false,
			repairEnd = repairEnd,
			nextTry = now + 3,
		}
		return
	end

	state = {
		unit = unit,
		heroName = heroName,
		broken = broken or false,
		repairEnd = repairEnd,
	}
	self.players[playerID] = state
	Stat("statues_created")
	Log("P%d: статуя %s создана на %s%s", playerID, EntLabel(unit), pointName, state.broken and " (сломана, чинится)" or "")
	if state.broken then
		self:ApplyBrokenLook(state)
	end
end

-- Шмот героя есть только на клиенте, поэтому статуя — иллюзия: косметику копирует движок.
function BuybackStatues:CreateStatue(playerID, hero, point)
	local illusions = CreateIllusions(hero, hero, {
		outgoing_damage = -100,
		incoming_damage = 0,
		bounty_base = 0,
		bounty_growth = 0,
		duration = ILLUSION_DURATION,
	}, 1, 0, false, false)
	local unit = illusions and illusions[1]
	if not IsAliveEntity(unit) then
		print("[BuybackStatues] Не удалось создать статую " .. hero:GetUnitName() .. ", повтор через 3 с")
		return nil
	end

	local kv = GetUnitKeyValuesByName(hero:GetUnitName())
	unit:SetAbsOrigin(point:GetAbsOrigin())
	unit:SetForwardVector(point:GetForwardVector())
	unit:SetModelScale(tonumber(kv and kv.ModelScale) or 1)
	unit:SetIdleAcquire(false)
	if unit.SetAttackCapability then
		unit:SetAttackCapability(DOTA_UNIT_CAP_NO_ATTACK)
	end
	if unit.SetDayTimeVisionRange then
		unit:SetDayTimeVisionRange(0)
		unit:SetNightTimeVisionRange(0)
	end
	if unit.SetMinimumGoldBounty then
		unit:SetMinimumGoldBounty(0)
		unit:SetMaximumGoldBounty(0)
	end
	if unit.SetDeathXP then
		unit:SetDeathXP(0)
	end
	unit:Stop()
	unit._buybackPlayerID = playerID
	ApplyStatueHealth(unit, true)
	unit:AddNewModifier(unit, nil, MODIFIER_NAME, {})
	unit:AddNewModifier(unit, nil, STONE_MODIFIER, {})
	self:StripIllusion(unit)

	Timers:CreateTimer(POSE_DELAY, function()
		if not IsAliveEntity(unit) or unit._buybackPlayerID ~= playerID then
			return nil
		end
		self:StripIllusion(unit)
		if unit:GetMaxHealth() ~= STATUE_HEALTH then
			local state = self.players[playerID]
			ApplyStatueHealth(unit, not (state and state.broken))
		end
		if not unit:HasModifier(FROZEN_MODIFIER) then
			unit:AddNewModifier(unit, nil, FROZEN_MODIFIER, {})
		end
		return nil
	end)
	return unit
end

function BuybackStatues:StripIllusion(unit)
	if unit.SetControllableByPlayer then
		unit:SetControllableByPlayer(-1, true)
	end
	for _, modifier in ipairs(unit:FindAllModifiers()) do
		local name = modifier:GetName()
		if name == "modifier_illusion" then
			modifier:SetDuration(-1, true)
		elseif not KEEP_MODIFIERS[name] then
			modifier:Destroy()
		end
	end
end

function BuybackStatues:ApplyBrokenLook(state)
	local unit = state.unit
	if not IsAliveEntity(unit) then
		return
	end
	unit:AddNoDraw()
	local modifier = unit:FindModifierByName(MODIFIER_NAME)
	if modifier then
		modifier.broken = true
		modifier:BeginRepair()
	end
end

function BuybackStatues:DebugPrint(ctx, onlyPlayerID)
	self:DebugOut(ctx, "разминка=%s кулдаун_поломки=%.0f с время=%.1f chat=%s verbose=%s",
		tostring(self:IsWarmup()), self.cooldownLength or 0, GameRules:GetGameTime(),
		tostring(self.debug.chat), tostring(self.debug.verbose))
	local shown = 0
	for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		local hero = PlayerResource and PlayerResource:GetSelectedHeroEntity(playerID)
		if (onlyPlayerID == nil or onlyPlayerID == playerID) and self:IsMatchPlayer(playerID) and IsAliveEntity(hero) then
			shown = shown + 1
			local state = self.players[playerID]
			local unit = state and state.unit
			self:DebugOut(ctx, "P%d %s слот=%s точка=%s статуя=%s сломана=%s ждёт_байбек=%s",
				playerID, hero:GetUnitName(), tostring(self:TeamSlot(playerID)), tostring(self:PointName(playerID)),
				EntLabel(unit), tostring(state and state.broken), tostring(state and state.pendingBuyback))
			if state and state.repairEnd then
				self:DebugOut(ctx, "    до конца починки: %.1f с", state.repairEnd - GameRules:GetGameTime())
			end
			if state and state.nextTry then
				self:DebugOut(ctx, "    повтор создания через: %.1f с", state.nextTry - GameRules:GetGameTime())
			end
			local cost = PlayerResource.GetBuybackCost and PlayerResource:GetBuybackCost(playerID) or nil
			self:DebugOut(ctx, "    герой жив=%s, кулдаун байбека=%.1f с (движок: до %.1f, сейчас %.1f), цена=%s, золото=%d",
				tostring(hero:IsAlive()), GetBuybackCooldown(hero), GetBuybackCooldownRaw(hero), GameRules:GetGameTime(),
				tostring(cost), PlayerResource:GetGold(playerID))
			if IsAliveEntity(unit) then
				local names = {}
				for _, modifier in ipairs(unit:FindAllModifiers()) do
					table.insert(names, modifier:GetName())
				end
				local point = self:FindPoint(playerID)
				self:DebugOut(ctx, "    здоровье %.0f / %.0f, броня %.1f, pos=(%d, %d)%s, скрыта=%s",
					unit:GetHealth(), unit:GetMaxHealth(), unit:GetPhysicalArmorValue(false),
					unit:GetAbsOrigin().x, unit:GetAbsOrigin().y,
					IsAliveEntity(point) and string.format(" (до точки %.0f)", (unit:GetAbsOrigin() - point:GetAbsOrigin()):Length2D()) or "",
					tostring(unit.IsNoDraw and unit:IsNoDraw()))
				self:DebugOut(ctx, "    модификаторы: %s", #names > 0 and table.concat(names, ", ") or "нет")
			end
		end
	end
	if shown == 0 then
		self:DebugOut(ctx, "нет подходящих игроков с героем")
	end
end

function BuybackStatues:IsValidAttacker(statue, attacker)
	if not IsAliveEntity(statue) or not IsAliveEntity(attacker) then
		return false
	end
	if attacker:GetTeamNumber() == statue:GetTeamNumber() then
		return false
	end
	if attacker:GetTeamNumber() == DOTA_TEAM_NEUTRALS then
		return false
	end
	if attacker.IsTower and attacker:IsTower() then
		return false
	end
	if attacker.IsFort and attacker:IsFort() then
		return false
	end
	if attacker.IsAncient and attacker:IsAncient() then
		return false
	end
	if attacker.IsBoss and attacker:IsBoss() then
		return false
	end

	local name = attacker.GetUnitName and attacker:GetUnitName() or ""
	if string.find(name, "fountain", 1, true)
		or string.find(name, "mortimer", 1, true)
		or string.find(name, "primal_beast", 1, true)
		or string.find(name, "caravan", 1, true)
	then
		return false
	end

	if attacker.IsRealHero and attacker:IsRealHero() then
		return true
	end
	if attacker.IsIllusion and attacker:IsIllusion() then
		return true
	end
	if attacker.IsTempestDouble and attacker:IsTempestDouble() then
		return true
	end
	if attacker.IsClone and attacker:IsClone() then
		return true
	end
	if (attacker.IsCreep and attacker:IsCreep()) or (attacker.IsSummoned and attacker:IsSummoned()) then
		return true
	end
	return false
end

function BuybackStatues:IsAttackDamage(event)
	if event.damage_category ~= nil then
		return event.damage_category == DOTA_DAMAGE_CATEGORY_ATTACK
	end
	local inflictor = event.entindex_inflictor_const or event.entindex_inflictor
	return inflictor == nil or inflictor == 0
end

function BuybackStatues:DamageFilter(event)
	local victimIndex = event.entindex_victim_const or event.entindex_victim
	local victim = victimIndex and EntIndexToHScript(victimIndex) or nil
	if not IsAliveEntity(victim) or victim._buybackPlayerID == nil then
		return true
	end

	local playerID = victim._buybackPlayerID
	local state = self.players[playerID]
	local attackerIndex = event.entindex_attacker_const or event.entindex_attacker
	local attacker = attackerIndex and EntIndexToHScript(attackerIndex) or nil
	local incoming = event.damage or 0

	if not state or state.unit ~= victim or state.broken then
		event.damage = 0
		Verbose("P%d удар %.0f от %s: заблокирован (статуя сломана или устарела)", playerID, incoming, EntLabel(attacker))
		return true
	end

	if not self:IsAttackDamage(event) then
		event.damage = 0
		Stat("damage_blocked_not_attack")
		Verbose("P%d урон %.0f от %s: заблокирован (не атака)", playerID, incoming, EntLabel(attacker))
		return true
	end
	if not self:IsValidAttacker(victim, attacker) then
		event.damage = 0
		Stat("damage_blocked_attacker")
		Verbose("P%d удар %.0f от %s: заблокирован (атакующий не может бить статую)", playerID, incoming, EntLabel(attacker))
		return true
	end

	Stat("damage_accepted")
	if incoming >= victim:GetHealth() then
		event.damage = 0
		Verbose("P%d удар %.0f от %s: смертельный, статуя ломается", playerID, incoming, EntLabel(attacker))
		self:Break(playerID, self.cooldownLength, "уничтожена " .. EntLabel(attacker))
	else
		Verbose("P%d удар %.0f от %s: здоровье %.0f -> %.0f", playerID, incoming, EntLabel(attacker),
			victim:GetHealth(), victim:GetHealth() - incoming)
	end
	return true
end

function BuybackStatues:FilterBuybackOrder(data)
	local playerID = data and data.issuer_player_id_const
	if self:IsWarmup() then
		Stat("buyback_blocked_warmup")
		Log("P%s: байбек заблокирован (разминка)", tostring(playerID))
		return false
	end
	local state = playerID and self.players[playerID]
	if state and state.broken then
		Stat("buyback_blocked_broken")
		Log("P%s: байбек заблокирован (статуя чинится ещё %.0f с)", tostring(playerID),
			(state.repairEnd or GameRules:GetGameTime()) - GameRules:GetGameTime())
		return false
	end
	-- Статуя цела — байбек обязан пройти. Снимаем любой остаточный кулдаун движка до проверки приказа.
	local hero = playerID ~= nil and PlayerResource:GetSelectedHeroEntity(playerID) or nil
	local raw = GetBuybackCooldownRaw(hero)
	if raw ~= 0 then
		Log("P%s: перед байбеком снят кулдаун движка (raw %.1f, время %.1f)", tostring(playerID), raw, GameRules:GetGameTime())
		SetBuybackCooldown(playerID, hero, 0)
	end
	Verbose("P%s: приказ байбека пропущен (статуя %s)", tostring(playerID), state and "цела" or "отсутствует")
	return true
end

function BuybackStatues:OnBuybackEvent(event)
	local playerID = event and event.player_id
	if playerID == nil then
		return
	end
	local state = self.players[playerID]
	if state then
		state.pendingBuyback = true
	end
	Timers:CreateTimer(0, function()
		local hero = PlayerResource:GetSelectedHeroEntity(playerID)
		Stat("buybacks")
		local engineCooldown = GetBuybackCooldown(hero)
		Log("P%d: байбек, кулдаун движка %.0f с, статуя %.0f с%s", playerID, engineCooldown, self.cooldownLength,
			math.abs(engineCooldown - self.cooldownLength) > 2 and " (не совпадают: проверь CUSTOM_BUYBACK_COOLDOWN_ENABLED)" or "")
		self:Break(playerID, self.cooldownLength, "байбек")
		return nil
	end)
end

function BuybackStatues:Break(playerID, duration, reason)
	local state = self.players[playerID]
	if not state or state.broken or not IsAliveEntity(state.unit) then
		Log("P%s: поломка (%s) пропущена: %s", tostring(playerID), tostring(reason),
			not state and "нет статуи" or state.broken and "уже сломана" or "юнит статуи недействителен")
		if state then
			state.pendingBuyback = nil
		end
		return
	end

	if not duration or duration < 1 then
		duration = self.cooldownLength or BUYBACK_COOLDOWN
	end
	state.broken = true
	state.pendingBuyback = nil
	state.repairEnd = GameRules:GetGameTime() + duration

	local hero = PlayerResource:GetSelectedHeroEntity(playerID)
	if not self:IsWarmup() then
		-- Кулдаун на герое — то, что игрок видит на кнопке. Без него кнопка выглядит готовой и просто не нажимается.
		SetBuybackCooldown(playerID, hero, duration)
	end
	self:ApplyBrokenLook(state)
	Stat("breaks")
	Log("P%d: статуя сломана (%s), починка %.0f с%s", playerID, tostring(reason), duration,
		self:IsWarmup() and ", разминка: кулдаун на кнопку не ставится" or "")
end

function BuybackStatues:FinishRepair(playerID)
	local state = self.players[playerID]
	if not state or not IsAliveEntity(state.unit) then
		return
	end

	state.broken = false
	state.repairEnd = nil
	state.pendingBuyback = nil
	ApplyStatueHealth(state.unit, true)
	state.unit:RemoveNoDraw()

	local modifier = state.unit:FindModifierByName(MODIFIER_NAME)
	if modifier then
		modifier:EndRepair()
	end

	local hero = PlayerResource:GetSelectedHeroEntity(playerID)
	if not self:IsWarmup() then
		SetBuybackCooldown(playerID, hero, 0)
	end
	Stat("repairs")
	Log("P%d: статуя починена, байбек снова доступен", playerID)
end

function BuybackStatues:SyncBuyback(playerID, hero)
	local state = self.players[playerID]
	if not state or not IsAliveEntity(state.unit) or state.pendingBuyback then
		return
	end

	if state.broken then
		local remaining = (state.repairEnd or GameRules:GetGameTime()) - GameRules:GetGameTime()
		if remaining <= 0 then
			self:FinishRepair(playerID)
			return
		end
		if not self:IsWarmup() and math.abs(GetBuybackCooldown(hero) - remaining) > 0.75 then
			Verbose("P%d: кулдаун на кнопке %.1f -> %.1f (починка)", playerID, GetBuybackCooldown(hero), remaining)
			SetBuybackCooldown(playerID, hero, remaining)
		end
		return
	end

	-- Целая статуя: на кнопке нет кулдауна, байбек можно купить.
	-- Проверяем сырое значение: если движок хранит время в другой шкале, чем GetGameTime,
	-- вычисленный остаток выходит <= 0, а движок всё равно считает байбек на перезарядке.
	if not self:IsWarmup() and GetBuybackCooldownRaw(hero) ~= 0 then
		Verbose("P%d: кулдаун на кнопке (raw %.1f) -> 0 (статуя цела)", playerID, GetBuybackCooldownRaw(hero))
		SetBuybackCooldown(playerID, hero, 0)
	end
end

-- Отладочные команды ---------------------------------------------------------
-- Консоль: buyback_statue_<команда> [аргументы]; чат: -bb <команда> [аргументы].
-- Чат и команды, меняющие состояние, работают только в Tools mode или с sv_cheats.
--   help                        список команд
--   debug [0|1]                 события статуй в чат
--   verbose [0|1]               подробный лог: удары, синхронизация кулдауна, приказы байбека
--   status [pid]                состояние статуй (старое имя buyback_statue_debug тоже работает)
--   points                      точки Hammer: найдены ли, координаты, кто на них
--   stats                       счётчики событий и ошибки
--   break [pid] [сек]           сломать статую (как после байбека)
--   repair [pid]                закончить починку сейчас
--   respawn [pid]               пересоздать фигуру статуи (состояние поломки сохраняется)
--   hp [pid] [значение]         выставить здоровье статуи
--   cooldown [сек]              длительность починки по умолчанию
--   die                         убить своего героя (проверить байбек)
-- pid по умолчанию — игрок, который ввёл команду.

local function DebugAllowed()
	if IsInToolsMode and IsInToolsMode() then
		return true
	end
	return GameRules and GameRules.IsCheatMode and GameRules:IsCheatMode() or false
end

local function ParseToggle(value, current)
	if value == nil or value == "" then
		return not current
	end
	return value == "1" or value == "on" or value == "true"
end

function BuybackStatues:DebugOut(ctx, fmt, ...)
	local text = "[BuybackStatues] " .. string.format(fmt, ...)
	print(text)
	if ctx and ctx.chat then
		Chat(text)
	end
end

function BuybackStatues:DebugPlayerID(ctx, arg)
	local explicit = tonumber(arg)
	if explicit then
		return explicit
	end
	if ctx and ctx.playerID ~= nil and ctx.playerID >= 0 then
		return ctx.playerID
	end
	local player = Convars and Convars.GetCommandClient and Convars:GetCommandClient() or nil
	if player and player.GetPlayerID and player:GetPlayerID() >= 0 then
		return player:GetPlayerID()
	end
	for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if self:IsMatchPlayer(playerID) and PlayerResource:GetSelectedHeroEntity(playerID) then
			return playerID
		end
	end
	return nil
end

BuybackStatues.DebugCommands = {}
local Commands = BuybackStatues.DebugCommands

Commands.help = function(self, ctx)
	self:DebugOut(ctx, "команды: debug [0|1], verbose [0|1], status [pid], points, stats, break [pid] [сек], repair [pid], respawn [pid], hp [pid] [hp], cooldown [сек], die")
	self:DebugOut(ctx, "консоль: buyback_statue_<команда>; чат: -bb <команда>. Золото на байбек: ванильный чит -gold.")
end

Commands.debug = function(self, ctx, arg)
	self.debug.chat = ParseToggle(arg, self.debug.chat)
	self:DebugOut(ctx, "вывод в чат: %s", tostring(self.debug.chat))
end

Commands.verbose = function(self, ctx, arg)
	self.debug.verbose = ParseToggle(arg, self.debug.verbose)
	self:DebugOut(ctx, "подробный лог: %s", tostring(self.debug.verbose))
end

Commands.status = function(self, ctx, arg)
	self:DebugPrint(ctx, tonumber(arg))
end

Commands.points = function(self, ctx)
	for _, side in ipairs({ "good", "bad" }) do
		local points = self:SidePoints(side)
		for slot = 1, 3 do
			local name = string.format("trinity_buyback_statue_%s_%d", side, slot)
			local point = points[slot]
			local count = #(Entities:FindAllByName(name) or {})
			local owner = "-"
			for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
				if self:IsMatchPlayer(playerID) and self:PointName(playerID) == name then
					owner = "P" .. playerID
				end
			end
			local dupes = count > 1 and string.format(", точек с этим именем: %d — переименуй в Hammer", count) or ""
			if IsAliveEntity(point) then
				local origin = point:GetAbsOrigin()
				local pointLabel = point:GetName() ~= name and (" -> взята точка " .. point:GetName()) or ""
				self:DebugOut(ctx, "слот %s: (%d, %d, %d) игрок=%s%s%s", name, origin.x, origin.y, origin.z, owner, pointLabel, dupes)
			else
				self:DebugOut(ctx, "слот %s: НЕТ ТОЧКИ НА КАРТЕ (игрок=%s)", name, owner)
			end
		end
	end
end

Commands.stats = function(self, ctx)
	local keys = {}
	for key in pairs(self.stats) do
		table.insert(keys, key)
	end
	table.sort(keys)
	local parts = {}
	for _, key in ipairs(keys) do
		table.insert(parts, key .. "=" .. tostring(self.stats[key]))
	end
	self:DebugOut(ctx, "счётчики: %s", #parts > 0 and table.concat(parts, ", ") or "(пусто)")
	local errors = 0
	for key in pairs(self.reportedErrors or {}) do
		errors = errors + 1
		self:DebugOut(ctx, "ошибка: %s", key)
	end
	if errors == 0 then
		self:DebugOut(ctx, "ошибок нет")
	end
end

Commands["break"] = function(self, ctx, arg1, arg2)
	local playerID = self:DebugPlayerID(ctx, arg1)
	self:Break(playerID, tonumber(arg2) or self.cooldownLength, "команда отладки")
end

Commands.repair = function(self, ctx, arg)
	local playerID = self:DebugPlayerID(ctx, arg)
	local state = playerID and self.players[playerID]
	if not state or not state.broken then
		self:DebugOut(ctx, "P%s: статуя не сломана", tostring(playerID))
		return
	end
	self:FinishRepair(playerID)
end

Commands.respawn = function(self, ctx, arg)
	local playerID = self:DebugPlayerID(ctx, arg)
	local state = playerID and self.players[playerID]
	if state then
		RemoveEntity(state.unit)
		state.unit = nil
		state.heroName = nil
		state.nextTry = nil
	end
	local hero = playerID and PlayerResource:GetSelectedHeroEntity(playerID)
	if IsAliveEntity(hero) then
		self:EnsureStatue(playerID, hero)
	end
	self:DebugOut(ctx, "P%s: статуя пересоздана -> %s", tostring(playerID),
		EntLabel(self.players[playerID] and self.players[playerID].unit))
end

Commands.hp = function(self, ctx, arg1, arg2)
	local playerID, value = arg1, arg2
	if arg2 == nil or arg2 == "" then
		playerID, value = nil, arg1
	end
	playerID = self:DebugPlayerID(ctx, playerID)
	local state = playerID and self.players[playerID]
	value = tonumber(value)
	if not state or not IsAliveEntity(state.unit) or not value then
		self:DebugOut(ctx, "использование: hp [pid] <значение>")
		return
	end
	state.unit:SetHealth(math.max(1, math.min(value, state.unit:GetMaxHealth())))
	self:DebugOut(ctx, "P%d: здоровье статуи %.0f", playerID, state.unit:GetHealth())
end

Commands.cooldown = function(self, ctx, arg)
	local value = tonumber(arg)
	if value and value >= 1 then
		self.cooldownLength = value
	end
	self:DebugOut(ctx, "длительность починки: %.0f с (CUSTOM_BUYBACK_COOLDOWN = %d с, после перезапуска вернётся; кулдаун движка эта команда не меняет)", self.cooldownLength or 0, BUYBACK_COOLDOWN)
end

Commands.die = function(self, ctx)
	local playerID = self:DebugPlayerID(ctx)
	local hero = playerID and PlayerResource:GetSelectedHeroEntity(playerID)
	if not IsAliveEntity(hero) or not hero:IsAlive() then
		self:DebugOut(ctx, "нет живого героя")
		return
	end
	hero:Kill(nil, hero)
	self:DebugOut(ctx, "P%d: герой убит", playerID)
end

-- Только чтение: работают без читов.
local READ_ONLY = { help = true, debug = true, verbose = true, status = true, points = true, stats = true }

function BuybackStatues:RunDebugCommand(ctx, name, arg1, arg2)
	if name == nil or name == "" then
		name = "help"
	end
	local command = self.DebugCommands[name]
	if not command then
		self:DebugOut(ctx, "неизвестная команда '%s'", tostring(name))
		command = self.DebugCommands.help
	elseif not READ_ONLY[name] and not DebugAllowed() then
		self:DebugOut(ctx, "'%s' работает только в Tools mode или с sv_cheats", name)
		return
	end
	local ok, err = pcall(command, self, ctx, arg1, arg2)
	if not ok then
		self:DebugOut(ctx, "команда '%s' упала: %s", tostring(name), tostring(err))
	end
end

function BuybackStatues:RegisterDebugCommands()
	if self._debugCommandsRegistered then
		return
	end
	self._debugCommandsRegistered = true

	for name in pairs(self.DebugCommands) do
		Convars:RegisterCommand("buyback_statue_" .. name, function(_, arg1, arg2)
			BuybackStatues:RunDebugCommand({ chat = false }, name, arg1, arg2)
		end, "Статуи байбека, отладка: " .. name, 0)
	end
	Convars:RegisterCommand("buyback_statue_debug", function(_, arg1)
		BuybackStatues:RunDebugCommand({ chat = false }, "status", arg1)
	end, "Статуи байбека: состояние по игрокам", 0)

	ListenToGameEvent("player_chat", function(keys)
		local text = keys and keys.text
		if type(text) ~= "string" or not DebugAllowed() then
			return
		end
		local name, arg1, arg2 = string.match(text, "^%-bb%s*(%S*)%s*(%S*)%s*(%S*)")
		if name == nil then
			return
		end
		BuybackStatues:RunDebugCommand({ chat = true, playerID = keys.playerid }, name,
			arg1 ~= "" and arg1 or nil, arg2 ~= "" and arg2 or nil)
	end, nil)
end

-- Статуя --------------------------------------------------------------------

modifier_trinity_buyback_statue = class({})

function modifier_trinity_buyback_statue:IsHidden()
	return true
end

function modifier_trinity_buyback_statue:IsPurgable()
	return false
end

function modifier_trinity_buyback_statue:RemoveOnDeath()
	return false
end

function modifier_trinity_buyback_statue:OnCreated()
	if not IsServer() then
		return
	end
	local parent = self:GetParent()
	self.playerID = parent._buybackPlayerID or -1
	self.broken = false
end

function modifier_trinity_buyback_statue:CheckState()
	local state = {
		[MODIFIER_STATE_ROOTED] = true,
		[MODIFIER_STATE_DISARMED] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_NOT_ON_MINIMAP] = true,
		[MODIFIER_STATE_SILENCED] = true,
		[MODIFIER_STATE_MUTED] = true,
		[MODIFIER_STATE_PASSIVES_DISABLED] = true,
		[MODIFIER_STATE_COMMAND_RESTRICTED] = true,
		[MODIFIER_STATE_MAGIC_IMMUNE] = true,
		-- Статуя — не герой: без полоски здоровья, имени и уровня над головой.
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
	}
	-- UNSELECTABLE делает юнит некликабельным: по целой статуе нельзя отдать приказ атаки.
	-- Поэтому невыделяемой она становится только сломанной.
	if self.broken then
		state[MODIFIER_STATE_UNSELECTABLE] = true
		state[MODIFIER_STATE_INVULNERABLE] = true
		state[MODIFIER_STATE_UNTARGETABLE] = true
		state[MODIFIER_STATE_ATTACK_IMMUNE] = true
	end
	return state
end

function modifier_trinity_buyback_statue:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_PROPERTY_MIN_HEALTH,
		MODIFIER_PROPERTY_DISABLE_HEALING,
		MODIFIER_EVENT_ON_TAKEDAMAGE,
	}
end

function modifier_trinity_buyback_statue:GetModifierPhysicalArmorBonus()
	local parent = self:GetParent()
	if not parent or parent:IsNull() or self._readingArmor then
		return 0
	end
	self._readingArmor = true
	local current = parent.GetPhysicalArmorValue and parent:GetPhysicalArmorValue(false) or 0
	self._readingArmor = false
	return STATUE_ARMOR - current
end

function modifier_trinity_buyback_statue:GetMinHealth()
	return 1
end

function modifier_trinity_buyback_statue:GetDisableHealing()
	return 1
end

function modifier_trinity_buyback_statue:OnTakeDamage(event)
	if not IsServer() or self.broken or not event or event.unit ~= self:GetParent() then
		return
	end
	if (event.damage or 0) <= 0 then
		return
	end
	local parent = self:GetParent()
	if parent:GetHealth() > 1 then
		return
	end
	if event.damage_category ~= nil and event.damage_category ~= DOTA_DAMAGE_CATEGORY_ATTACK then
		return
	end
	if not BuybackStatues:IsValidAttacker(parent, event.attacker) then
		return
	end
	BuybackStatues:Break(self.playerID, BuybackStatues.cooldownLength, "уничтожена " .. EntLabel(event.attacker) .. " (min health)")
end

function modifier_trinity_buyback_statue:BeginRepair()
	if not IsServer() then
		return
	end
	self.broken = true
	local parent = self:GetParent()
	if not IsAliveEntity(parent) then
		return
	end
	local origin = parent:GetAbsOrigin()
	self:DestroyRepairParticles()
	self.repairParticle = ParticleManager:CreateParticle(REPAIR_PARTICLE, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(self.repairParticle, 0, origin)
	ParticleManager:SetParticleControl(self.repairParticle, 1, origin)
	self.ringParticle = ParticleManager:CreateParticle(REPAIR_RING_PARTICLE, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(self.ringParticle, 0, origin)
	ParticleManager:SetParticleControl(self.ringParticle, 1, Vector(160, 0, 0))
end

function modifier_trinity_buyback_statue:EndRepair()
	if not IsServer() then
		return
	end
	self.broken = false
	self:DestroyRepairParticles()
end

function modifier_trinity_buyback_statue:DestroyRepairParticles()
	-- Уничтожаем сразу: у кольца прогресса бесконечная жизнь частиц, без immediate оно остаётся на земле.
	if self.repairParticle then
		ParticleManager:DestroyParticle(self.repairParticle, true)
		ParticleManager:ReleaseParticleIndex(self.repairParticle)
		self.repairParticle = nil
	end
	if self.ringParticle then
		ParticleManager:DestroyParticle(self.ringParticle, true)
		ParticleManager:ReleaseParticleIndex(self.ringParticle)
		self.ringParticle = nil
	end
end

function modifier_trinity_buyback_statue:OnDestroy()
	if not IsServer() then
		return
	end
	self:DestroyRepairParticles()
end

modifier_trinity_buyback_statue_stone = class({})

function modifier_trinity_buyback_statue_stone:IsHidden()
	return true
end

function modifier_trinity_buyback_statue_stone:IsPurgable()
	return false
end

function modifier_trinity_buyback_statue_stone:RemoveOnDeath()
	return false
end

function modifier_trinity_buyback_statue_stone:GetStatusEffectName()
	return STONE_EFFECT
end

function modifier_trinity_buyback_statue_stone:StatusEffectPriority()
	return STONE_EFFECT_PRIORITY
end

modifier_trinity_buyback_statue_frozen = class({})

function modifier_trinity_buyback_statue_frozen:IsHidden()
	return true
end

function modifier_trinity_buyback_statue_frozen:IsPurgable()
	return false
end

function modifier_trinity_buyback_statue_frozen:RemoveOnDeath()
	return false
end

function modifier_trinity_buyback_statue_frozen:CheckState()
	return {
		[MODIFIER_STATE_FROZEN] = true,
	}
end

if Timers then
	Timers:CreateTimer(0.5, function()
		if not BuybackStatues:InstallDamageFilter() then
			return 0.5
		end
		return nil
	end)
end
