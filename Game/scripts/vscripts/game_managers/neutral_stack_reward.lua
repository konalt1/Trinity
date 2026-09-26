if NeutralStackReward == nil then
	NeutralStackReward = {}
end

-- GetNeutralSpawners().type: 0 small, 1 medium, 2 large, 3 ancient.
local REWARD_BY_CAMP_TYPE = {
	[0] = { gold = 40, xp = 45 },
	[1] = { gold = 55, xp = 70 },
	[2] = { gold = 80, xp = 100 },
	[3] = { gold = 110, xp = 140 },
}

local STACK_MODIFIER_NAMES = {
	"modifier_stacked_neutral",
	"modifier_neutral_stacked",
}

local CAMP_MATCH_RADIUS = 1200
local SPAWN_WINDOW_SECONDS = 3
local CHECK_DELAYS = { 0.05, 0.2, 0.5, 1.0 }

local function IsAliveUnit(unit)
	return unit and not unit:IsNull() and unit:IsAlive()
end

function NeutralStackReward:IsCampCreep(unit)
	if not IsAliveUnit(unit) then
		return false
	end
	if unit:GetTeamNumber() ~= DOTA_TEAM_NEUTRALS then
		return false
	end
	if unit.IsRealHero and unit:IsRealHero() then
		return false
	end
	if unit.IsCourier and unit:IsCourier() then
		return false
	end
	if unit.IsBuilding and unit:IsBuilding() then
		return false
	end
	if unit.IsCreep and not unit:IsCreep() then
		return false
	end
	return true
end

function NeutralStackReward:ResolveHero(unit)
	if not unit or unit:IsNull() then
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
	if hero and not hero:IsNull() and hero:IsRealHero() and not hero:IsIllusion() then
		return hero
	end
	return nil
end

function NeutralStackReward:FindStackModifier(unit)
	for _, name in ipairs(STACK_MODIFIER_NAMES) do
		local modifier = unit:FindModifierByName(name)
		if modifier then
			return modifier, name
		end
	end

	local count = unit:GetModifierCount() or 0
	for index = 0, count - 1 do
		local name = unit:GetModifierNameByIndex(index)
		if name and string.find(name, "stack", 1, true) then
			local modifier = unit:FindModifierByName(name)
			local caster = modifier and modifier.GetCaster and modifier:GetCaster() or nil
			if modifier and (string.find(name, "stacked", 1, true) or self:ResolveHero(caster)) then
				return modifier, name
			end
		end
	end

	return nil, nil
end

function NeutralStackReward:CampLocation(camp)
	if not camp then
		return nil
	end
	if camp.location then
		return camp.location
	end
	if camp.x and camp.y then
		return Vector(camp.x, camp.y, camp.z or 0)
	end
	return nil
end

function NeutralStackReward:CampContains(origin, camp)
	local boxMin = camp.min
	local boxMax = camp.max
	if not boxMin or not boxMax then
		return false
	end

	local minX = math.min(boxMin.x, boxMax.x)
	local maxX = math.max(boxMin.x, boxMax.x)
	local minY = math.min(boxMin.y, boxMax.y)
	local maxY = math.max(boxMin.y, boxMax.y)
	return origin.x >= minX and origin.x <= maxX and origin.y >= minY and origin.y <= maxY
end

function NeutralStackReward:FindCamp(origin)
	if not GetNeutralSpawners then
		return nil
	end

	local camps = GetNeutralSpawners()
	if not camps then
		return nil
	end

	local contained = nil
	local best = nil
	local bestDistance = nil
	for _, camp in pairs(camps) do
		if self:CampContains(origin, camp) then
			contained = camp
			break
		end

		local location = self:CampLocation(camp)
		if location then
			local distance = (origin - location):Length2D()
			if not bestDistance or distance < bestDistance then
				best = camp
				bestDistance = distance
			end
		end
	end

	if contained then
		return contained
	end
	if best and bestDistance and bestDistance <= CAMP_MATCH_RADIUS then
		return best
	end
	return nil
