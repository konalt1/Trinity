modifier_chen_martyr_mark_creep = class({})

function modifier_chen_martyr_mark_creep:IsHidden()
	return false
end

function modifier_chen_martyr_mark_creep:IsDebuff()
	return false
end

function modifier_chen_martyr_mark_creep:IsPurgable()
	return true
end

function modifier_chen_martyr_mark_creep:OnCreated(kv)
	self.as_bonus = 0
	self.target = nil

	local ability = self:GetAbility()
	if ability and not ability:IsNull() then
		self.as_bonus = ability:GetSpecialValueFor("creep_bonus_as")
		self.interval = ability:GetSpecialValueFor("attack_refresh_interval")
	end

	if self.interval <= 0 then
		self.interval = 0.4
	end

	local ent = kv and kv.target_entindex
	if ent then
		self.target = EntIndexToHScript(tonumber(ent) or ent)
	end

	self:StartIntervalThink(self.interval)
	if IsServer() and self.target and not self.target:IsNull() and self.target:IsAlive() then
		self:GetParent():MoveToTargetToAttack(self.target)
	end
end

function modifier_chen_martyr_mark_creep:OnRefresh(kv)
	local ability = self:GetAbility()
	if ability and not ability:IsNull() then
		self.as_bonus = ability:GetSpecialValueFor("creep_bonus_as")
		self.interval = ability:GetSpecialValueFor("attack_refresh_interval")
	end
	local ent = kv and kv.target_entindex
	if ent then
		self.target = EntIndexToHScript(tonumber(ent) or ent)
	end
end

function modifier_chen_martyr_mark_creep:OnIntervalThink()
	if not IsServer() then
		return
	end

	local target = self.target
	if not target or target:IsNull() or not target:IsAlive() then
		self:Destroy()
		return
	end

	local parent = self:GetParent()
	if not parent or parent:IsNull() or not parent:IsAlive() then
		self:Destroy()
		return
	end

	parent:MoveToTargetToAttack(target)
end

function modifier_chen_martyr_mark_creep:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
	}
end

function modifier_chen_martyr_mark_creep:GetModifierAttackSpeedBonus_Constant()
	return self.as_bonus or 0
end
