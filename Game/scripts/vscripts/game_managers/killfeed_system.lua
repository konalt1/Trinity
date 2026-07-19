KillfeedSystem = KillfeedSystem or {}

-- Reward config. Change these values here, not in gamemode.lua.
KillfeedSystem.HERO_KILL_GOLD_MODE = KillfeedSystem.HERO_KILL_GOLD_MODE or "fixed" -- "level" or "fixed"
KillfeedSystem.FIXED_HERO_KILL_GOLD = KillfeedSystem.FIXED_HERO_KILL_GOLD or 1
KillfeedSystem.LEVEL_GOLD_BASE = KillfeedSystem.LEVEL_GOLD_BASE or 0
KillfeedSystem.LEVEL_GOLD_PER_LEVEL = KillfeedSystem.LEVEL_GOLD_PER_LEVEL or 1
KillfeedSystem.LEVEL_GOLD_MIN = KillfeedSystem.LEVEL_GOLD_MIN or 1
KillfeedSystem.LEVEL_GOLD_MAX = KillfeedSystem.LEVEL_GOLD_MAX or nil
KillfeedSystem.HERO_KILL_GOLD_BY_LEVEL = KillfeedSystem.HERO_KILL_GOLD_BY_LEVEL or {}
KillfeedSystem.HERO_KILL_NET_WORTH_BONUS_MULTIPLIER = KillfeedSystem.HERO_KILL_NET_WORTH_BONUS_MULTIPLIER or 0.3

KillfeedSystem.ASSIST_WINDOW = KillfeedSystem.ASSIST_WINDOW or 10.0
KillfeedSystem.ASSIST_FROM_DAMAGE = KillfeedSystem.ASSIST_FROM_DAMAGE ~= false
KillfeedSystem.ASSIST_FROM_RADIUS = KillfeedSystem.ASSIST_FROM_RADIUS ~= false
KillfeedSystem.ASSIST_RADIUS = KillfeedSystem.ASSIST_RADIUS or 1200
KillfeedSystem.ASSIST_RADIUS_INCLUDE_DEAD = KillfeedSystem.ASSIST_RADIUS_INCLUDE_DEAD == true
KillfeedSystem.ASSIST_FROM_DEBUFFS = KillfeedSystem.ASSIST_FROM_DEBUFFS ~= false
KillfeedSystem.HERO_ASSIST_GOLD_MODE = KillfeedSystem.HERO_ASSIST_GOLD_MODE or "fixed" -- "fixed", "level", or "none"
KillfeedSystem.FIXED_HERO_ASSIST_GOLD = KillfeedSystem.FIXED_HERO_ASSIST_GOLD or 1
KillfeedSystem.LEVEL_ASSIST_GOLD_BASE = KillfeedSystem.LEVEL_ASSIST_GOLD_BASE or 0
KillfeedSystem.LEVEL_ASSIST_GOLD_PER_LEVEL = KillfeedSystem.LEVEL_ASSIST_GOLD_PER_LEVEL or 1
KillfeedSystem.LEVEL_ASSIST_GOLD_MIN = KillfeedSystem.LEVEL_ASSIST_GOLD_MIN or 1
KillfeedSystem.LEVEL_ASSIST_GOLD_MAX = KillfeedSystem.LEVEL_ASSIST_GOLD_MAX or nil
KillfeedSystem.HERO_ASSIST_GOLD_BY_LEVEL = KillfeedSystem.HERO_ASSIST_GOLD_BY_LEVEL or {}
KillfeedSystem.HERO_ASSIST_NET_WORTH_BONUS_MULTIPLIER = KillfeedSystem.HERO_ASSIST_NET_WORTH_BONUS_MULTIPLIER or 0.5

-- Set to a number or function(killedHero, killerHero, actualGold) if the killfeed must show a custom value.
-- Leave nil to show the same gold that the killer receives.
KillfeedSystem.KILLFEED_DISPLAY_GOLD_OVERRIDE = KillfeedSystem.KILLFEED_DISPLAY_GOLD_OVERRIDE or nil

KillfeedSystem.DEBUG = KillfeedSystem.DEBUG == true
KillfeedSystem._allowedHeroKillGold = KillfeedSystem._allowedHeroKillGold or {}
KillfeedSystem._damageRecords = KillfeedSystem._damageRecords or {}
KillfeedSystem._initialized = KillfeedSystem._initialized or false

