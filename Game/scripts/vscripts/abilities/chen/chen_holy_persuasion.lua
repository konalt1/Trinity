LinkLuaModifier("modifier_chen_holy_persuasion_custom_buff", "abilities/chen/chen_holy_persuasion", LUA_MODIFIER_MOTION_NONE)

chen_holy_persuasion_custom = class({})
modifier_chen_holy_persuasion_custom_buff = class({})

local function IsValidHolyPersuasionTarget(target, caster)
	if not target or target:IsNull() or not target:IsAlive() then
		return false
	end
	if not target:IsCreep() or target:IsHero() or target:IsAncient() then
		return false
	end
	if target:IsNeutralUnitType() then
		return true
	end
	return target:GetTeamNumber() ~= caster:GetTeamNumber()
end

function chen_holy_persuasion_custom:CastFilterResultTarget(target)
	if IsValidHolyPersuasionTarget(target, self:GetCaster()) then
		return UF_SUCCESS
	end
	return UF_FAIL_CUSTOM
end

function chen_holy_persuasion_custom:GetCustomCastErrorTarget(target)
	return "#dota_hud_error_cant_cast_on_other"
end

function chen_holy_persuasion_custom:OnSpellStart()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	if not IsValidHolyPersuasionTarget(target, caster) then
		return
	end

	local playerID = caster:GetPlayerOwnerID()
	local bonusHealth = self:GetSpecialValueFor("bonus_health")
	local maxHealth = target:GetMaxHealth() + bonusHealth
	local curHealth = target:GetHealth() + bonusHealth

	target:Stop()
	target:SetTeam(caster:GetTeamNumber())
	target:SetOwner(caster)
	target:SetControllableByPlayer(playerID, true)
	if target.SetPlayerID then
		target:SetPlayerID(playerID)
	end

	target:SetBaseMaxHealth(maxHealth)
	target:SetMaxHealth(maxHealth)
	target:SetHealth(math.min(curHealth, maxHealth))

	target:AddNewModifier(caster, self, "modifier_chen_holy_persuasion_custom_buff", {})

	local pfx = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_chen/chen_holy_persuasion.vpcf",
		PATTACH_ABSORIGIN_FOLLOW,
		target
	)
	ParticleManager:SetParticleControlEnt(pfx, 1, caster, PATTACH_POINT_FOLLOW, "attach_attack1", caster:GetAbsOrigin(), true)
	ParticleManager:ReleaseParticleIndex(pfx)

	EmitSoundOn("Hero_Chen.HolyPersuasion", target)
end

function modifier_chen_holy_persuasion_custom_buff:IsHidden()
	return false
end

function modifier_chen_holy_persuasion_custom_buff:IsDebuff()
	return false
end

function modifier_chen_holy_persuasion_custom_buff:IsPurgable()
	return false
end

function modifier_chen_holy_persuasion_custom_buff:RemoveOnDeath()
	return true
end

function modifier_chen_holy_persuasion_custom_buff:GetTexture()
	return "chen_holy_persuasion"
end

function modifier_chen_holy_persuasion_custom_buff:OnCreated()
	if not IsServer() then
		return
	end

	local ability = self:GetAbility()
	if ability and not ability:IsNull() then
		self.bonus_damage = ability:GetSpecialValueFor("bonus_damage")
		self.bounty_share_pct = ability:GetSpecialValueFor("bounty_share_pct")
		self.fallback_bounty = ability:GetSpecialValueFor("fallback_bounty")
		self.chen_entindex = ability:GetCaster():entindex()
	end
end

function modifier_chen_holy_persuasion_custom_buff:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_EVENT_ON_DEATH,
	}
end

function modifier_chen_holy_persuasion_custom_buff:GetModifierPreAttack_BonusDamage()
	return self.bonus_damage or 0
end

function modifier_chen_holy_persuasion_custom_buff:OnDeath(event)
	if not IsServer() then
		return
	end
	if not event.unit or event.unit ~= self:GetParent() then
		return
	end

	local hero = self.chen_entindex and EntIndexToHScript(self.chen_entindex) or nil
	if not hero or hero:IsNull() or not hero:IsRealHero() then
		return
	end

	local parent = self:GetParent()
	local baseBounty = 0
	if parent.GetGoldBounty then
		baseBounty = parent:GetGoldBounty() or 0
	end

	local pct = self.bounty_share_pct or 0
	local gold = math.floor(baseBounty * pct / 100)
	if gold <= 0 and (self.fallback_bounty or 0) > 0 then
		gold = self.fallback_bounty
	end

	if gold > 0 then
		hero:ModifyGold(gold, false, DOTA_ModifyGold_CreepKill)
	end
end
