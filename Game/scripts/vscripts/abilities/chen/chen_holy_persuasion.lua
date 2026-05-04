LinkLuaModifier("modifier_chen_holy_persuasion_slave", "abilities/chen/chen_holy_persuasion", LUA_MODIFIER_MOTION_NONE)

chen_holy_persuasion_custom = class({})

local function GetTalentValue(hero, talentName, valueName, fallback)
	if not hero or hero:IsNull() then
		return fallback or 0
	end

	local talent = hero:FindAbilityByName(talentName)
	if not talent or talent:IsNull() or talent:GetLevel() <= 0 then
		return fallback or 0
	end

	local value = 0
	if valueName then
		value = talent:GetSpecialValueFor(valueName)
	end
	if value == 0 then
		value = talent:GetSpecialValueFor("value")
	end

	return value or fallback or 0
end

local function IsChenBarrackUnit(unit)
	if not unit or unit:IsNull() then
		return false
	end

	local unitName = unit:GetUnitName() or ""
	return string.find(unitName, "npc_chen_barrack", 1, true) == 1
end

local function IsValidPersuasionTarget(target, caster)
	if not target or target:IsNull() or not target:IsAlive() then
		return false
	end

	if not target:IsCreep() or target:IsHero() or target:IsBuilding() or target:IsAncient() then
		return false
	end

	if IsChenBarrackUnit(target) then
		return false
	end

	return target:GetTeamNumber() ~= caster:GetTeamNumber()
end

local function GetUnitGoldBounty(unit, fallback)
	local bounty = 0
	if unit and not unit:IsNull() and unit.GetGoldBounty then
		bounty = unit:GetGoldBounty() or 0
	end

	if bounty <= 0 then
		bounty = fallback or 0
	end

	return math.max(0, bounty)
end

local function LevelUnitAbilities(unit)
	local count = 6
	if unit and unit.GetAbilityCount then
		count = unit:GetAbilityCount()
	end

	for slot = 0, count - 1 do
		local ability = unit:GetAbilityByIndex(slot)
		if ability and not ability:IsNull() and ability:GetLevel() == 0 then
			ability:SetLevel(1)
		end
	end
end

function chen_holy_persuasion_custom:CastFilterResultTarget(target)
	if IsValidPersuasionTarget(target, self:GetCaster()) then
		return UF_SUCCESS
	end

	return UF_FAIL_CUSTOM
end

function chen_holy_persuasion_custom:GetCustomCastErrorTarget(target)
	return "#dota_hud_error_chen_holy_persuasion_invalid_target"
end

