holy_ground = class({})

LinkLuaModifier("modifier_holy_ground_thinker", "abilities/omniknight/holy_ground", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_holy_ground_slow", "abilities/omniknight/holy_ground", LUA_MODIFIER_MOTION_NONE)

--------------------------------------------------------------------------------
-- Precache
function holy_ground:Precache(context)
	PrecacheResource("particle", "particles/Omniknight/omniknight_guardian_angel_ally_custom.vpcf", context)
	PrecacheResource("particle", "particles/Omniknight/pulse_main.vpcf", context)
	PrecacheResource("particle", "particles/Omniknight/omniknight_purification_custom.vpcf", context)
	PrecacheResource("soundfile", "soundevents/trinity_sounds.vsndevts", context)
end

--------------------------------------------------------------------------------
-- AOE Radius
function holy_ground:GetAOERadius()
	return self:GetSpecialValueFor( "radius" )
end

--------------------------------------------------------------------------------
-- Ability Phase Start (plays during cast animation, BEFORE spell actually casts)
function holy_ground:OnAbilityPhaseStart()
	local caster = self:GetCaster()
	EmitSoundOn("Holy_Ground.Cast", caster)
	return true
end

--------------------------------------------------------------------------------
-- Ability Phase Interrupted (if cast is cancelled, stop the sound)
function holy_ground:OnAbilityPhaseInterrupted()
	local caster = self:GetCaster()
	StopSoundOn("Holy_Ground.Cast", caster)
end

--------------------------------------------------------------------------------
-- Ability Start
function holy_ground:OnSpellStart()
	local caster = self:GetCaster()
	local point = self:GetCursorPosition()

	local radius = self:GetSpecialValueFor("radius")
	local duration = self:GetSpecialValueFor("duration")
	local slow_percent = self:GetSpecialValueFor("slow_percent")
	local heal_amount = self:GetSpecialValueFor("heal_amount")
	local mind_power_multiplier = self:GetSpecialValueFor("mind_power_multiplier")
	local heal_interval = self:GetSpecialValueFor("heal_interval")

	local mind_power = 0
	if GetHeroMindPower then
		mind_power = GetHeroMindPower(caster) or 0
	else
		mind_power = caster:GetIntellect(false) or 0
	end

	local mind_power_bonus = mind_power * mind_power_multiplier
	local total_heal = math.max(0, heal_amount + mind_power_bonus)

	CreateModifierThinker(
		caster,
		self,
		"modifier_holy_ground_thinker",
		{
			duration = duration,
			radius = radius,
			slow_percent = slow_percent,
			total_heal = total_heal,
			heal_interval = heal_interval,
		},
		point,
		caster:GetTeamNumber(),
		false
	)
end

--------------------------------------------------------------------------------
-- Holy Ground Thinker Modifier
--------------------------------------------------------------------------------
modifier_holy_ground_thinker = class({})

function modifier_holy_ground_thinker:IsHidden()
	return true
end

function modifier_holy_ground_thinker:IsPurgable()
	return false
end

function modifier_holy_ground_thinker:OnCreated(kv)
	if not IsServer() then return end

	local ability = self:GetAbility()
	local parent = self:GetParent()

	self.radius = kv.radius or ability:GetSpecialValueFor("radius")
	self.slow_percent = kv.slow_percent or ability:GetSpecialValueFor("slow_percent")
	self.total_heal = kv.total_heal or ability:GetSpecialValueFor("heal_amount")
	self.heal_interval = kv.heal_interval or ability:GetSpecialValueFor("heal_interval")
	self.position = parent:GetAbsOrigin()

	self.particles = {}

	self.cast_particle = ParticleManager:CreateParticle("particles/Omniknight/omniknight_guardian_angel_ally_custom.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(self.cast_particle, 0, self.position)
	ParticleManager:SetParticleControl(self.cast_particle, 1, Vector(self.radius, 0, 0))
	ParticleManager:SetParticleControl(self.cast_particle, 3, Vector(20, 0, 0))

	self:StartIntervalThink(self.heal_interval)

	EmitSoundOn("Holy_Ground.Ambient", parent)
end

function modifier_holy_ground_thinker:OnIntervalThink()
	if not IsServer() then return end

	local pulse_duration = 0.45
	local pulse_particle = ParticleManager:CreateParticle("particles/Omniknight/pulse_main.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(pulse_particle, 0, self.position)
	ParticleManager:SetParticleControl(pulse_particle, 1, Vector(self.radius, self.radius / pulse_duration, 0))
	ParticleManager:SetParticleControl(pulse_particle, 2, Vector(pulse_duration, 0, 0))
	table.insert(self.particles, pulse_particle)

	local allies = FindUnitsInRadius(
		self:GetCaster():GetTeamNumber(),
		self.position,
		nil,
		self.radius,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	local healed_someone = false
	for _, ally in pairs(allies) do
		ally:Heal(self.total_heal, self:GetAbility())
		healed_someone = true

		local heal_particle = ParticleManager:CreateParticle("particles/Omniknight/omniknight_purification_custom.vpcf", PATTACH_ABSORIGIN_FOLLOW, ally)
		ParticleManager:SetParticleControl(heal_particle, 0, ally:GetAbsOrigin())
		ParticleManager:SetParticleControl(heal_particle, 1, Vector(100, 0, 0))
		table.insert(self.particles, heal_particle)
	end

	if healed_someone then
		EmitSoundOnLocationWithCaster(self.position, "Holy_Ground.Bell", self:GetCaster())
	end

	local enemies = FindUnitsInRadius(
		self:GetCaster():GetTeamNumber(),
		self.position,
		nil,
		self.radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	for _, enemy in pairs(enemies) do
		enemy:AddNewModifier(self:GetCaster(), self:GetAbility(), "modifier_holy_ground_slow", {
			duration = self.heal_interval + 0.5,
			slow_percent = self.slow_percent
		})
	end
end

function modifier_holy_ground_thinker:OnDestroy()
	if not IsServer() then return end

	if self.cast_particle then
		ParticleManager:DestroyParticle(self.cast_particle, false)
		ParticleManager:ReleaseParticleIndex(self.cast_particle)
	end

	if self.particles then
		for _, particle in pairs(self.particles) do
			ParticleManager:DestroyParticle(particle, true)
			ParticleManager:ReleaseParticleIndex(particle)
		end
		self.particles = {}
	end

	StopSoundOn("Holy_Ground.Ambient", self:GetParent())
end

--------------------------------------------------------------------------------
-- Holy Ground Slow Modifier
--------------------------------------------------------------------------------
modifier_holy_ground_slow = class({})

function modifier_holy_ground_slow:IsHidden()
	return false
end

function modifier_holy_ground_slow:IsDebuff()
	return true
end

function modifier_holy_ground_slow:IsPurgable()
	return true
end

function modifier_holy_ground_slow:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
	}
	return funcs
end

function modifier_holy_ground_slow:GetModifierMoveSpeedBonus_Percentage()
	return -self.slow_percent
end

function modifier_holy_ground_slow:OnCreated(kv)
	if not IsServer() then return end

	self.slow_percent = kv.slow_percent or 0
	if self.slow_percent == 0 then
		local ability = self:GetAbility()
		if ability then
			self.slow_percent = ability:GetSpecialValueFor("slow_percent") or 0
		end
	end
end
