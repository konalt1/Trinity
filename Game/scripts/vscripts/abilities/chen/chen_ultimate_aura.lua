LinkLuaModifier("modifier_chen_ultimate_aura", "abilities/chen/chen_ultimate_aura", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_ultimate_aura_buff", "abilities/chen/chen_ultimate_aura", LUA_MODIFIER_MOTION_NONE)

chen_ultimate_aura = class({})

function chen_ultimate_aura:GetIntrinsicModifierName()
	local caster = self:GetCaster()
	if caster and not caster:IsNull() and HasShard(caster) then
		return "modifier_chen_ultimate_aura"
	end

	return nil
end

local function ArePassivesDisabled(unit)
	return unit and unit.PassivesDisabled and unit:PassivesDisabled()
end

local function GetChenMindPower(chen)
	if not chen or chen:IsNull() then
		return 0
	end

	if GetHeroMindPower then
		return GetHeroMindPower(chen) or 0
	end

	return chen:GetIntellect(false) or 0
end

local function CalculateChenUltimateAuraBonuses(caster, ability)
	if not caster or caster:IsNull() or not ability or ability:IsNull() then
		return 0, 0
	end

	if not HasShard(caster) or ArePassivesDisabled(caster) then
		return 0, 0
	end

	local baseHealth = ability:GetSpecialValueFor("bonus_health")
	local healthMultiplier = ability:GetSpecialValueFor("mind_power_health_multiplier")
	local baseDamage = ability:GetSpecialValueFor("bonus_damage")
	local damageMultiplier = ability:GetSpecialValueFor("mind_power_damage_multiplier")
	local mindPower = GetChenMindPower(caster)

	local bonusHealth = baseHealth + mindPower * healthMultiplier
	local bonusDamage = baseDamage + mindPower * damageMultiplier

	return bonusHealth, bonusDamage
end

local function SyncChenUltimateAuraBuffValues(modifier)
	if not IsServer() then
		return
	end

	local bonusHealth, bonusDamage = CalculateChenUltimateAuraBonuses(modifier:GetCaster(), modifier:GetAbility())
	local stackDamage = math.floor(bonusDamage)
	local valuesChanged = modifier.bonus_health ~= bonusHealth
		or modifier.bonus_damage ~= bonusDamage
		or modifier:GetStackCount() ~= stackDamage

	modifier.bonus_health = bonusHealth
	modifier.bonus_damage = bonusDamage

	if valuesChanged then
		modifier:SetStackCount(stackDamage)
		modifier:SendBuffRefreshToClients()
	end
end

modifier_chen_ultimate_aura = class({})

function modifier_chen_ultimate_aura:IsHidden()
	return false
end

function modifier_chen_ultimate_aura:IsPurgable()
	return false
end

function modifier_chen_ultimate_aura:IsDebuff()
	return false
end

function modifier_chen_ultimate_aura:RemoveOnDeath()
	return true
end

function modifier_chen_ultimate_aura:OnCreated()
	if not IsServer() then
		return
	end

	if not HasShard(self:GetParent()) then
		self:Destroy()
	end
end

function modifier_chen_ultimate_aura:IsAura()
	local parent = self:GetParent()
	if not parent or parent:IsNull() then
		return false
	end

	if IsServer() then
		if not parent:IsAlive() then
			return false
		end

		if not HasShard(parent) or ArePassivesDisabled(parent) then
			return false
		end
	end

	return true
end

function modifier_chen_ultimate_aura:GetModifierAura()
	return "modifier_chen_ultimate_aura_buff"
end

function modifier_chen_ultimate_aura:GetAuraRadius()
	local ability = self:GetAbility()
	if ability and not ability:IsNull() then
		return ability:GetSpecialValueFor("aura_radius")
	end

	return 1000
end

function modifier_chen_ultimate_aura:GetAuraSearchTeam()
	return DOTA_UNIT_TARGET_TEAM_FRIENDLY
end

function modifier_chen_ultimate_aura:GetAuraSearchType()
	return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC
end

function modifier_chen_ultimate_aura:GetAuraSearchFlags()
	return DOTA_UNIT_TARGET_FLAG_NONE
end

function modifier_chen_ultimate_aura:GetTexture()
	return "chen_divine_favor"
end

modifier_chen_ultimate_aura_buff = class({})

function modifier_chen_ultimate_aura_buff:IsHidden()
	return false
end

function modifier_chen_ultimate_aura_buff:IsPurgable()
	return false
end

function modifier_chen_ultimate_aura_buff:IsDebuff()
	return false
end

function modifier_chen_ultimate_aura_buff:RemoveOnDeath()
	return true
end

function modifier_chen_ultimate_aura_buff:GetTexture()
	return "chen_divine_favor"
end

function modifier_chen_ultimate_aura_buff:OnCreated()
	self.bonus_health = 0
	self.bonus_damage = 0

	if not IsServer() then
		return
	end

	self:SetHasCustomTransmitterData(true)
	SyncChenUltimateAuraBuffValues(self)
	self:StartIntervalThink(0.5)
end

function modifier_chen_ultimate_aura_buff:OnRefresh()
	if IsServer() then
		SyncChenUltimateAuraBuffValues(self)
	end
end

function modifier_chen_ultimate_aura_buff:OnIntervalThink()
	SyncChenUltimateAuraBuffValues(self)
end

function modifier_chen_ultimate_aura_buff:AddCustomTransmitterData()
	return {
		bonus_health = self.bonus_health or 0,
	}
end

function modifier_chen_ultimate_aura_buff:HandleCustomTransmitterData(data)
	self.bonus_health = data.bonus_health or 0
end

function modifier_chen_ultimate_aura_buff:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_EXTRA_HEALTH_BONUS,
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_TOOLTIP,
		MODIFIER_PROPERTY_TOOLTIP2,
	}
end

function modifier_chen_ultimate_aura_buff:GetModifierExtraHealthBonus()
	return self.bonus_health or 0
end

function modifier_chen_ultimate_aura_buff:GetModifierPreAttack_BonusDamage()
	if IsServer() then
		return self.bonus_damage or 0
	end

	return self:GetStackCount()
end

function modifier_chen_ultimate_aura_buff:OnTooltip()
	if IsServer() then
		return math.floor(self.bonus_damage or 0)
	end

	return self:GetStackCount()
end

function modifier_chen_ultimate_aura_buff:OnTooltip2()
	return math.floor(self.bonus_health or 0)
end
