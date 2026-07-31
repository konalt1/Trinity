LinkLuaModifier(
	"modifier_ember_searing_chains_trinity",
	"abilities/ember_spirit/ember_searing_chains_trinity",
	LUA_MODIFIER_MOTION_NONE
)

ember_searing_chains_trinity = class({})

function ember_searing_chains_trinity:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_ember_spirit/ember_spirit_searing_chains_cast.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_ember_spirit/ember_spirit_searing_chains_debuff.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ember_spirit.vsndevts", context)
end

function ember_searing_chains_trinity:OnSpellStart()
	local caster = self:GetCaster()
	local radius = self:GetSpecialValueFor("radius")
	local duration = self:GetSpecialValueFor("duration")
	local unit_count = self:GetSpecialValueFor("unit_count")

	local enemies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		caster:GetAbsOrigin(),
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	local cast_particle = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_ember_spirit/ember_spirit_searing_chains_cast.vpcf",
		PATTACH_ABSORIGIN_FOLLOW,
		caster
	)
	ParticleManager:ReleaseParticleIndex(cast_particle)
	caster:EmitSound("Hero_EmberSpirit.SearingChains.Cast")

	for _ = 1, math.min(unit_count, #enemies) do
		local index = RandomInt(1, #enemies)
		local enemy = table.remove(enemies, index)
		local actual_duration = duration * (1 - enemy:GetStatusResistance())

		enemy:AddNewModifier(caster, self, "modifier_ember_searing_chains_trinity", {
			duration = actual_duration,
		})
		enemy:EmitSound("Hero_EmberSpirit.SearingChains.Target")
	end
end

modifier_ember_searing_chains_trinity = class({})

function modifier_ember_searing_chains_trinity:IsDebuff() return true end
function modifier_ember_searing_chains_trinity:IsPurgable() return true end

function modifier_ember_searing_chains_trinity:GetEffectName()
	return "particles/units/heroes/hero_ember_spirit/ember_spirit_searing_chains_debuff.vpcf"
end

function modifier_ember_searing_chains_trinity:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_ember_searing_chains_trinity:CheckState()
	return { [MODIFIER_STATE_ROOTED] = true }
end

function modifier_ember_searing_chains_trinity:OnCreated()
	local ability = self:GetAbility()
	if not ability then return end

	self.tick_interval = ability:GetSpecialValueFor("tick_interval")
	self.damage_per_second = ability:GetSpecialValueFor("damage_per_second")
	self.mind_power_multiplier = ability:GetSpecialValueFor("mind_power_multiplier")

	if not IsServer() then return end

	local caster = self:GetCaster()
	local mind_power = GetHeroMindPower and (GetHeroMindPower(caster) or 0) or 0
	self.damage_per_second = self.damage_per_second + mind_power * self.mind_power_multiplier
	self:StartIntervalThink(self.tick_interval)
end

function modifier_ember_searing_chains_trinity:OnRefresh()
	self:OnCreated()
end

function modifier_ember_searing_chains_trinity:OnIntervalThink()
	local parent = self:GetParent()
	local caster = self:GetCaster()
	local ability = self:GetAbility()
	if not parent or parent:IsNull() or not caster or caster:IsNull() or not ability then return end

	ApplyDamage({
		victim = parent,
		attacker = caster,
		damage = self.damage_per_second * self.tick_interval,
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability = ability,
	})
end
