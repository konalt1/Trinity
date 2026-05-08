chen_holy_persuasion_custom = class({})

function chen_holy_persuasion_custom:OnSpellStart()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	
	if not target or target:IsNull() or not target:IsAlive() then
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
	newCreep:SetBaseMaxHealth(newCreep:GetMaxHealth() + bonusHealth)
	newCreep:SetMaxHealth(newCreep:GetMaxHealth() + bonusHealth)
	newCreep:SetHealth(newCreep:GetMaxHealth())
	
	-- Bonus damage
	local baseDamageMin = newCreep:GetBaseDamageMin()
	local baseDamageMax = newCreep:GetBaseDamageMax()
	newCreep:SetBaseDamageMin(baseDamageMin + bonusDamage)
	newCreep:SetBaseDamageMax(baseDamageMax + bonusDamage)

	-- Mark as tamed by Chen
	newCreep.chen_tamed = true
	newCreep.chen_owner_entindex = caster:entindex()

	-- Give gold reward immediately
	if goldReward > 0 then
		PlayerResource:ModifyGold(playerID, goldReward, true, DOTA_ModifyGold_CreepKill)
	end

	-- Level up abilities
	for slot = 0, 15 do
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

	if target:IsHero() or target:IsBuilding() or target:IsAncient() then
		return UF_FAIL_CUSTOM
	end

	if target:GetTeamNumber() == self:GetCaster():GetTeamNumber() then
		return UF_FAIL_CUSTOM
	end

	return UF_SUCCESS
end

function chen_holy_persuasion_custom:GetCustomCastErrorTarget(target)
	if target:IsHero() or target:IsBuilding() or target:IsAncient() then
		return "#dota_hud_error_chen_holy_persuasion_invalid_target"
	end
	
	if target:GetTeamNumber() == self:GetCaster():GetTeamNumber() then
		return "#dota_hud_error_chen_holy_persuasion_friendly_target"
	end

	return ""
end