function KillfeedSystem:Debug(message)
	if not self.DEBUG then
		return
	end

	Msg("[KillfeedSystem] " .. tostring(message) .. "\n")
end

function KillfeedSystem:IsValidEntity(entity)
	return entity ~= nil and (not entity.IsNull or not entity:IsNull())
end

function KillfeedSystem:IsRealHero(entity)
	if not self:IsValidEntity(entity) then
		return false
	end
	if not entity.IsRealHero or not entity:IsRealHero() then
		return false
	end
	if entity.IsIllusion and entity:IsIllusion() then
		return false
	end

	return true
end

function KillfeedSystem:IsValidPlayerID(playerID)
	playerID = tonumber(playerID)
	if playerID == nil or playerID < 0 then
		return false
	end

	if PlayerResource and PlayerResource.IsValidPlayerID then
		return PlayerResource:IsValidPlayerID(playerID)
	end

	return true
end

function KillfeedSystem:GetPlayerHero(playerID)
	if not self:IsValidPlayerID(playerID) then
		return nil
	end

	local hero = PlayerResource and PlayerResource.GetSelectedHeroEntity and PlayerResource:GetSelectedHeroEntity(playerID)
	if self:IsValidEntity(hero) then
		return hero
	end

	return nil
end

function KillfeedSystem:GetHeroLevel(hero)
	if not self:IsValidEntity(hero) or not hero.GetLevel then
		return 1
	end

	local level = tonumber(hero:GetLevel()) or 1
	if level < 1 then
		level = 1
	end

	return level
end

function KillfeedSystem:GetHeroNetWorth(hero)
	local playerID = self:GetHeroPlayerID(hero)
	if not self:IsValidPlayerID(playerID) then
		return 0
	end

	if PlayerResource and PlayerResource.GetNetWorth then
		return math.max(0, tonumber(PlayerResource:GetNetWorth(playerID)) or 0)
	end

	return 0
end

function KillfeedSystem:NormalizeGold(gold)
	gold = math.floor(tonumber(gold) or 0)
	if gold < 0 then
		gold = 0
	end

	return gold
end

function KillfeedSystem:GetGameTime()
	if GameRules and GameRules.GetGameTime then
		return GameRules:GetGameTime()
	end
	if Time then
		return Time()
	end

	return 0
end

function KillfeedSystem:GetHeroKillGoldForLevel(level)
	level = math.floor(tonumber(level) or 1)
	if level < 1 then
		level = 1
	end

	local byLevel = self.HERO_KILL_GOLD_BY_LEVEL[level]
	if byLevel ~= nil then
		return self:NormalizeGold(byLevel)
	end

	local gold = (tonumber(self.LEVEL_GOLD_BASE) or 0) + level * (tonumber(self.LEVEL_GOLD_PER_LEVEL) or 0)
	gold = self:NormalizeGold(gold)

	local minGold = tonumber(self.LEVEL_GOLD_MIN)
	if minGold ~= nil and gold < minGold then
		gold = minGold
	end

	local maxGold = tonumber(self.LEVEL_GOLD_MAX)
	if maxGold ~= nil and gold > maxGold then
		gold = maxGold
	end

	return self:NormalizeGold(gold)
end

function KillfeedSystem:GetGoldForLevel(level, byLevelTable, baseGold, goldPerLevel, minGold, maxGold)
	level = math.floor(tonumber(level) or 1)
	if level < 1 then
		level = 1
	end

	if byLevelTable and byLevelTable[level] ~= nil then
		return self:NormalizeGold(byLevelTable[level])
	end

	local gold = (tonumber(baseGold) or 0) + level * (tonumber(goldPerLevel) or 0)
	gold = self:NormalizeGold(gold)

	minGold = tonumber(minGold)
	if minGold ~= nil and gold < minGold then
		gold = minGold
	end

	maxGold = tonumber(maxGold)
	if maxGold ~= nil and gold > maxGold then
		gold = maxGold
	end

	return self:NormalizeGold(gold)
end

