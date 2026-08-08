-- Ember Spirit: Flame Guard (переработка — пассивный)
-- За атаку по крипу герой получает 1 заряд, по герою — 3 (до максимума). Если некоторое время
-- не атаковать, заряды сгорают. Каждый заряд даёт щит, поглощающий магический
-- урон, и АоЕ урон вокруг героя. Удары пополняют щит.

LinkLuaModifier("modifier_ember_flame_guard_passive", "abilities/ember_spirit/ember_flame_guard_passive", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_ember_flame_guard_passive_shield", "abilities/ember_spirit/ember_flame_guard_passive", LUA_MODIFIER_MOTION_NONE)

local FLAME_GUARD_PARTICLE = "particles/econ/items/ember_spirit/ember_ti9/ember_ti9_flameguard.vpcf"

ember_flame_guard_passive = class({})

function ember_flame_guard_passive:Precache(context)
	PrecacheResource("particle", FLAME_GUARD_PARTICLE, context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ember_spirit.vsndevts", context)
end

function ember_flame_guard_passive:GetIntrinsicModifierName()
	return "modifier_ember_flame_guard_passive"
end

--------------------------------------------------------------------------------
-- Основной пассивный модификатор: копит заряды от ударов, наносит АоЕ урон,
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

function modifier_ember_flame_guard_passive:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
end

function modifier_ember_flame_guard_passive:OnCreated()
	if not IsServer() then return end

	self.charges = 0
	self.expire_time = 0
	self:SetStackCount(0)
	self:StartIntervalThink(0.25)
end

function modifier_ember_flame_guard_passive:OnAttackLanded(params)
	if not IsServer() then return end

	local parent = self:GetParent()
	if params.attacker ~= parent then return end
	if parent:IsIllusion() then return end
	if self:GetAbility():GetLevel() == 0 then return end

	local target = params.target
	if not target or target:IsBuilding() or target:IsOther() then return end
	if target:GetTeamNumber() == parent:GetTeamNumber() then return end

	local ability = self:GetAbility()
	local charge_count = target:IsHero()
		and ability:GetSpecialValueFor("charges_per_hero_attack")
		or ability:GetSpecialValueFor("charges_per_creep_attack")

	self:GainCharge(charge_count)
end

function modifier_ember_flame_guard_passive:GainCharge(charge_count)
	local parent = self:GetParent()
	local ability = self:GetAbility()

	local max_charges = ability:GetSpecialValueFor("max_charges")
	local charge_duration = ability:GetSpecialValueFor("charge_duration")
	local shield_per_charge = ability:GetSpecialValueFor("shield_per_charge")

	self.charges = math.min(self.charges + charge_count, max_charges)
	self.expire_time = GameRules:GetGameTime() + charge_duration
	self:SetStackCount(self.charges)

	local max_shield = shield_per_charge * self.charges

	local shield_modifier = parent:FindModifierByName("modifier_ember_flame_guard_passive_shield")
	if not shield_modifier then
		shield_modifier = parent:AddNewModifier(parent, ability, "modifier_ember_flame_guard_passive_shield", {})
	end

	-- Удар пополняет щит на величину полученных зарядов (до текущего максимума)
	shield_modifier:SetStackCount(math.min(shield_modifier:GetStackCount() + shield_per_charge * charge_count, max_shield))

	self:CreateParticle()
end

function modifier_ember_flame_guard_passive:ResetCharges()
	local parent = self:GetParent()

	if self.charges == 0 then return end

	self.charges = 0
	self:SetStackCount(0)

	local shield_modifier = parent:FindModifierByName("modifier_ember_flame_guard_passive_shield")
	if shield_modifier then
		shield_modifier:Destroy()
	end

	self:DestroyParticle()
end

function modifier_ember_flame_guard_passive:OnIntervalThink()
	local parent = self:GetParent()
	local ability = self:GetAbility()

	if not parent:IsAlive() or ability:GetLevel() == 0 then
		self:ResetCharges()
		return
	end

	-- Заряды сгорают, если герой давно не атаковал
	if self.charges > 0 and GameRules:GetGameTime() >= self.expire_time then
		self:ResetCharges()
		return
	end

	if self.charges > 0 then
		self:DealAoeDamage()
	end
end

function modifier_ember_flame_guard_passive:DealAoeDamage()
	local parent = self:GetParent()
	local ability = self:GetAbility()

	local radius = ability:GetSpecialValueFor("radius")
	local dps_per_charge = ability:GetSpecialValueFor("damage_per_second_per_charge")
	local mind_power_multiplier = ability:GetSpecialValueFor("mind_power_multiplier")

	-- Бонус от Силы магии
	local mind_power_value = GetHeroMindPower and (GetHeroMindPower(parent) or 0) or 0

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

	self.particle = ParticleManager:CreateParticle(FLAME_GUARD_PARTICLE, PATTACH_ABSORIGIN_FOLLOW, parent)
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
	return {
		MODIFIER_PROPERTY_INCOMING_SPELL_DAMAGE_CONSTANT,
		MODIFIER_PROPERTY_TOTALDAMAGEOUTGOING_PERCENTAGE,
	}
end

function modifier_ember_flame_guard_passive_shield:GetModifierTotalDamageOutgoing_Percentage(params)
	params = params or {}
	if self:GetStackCount() <= 0 then return 0 end
	if params.attacker and params.attacker ~= self:GetParent() then return 0 end

	local damage_type = params.damage_type or params.damagetype_const
	if damage_type ~= DAMAGE_TYPE_MAGICAL then return 0 end

	local ability = self:GetAbility()
	if not ability or ability:IsNull() then return 0 end

	local parent = self:GetParent()
	local mind_power = GetHeroMindPower and (GetHeroMindPower(parent) or 0) or 0
	local multiplier = ability:GetSpecialValueFor("magic_damage_amp_mind_power_multiplier")
	return math.max(0, mind_power * multiplier)
end

function modifier_ember_flame_guard_passive_shield:GetModifierIncomingSpellDamageConstant(params)
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
