-- Ванильный Sleight of Fist. При получении шарда оба заряда сразу становятся полными.

LinkLuaModifier("modifier_ember_spirit_sleight_of_fist_shard_refresh", "abilities/ember_spirit/ember_spirit_sleight_of_fist", LUA_MODIFIER_MOTION_NONE)

local SHARD_MODIFIER = "modifier_item_aghanims_shard"
local CHARGE_POLL_INTERVAL = 0.03
local CHARGE_POLL_TRIES = 30

ember_spirit_sleight_of_fist = class({})

function ember_spirit_sleight_of_fist:GetIntrinsicModifierName()
	return "modifier_ember_spirit_sleight_of_fist_shard_refresh"
end

modifier_ember_spirit_sleight_of_fist_shard_refresh = class({})

function modifier_ember_spirit_sleight_of_fist_shard_refresh:IsHidden()
	return true
end

function modifier_ember_spirit_sleight_of_fist_shard_refresh:IsPurgable()
	return false
end

function modifier_ember_spirit_sleight_of_fist_shard_refresh:RemoveOnDeath()
	return false
end

function modifier_ember_spirit_sleight_of_fist_shard_refresh:OnCreated()
	if not IsServer() then
		return
	end
	if self:GetParent():HasModifier(SHARD_MODIFIER) then
		self:QueueChargeRefresh()
	end
end

function modifier_ember_spirit_sleight_of_fist_shard_refresh:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_MODIFIER_ADDED,
	}
end

function modifier_ember_spirit_sleight_of_fist_shard_refresh:OnModifierAdded(keys)
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if not keys or keys.unit ~= parent then
		return
	end

	local added = keys.added_buff
	if not added or added:IsNull() or added:GetName() ~= SHARD_MODIFIER then
		return
	end

	self:QueueChargeRefresh()
end

function modifier_ember_spirit_sleight_of_fist_shard_refresh:QueueChargeRefresh()
	self.refresh_tries = 0
	self:StartIntervalThink(CHARGE_POLL_INTERVAL)
end

function modifier_ember_spirit_sleight_of_fist_shard_refresh:ShardChargeCap(ability)
	local level = ability:GetLevel()
	local max_charges = ability:GetMaxAbilityCharges(level)
	if max_charges < 2 and level > 1 then
		max_charges = ability:GetMaxAbilityCharges(level - 1)
	end
	return max_charges
end

function modifier_ember_spirit_sleight_of_fist_shard_refresh:OnIntervalThink()
	local ability = self:GetAbility()
	local parent = self:GetParent()
	if not ability or ability:IsNull() or not parent or parent:IsNull() or not parent:HasModifier(SHARD_MODIFIER) then
		self:StartIntervalThink(-1)
		return
	end

	if ability:GetLevel() < 1 then
		self:StartIntervalThink(0.25)
		return
	end

	if self:ShardChargeCap(ability) < 2 then
		self.refresh_tries = (self.refresh_tries or 0) + 1
		self:StartIntervalThink(CHARGE_POLL_INTERVAL)
		if self.refresh_tries >= CHARGE_POLL_TRIES then
			self:StartIntervalThink(-1)
		end
		return
	end

	ability:RefreshCharges()
	self:StartIntervalThink(-1)
end