function KillfeedSystem:GetHeroKillGoldReward(killedHero, killerHero)
	local baseGold = 0
	if self.HERO_KILL_GOLD_MODE == "fixed" then
		baseGold = self:NormalizeGold(self.FIXED_HERO_KILL_GOLD)
	else
		baseGold = self:GetHeroKillGoldForLevel(self:GetHeroLevel(killedHero))
	end

	local netWorthBonus = self:GetHeroNetWorth(killedHero) * (tonumber(self.HERO_KILL_NET_WORTH_BONUS_MULTIPLIER) or 0)
	return self:NormalizeGold(baseGold + netWorthBonus)
end

function KillfeedSystem:GetHeroAssistGoldReward(killedHero, assisterHero, killerHero)
	if self.HERO_ASSIST_GOLD_MODE == "none" then
		return 0
	end

	local baseGold = 0
	if self.HERO_ASSIST_GOLD_MODE == "level" then
		baseGold = self:GetGoldForLevel(
			self:GetHeroLevel(killedHero),
			self.HERO_ASSIST_GOLD_BY_LEVEL,
			self.LEVEL_ASSIST_GOLD_BASE,
			self.LEVEL_ASSIST_GOLD_PER_LEVEL,
			self.LEVEL_ASSIST_GOLD_MIN,
			self.LEVEL_ASSIST_GOLD_MAX
		)
	else
		baseGold = self:NormalizeGold(self.FIXED_HERO_ASSIST_GOLD)
	end

	local netWorthBonus = self:GetHeroNetWorth(killedHero) * (tonumber(self.HERO_ASSIST_NET_WORTH_BONUS_MULTIPLIER) or 0)
	return self:NormalizeGold(baseGold + netWorthBonus)
end

function KillfeedSystem:GetKillfeedGoldReward(killedHero, killerHero, actualGold)
	local override = self.KILLFEED_DISPLAY_GOLD_OVERRIDE
	if type(override) == "function" then
		return self:NormalizeGold(override(killedHero, killerHero, actualGold))
	end
	if override ~= nil then
		return self:NormalizeGold(override)
	end

	return self:NormalizeGold(actualGold)
end

function KillfeedSystem:SetFixedHeroKillGold(gold)
	self.HERO_KILL_GOLD_MODE = "fixed"
	self.FIXED_HERO_KILL_GOLD = self:NormalizeGold(gold)
end

function KillfeedSystem:SetLevelHeroKillGold(baseGold, goldPerLevel, minGold, maxGold)
	self.HERO_KILL_GOLD_MODE = "level"
	self.LEVEL_GOLD_BASE = tonumber(baseGold) or 0
	self.LEVEL_GOLD_PER_LEVEL = tonumber(goldPerLevel) or 0
	self.LEVEL_GOLD_MIN = minGold ~= nil and tonumber(minGold) or nil
	self.LEVEL_GOLD_MAX = maxGold ~= nil and tonumber(maxGold) or nil
end

function KillfeedSystem:SetHeroKillGoldByLevel(level, gold)
	level = math.floor(tonumber(level) or 0)
	if level < 1 then
		return
	end

	self.HERO_KILL_GOLD_MODE = "level"
	self.HERO_KILL_GOLD_BY_LEVEL[level] = self:NormalizeGold(gold)
end

function KillfeedSystem:SetFixedHeroAssistGold(gold)
	self.HERO_ASSIST_GOLD_MODE = "fixed"
	self.FIXED_HERO_ASSIST_GOLD = self:NormalizeGold(gold)
end

function KillfeedSystem:SetLevelHeroAssistGold(baseGold, goldPerLevel, minGold, maxGold)
	self.HERO_ASSIST_GOLD_MODE = "level"
	self.LEVEL_ASSIST_GOLD_BASE = tonumber(baseGold) or 0
	self.LEVEL_ASSIST_GOLD_PER_LEVEL = tonumber(goldPerLevel) or 0
	self.LEVEL_ASSIST_GOLD_MIN = minGold ~= nil and tonumber(minGold) or nil
	self.LEVEL_ASSIST_GOLD_MAX = maxGold ~= nil and tonumber(maxGold) or nil
end