function chen_holy_persuasion_custom:OnSpellStart()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	if not IsValidPersuasionTarget(target, caster) then
		return
	end

	if target:GetTeamNumber() ~= DOTA_TEAM_NEUTRALS and target.TriggerSpellAbsorb and target:TriggerSpellAbsorb(self) then
		return
	end

	local playerID = caster:GetPlayerOwnerID()
	local fallbackBounty = self:GetSpecialValueFor("fallback_bounty")
	local originalBounty = GetUnitGoldBounty(target, fallbackBounty)
	local targetUnitName = target:GetUnitName()
	local targetPos = target:GetAbsOrigin()
	local targetForward = target:GetForwardVector()

	local bonusHealth = self:GetSpecialValueFor("bonus_health")
	local bonusDamage = self:GetSpecialValueFor("bonus_damage")
	bonusHealth = bonusHealth + GetTalentValue(caster, "special_bonus_unique_custom_chen_3", "bonus_health", 0)
	bonusDamage = bonusDamage + GetTalentValue(caster, "special_bonus_unique_custom_chen_4", "bonus_damage", 0)

	if originalBounty > 0 then
		local goldReward = math.floor(originalBounty * self:GetSpecialValueFor("bounty_share_pct") / 100)
		caster:ModifyGold(goldReward, true, DOTA_ModifyGold_CreepKill)
		local player = caster:GetPlayerOwner()
		if player then
			SendOverheadEventMessage(player, OVERHEAD_ALERT_GOLD, caster, goldReward, nil)
		end
	end

	target.chen_skip_bounty_share = true
	UTIL_Remove(target)

	local teamNumber = caster:GetTeamNumber()
	local newCreep = CreateUnitByName(targetUnitName, targetPos, true, caster, caster, teamNumber)

	if not newCreep then
		return
	end

	newCreep:SetOwner(caster)
	newCreep:SetControllableByPlayer(playerID, true)
	if newCreep.SetPlayerID then
		newCreep:SetPlayerID(playerID)
	end
	newCreep:SetForwardVector(targetForward)

	newCreep.chen_original_unit_name = targetUnitName
	newCreep.chen_original_gold_bounty = originalBounty
	newCreep.chen_owner_entindex = caster:entindex()
	newCreep.chen_skip_bounty_share = false

	newCreep:AddNewModifier(caster, self, "modifier_chen_holy_persuasion_slave", {
		bonus_health = bonusHealth,
		bonus_damage = bonusDamage,
		bounty_share_pct = 0,
		original_bounty = 0,
	})

	LevelUnitAbilities(newCreep)

	-- Midas effect
	local midasParticle = ParticleManager:CreateParticle("particles/items2_fx/hand_of_midas.vpcf", PATTACH_ABSORIGIN_FOLLOW, newCreep)
	ParticleManager:SetParticleControlEnt(midasParticle, 0, newCreep, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", newCreep:GetAbsOrigin(), true)
	ParticleManager:SetParticleControlEnt(midasParticle, 1, caster, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)
	ParticleManager:ReleaseParticleIndex(midasParticle)

	-- Dominator effect
	local dominatorParticle = ParticleManager:CreateParticle("particles/items_fx/dominator.vpcf", PATTACH_ABSORIGIN_FOLLOW, newCreep)
	ParticleManager:SetParticleControlEnt(dominatorParticle, 0, newCreep, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", newCreep:GetAbsOrigin(), true)
	ParticleManager:SetParticleControlEnt(dominatorParticle, 1, caster, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)
	ParticleManager:ReleaseParticleIndex(dominatorParticle)

	FindClearSpaceForUnit(newCreep, targetPos, true)
	EmitSoundOn("Hero_Chen.HolyPersuasionEnemy", newCreep)
end

modifier_chen_holy_persuasion_slave = class({})

function modifier_chen_holy_persuasion_slave:IsHidden()
	return false
end

function modifier_chen_holy_persuasion_slave:IsPurgable()
	return false
end

function modifier_chen_holy_persuasion_slave:RemoveOnDeath()
	return true
end

function modifier_chen_holy_persuasion_slave:OnCreated(kv)
	local ability = self:GetAbility()
	self.bonus_health = 0
	self.bonus_damage = 0
	self.bounty_share_pct = 0
	self.original_bounty = 0
	self.owner_entindex = nil

	if ability and not ability:IsNull() then
		self.bonus_health = ability:GetSpecialValueFor("bonus_health")
		self.bonus_damage = ability:GetSpecialValueFor("bonus_damage")
		self.bounty_share_pct = ability:GetSpecialValueFor("bounty_share_pct")
	end

	if kv then
		self.bonus_health = tonumber(kv.bonus_health) or self.bonus_health
		self.bonus_damage = tonumber(kv.bonus_damage) or self.bonus_damage
		self.bounty_share_pct = tonumber(kv.bounty_share_pct) or self.bounty_share_pct
		self.original_bounty = tonumber(kv.original_bounty) or self.original_bounty
	end

	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	local caster = self:GetCaster()
	if caster and not caster:IsNull() then
		self.owner_entindex = caster:entindex()
		parent.chen_owner_entindex = self.owner_entindex
	end

	Timers:CreateTimer(0, function()
		if parent and not parent:IsNull() and parent:IsAlive() then
			parent:SetHealth(math.min(parent:GetMaxHealth(), parent:GetHealth() + self.bonus_health))
		end
	end)
end

function modifier_chen_holy_persuasion_slave:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_EXTRA_HEALTH_BONUS,
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_EVENT_ON_DEATH,
	}
end

function modifier_chen_holy_persuasion_slave:GetModifierExtraHealthBonus()
	return self.bonus_health or 0
end

function modifier_chen_holy_persuasion_slave:GetModifierPreAttack_BonusDamage()
	return self.bonus_damage or 0
end

function modifier_chen_holy_persuasion_slave:OnDeath(params)
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if not params.unit or params.unit ~= parent then
		return
	end

	if parent.chen_skip_bounty_share then
		return
	end

	local owner = nil
	local entindex = self.owner_entindex or parent.chen_owner_entindex
	if entindex then
		owner = EntIndexToHScript(entindex)
	end

	if not owner or owner:IsNull() or not owner:IsRealHero() then
		return
	end

	local bounty = self.original_bounty
	if bounty <= 0 then
		bounty = parent.chen_original_gold_bounty or 0
	end

	local gold = math.floor(bounty * (self.bounty_share_pct or 0) / 100)
	if gold <= 0 then
		return
	end

	owner:ModifyGold(gold, true, DOTA_ModifyGold_CreepKill)
	local player = owner:GetPlayerOwner()
	if player then
		SendOverheadEventMessage(player, OVERHEAD_ALERT_GOLD, owner, gold, nil)
	end
end

function modifier_chen_holy_persuasion_slave:GetEffectName()
	return "particles/units/heroes/hero_chen/chen_holy_persuasion.vpcf"
end

function modifier_chen_holy_persuasion_slave:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end