chen_holy_persuasion_custom = class({})

local UNDOMINATABLE_UNITS = {
	["npc_guardian_good"] = true,
	["npc_guardian_bad"] = true,
	["npc_dota_roshan"] = true,
	["npc_dota_roshan_custom"] = true,
	["npc_dota_roshan_pathway"] = true,
	["npc_dota_lich_ice_spire"] = true,
}

local function IsUndominatableTarget(target)
	if not target or target:IsNull() then
		return true
	end

	if target:IsHero() or target:IsBuilding() or target:IsAncient() or target:IsOther() then
		return true
	end

	return UNDOMINATABLE_UNITS[target:GetUnitName()] == true
end

local function GetChenMindPower(hero)
	if GetHeroMindPower then
		return GetHeroMindPower(hero) or 0
	end

	return hero and hero:GetIntellect(false) or 0
end

local function IsValidTamedCreep(creep, caster)
	if not creep or creep:IsNull() or not creep:IsAlive() then
		return false
	end

	return creep.chen_tamed == true and creep.chen_owner_entindex == caster:entindex()
end

local function GetTamedCreeps(caster)
	caster.chen_holy_persuasion_creeps = caster.chen_holy_persuasion_creeps or {}

	local tamedCreeps = {}
	local seen = {}

	for _, creep in ipairs(caster.chen_holy_persuasion_creeps) do
		if IsValidTamedCreep(creep, caster) then
			seen[creep:entindex()] = true
			table.insert(tamedCreeps, creep)
		end
	end

	local units = FindUnitsInRadius(
		caster:GetTeamNumber(),
		caster:GetAbsOrigin(),
		nil,
		FIND_UNITS_EVERYWHERE,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY,
		DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	for _, creep in pairs(units) do
		if IsValidTamedCreep(creep, caster) and not seen[creep:entindex()] then
			table.insert(tamedCreeps, creep)
		end
	end

	table.sort(tamedCreeps, function(a, b)
		return (a.chen_tamed_created_time or 0) < (b.chen_tamed_created_time or 0)
	end)

	caster.chen_holy_persuasion_creeps = tamedCreeps
	return tamedCreeps
end

local function EnforceTamedCreepLimit(caster, maxCreeps)
	if not maxCreeps or maxCreeps <= 0 then
		return
	end

	local tamedCreeps = GetTamedCreeps(caster)
	while #tamedCreeps > maxCreeps do
		local oldest = table.remove(tamedCreeps, 1)
		if oldest and not oldest:IsNull() then
			oldest:ForceKill(false)
			UTIL_Remove(oldest)
		end
	end

	caster.chen_holy_persuasion_creeps = tamedCreeps
end

function chen_holy_persuasion_custom:OnSpellStart()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	
	if not target or target:IsNull() or not target:IsAlive() then
		return
	end

	if IsUndominatableTarget(target) then
		return
	end

	if target:TriggerSpellAbsorb(self) then
		return
	end

	-- Get target properties
	local targetName = target:GetUnitName()
	local targetOrigin = target:GetAbsOrigin()
	local targetForward = target:GetForwardVector()
	local targetTeam = target:GetTeamNumber()
	local playerID = caster:GetPlayerOwnerID()
	local teamNumber = caster:GetTeamNumber()

	-- Get ability values
	local bonusHealth = self:GetSpecialValueFor("bonus_health")
	local bonusDamage = self:GetSpecialValueFor("bonus_damage")
	local bountySharePct = self:GetSpecialValueFor("bounty_share_pct")
	local fallbackBounty = self:GetSpecialValueFor("fallback_bounty")
	local mindPowerHealthMultiplier = self:GetSpecialValueFor("mind_power_health_multiplier")
	local maxCreeps = self:GetSpecialValueFor("max_creeps")
	local mindPowerHealthBonus = math.floor(GetChenMindPower(caster) * mindPowerHealthMultiplier)
	local totalBonusHealth = math.max(0, bonusHealth + mindPowerHealthBonus)

	-- Calculate bounty share
	local targetBounty = target:GetGoldBounty() or fallbackBounty
	local goldReward = math.floor(targetBounty * bountySharePct / 100)

	-- Kill the original creep
	target:ForceKill(false)
	UTIL_Remove(target)

	-- Create new creep on Chen's team
	local newCreep = CreateUnitByName(targetName, targetOrigin, true, caster, caster, teamNumber)
	if not newCreep then
		return
	end

	-- Set ownership
	newCreep:SetOwner(caster)
	newCreep:SetControllableByPlayer(playerID, true)
	if newCreep.SetPlayerID then
		newCreep:SetPlayerID(playerID)
	end

	-- Set orientation
	newCreep:SetForwardVector(targetForward)
	FindClearSpaceForUnit(newCreep, targetOrigin, true)

	-- Apply bonus stats
	local newMaxHealth = math.max(1, newCreep:GetMaxHealth() + totalBonusHealth)
	newCreep:SetBaseMaxHealth(newMaxHealth)
	newCreep:SetMaxHealth(newMaxHealth)
	newCreep:SetHealth(newMaxHealth)
	
	-- Bonus damage
	local baseDamageMin = newCreep:GetBaseDamageMin()
	local baseDamageMax = newCreep:GetBaseDamageMax()
	newCreep:SetBaseDamageMin(baseDamageMin + bonusDamage)
	newCreep:SetBaseDamageMax(baseDamageMax + bonusDamage)

	-- Mark as tamed by Chen
	newCreep.chen_tamed = true
	newCreep.chen_owner_entindex = caster:entindex()
	newCreep.chen_tamed_created_time = GameRules:GetGameTime()
	caster.chen_holy_persuasion_creeps = GetTamedCreeps(caster)
	EnforceTamedCreepLimit(caster, maxCreeps)

	-- Give gold reward immediately
	if goldReward > 0 then
		PlayerResource:ModifyGold(playerID, goldReward, true, DOTA_ModifyGold_CreepKill)
	end

	-- Level up abilities
	for slot = 0, 7 do
		local ability = newCreep:GetAbilityByIndex(slot)
		if ability and ability:GetLevel() == 0 then
			ability:SetLevel(1)
		end
	end

	-- Emit sounds and particles
	EmitSoundOn("Hero_Chen.HolyPersuasion", newCreep)
	local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_chen/chen_holy_persuasion.vpcf", PATTACH_ABSORIGIN_FOLLOW, newCreep)
	ParticleManager:ReleaseParticleIndex(particle)
end

function chen_holy_persuasion_custom:CastFilterResultTarget(target)
	if not target or target:IsNull() then
		return UF_FAIL_CUSTOM
	end

	if IsUndominatableTarget(target) then
		return UF_FAIL_CUSTOM
	end

	if target:GetTeamNumber() == self:GetCaster():GetTeamNumber() then
		return UF_FAIL_CUSTOM
	end

	return UF_SUCCESS
end

function chen_holy_persuasion_custom:GetCustomCastErrorTarget(target)
	if IsUndominatableTarget(target) then
		return "#dota_hud_error_chen_holy_persuasion_invalid_target"
	end
	
	if target:GetTeamNumber() == self:GetCaster():GetTeamNumber() then
		return "#dota_hud_error_chen_holy_persuasion_friendly_target"
	end

	return ""
end
