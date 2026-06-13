if CreepBountyComeback == nil then
	CreepBountyComeback = {}
end

function CreepBountyComeback.IsValidUnit(unit)
	return unit and not unit:IsNull()
end

function CreepBountyComeback.GetOpponentTeam(team)
	if team == DOTA_TEAM_GOODGUYS then
		return DOTA_TEAM_BADGUYS
	end
	if team == DOTA_TEAM_BADGUYS then
		return DOTA_TEAM_GOODGUYS
	end
	return nil
end

function CreepBountyComeback.GetTeamNetWorth(team)
	if not PlayerResource then
		return 0
	end

	local total = 0
	for _, playerID in ipairs(CreepBountyComeback.GetTeamPlayerIDs(team)) do
		if PlayerResource.GetNetWorth then
			total = total + PlayerResource:GetNetWorth(playerID)
		else
			local hero = PlayerResource:GetSelectedHeroEntity(playerID)
			if hero and not hero:IsNull() then
				total = total + hero:GetGold()
			end
		end
	end

	return total
end

function CreepBountyComeback.GetTeamPlayerIDs(team)
	local playerIDs = {}
	if not PlayerResource then
		return playerIDs
	end

	local playerCount = PlayerResource:GetPlayerCount() or 0
	for playerID = 0, playerCount - 1 do
		if PlayerResource:IsValidPlayer(playerID) and PlayerResource:GetTeam(playerID) == team then
			table.insert(playerIDs, playerID)
		end
	end

	return playerIDs
end

function CreepBountyComeback.GetTeamTotalExperience(team)
	if not PlayerResource then
		return 0
	end

	local total = 0
	for _, playerID in ipairs(CreepBountyComeback.GetTeamPlayerIDs(team)) do
		if PlayerResource.GetTotalEarnedXP then
			total = total + (PlayerResource:GetTotalEarnedXP(playerID) or 0)
		else
			local hero = PlayerResource:GetSelectedHeroEntity(playerID)
			if hero and not hero:IsNull() and hero.GetCurrentXP then
				total = total + (hero:GetCurrentXP() or 0)
			end
		end
	end

	return total
end

function CreepBountyComeback.CalculateComebackBonusPct(deficit, maxBonusPct, deficitForMax)
	if deficit <= 0 then
		return 0
	end

	maxBonusPct = maxBonusPct or 50
	deficitForMax = deficitForMax or 5000
	if deficitForMax <= 0 then
		return 0
	end

	return math.min(maxBonusPct, deficit * maxBonusPct / deficitForMax)
end

function CreepBountyComeback.GetBonusPct(team)
	local opponentTeam = CreepBountyComeback.GetOpponentTeam(team)
	if not opponentTeam then
		return 0
	end

	local deficit = CreepBountyComeback.GetTeamNetWorth(opponentTeam) - CreepBountyComeback.GetTeamNetWorth(team)
	return CreepBountyComeback.CalculateComebackBonusPct(
		deficit,
		CREEP_BOUNTY_COMEBACK_MAX_BONUS_PCT,
		CREEP_BOUNTY_COMEBACK_NW_FOR_MAX
	)
end

function CreepBountyComeback.GetExpBonusPct(team)
	local opponentTeam = CreepBountyComeback.GetOpponentTeam(team)
	if not opponentTeam then
		return 0
	end

	local deficit = CreepBountyComeback.GetTeamTotalExperience(opponentTeam) - CreepBountyComeback.GetTeamTotalExperience(team)
	return CreepBountyComeback.CalculateComebackBonusPct(
		deficit,
		CREEP_XP_COMEBACK_MAX_BONUS_PCT,
		CREEP_XP_COMEBACK_XP_FOR_MAX
	)
end

function CreepBountyComeback.GetKillBounty(unit)
	if not CreepBountyComeback.IsValidUnit(unit) then
		return 0
	end

	if unit.GetGoldBounty then
		local bounty = unit:GetGoldBounty()
		if bounty and bounty > 0 then
			return math.floor(bounty)
		end
	end

	local unitName = unit:GetUnitName()
	local minBounty = 0
	local maxBounty = 0

	if GetUnitKeyValue then
		minBounty = tonumber(GetUnitKeyValue(unitName, "BountyGoldMin")) or 0
		maxBounty = tonumber(GetUnitKeyValue(unitName, "BountyGoldMax")) or minBounty
	end

	if maxBounty < minBounty then
		maxBounty = minBounty
	end

	if maxBounty > minBounty then
		return RandomInt(minBounty, maxBounty)
	end

	return math.floor(minBounty)
