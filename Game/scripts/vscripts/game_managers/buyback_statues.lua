BuybackStatues = BuybackStatues or {}

local STATUE_UNIT = "npc_trinity_buyback_statue"
local FIGURE_UNIT = "npc_trinity_buyback_statue_figure"
local MODIFIER_NAME = "modifier_trinity_buyback_statue"
local FIGURE_MODIFIER = "modifier_trinity_buyback_statue_figure"
local FROZEN_MODIFIER = "modifier_trinity_buyback_statue_frozen"
local REPAIR_PARTICLE = "particles/items5_fx/repair_kit.vpcf"
local REPAIR_RING_PARTICLE = "particles/generic_gameplay/launchpad_progress_ring.vpcf"
-- Кандидаты каменной текстуры. Выбор в игре: buyback_statue_stone N. На каждую свой модификатор.
local STONE_STATUS_EFFECTS = {
	"particles/status_fx/status_effect_medusa_stone_gaze.vpcf",
	"particles/status_fx/status_effect_earth_spirit_petrify.vpcf",
	"particles/status_fx/status_effect_effigy_jade_stone.vpcf",
}
local DEFAULT_STONE_INDEX = 1
local STONE_MODIFIER_PREFIX = "modifier_trinity_buyback_statue_stone_"
local INVISIBLE_MODEL = "models/development/invisiblebox.vmdl"
local FIGURE_ENABLED = true
-- Через сколько секунд после создания фигура замирает: сразу после спавна модель ещё в bind-позе.
local FIGURE_POSE_DELAY = 0.4
-- Иллюзия-фигура живёт 10 часов: дольше любого матча.
local FIGURE_DURATION = 36000
local FALLBACK_BUYBACK_COOLDOWN = 360