end

function NeutralStackReward:RewardFor(unit, camp)
	if unit.IsAncient and unit:IsAncient() then
		return REWARD_BY_CAMP_TYPE[3], 3
	end
	if not camp then
		return nil, nil
	end
	local campType = camp.type
	return REWARD_BY_CAMP_TYPE[campType], campType
end

function NeutralStackReward:PayKey(origin, camp)
	local minute = 0
	if GameRules and GameRules.GetDOTATime then
		minute = math.floor(GameRules:GetDOTATime(false, false) / 60)
	end

	local location = self:CampLocation(camp) or origin
	return string.format(
		"%d:%d:%d",
		minute,
		math.floor(location.x + 0.5),
		math.floor(location.y + 0.5)
	)
end

function NeutralStackReward:InSpawnWindow()
	if not GameRules or not GameRules.GetDOTATime then
		return true
	end
	local second = GameRules:GetDOTATime(false, false) % 60
	return second <= SPAWN_WINDOW_SECONDS
end

function NeutralStackReward:Grant(hero, reward)
	hero:ModifyGold(reward.gold, false, DOTA_ModifyGold_Unspecified)
	hero:AddExperience(reward.xp, DOTA_ModifyXP_Unspecified, false, true)
	SendOverheadEventMessage(nil, OVERHEAD_ALERT_GOLD, hero, reward.gold, nil)
	local xpAlert = OVERHEAD_ALERT_XP
	if xpAlert == nil then
		xpAlert = 3
	end
	SendOverheadEventMessage(nil, xpAlert, hero, reward.xp, nil)
end

function NeutralStackReward:HandleCreep(unit)
	if not self:IsCampCreep(unit) then
		return false
	end

	if unit._trinityStackBuffCleared then
		local leftover, leftoverName = self:FindStackModifier(unit)
		if leftover then
			unit:RemoveModifierByName(leftoverName)
		end
		return false
	end

	local modifier, modifierName = self:FindStackModifier(unit)
	if not modifier then
		return false
	end

	local caster = modifier.GetCaster and modifier:GetCaster() or nil
	unit:RemoveModifierByName(modifierName)
	unit._trinityStackBuffCleared = true

	if not self:InSpawnWindow() then
		return false
	end

	local origin = unit:GetAbsOrigin()
	local camp = self:FindCamp(origin)
	local key = self:PayKey(origin, camp)
	if self._paid[key] then
		return false
	end

	local hero = self:ResolveHero(caster)
	local reward, campType = self:RewardFor(unit, camp)
	if not hero or not reward then
		if not self._missPrinted then
			self._missPrinted = true
			local casterName = "nil"
			if caster and not caster:IsNull() and caster.GetUnitName then
				casterName = tostring(caster:GetUnitName())
			end
			print(string.format(
				"[NeutralStack] skip payout modifier=%s caster=%s campType=%s",
				tostring(modifierName),
				casterName,
				tostring(campType)
			))
		end
		return false
	end

	self._paid[key] = true
	self:Grant(hero, reward)
	return false
end

function NeutralStackReward:OnNPCSpawned(keys)
	if not keys or not keys.entindex then
		return
	end

	local unit = EntIndexToHScript(keys.entindex)
	if not self:IsCampCreep(unit) then
		return
	end

	self:HandleCreep(unit)

	local attempt = 0
	Timers:CreateTimer(CHECK_DELAYS[1], function()
		attempt = attempt + 1
		if unit and not unit:IsNull() then
			self:HandleCreep(unit)
		end
		local nextDelay = CHECK_DELAYS[attempt + 1]
		if not nextDelay then
			return nil
		end
		return nextDelay - CHECK_DELAYS[attempt]
	end)
end

function NeutralStackReward:Init()
	if self._initialized then
		return
	end
	self._initialized = true
	self._paid = self._paid or {}

	ListenToGameEvent("npc_spawned", function(keys)
		NeutralStackReward:OnNPCSpawned(keys)
	end, nil)
end

return NeutralStackReward
