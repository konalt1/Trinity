-- Trinity: возврат лесных крипов в лагерь.
--
-- На плейтесте 2026-10-03 нейтралы из лагеря гнались за героем через всю карту.
-- Здесь страховка поверх движка: крип лагеря (npc_dota_creep_neutral), ушедший от точки
-- появления дальше LEASH_RANGE, бросает цель и идёт домой. По пути не атакует;
-- если за RETURN_TIMEOUT не дошёл (застрял) — переносится в лагерь.
-- Подчинённые крипы (Helm, Chen) сменили команду и не трогаются; боссы, мины Течиса,
-- курьеры каравана — другие классы юнитов и тоже не трогаются.

if NeutralLeash == nil then
	NeutralLeash = {}
end

LinkLuaModifier("modifier_trinity_neutral_return", "game_managers/neutral_leash", LUA_MODIFIER_MOTION_NONE)

local THINK_INTERVAL = 0.5
local LEASH_RANGE = 1600
local RETURN_DONE_RANGE = 150
local RETURN_THINK = 0.25
local RETURN_TIMEOUT = 8
local CAMP_CREEP_CLASS = "npc_dota_creep_neutral"

local function IsValid(unit)
	return unit ~= nil and not unit:IsNull()
end

function NeutralLeash:IsCampCreep(unit)
	if not IsValid(unit) or unit:GetClassname() ~= CAMP_CREEP_CLASS then
		return false
	end
	if unit:GetTeamNumber() ~= DOTA_TEAM_NEUTRALS then
		return false
	end
	if unit.IsSummoned and unit:IsSummoned() then
		return false
	end
	local owner = unit.GetOwner and unit:GetOwner() or nil
	return owner == nil or not owner.IsBaseNPC or not owner:IsBaseNPC()
end

function NeutralLeash:OnNPCSpawned(keys)
	local unit = keys and keys.entindex and EntIndexToHScript(keys.entindex) or nil
	if not self:IsCampCreep(unit) or unit.trinityLeashHome then
		return
	end
	unit.trinityLeashHome = unit:GetAbsOrigin()
end

function NeutralLeash:Think()
	local units = FindUnitsInRadius(
		DOTA_TEAM_NEUTRALS,
		Vector(0, 0, 0),
		nil,
		FIND_UNITS_EVERYWHERE,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY,
		DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_INVULNERABLE,
		FIND_ANY_ORDER,
		false
	)
	for _, unit in ipairs(units) do
		local home = unit.trinityLeashHome
		if home and unit:IsAlive() and self:IsCampCreep(unit)
			and not unit:HasModifier("modifier_trinity_neutral_return")
			and (unit:GetAbsOrigin() - home):Length2D() > LEASH_RANGE
		then
			unit:AddNewModifier(unit, nil, "modifier_trinity_neutral_return", {})
		end
	end
end

function NeutralLeash:Init()
	if self._initialized then
		return
	end
	self._initialized = true

	ListenToGameEvent("npc_spawned", function(keys)
		NeutralLeash:OnNPCSpawned(keys)
	end, nil)

	Timers:CreateTimer(THINK_INTERVAL, function()
		local ok, err = pcall(NeutralLeash.Think, NeutralLeash)
		if not ok then
			print("[NeutralLeash] think failed: " .. tostring(err))
		end
		return THINK_INTERVAL
	end)
end

-- ---------------------------------------------------------------------------
-- Крип идёт домой

modifier_trinity_neutral_return = class({})

function modifier_trinity_neutral_return:IsHidden()
	return true
end

function modifier_trinity_neutral_return:IsPurgable()
	return false
end

function modifier_trinity_neutral_return:CheckState()
	return {
		[MODIFIER_STATE_DISARMED] = true,
	}
end

function modifier_trinity_neutral_return:OnCreated()
	if not IsServer() then
		return
	end
	local parent = self:GetParent()
	self.home = parent.trinityLeashHome or parent:GetAbsOrigin()
	self.started = GameRules:GetGameTime()
	self:OnIntervalThink()
	self:StartIntervalThink(RETURN_THINK)
end

function modifier_trinity_neutral_return:OnIntervalThink()
	local parent = self:GetParent()
	if not IsValid(parent) or not parent:IsAlive() then
		self:Destroy()
		return
	end
	if (parent:GetAbsOrigin() - self.home):Length2D() <= RETURN_DONE_RANGE then
		self:Destroy()
		return
	end
	if GameRules:GetGameTime() - self.started >= RETURN_TIMEOUT then
		FindClearSpaceForUnit(parent, self.home, true)
		self:Destroy()
		return
	end
	parent:MoveToPosition(self.home)
end

function modifier_trinity_neutral_return:OnDestroy()
	if not IsServer() then
		return
	end
	local parent = self:GetParent()
	if IsValid(parent) and parent:IsAlive() then
		parent:Stop()
	end
end

return NeutralLeash