end

function CreepBountyComeback.GetKillExperience(unit)
	if not CreepBountyComeback.IsValidUnit(unit) then
		return 0
	end

	if unit.GetDeathXP then
		local xp = unit:GetDeathXP()
		if xp and xp > 0 then
			return math.floor(xp)
		end
	end

	if GetUnitKeyValue then
		return math.floor(tonumber(GetUnitKeyValue(unit:GetUnitName(), "BountyXP")) or 0)
	end

	return 0
end

function CreepBountyComeback.IsBountyCreep(unit)
	if not CreepBountyComeback.IsValidUnit(unit) then
		return false
	end

	if unit:IsRealHero() or unit:IsBuilding() or unit:IsCourier() then
		return false
	end

	if unit.IsFort and unit:IsFort() then
		return false
	end

	return true
end

function CreepBountyComeback.GetKillerPlayerID(attacker)
	if not CreepBountyComeback.IsValidUnit(attacker) then
		return -1
	end

	if attacker.IsRealHero and attacker:IsRealHero() then
		local playerID = attacker:GetPlayerID()
		if playerID ~= nil and playerID >= 0 and PlayerResource:IsValidPlayer(playerID) then
			return playerID
		end
	end

	local playerID = attacker:GetPlayerOwnerID()
	if playerID ~= nil and playerID >= 0 and PlayerResource:IsValidPlayer(playerID) then
		return playerID
	end

	local owner = attacker.GetOwnerEntity and attacker:GetOwnerEntity()
	if CreepBountyComeback.IsValidUnit(owner) and owner.IsRealHero and owner:IsRealHero() then
		playerID = owner:GetPlayerID()
		if playerID ~= nil and playerID >= 0 and PlayerResource:IsValidPlayer(playerID) then
			return playerID
		end
	end

	return -1
end

function CreepBountyComeback.ShouldSkipAttacker(attacker)
	if ChenBarrackGold and ChenBarrackGold.IsBarrackUnit and ChenBarrackGold.IsBarrackUnit(attacker) then
		return true
	end

	return false
end

function CreepBountyComeback.OnEntityKilled(event)
	if not event then
		return
	end

	local killed = EntIndexToHScript(event.entindex_killed)
	local attacker = EntIndexToHScript(event.entindex_attacker)

	if not CreepBountyComeback.IsBountyCreep(killed) then
		return
	end

	if not CreepBountyComeback.IsValidUnit(attacker) or CreepBountyComeback.ShouldSkipAttacker(attacker) then
		return
	end

	local playerID = CreepBountyComeback.GetKillerPlayerID(attacker)
	if playerID < 0 then
		return
	end

	local killerTeam = PlayerResource:GetTeam(playerID)
	if killerTeam ~= DOTA_TEAM_GOODGUYS and killerTeam ~= DOTA_TEAM_BADGUYS then
		return
	end

	local baseGold = CreepBountyComeback.GetKillBounty(killed)
	local bonusPct = CreepBountyComeback.GetBonusPct(killerTeam)
	local bonusGold = baseGold > 0 and math.floor(baseGold * bonusPct / 100) or 0
	local baseXP = CreepBountyComeback.GetKillExperience(killed)
	local expBonusPct = CreepBountyComeback.GetExpBonusPct(killerTeam)
	local bonusXP = baseXP > 0 and math.floor(baseXP * expBonusPct / 100) or 0

	local hero = PlayerResource:GetSelectedHeroEntity(playerID)

	if bonusGold > 0 then
		if hero and not hero:IsNull() then
			hero:ModifyGold(bonusGold, false, DOTA_ModifyGold_CreepKill)
		elseif PlayerResource.ModifyGold then
			PlayerResource:ModifyGold(playerID, bonusGold, false, DOTA_ModifyGold_CreepKill)
		end
	end

	if bonusXP > 0 and hero and not hero:IsNull() then
		hero:AddExperience(bonusXP, DOTA_ModifyXP_CreepKill, false, true)
	end
end

function CreepBountyComeback.Init()
	if CreepBountyComeback._initialized then
		return
	end

	CreepBountyComeback._initialized = true
end

return CreepBountyComeback