function KillfeedSystem:SetHeroAssistGoldByLevel(level, gold)
	level = math.floor(tonumber(level) or 0)
	if level < 1 then
		return
	end

	self.HERO_ASSIST_GOLD_MODE = "level"
	self.HERO_ASSIST_GOLD_BY_LEVEL[level] = self:NormalizeGold(gold)
end

function KillfeedSystem:SetHeroAssistGoldDisabled()
	self.HERO_ASSIST_GOLD_MODE = "none"
end

function KillfeedSystem:SetAssistRadius(radius, includeDead)
	self.ASSIST_RADIUS = tonumber(radius) or self.ASSIST_RADIUS
	self.ASSIST_RADIUS_INCLUDE_DEAD = includeDead == true
end

function KillfeedSystem:SetAssistSources(fromDamage, fromRadius, fromDebuffs)
	if fromDamage ~= nil then
		self.ASSIST_FROM_DAMAGE = fromDamage == true
	end
	if fromRadius ~= nil then
		self.ASSIST_FROM_RADIUS = fromRadius == true
	end
	if fromDebuffs ~= nil then
		self.ASSIST_FROM_DEBUFFS = fromDebuffs == true
	end
end

function KillfeedSystem:ResolveKillerHero(unit)
	if not self:IsValidEntity(unit) then
		return nil
	end

	if self:IsRealHero(unit) then
		return unit
	end

	local owner = unit.GetOwner and unit:GetOwner()
	if self:IsRealHero(owner) then
		return owner
	end

	local ownerEntity = unit.GetOwnerEntity and unit:GetOwnerEntity()
	if self:IsRealHero(ownerEntity) then
		return ownerEntity
	end

	local playerOwner = unit.GetPlayerOwner and unit:GetPlayerOwner()
	if self:IsValidEntity(playerOwner) and playerOwner.GetAssignedHero then
		local assignedHero = playerOwner:GetAssignedHero()
		if self:IsRealHero(assignedHero) then
			return assignedHero
		end
	end

	local playerID = unit.GetPlayerOwnerID and unit:GetPlayerOwnerID() or -1
	return self:GetPlayerHero(playerID)
end

function KillfeedSystem:ApplyHeroKillBounty(hero)
	if not self:IsRealHero(hero) then
		return
	end

	local reward = self:GetHeroKillGoldReward(hero, nil)
	if hero.SetMinimumGoldBounty then
		hero:SetMinimumGoldBounty(reward)
	end
	if hero.SetMaximumGoldBounty then
		hero:SetMaximumGoldBounty(reward)
	end
end

function KillfeedSystem:OnNPCSpawned(npc)
	self:ApplyHeroKillBounty(npc)
end

function KillfeedSystem:OnEntityHurt(keys)
	if not keys then
		return
	end

	local victimIndex = keys.entindex_killed or keys.entindex_victim or keys.entindex_target
	local attackerIndex = keys.entindex_attacker
	if not victimIndex or not attackerIndex then
		return
	end

	local victim = EntIndexToHScript(victimIndex)
	local attacker = EntIndexToHScript(attackerIndex)
	if not self:IsRealHero(victim) then
		return
	end

	local attackerHero = self:ResolveKillerHero(attacker)
	if not self:IsRealHero(attackerHero) then
		return
	end
	if attackerHero == victim then
		return
	end
	if attackerHero.GetTeamNumber and victim.GetTeamNumber and attackerHero:GetTeamNumber() == victim:GetTeamNumber() then
		return
	end

	local attackerPlayerID = attackerHero.GetPlayerOwnerID and attackerHero:GetPlayerOwnerID() or -1
	if not self:IsValidPlayerID(attackerPlayerID) then
		return
	end

	local victimEntIndex = victim:entindex()
	self._damageRecords[victimEntIndex] = self._damageRecords[victimEntIndex] or {}
	self._damageRecords[victimEntIndex][attackerPlayerID] = self:GetGameTime()
end

function KillfeedSystem:OnPlayerGainedLevel(keys)
	if not keys then
		return
	end

	local playerID = keys.player_id or keys.PlayerID or keys.playerid
	self:ApplyHeroKillBounty(self:GetPlayerHero(playerID))
end

function KillfeedSystem:AllowHeroKillGold(playerID, gold)
	playerID = tonumber(playerID)
	gold = self:NormalizeGold(gold)
	if playerID == nil or gold <= 0 then
		return
	end

	self._allowedHeroKillGold[playerID] = (self._allowedHeroKillGold[playerID] or 0) + gold
