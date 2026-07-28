-- Shadow Fiend: Shadowraze (переработка)
-- Дебафф стакается не от количества попаданий, а от Силы магии героя:
-- 1 стак за каждые mind_power_per_stack Силы магии.
-- Урон = базовый + стаки * stack_bonus_damage + души Некромастерии * damage_per_soul.

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

local function ShadowrazeSpellStart(self)
	local caster = self:GetCaster()

	local range = self:GetSpecialValueFor("shadowraze_range")
	local radius = self:GetSpecialValueFor("shadowraze_radius")
	local base_damage = self:GetSpecialValueFor("shadowraze_damage")
	local stack_bonus_damage = self:GetSpecialValueFor("stack_bonus_damage")
	local mind_power_per_stack = self:GetSpecialValueFor("mind_power_per_stack")
	local damage_per_soul = self:GetSpecialValueFor("damage_per_soul")
	local duration = self:GetSpecialValueFor("duration")

	local raze_position = caster:GetAbsOrigin() + caster:GetForwardVector() * range

	-- Стаки определяются Силой магии в момент применения
	local stacks = 0
	if mind_power_per_stack > 0 then
		stacks = math.floor(GetCasterMindPower(caster) / mind_power_per_stack)
	end

	-- Бонус от душ Некромастерии (врождённая способность остаётся ванильной)
	local soul_bonus = 0
	local necromastery = caster:FindModifierByName("modifier_nevermore_necromastery")
	if necromastery then
		soul_bonus = necromastery:GetStackCount() * damage_per_soul
	end

	local damage = base_damage + stacks * stack_bonus_damage + soul_bonus

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
		ApplyDamage({
			victim = enemy,
			attacker = caster,
			damage = damage,
			damage_type = DAMAGE_TYPE_MAGICAL,
			ability = self,
		})

		local debuff = enemy:AddNewModifier(caster, self, "modifier_nevermore_shadowraze_trinity_debuff", { duration = duration })
		if debuff then
			debuff:SetStackCount(stacks)
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
-- Дебафф: показывает число стаков от Силы магии, с которым был нанесён удар
--------------------------------------------------------------------------------

modifier_nevermore_shadowraze_trinity_debuff = class({})

function modifier_nevermore_shadowraze_trinity_debuff:IsHidden() return false end
function modifier_nevermore_shadowraze_trinity_debuff:IsDebuff() return true end
function modifier_nevermore_shadowraze_trinity_debuff:IsPurgable() return true end

function modifier_nevermore_shadowraze_trinity_debuff:GetTexture()
	return "nevermore_shadowraze1"
end
