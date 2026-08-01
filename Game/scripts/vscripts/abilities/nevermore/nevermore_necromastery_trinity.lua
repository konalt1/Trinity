LinkLuaModifier(
	"modifier_nevermore_necromastery",
	"abilities/nevermore/nevermore_necromastery_trinity",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_nevermore_necromastery_armor_aura",
	"abilities/nevermore/nevermore_necromastery_trinity",
	LUA_MODIFIER_MOTION_NONE
)

nevermore_necromastery = class({})

function nevermore_necromastery:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_nevermore/nevermore_souls_hero_effect.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_nevermore/nevermore_necro_souls.vpcf", context)
end

function nevermore_necromastery:GetIntrinsicModifierName()
	return "modifier_nevermore_necromastery"
end

modifier_nevermore_necromastery = class({})

function modifier_nevermore_necromastery:IsHidden() return false end
function modifier_nevermore_necromastery:IsPurgable() return false end
function modifier_nevermore_necromastery:IsDebuff() return false end
function modifier_nevermore_necromastery:RemoveOnDeath() return false end

function modifier_nevermore_necromastery:GetTexture()
	return "nevermore_necromastery"
end

function modifier_nevermore_necromastery:GetEffectName()
	return "particles/units/heroes/hero_nevermore/nevermore_souls_hero_effect.vpcf"
end

function modifier_nevermore_necromastery:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_nevermore_necromastery:IsAura()
	local parent = self:GetParent()
	local ability = self:GetAbility()
	if not parent or parent:IsNull() or not ability or ability:IsNull() then return false end
	if ability:GetLevel() <= 0 then return false end
	if parent:PassivesDisabled() then return false end
	return true
end

function modifier_nevermore_necromastery:GetModifierAura()
	return "modifier_nevermore_necromastery_armor_aura"
end

function modifier_nevermore_necromastery:GetAuraRadius()
	local ability = self:GetAbility()
	if not ability or ability:IsNull() then return 0 end
	return ability:GetSpecialValueFor("aura_radius")
end

function modifier_nevermore_necromastery:GetAuraSearchTeam()
	return DOTA_UNIT_TARGET_TEAM_ENEMY
end

function modifier_nevermore_necromastery:GetAuraSearchType()
	return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC
end

function modifier_nevermore_necromastery:GetAuraSearchFlags()
	return DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES
end

function modifier_nevermore_necromastery:GetAuraDuration()
	return 0.5
end

function modifier_nevermore_necromastery:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_DEATH,
	}
end

function modifier_nevermore_necromastery:GetMaxSouls()
	local ability = self:GetAbility()
	if not ability or ability:IsNull() then return 0 end

	return ability:GetSpecialValueFor("max_souls")
end

function modifier_nevermore_necromastery:GetMindPowerBonus()
	local parent = self:GetParent()
	local ability = self:GetAbility()
	if not ability or ability:IsNull() or parent:PassivesDisabled() then return 0 end

	return self:GetStackCount() * ability:GetSpecialValueFor("mind_power_per_soul")
end

function modifier_nevermore_necromastery:AddSouls(amount)
	if not IsServer() or amount <= 0 then return end

	local new_count = math.min(self:GetStackCount() + amount, self:GetMaxSouls())
	self:SetStackCount(new_count)
end

function modifier_nevermore_necromastery:OnRefresh()
	if not IsServer() then return end

	-- Clamp existing souls when KV values or the ability level change.
	self:SetStackCount(math.min(self:GetStackCount(), self:GetMaxSouls()))
end

function modifier_nevermore_necromastery:OnDeath(params)
	if not IsServer() then return end

	local parent = self:GetParent()
	local dead_unit = params.unit
	local attacker = params.attacker
	local ability = self:GetAbility()
	if not ability or ability:IsNull() then return end

	-- Standard Necromastery release: only a configured share of souls remains.
	if dead_unit == parent then
		-- Requiem must snapshot the souls (and therefore Mind Power) before
		-- Necromastery removes its configured share on death.
		if not parent:IsReincarnating() then
			local requiem = parent:FindAbilityByName("nevermore_requiem_trinity")
			if requiem and not requiem:IsNull() and requiem:GetLevel() > 0 then
				requiem:ReleaseDeathRequiem(self:GetStackCount())
			end
		end

		local souls_released = ability:GetSpecialValueFor("souls_released_on_death_pct") * 0.01
		local souls_retained = 1 - souls_released
		self:SetStackCount(math.floor(self:GetStackCount() * souls_retained))
		return
	end

	if attacker ~= parent or parent:PassivesDisabled() then return end
	if not dead_unit or dead_unit:IsNull() then return end
	if dead_unit:GetTeamNumber() == parent:GetTeamNumber() then return end
	if dead_unit:IsIllusion() or dead_unit:IsTempestDouble() then return end
	if dead_unit:IsBuilding() or dead_unit:IsOther() then return end
	if dead_unit:IsReincarnating() then return end

	local souls = ability:GetSpecialValueFor("souls_per_kill")
	if dead_unit:IsRealHero() then
		souls = ability:GetSpecialValueFor("souls_per_hero_kill")
	end

	self:AddSouls(souls)
	self:PlaySoulEffect(dead_unit)
end

function modifier_nevermore_necromastery:PlaySoulEffect(dead_unit)
	local particle = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_nevermore/nevermore_necro_souls.vpcf",
		PATTACH_ABSORIGIN_FOLLOW,
		dead_unit
	)
	ParticleManager:SetParticleControlEnt(
		particle,
		1,
		self:GetParent(),
		PATTACH_ABSORIGIN_FOLLOW,
		"attach_hitloc",
		self:GetParent():GetAbsOrigin(),
		true
	)
	ParticleManager:ReleaseParticleIndex(particle)
end

--------------------------------------------------------------------------------
-- Аура снижения брони (замена Presence of the Dark Lord на Некромастерии)
--------------------------------------------------------------------------------

modifier_nevermore_necromastery_armor_aura = class({})

function modifier_nevermore_necromastery_armor_aura:IsHidden() return false end
function modifier_nevermore_necromastery_armor_aura:IsDebuff() return true end
function modifier_nevermore_necromastery_armor_aura:IsPurgable() return false end

function modifier_nevermore_necromastery_armor_aura:GetTexture()
	return "nevermore_necromastery"
end

function modifier_nevermore_necromastery_armor_aura:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
	}
end

function modifier_nevermore_necromastery_armor_aura:GetModifierPhysicalArmorBonus()
	local ability = self:GetAbility()
	if not ability or ability:IsNull() then return 0 end
	return -ability:GetSpecialValueFor("armor_reduction")
end

-- GetHeroMindPower() reads custom bonuses through this registry.
MIND_POWER_MODIFIER_REGISTRY = MIND_POWER_MODIFIER_REGISTRY or {}
MIND_POWER_MODIFIER_REGISTRY["modifier_nevermore_necromastery"] = function(modifier)
	local ability = modifier:GetAbility()
	local parent = modifier:GetParent()
	if not ability or ability:IsNull() or not parent or parent:IsNull() or parent:PassivesDisabled() then return 0 end

	return modifier:GetStackCount() * ability:GetSpecialValueFor("mind_power_per_soul")
end