end

function KillfeedSystem:ConsumeAllowedHeroKillGold(playerID, gold)
	playerID = tonumber(playerID)
	gold = self:NormalizeGold(gold)
	if playerID == nil or gold <= 0 then
		return false
	end

	local allowedGold = self._allowedHeroKillGold[playerID] or 0
	if allowedGold < gold then
		return false
	end

	allowedGold = allowedGold - gold
	self._allowedHeroKillGold[playerID] = allowedGold > 0 and allowedGold or nil
	return true
end

function KillfeedSystem:ClearAllowedHeroKillGold(playerID)
	playerID = tonumber(playerID)
	if playerID == nil then
		return
	end

	self._allowedHeroKillGold[playerID] = nil
end

function KillfeedSystem:GetHeroPlayerID(hero)
	if not self:IsValidEntity(hero) or not hero.GetPlayerOwnerID then
		return -1
	end

	return hero:GetPlayerOwnerID()
end

function KillfeedSystem:IsSameTeam(hero, team)
	return team ~= nil and hero and hero.GetTeamNumber and hero:GetTeamNumber() == team
end

function KillfeedSystem:AddAssistPlayerID(assistPlayerIDs, seenPlayerIDs, playerID, killedHero, killerPlayerID, killerTeam)
	playerID = tonumber(playerID)
	if not self:IsValidPlayerID(playerID) then
		return false
	end
	if playerID == killerPlayerID or seenPlayerIDs[playerID] then
		return false
	end

	local hero = self:GetPlayerHero(playerID)
	if not self:IsRealHero(hero) then
		return false
	end
	if killerTeam ~= nil and not self:IsSameTeam(hero, killerTeam) then
		return false
	end
	if killedHero and killedHero.GetTeamNumber and self:IsSameTeam(hero, killedHero:GetTeamNumber()) then
		return false
	end

	seenPlayerIDs[playerID] = true
	table.insert(assistPlayerIDs, playerID)
	return true
end

function KillfeedSystem:AddAssistHero(assistPlayerIDs, seenPlayerIDs, hero, killedHero, killerPlayerID, killerTeam)
	if not self:IsRealHero(hero) then
		return false
	end

	return self:AddAssistPlayerID(
		assistPlayerIDs,
		seenPlayerIDs,
		self:GetHeroPlayerID(hero),
		killedHero,
		killerPlayerID,
		killerTeam
	)
end

function KillfeedSystem:GetModifierCasterHero(modifier)
	if not modifier then
		return nil
	end

	local caster = nil
	if modifier.GetCaster then
		caster = modifier:GetCaster()
	end
	if not self:IsValidEntity(caster) and modifier.GetAbility then
		local ability = modifier:GetAbility()
		if ability and ability.GetCaster then
			caster = ability:GetCaster()
		end
	end

	return self:ResolveKillerHero(caster)
end

function KillfeedSystem:IsNegativeModifierFromEnemy(modifier, killedHero, killerTeam)
	if not modifier or not modifier.IsDebuff or not modifier:IsDebuff() then
		return false
	end

	local casterHero = self:GetModifierCasterHero(modifier)
	if not self:IsRealHero(casterHero) then
		return false
	end
	if killerTeam ~= nil and not self:IsSameTeam(casterHero, killerTeam) then
		return false
	end
	if killedHero and killedHero.GetTeamNumber and self:IsSameTeam(casterHero, killedHero:GetTeamNumber()) then
		return false
	end

	return true
end

function KillfeedSystem:AddDamageAssistPlayerIDs(assistPlayerIDs, seenPlayerIDs, killedHero, killerPlayerID, killerTeam)
	if not self.ASSIST_FROM_DAMAGE then
		return
	end

	local victimEntIndex = killedHero:entindex()
	local records = self._damageRecords[victimEntIndex]
	if not records then
		return
	end

	local now = self:GetGameTime()
	for playerID, timestamp in pairs(records) do
		if now - timestamp <= self.ASSIST_WINDOW then
			self:AddAssistPlayerID(assistPlayerIDs, seenPlayerIDs, playerID, killedHero, killerPlayerID, killerTeam)
		end
	end
