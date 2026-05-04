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
	self.attack_speed = 0
	self.interval = 0.4
	self.force_attack = 0
	self.target = nil

	local ability = self:GetAbility()
	if ability and not ability:IsNull() then
		self.attack_speed = ability:GetSpecialValueFor("attack_speed")
		if self.attack_speed == 0 then
			self.attack_speed = ability:GetSpecialValueFor("creep_bonus_as")
		end
		self.interval = ability:GetSpecialValueFor("attack_refresh_interval")
	end

	if kv then
		self.attack_speed = tonumber(kv.attack_speed) or self.attack_speed
		self.interval = tonumber(kv.attack_refresh_interval) or self.interval
		self.force_attack = tonumber(kv.force_attack) or 0

		if kv.target_entindex then
			self.target = EntIndexToHScript(tonumber(kv.target_entindex))
		end
	end

	if self.interval <= 0 then
		self.interval = 0.4
	end

	if IsServer() then
		self:StartIntervalThink(self.interval)
		self:OnIntervalThink()
	end
end

function modifier_chen_martyr_mark_creep:OnRefresh(kv)
	self:OnCreated(kv)
end

function modifier_chen_martyr_mark_creep:OnDestroy()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if parent and not parent:IsNull() and parent.SetForceAttackTarget then
		parent:SetForceAttackTarget(nil)
	end
end

function modifier_chen_martyr_mark_creep:ForceAttackTarget()
	if not IsServer() or self.force_attack ~= 1 then
		return
	end

	local parent = self:GetParent()
	local target = self.target
	if not parent or parent:IsNull() or not parent:IsAlive() then
		self:Destroy()
		return
	end
	if not target or target:IsNull() or not target:IsAlive() then
		self:Destroy()
		return
	end

	if parent.SetForceAttackTarget then
		parent:SetForceAttackTarget(nil)
	end

	ExecuteOrderFromTable({
		UnitIndex = parent:entindex(),
		OrderType = DOTA_UNIT_ORDER_ATTACK_TARGET,
		TargetIndex = target:entindex(),
		Queue = false,
	})
end

function modifier_chen_martyr_mark_creep:OnIntervalThink()
	self:ForceAttackTarget()
end

function modifier_chen_martyr_mark_creep:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
	}
end

function modifier_chen_martyr_mark_creep:GetModifierAttackSpeedBonus_Constant()
	return self.attack_speed or 0
end

function modifier_chen_martyr_mark_creep:GetEffectName()
	return "particles/units/heroes/hero_chen/chen_penitence.vpcf"
end

function modifier_chen_martyr_mark_creep:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end