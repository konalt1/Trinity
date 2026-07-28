-- Ember Spirit: Flame Guard (переработка — пассивный)
-- За каждый стоящий на карте Fire Remnant герой получает заряд.
-- Каждый заряд даёт щит, поглощающий магический урон, и АоЕ урон вокруг героя.

LinkLuaModifier("modifier_ember_flame_guard_passive", "abilities/ember_spirit/ember_flame_guard_passive", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_ember_flame_guard_passive_shield", "abilities/ember_spirit/ember_flame_guard_passive", LUA_MODIFIER_MOTION_NONE)

ember_flame_guard_passive = class({})

function ember_flame_guard_passive:GetIntrinsicModifierName()
	return "modifier_ember_flame_guard_passive"
end

--------------------------------------------------------------------------------
-- Основной пассивный модификатор: считает остатки, наносит АоЕ урон,
-- управляет модификатором щита. StackCount = текущее число зарядов.
--------------------------------------------------------------------------------

modifier_ember_flame_guard_passive = class({})

function modifier_ember_flame_guard_passive:IsHidden() return self:GetStackCount() == 0 end
function modifier_ember_flame_guard_passive:IsPurgable() return false end
function modifier_ember_flame_guard_passive:RemoveOnDeath() return false end
function modifier_ember_flame_guard_passive:IsBuff() return true end

function modifier_ember_flame_guard_passive:GetTexture()
	return "ember_spirit_flame_guard"
end

function modifier_ember_flame_guard_passive:OnCreated()
	if not IsServer() then return end

	self.charges = 0
	self:SetStackCount(0)
	self:StartIntervalThink(0.25)
end

function modifier_ember_flame_guard_passive:CountRemnants()
	local parent = self:GetParent()

	local units = FindUnitsInRadius(
		parent:GetTeamNumber(),
		parent:GetAbsOrigin(),
		nil,
		FIND_UNITS_EVERYWHERE,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY,
		DOTA_UNIT_TARGET_ALL,
		DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_NOT_ILLUSIONS + DOTA_UNIT_TARGET_FLAG_OUT_OF_WORLD,
		FIND_ANY_ORDER,
		false
	)

	local count = 0
	for _, unit in pairs(units) do
		if unit:GetUnitName() == "npc_dota_ember_spirit_remnant" and unit:IsAlive() then
			local ownerID = unit:GetPlayerOwnerID()
			if ownerID == -1 or ownerID == parent:GetPlayerOwnerID() then
				count = count + 1
			end
		end
	end

	return count
end

function modifier_ember_flame_guard_passive:OnIntervalThink()
	local parent = self:GetParent()
	local ability = self:GetAbility()
	if not parent:IsAlive() or ability:GetLevel() == 0 then
		self:UpdateCharges(0)
		return
	end

	self:UpdateCharges(self:CountRemnants())

	if self.charges > 0 then
		self:DealAoeDamage()
	end
end

function modifier_ember_flame_guard_passive:UpdateCharges(new_charges)
	local parent = self:GetParent()
	local ability = self:GetAbility()
	local old_charges = self.charges

	if new_charges == old_charges then return end

	self.charges = new_charges
	self:SetStackCount(new_charges)

	local shield_per_charge = ability:GetSpecialValueFor("shield_per_charge")
	local max_shield = shield_per_charge * new_charges

	local shield_modifier = parent:FindModifierByName("modifier_ember_flame_guard_passive_shield")

	if new_charges == 0 then
		if shield_modifier then
			shield_modifier:Destroy()
		end
		self:DestroyParticle()
		return
	end

	if not shield_modifier then
		shield_modifier = parent:AddNewModifier(parent, ability, "modifier_ember_flame_guard_passive_shield", {})
	end

	if new_charges > old_charges then
		-- Новый остаток поставлен — щит восстанавливается до максимума
		shield_modifier:SetStackCount(max_shield)
	else
		-- Остаток исчез — текущий щит обрезается до нового максимума
		shield_modifier:SetStackCount(math.min(shield_modifier:GetStackCount(), max_shield))
	end

	self:CreateParticle()
end

function modifier_ember_flame_guard_passive:DealAoeDamage()
	local parent = self:GetParent()
	local ability = self:GetAbility()

	local radius = ability:GetSpecialValueFor("radius")
	local dps_per_charge = ability:GetSpecialValueFor("damage_per_second_per_charge")
	local mind_power_multiplier = ability:GetSpecialValueFor("mind_power_multiplier")

	-- Бонус от Силы магии
	local mind_power_value = 0
	local mind_power_modifier = parent:FindModifierByName("modifier_mind_power")
	if mind_power_modifier then
		mind_power_value = mind_power_modifier:GetStackCount()
	end

	local dps = dps_per_charge * self.charges + mind_power_value * mind_power_multiplier
	local tick_damage = dps * 0.25 -- урон за интервал думателя

	local enemies = FindUnitsInRadius(
		parent:GetTeamNumber(),
		parent:GetAbsOrigin(),
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	for _, enemy in pairs(enemies) do
		ApplyDamage({
			victim = enemy,
			attacker = parent,
			damage = tick_damage,
			damage_type = DAMAGE_TYPE_MAGICAL,
			ability = ability,
		})
	end
end

function modifier_ember_flame_guard_passive:CreateParticle()
	if self.particle then return end

	local parent = self:GetParent()
	local radius = self:GetAbility():GetSpecialValueFor("radius")

	self.particle = ParticleManager:CreateParticle("particles/units/heroes/hero_ember_spirit/ember_spirit_flameguard.vpcf", PATTACH_ABSORIGIN_FOLLOW, parent)
	ParticleManager:SetParticleControl(self.particle, 1, Vector(radius, radius, radius))
end

function modifier_ember_flame_guard_passive:DestroyParticle()
	if self.particle then
		ParticleManager:DestroyParticle(self.particle, false)
		ParticleManager:ReleaseParticleIndex(self.particle)
		self.particle = nil
	end
end

function modifier_ember_flame_guard_passive:OnDestroy()
	if not IsServer() then return end
	self:DestroyParticle()
end

--------------------------------------------------------------------------------
-- Модификатор щита: StackCount = оставшийся запас щита.
-- Поглощает магический урон, отображается барьером на полосе здоровья.
--------------------------------------------------------------------------------

modifier_ember_flame_guard_passive_shield = class({})

function modifier_ember_flame_guard_passive_shield:IsHidden() return false end
function modifier_ember_flame_guard_passive_shield:IsPurgable() return false end
function modifier_ember_flame_guard_passive_shield:RemoveOnDeath() return true end
function modifier_ember_flame_guard_passive_shield:IsBuff() return true end

function modifier_ember_flame_guard_passive_shield:GetTexture()
	return "ember_spirit_flame_guard"
end

function modifier_ember_flame_guard_passive_shield:DeclareFunctions()
	return { MODIFIER_PROPERTY_INCOMING_DAMAGE_CONSTANT }
end

function modifier_ember_flame_guard_passive_shield:GetModifierIncomingDamageConstant(params)
	if IsServer() then
		if params.damage_type ~= DAMAGE_TYPE_MAGICAL then
			return 0
		end

		local shield = self:GetStackCount()
		if shield <= 0 then
			return 0
		end

		local block = math.min(params.damage, shield)
		self:SetStackCount(shield - block)
		return -block
	else
		-- На клиенте возвращаем остаток щита — отображается барьером на HP-баре
		return self:GetStackCount()
	end
end