end

function KillfeedSystem:AddRadiusAssistPlayerIDs(assistPlayerIDs, seenPlayerIDs, killedHero, killerPlayerID, killerTeam)
	if not self.ASSIST_FROM_RADIUS then
		return
	end
	if not self:IsValidEntity(killedHero) or not killedHero.GetAbsOrigin then
		return
	end

	local radius = tonumber(self.ASSIST_RADIUS) or 0
	if radius <= 0 then
		return
	end

	local origin = killedHero:GetAbsOrigin()
	local maxPlayers = DOTA_MAX_PLAYERS or 64
	for playerID = 0, maxPlayers - 1 do
		if playerID ~= killerPlayerID and self:IsValidPlayerID(playerID) then
			local hero = self:GetPlayerHero(playerID)
			if self:IsRealHero(hero)
				and (self.ASSIST_RADIUS_INCLUDE_DEAD or not hero.IsAlive or hero:IsAlive())
				and hero.GetAbsOrigin
				and (hero:GetAbsOrigin() - origin):Length2D() <= radius then
				self:AddAssistHero(assistPlayerIDs, seenPlayerIDs, hero, killedHero, killerPlayerID, killerTeam)
			end
		end
	end
end

function KillfeedSystem:AddDebuffAssistPlayerIDs(assistPlayerIDs, seenPlayerIDs, killedHero, killerPlayerID, killerTeam)
	if not self.ASSIST_FROM_DEBUFFS then
		return
	end
	if not self:IsValidEntity(killedHero) or not killedHero.FindAllModifiers then
		return
	end

	for _, modifier in pairs(killedHero:FindAllModifiers()) do
		if self:IsNegativeModifierFromEnemy(modifier, killedHero, killerTeam) then
			self:AddAssistHero(
				assistPlayerIDs,
				seenPlayerIDs,
				self:GetModifierCasterHero(modifier),
				killedHero,
				killerPlayerID,
				killerTeam
			)
		end
	end
end

function KillfeedSystem:ModifyGoldFilter(data)
	if not data or data.reason_const ~= DOTA_ModifyGold_HeroKill then
		return true
	end

	local playerID = data.player_id_const or data.player_id or data.PlayerID
	local gold = tonumber(data.gold) or 0

	if self:ConsumeAllowedHeroKillGold(playerID, gold) then
		self:Debug("allowed custom hero kill gold player=" .. tostring(playerID) .. " gold=" .. tostring(gold))
		return true
	end

	self:Debug("blocked native hero kill gold player=" .. tostring(playerID) .. " gold=" .. tostring(gold))
	data.gold = 0
	return true
end

function KillfeedSystem:GetAssistPlayerIDs(killedHero, killerPlayerID)
	local assistPlayerIDs = {}
	if not self:IsRealHero(killedHero) then
		return assistPlayerIDs
	end

	local seenPlayerIDs = {}
	local killerHero = self:GetPlayerHero(killerPlayerID)
	local killerTeam = killerHero and killerHero.GetTeamNumber and killerHero:GetTeamNumber() or nil

	self:AddDamageAssistPlayerIDs(assistPlayerIDs, seenPlayerIDs, killedHero, killerPlayerID, killerTeam)
	self:AddRadiusAssistPlayerIDs(assistPlayerIDs, seenPlayerIDs, killedHero, killerPlayerID, killerTeam)
	self:AddDebuffAssistPlayerIDs(assistPlayerIDs, seenPlayerIDs, killedHero, killerPlayerID, killerTeam)

	return assistPlayerIDs
end

function KillfeedSystem:ClearDamageRecord(killedHero)
	if not self:IsValidEntity(killedHero) or not killedHero.entindex then
		return
	end

	self._damageRecords[killedHero:entindex()] = nil
end