LinkLuaModifier(MODIFIER_NAME, "game_managers/buyback_statues", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier(FIGURE_MODIFIER, "game_managers/buyback_statues", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier(FROZEN_MODIFIER, "game_managers/buyback_statues", LUA_MODIFIER_MOTION_NONE)
for index = 1, #STONE_STATUS_EFFECTS do
	LinkLuaModifier(STONE_MODIFIER_PREFIX .. index, "game_managers/buyback_statues", LUA_MODIFIER_MOTION_NONE)
end

local function IsAliveEntity(entity)
	return entity and not entity:IsNull()
end

-- В актуальной Dota метода может не быть. Байбек на разминке всё равно режет FilterBuybackOrder.
local function SetBuybackBlocked(hero, blocked)
	if hero.SetBuyBackDisabledByReapersScythe then
		hero:SetBuyBackDisabledByReapersScythe(blocked)
	end
end

local function RemoveEntity(entity)
	if IsAliveEntity(entity) then
		UTIL_Remove(entity)
	end
end

function BuybackStatues:Init()
	if self._initialized then
		return
	end
	self._initialized = true
	self.players = self.players or {}
	self.missingPoints = self.missingPoints or {}
	self.cooldownLength = self.cooldownLength or FALLBACK_BUYBACK_COOLDOWN

	Convars:RegisterCommand("buyback_statue_debug", function()
		self:DebugPrint()
	end, "Статуи байбека: модель, шмот и состояние по игрокам", 0)

	Convars:RegisterCommand("buyback_statue_stone", function(_, index)
		self:SetStoneIndex(tonumber(index))
	end, "Статуи байбека: номер каменной текстуры 1.." .. #STONE_STATUS_EFFECTS, 0)

	Timers:CreateTimer(0.5, function()
		self:Think()
		return 0.5
	end)
end

function BuybackStatues:Think()
	if not PlayerResource then
		return
	end

	for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if self:IsMatchPlayer(playerID) then
			local hero = PlayerResource:GetSelectedHeroEntity(playerID)
			if IsAliveEntity(hero) and hero:IsRealHero() and not hero:IsIllusion() then
				self:EnsureStatue(playerID, hero)
				self:SyncBuyback(playerID, hero)
			end
		end
	end
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

function BuybackStatues:EnsureStatue(playerID, hero)
	local state = self.players[playerID]
	if state and IsAliveEntity(state.unit) then
		local modifier = state.unit:FindModifierByName(MODIFIER_NAME)
		if modifier then
			modifier.playerID = playerID
		end
		self:RefreshFigure(state, hero)
		return
	end

	local pointName = self:PointName(playerID)
	if not pointName then
		return
	end
	local point = Entities:FindByName(nil, pointName)
	if not IsAliveEntity(point) then
		if not self.missingPoints[pointName] then
			self.missingPoints[pointName] = true
			print("[BuybackStatues] Нет точки Hammer: " .. pointName)
		end
		return
	end

	local statue = CreateUnitByName(
		STATUE_UNIT,
		point:GetAbsOrigin(),
		false,
		nil,
		nil,
		PlayerResource:GetTeam(playerID)
	)
	if not statue then
		print("[BuybackStatues] Не удалось создать статую для игрока " .. tostring(playerID))
		return
	end

	statue:SetAbsOrigin(point:GetAbsOrigin())
	statue:SetForwardVector(point:GetForwardVector())
	statue:SetIdleAcquire(false)
	statue:SetOriginalModel(INVISIBLE_MODEL)
	statue:SetModel(INVISIBLE_MODEL)
	statue._buybackPlayerID = playerID
	statue:AddNewModifier(statue, nil, MODIFIER_NAME, { player_id = playerID })

	state = {
		unit = statue,
		heroName = nil,
		broken = false,
		repairEnd = nil,
	}
	self.players[playerID] = state
	self:RefreshFigure(state, hero)
end

-- Внешний вид статуи --------------------------------------------------------

-- Шмот героя существует только на клиенте: сервер его не видит (ни GetChildren, ни dota_item_wearable).
-- Поэтому фигура — иллюзия героя: её косметику копирует сам движок.
function BuybackStatues:StoneIndex()
	return self.stoneIndex or DEFAULT_STONE_INDEX
end

function BuybackStatues:ApplyStone(unit, index)
	for i = 1, #STONE_STATUS_EFFECTS do
		unit:RemoveModifierByName(STONE_MODIFIER_PREFIX .. i)
	end
	unit:AddNewModifier(unit, nil, STONE_MODIFIER_PREFIX .. index, {})
end

function BuybackStatues:SetStoneIndex(index)
	if not index or not STONE_STATUS_EFFECTS[index] then
		print("[BuybackStatues] Каменные текстуры:")
		for i, path in ipairs(STONE_STATUS_EFFECTS) do
			print(string.format("    %d%s %s", i, i == self:StoneIndex() and " *" or "  ", path))
		end
		return
	end
	self.stoneIndex = index
	for _, state in pairs(self.players or {}) do
		if IsAliveEntity(state.unit) then
			self:ForEachFigurePart(state.unit, function(unit)
				self:ApplyStone(unit, index)
			end)
		end
	end
	print("[BuybackStatues] Каменная текстура " .. index .. ": " .. STONE_STATUS_EFFECTS[index])
end

function BuybackStatues:RefreshFigure(state, hero)
	if not FIGURE_ENABLED or not IsAliveEntity(state.unit) then
		self:DestroyFigure(state.unit)
		return
	end

	local heroName = hero:GetUnitName()
	local figureAlive = state.unit._buybackFigure and IsAliveEntity(state.unit._buybackFigure.body)
	if figureAlive and state.heroName == heroName then
		return
	end
	if not hero:IsAlive() then
		return
	end
	local now = GameRules:GetGameTime()
	if state.nextFigureTry and now < state.nextFigureTry then
		return
	end

	if self:BuildFigure(state.unit, hero) then
		state.heroName = heroName
		state.nextFigureTry = nil
		self:SetFigureVisible(state.unit, not state.broken)
	else
		state.nextFigureTry = now + 3
	end
end

function BuybackStatues:BuildFigure(statue, hero)
	self:DestroyFigure(statue)

	local origin = statue:GetAbsOrigin()
	local illusions = CreateIllusions(hero, hero, {
		outgoing_damage = -100,
		incoming_damage = 0,
		bounty_base = 0,
		bounty_growth = 0,
		duration = FIGURE_DURATION,
	}, 1, 0, false, false)
	local body = illusions and illusions[1]
	if not IsAliveEntity(body) then
		print("[BuybackStatues] Не удалось создать фигуру " .. hero:GetUnitName() .. ", повтор через 3 с")
		return false
	end

	local kv = GetUnitKeyValuesByName(hero:GetUnitName())
	body:SetAbsOrigin(origin)
	body:SetForwardVector(statue:GetForwardVector())
	body:SetModelScale(tonumber(kv and kv.ModelScale) or 1)
	body:SetIdleAcquire(false)
	body:Stop()
	body:AddNewModifier(body, nil, FIGURE_MODIFIER, {})
	self:ApplyStone(body, self:StoneIndex())

	local figure = { body = body, parts = {} }
	statue._buybackFigure = figure

	Timers:CreateTimer(FIGURE_POSE_DELAY, function()
		if statue._buybackFigure ~= figure then
			return nil
		end
		self:ForEachFigurePart(statue, function(unit)
			unit:AddNewModifier(unit, nil, FROZEN_MODIFIER, {})
		end)
		return nil
	end)
	return true
end

function BuybackStatues:ForEachFigurePart(statue, callback)
	local figure = statue and statue._buybackFigure
	if not figure then
		return
	end
	if IsAliveEntity(figure.body) then
		callback(figure.body)
	end
	for _, part in ipairs(figure.parts) do
		if IsAliveEntity(part) then
			callback(part)
		end
	end
end

function BuybackStatues:SetFigureVisible(statue, visible)
	self:ForEachFigurePart(statue, function(unit)
		if visible then
			unit:RemoveNoDraw()
		else
			unit:AddNoDraw()
		end
	end)
end

function BuybackStatues:DestroyFigure(statue)
	if not statue then
		return
	end
	-- Иллюзии из старой версии статуй (живут до script_reload).
	RemoveEntity(statue._buybackEffigy)
	statue._buybackEffigy = nil

	local figure = statue._buybackFigure
	statue._buybackFigure = nil
	if not figure then
		return
	end
	for _, part in ipairs(figure.parts) do
		RemoveEntity(part)
	end
	RemoveEntity(figure.body)
end

function BuybackStatues:DebugPrint()
	for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		local hero = PlayerResource and PlayerResource:GetSelectedHeroEntity(playerID)
		if self:IsMatchPlayer(playerID) and IsAliveEntity(hero) then
			local state = self.players[playerID]
			local figure = state and IsAliveEntity(state.unit) and state.unit._buybackFigure
			print(string.format(
				"[BuybackStatues] P%d %s точка=%s сломана=%s частей фигуры=%d",
				playerID,
				hero:GetUnitName(),
				tostring(self:PointName(playerID)),
				tostring(state and state.broken),
				figure and (#figure.parts + 1) or 0
			))
			print("    модель героя: " .. hero:GetModelName())
			print("    камень: " .. STONE_STATUS_EFFECTS[self:StoneIndex()])
			local body = figure and figure.body
			if IsAliveEntity(body) then
				local names = {}
				for _, modifier in ipairs(body:FindAllModifiers()) do
					names[#names + 1] = modifier:GetName()
				end
				print("    модификаторы тела: " .. table.concat(names, ", "))
			end
		end
	end
end

-- Урон, байбек, починка -----------------------------------------------------

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

function BuybackStatues:PlayerIDForStatue(statue)
	if not IsAliveEntity(statue) then
		return nil
	end
	return statue._buybackPlayerID
end

function BuybackStatues:DamageFilter(event)
	local victimIndex = event.entindex_victim_const or event.entindex_victim
	local victim = victimIndex and EntIndexToHScript(victimIndex) or nil
	if not IsAliveEntity(victim) or victim:GetUnitName() ~= STATUE_UNIT then
		return true
	end

	local playerID = self:PlayerIDForStatue(victim)
	local state = playerID and self.players[playerID] or nil
	if not state or state.broken or state.unit ~= victim then
		return false
	end

	local attackerIndex = event.entindex_attacker_const or event.entindex_attacker
	local attacker = attackerIndex and EntIndexToHScript(attackerIndex) or nil
	if not self:IsValidAttacker(victim, attacker) then
		return false
	end

	local health = victim:GetHealth()
	if (event.damage or 0) >= health then
		event.damage = 0
		self:Break(playerID, self.cooldownLength, false)
	end
	return true
end

function BuybackStatues:FilterBuybackOrder(data)
	local playerID = data.issuer_player_id_const
	if playerID == nil then
		return false
	end
	if self:IsWarmup() then
		return false
	end

	local state = self.players[playerID]
	if not state or not IsAliveEntity(state.unit) then
		return true
	end
	if state.broken then
		return false
	end

	local hero = PlayerResource:GetSelectedHeroEntity(playerID)
	Timers:CreateTimer(0, function()
		if not IsAliveEntity(hero) then
			return nil
		end
		local cooldown = hero:GetBuybackCooldownTime()
		if cooldown and cooldown > 0 then
			self.cooldownLength = cooldown
			self:Break(playerID, cooldown, true)
		end
		return nil
	end)
	return true
end

function BuybackStatues:Break(playerID, duration, fromBuyback)
	local state = self.players[playerID]
	if not state or state.broken or not IsAliveEntity(state.unit) then
		return
	end

	if not duration or duration < 1 then
		duration = self.cooldownLength or FALLBACK_BUYBACK_COOLDOWN
	end
	self.cooldownLength = duration
	state.broken = true
	state.repairEnd = GameRules:GetGameTime() + duration

	local hero = PlayerResource:GetSelectedHeroEntity(playerID)
	if IsAliveEntity(hero) and not fromBuyback and not self:IsWarmup() then
		hero:SetBuybackCooldownTime(duration)
	end

	self:SetFigureVisible(state.unit, false)
	local modifier = state.unit:FindModifierByName(MODIFIER_NAME)
	if modifier then
		modifier:BeginRepair()
	end
end

function BuybackStatues:FinishRepair(playerID)
	local state = self.players[playerID]
	if not state or not IsAliveEntity(state.unit) then
		return
	end

	state.broken = false
	state.repairEnd = nil
	local modifier = state.unit:FindModifierByName(MODIFIER_NAME)
	if modifier then
		modifier:EndRepair()
	end
	state.unit:SetHealth(state.unit:GetMaxHealth())
	self:SetFigureVisible(state.unit, true)

	local hero = PlayerResource:GetSelectedHeroEntity(playerID)
	if IsAliveEntity(hero) and not self:IsWarmup() then
		hero:SetBuybackCooldownTime(0)
	end
end

function BuybackStatues:SyncBuyback(playerID, hero)
	local state = self.players[playerID]
	if not state or not IsAliveEntity(state.unit) then
		if self:IsWarmup() then
			SetBuybackBlocked(hero, true)
		end
		return
	end

	if state.broken then
		local remaining = (state.repairEnd or GameRules:GetGameTime()) - GameRules:GetGameTime()
		if remaining <= 0 then
			self:FinishRepair(playerID)
			return
		end
	end

	if self:IsWarmup() then
		SetBuybackBlocked(hero, true)
		return
	end

	SetBuybackBlocked(hero, false)

	if state.broken then
		local remaining = (state.repairEnd or GameRules:GetGameTime()) - GameRules:GetGameTime()
		if remaining <= 0 then
			self:FinishRepair(playerID)
			return
		end
		local current = hero:GetBuybackCooldownTime() or 0
		if math.abs(current - remaining) > 0.75 then
			hero:SetBuybackCooldownTime(remaining)
		end
		return
	end

	local cooldown = hero:GetBuybackCooldownTime() or 0
	if cooldown > 1 then
		self.cooldownLength = cooldown
		self:Break(playerID, cooldown, true)
	end
end

-- Модификатор здания статуи -------------------------------------------------

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

function modifier_trinity_buyback_statue:OnCreated(kv)
	if not IsServer() then
		return
	end
	self.playerID = kv and kv.player_id or -1
	self.broken = false
end

function modifier_trinity_buyback_statue:CheckState()
	local state = {
		[MODIFIER_STATE_ROOTED] = true,
		[MODIFIER_STATE_DISARMED] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = false,
	}
	if self.broken then
		state[MODIFIER_STATE_INVULNERABLE] = true
		state[MODIFIER_STATE_UNTARGETABLE] = true
		state[MODIFIER_STATE_ATTACK_IMMUNE] = true
		state[MODIFIER_STATE_MAGIC_IMMUNE] = true
		state[MODIFIER_STATE_NO_HEALTH_BAR] = true
	end
	return state
end

function modifier_trinity_buyback_statue:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
		MODIFIER_PROPERTY_MIN_HEALTH,
		MODIFIER_PROPERTY_DISABLE_HEALING,
		MODIFIER_EVENT_ON_TAKEDAMAGE,
	}
end

function modifier_trinity_buyback_statue:GetModifierIncomingDamage_Percentage(event)
	if not IsServer() or self.broken or type(event) ~= "table" then
		return 0
	end
	local parent = self:GetParent()
	if not BuybackStatues:IsValidAttacker(parent, event.attacker) then
		return -100
	end
	return 0
end

function modifier_trinity_buyback_statue:GetMinHealth()
	return 1
end

function modifier_trinity_buyback_statue:GetDisableHealing()
	return 1
end

function modifier_trinity_buyback_statue:OnTakeDamage(event)
	if not IsServer() or self.broken then
		return
	end
	local parent = self:GetParent()
	if not event or event.unit ~= parent or parent:GetHealth() > 1 then
		return
	end
	if not BuybackStatues:IsValidAttacker(parent, event.attacker) then
		return
	end
	local damage = event.damage or 0
	if damage < parent:GetMaxHealth() and damage <= 1 then
		return
	end
	BuybackStatues:Break(self.playerID, BuybackStatues.cooldownLength, false)
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
	if self.repairParticle then
		ParticleManager:DestroyParticle(self.repairParticle, false)
		ParticleManager:ReleaseParticleIndex(self.repairParticle)
		self.repairParticle = nil
	end
	if self.ringParticle then
		ParticleManager:DestroyParticle(self.ringParticle, false)
		ParticleManager:ReleaseParticleIndex(self.ringParticle)
		self.ringParticle = nil
	end
end

function modifier_trinity_buyback_statue:OnDestroy()
	if not IsServer() then
		return
	end
	self:DestroyRepairParticles()
	local parent = self:GetParent()
	if IsAliveEntity(parent) then
		BuybackStatues:DestroyFigure(parent)
	end
end

-- Части каменной фигуры: тело героя и каждая вещь шмота ---------------------

modifier_trinity_buyback_statue_figure = class({})

function modifier_trinity_buyback_statue_figure:IsHidden()
	return true
end

function modifier_trinity_buyback_statue_figure:IsPurgable()
	return false
end

function modifier_trinity_buyback_statue_figure:RemoveOnDeath()
	return false
end

function modifier_trinity_buyback_statue_figure:CheckState()
	return {
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_UNTARGETABLE] = true,
		[MODIFIER_STATE_UNSELECTABLE] = true,
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_NOT_ON_MINIMAP] = true,
		[MODIFIER_STATE_ROOTED] = true,
		[MODIFIER_STATE_DISARMED] = true,
		[MODIFIER_STATE_SILENCED] = true,
		[MODIFIER_STATE_MUTED] = true,
		[MODIFIER_STATE_PASSIVES_DISABLED] = true,
		[MODIFIER_STATE_NO_TEAM_SELECT] = true,
		[MODIFIER_STATE_NO_TEAM_MOVE_TO] = true,
		[MODIFIER_STATE_COMMAND_RESTRICTED] = true,
	}
end

for index, path in ipairs(STONE_STATUS_EFFECTS) do
	local stone = class({})
	function stone:IsHidden() return true end
	function stone:IsPurgable() return false end
	function stone:RemoveOnDeath() return false end
	function stone:GetStatusEffectName() return path end
	function stone:StatusEffectPriority() return MODIFIER_PRIORITY_SUPER_ULTRA end
	_G[STONE_MODIFIER_PREFIX .. index] = stone
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
