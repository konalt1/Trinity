-- Shadow Fiend: vanilla Shadowraze with Trinity Mind Power scaling.
-- Damage = base damage + existing Shadowraze stacks * stack damage
--          + caster Mind Power * mind power multiplier.

LinkLuaModifier("modifier_nevermore_shadowraze_trinity_debuff", "abilities/nevermore/nevermore_shadowraze_trinity", LUA_MODIFIER_MOTION_NONE)

local function GetCasterMindPower(caster)
	local mind_power_modifier = caster:FindModifierByName("modifier_mind_power")
	if mind_power_modifier then
		return mind_power_modifier:GetStackCount()
	end
	if GetHeroMindPower then
		return GetHeroMindPower(caster)
	end
	return 0
end

local function HasAghanimShard(unit)
	if HasShard then
		return HasShard(unit)
	end
	return unit and not unit:IsNull() and unit:HasModifier("modifier_item_aghanims_shard")
end

local function ShadowrazeSpellStart(self)
	local caster = self:GetCaster()

	local range = self:GetSpecialValueFor("shadowraze_range")
	local radius = self:GetSpecialValueFor("shadowraze_radius")
	local base_damage = self:GetSpecialValueFor("shadowraze_damage")
	local stack_bonus_damage = self:GetSpecialValueFor("stack_bonus_damage")
	local mind_power_multiplier = self:GetSpecialValueFor("mind_power_multiplier")
	local duration = self:GetSpecialValueFor("duration")

	local raze_position = caster:GetAbsOrigin() + caster:GetForwardVector() * range
	local mind_power_damage = GetCasterMindPower(caster) * mind_power_multiplier
	local shard_hero_hits = 0

	-- Эффекты
	local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_nevermore/nevermore_shadowraze.vpcf", PATTACH_WORLDORIGIN, caster)
	ParticleManager:SetParticleControl(particle, 0, raze_position)
	ParticleManager:ReleaseParticleIndex(particle)
	EmitSoundOnLocationWithCaster(raze_position, "Hero_Nevermore.Shadowraze", caster)

	local enemies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		raze_position,
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	for _, enemy in pairs(enemies) do
		if HasAghanimShard(caster) and enemy:IsRealHero() and not enemy:IsIllusion() then
			shard_hero_hits = shard_hero_hits + 1
		end

		-- Vanilla stacking: the current hit benefits from stacks applied by
		-- previous Shadowrazes, then adds one stack for the next hit.
		local debuff = enemy:FindModifierByName("modifier_nevermore_shadowraze_trinity_debuff")
		local existing_stacks = debuff and debuff:GetStackCount() or 0
		local damage = math.max(0, base_damage + existing_stacks * stack_bonus_damage + mind_power_damage)

		ApplyDamage({
			victim = enemy,
			attacker = caster,
			damage = damage,
			damage_type = DAMAGE_TYPE_MAGICAL,
			ability = self,
		})

		local debuff_duration = duration * (1 - enemy:GetStatusResistance())
		if debuff and not debuff:IsNull() then
			debuff:SetDuration(debuff_duration, true)
			debuff:SetStackCount(existing_stacks + 1)
		else
			debuff = enemy:AddNewModifier(caster, self, "modifier_nevermore_shadowraze_trinity_debuff", { duration = debuff_duration })
			if debuff then
				debuff:SetStackCount(1)
			end
		end
	end

	if shard_hero_hits > 0 then
		local reduction = shard_hero_hits * self:GetSpecialValueFor("shard_cooldown_reduction")
		local remaining = self:GetCooldownTimeRemaining()
		self:EndCooldown()
		if remaining > reduction then
			self:StartCooldown(remaining - reduction)
		end
	end
end

-- Подстраховка на случай, если LinkedAbility не синхронизирует уровни
local function ShadowrazeSyncLevels(self)
	local caster = self:GetCaster()
	local level = self:GetLevel()
	local raze_names = { "nevermore_shadowraze1_trinity", "nevermore_shadowraze2_trinity", "nevermore_shadowraze3_trinity" }

	for _, name in pairs(raze_names) do
		local raze = caster:FindAbilityByName(name)
		if raze and raze ~= self and raze:GetLevel() < level then
			raze:SetLevel(level)
		end
	end
end

nevermore_shadowraze1_trinity = class({})
nevermore_shadowraze2_trinity = class({})
nevermore_shadowraze3_trinity = class({})

nevermore_shadowraze1_trinity.OnSpellStart = ShadowrazeSpellStart
nevermore_shadowraze2_trinity.OnSpellStart = ShadowrazeSpellStart
nevermore_shadowraze3_trinity.OnSpellStart = ShadowrazeSpellStart

nevermore_shadowraze1_trinity.OnUpgrade = ShadowrazeSyncLevels
nevermore_shadowraze2_trinity.OnUpgrade = ShadowrazeSyncLevels
nevermore_shadowraze3_trinity.OnUpgrade = ShadowrazeSyncLevels

--------------------------------------------------------------------------------
-- Vanilla hit counter shared by all three Shadowrazes.
--------------------------------------------------------------------------------

modifier_nevermore_shadowraze_trinity_debuff = class({})

function modifier_nevermore_shadowraze_trinity_debuff:IsHidden() return false end
function modifier_nevermore_shadowraze_trinity_debuff:IsDebuff() return true end
function modifier_nevermore_shadowraze_trinity_debuff:IsPurgable() return true end

function modifier_nevermore_shadowraze_trinity_debuff:GetTexture()
	return "nevermore_shadowraze1"
end

function modifier_nevermore_shadowraze_trinity_debuff:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
	}
end

function modifier_nevermore_shadowraze_trinity_debuff:GetModifierMoveSpeedBonus_Percentage()
	local caster = self:GetCaster()
	local ability = self:GetAbility()
	if not ability or ability:IsNull() or not HasAghanimShard(caster) then return 0 end

	return -self:GetStackCount() * ability:GetSpecialValueFor("shard_slow_per_stack")
end

function modifier_nevermore_shadowraze_trinity_debuff:GetModifierPhysicalArmorBonus()
	local caster = self:GetCaster()
	local ability = self:GetAbility()
	if not ability or ability:IsNull() or not HasAghanimShard(caster) then return 0 end

	return -self:GetStackCount() * ability:GetSpecialValueFor("shard_armor_reduction_per_stack")
end