function KillfeedSystem:GrantHeroAssistGold(killedHero, killerHero, killerPlayerID)
	local assistPlayerIDs = self:GetAssistPlayerIDs(killedHero, killerPlayerID)
	if #assistPlayerIDs <= 0 then
		return 0, 0
	end

	local assistGold = self:GetHeroAssistGoldReward(killedHero, nil, killerHero)
	if assistGold <= 0 then
		return 0, 0
	end

	for _, playerID in pairs(assistPlayerIDs) do
		local assistHero = self:GetPlayerHero(playerID)
		local reward = self:GetHeroAssistGoldReward(killedHero, assistHero, killerHero)
		if reward > 0 and self:IsRealHero(assistHero) then
			self:AllowHeroKillGold(playerID, reward)
			assistHero:ModifyGold(reward, true, DOTA_ModifyGold_HeroKill)
			self:ClearAllowedHeroKillGold(playerID)
		end
	end

	return assistGold, #assistPlayerIDs
end

function KillfeedSystem:SendKillfeedEvent(killerHero, killedHero, actualGold, assistGold, assistCount)
	if not CustomGameEventManager then
		return
	end

	local killerPlayerID = killerHero.GetPlayerOwnerID and killerHero:GetPlayerOwnerID() or -1
	local killedPlayerID = killedHero.GetPlayerOwnerID and killedHero:GetPlayerOwnerID() or -1
	local displayGold = self:GetKillfeedGoldReward(killedHero, killerHero, actualGold)

	CustomGameEventManager:Send_ServerToAllClients("trinity_kill_toast", {
		killer_player = killerPlayerID,
		killed_player = killedPlayerID,
		killer_name = PlayerResource:GetPlayerName(killerPlayerID) or "",
		killed_name = PlayerResource:GetPlayerName(killedPlayerID) or "",
		killer_hero = killerHero:GetUnitName(),
		killed_hero = killedHero:GetUnitName(),
		killed_level = self:GetHeroLevel(killedHero),
		gold = displayGold,
		assist_gold = self:NormalizeGold(assistGold),
		assist_count = self:NormalizeGold(assistCount),
	})
end

function KillfeedSystem:GrantHeroKillGold(keys, killedHero)
	if not self:IsRealHero(killedHero) then
		return
	end
	if not keys or not keys.entindex_attacker then
		return
	end

	local attacker = EntIndexToHScript(keys.entindex_attacker)
	local killerHero = self:ResolveKillerHero(attacker)
	if not self:IsRealHero(killerHero) then
		return
	end
	if killerHero == killedHero then
		return
	end
	if killerHero.GetTeamNumber and killedHero.GetTeamNumber and killerHero:GetTeamNumber() == killedHero:GetTeamNumber() then
		return
	end

	local killerPlayerID = killerHero.GetPlayerOwnerID and killerHero:GetPlayerOwnerID() or -1
	local killedPlayerID = killedHero.GetPlayerOwnerID and killedHero:GetPlayerOwnerID() or -1
	if not self:IsValidPlayerID(killerPlayerID) or killerPlayerID == killedPlayerID then
		return
	end

	local reward = self:GetHeroKillGoldReward(killedHero, killerHero)
	if reward <= 0 then
		return
	end

	self:AllowHeroKillGold(killerPlayerID, reward)
	killerHero:ModifyGold(reward, true, DOTA_ModifyGold_HeroKill)
	self:ClearAllowedHeroKillGold(killerPlayerID)

	local assistGold, assistCount = self:GrantHeroAssistGold(killedHero, killerHero, killerPlayerID)
	self:SendKillfeedEvent(killerHero, killedHero, reward, assistGold, assistCount)
	self:ClearDamageRecord(killedHero)
	self:Debug(
		"hero kill reward killer=" .. tostring(killerPlayerID)
		.. " killed=" .. tostring(killedPlayerID)
		.. " killed_level=" .. tostring(self:GetHeroLevel(killedHero))
		.. " gold=" .. tostring(reward)
		.. " assist_gold=" .. tostring(assistGold)
		.. " assists=" .. tostring(assistCount)
	)
end

function KillfeedSystem:OnEntityKilled(keys, killedUnit)
	self:GrantHeroKillGold(keys, killedUnit)
end

function KillfeedSystem:Init()
	if self._initialized then
		return
	end

	self._initialized = true
	ListenToGameEvent("entity_hurt", function(keys)
		KillfeedSystem:OnEntityHurt(keys)
	end, nil)
	ListenToGameEvent("dota_player_gained_level", function(keys)
		KillfeedSystem:OnPlayerGainedLevel(keys)
	end, nil)

	self:Debug("loaded")
end

return KillfeedSystem
