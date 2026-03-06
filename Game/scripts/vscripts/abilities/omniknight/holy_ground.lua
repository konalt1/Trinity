holy_ground = class({})

LinkLuaModifier("modifier_holy_ground_thinker", "abilities/omniknight/holy_ground", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_holy_ground_slow", "abilities/omniknight/holy_ground", LUA_MODIFIER_MOTION_NONE)

local OMNI_HOLY_GROUND_FOLLOW_TALENT = "special_bonus_unique_custom_omniknight_6"

local function HasFollowTalent(caster)
	if not caster or caster:IsNull() then return false end
	local talent = caster:FindAbilityByName(OMNI_HOLY_GROUND_FOLLOW_TALENT)
	return talent and not talent:IsNull() and talent:GetLevel() > 0
end

--------------------------------------------------------------------------------
-- Precache
function holy_ground:Precache(context)
	-- Precache custom particles
	PrecacheResource("particle", "particles/Omniknight/omniknight_guardian_angel_ally_custom.vpcf", context)
	PrecacheResource("particle", "particles/Omniknight/pulse_main.vpcf", context)
	PrecacheResource("particle", "particles/Omniknight/omniknight_purification_custom.vpcf", context)
	
	-- Precache custom sounds
	PrecacheResource("soundfile", "soundevents/trinity_sounds.vsndevts", context)
end

--------------------------------------------------------------------------------
-- Dynamic behavior: NO_TARGET when follow talent is active
function holy_ground:GetBehavior()
	if HasFollowTalent(self:GetCaster()) then
		return DOTA_ABILITY_BEHAVIOR_NO_TARGET
	end
	return DOTA_ABILITY_BEHAVIOR_POINT + DOTA_ABILITY_BEHAVIOR_AOE
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
	
	-- Play "Deus Vult" sound during cast animation (before spell fires)
	EmitSoundOn("Holy_Ground.Cast", caster)
	
	return true -- must return true to continue casting
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
	-- unit identifier
	local caster = self:GetCaster()
	local follow_caster = HasFollowTalent(caster)
	local point = follow_caster and caster:GetAbsOrigin() or self:GetCursorPosition()

	-- load data
	local radius = self:GetSpecialValueFor("radius")
	local duration = self:GetSpecialValueFor("duration")
	local slow_percent = self:GetSpecialValueFor("slow_percent")
	local heal_amount = self:GetSpecialValueFor("heal_amount")
	local mind_power_multiplier = self:GetSpecialValueFor("mind_power_multiplier")
	local heal_interval = self:GetSpecialValueFor("heal_interval")
	
	-- Calculate Mind Power bonus
	local mind_power = 0
	if GetHeroMindPower then
		mind_power = GetHeroMindPower(caster) or 0
	else
		mind_power = caster:GetIntellect(false) or 0
	end
	
	-- Calculate total heal with Mind Power scaling
	local mind_power_bonus = mind_power * mind_power_multiplier
	local total_heal = math.max(0, heal_amount + mind_power_bonus)
	
	-- Create thinker for the holy ground area
	CreateModifierThinker(
		caster, -- player responsible
		self, -- ability responsible
		"modifier_holy_ground_thinker", -- modifier name
		{ 
			duration = duration,
			radius = radius,
			slow_percent = slow_percent,
			total_heal = total_heal,
			heal_interval = heal_interval,
			follow_caster = follow_caster and 1 or 0
		}, -- kv
		point, -- location
		caster:GetTeamNumber(), -- team number
		false  -- force create
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
	
	-- Store values from kv or ability
	self.radius = kv.radius or ability:GetSpecialValueFor("radius")
	self.slow_percent = kv.slow_percent or ability:GetSpecialValueFor("slow_percent")
	self.total_heal = kv.total_heal or ability:GetSpecialValueFor("heal_amount")
	self.heal_interval = kv.heal_interval or ability:GetSpecialValueFor("heal_interval")
	self.position = parent:GetAbsOrigin()
	self.follow_caster = (kv.follow_caster or 0) == 1
	
	-- Initialize particle storage table
	self.particles = {}
	
	-- Create cast particle effect
	self.cast_particle = ParticleManager:CreateParticle("particles/Omniknight/omniknight_guardian_angel_ally_custom.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(self.cast_particle, 0, self.position)  -- CP 0 - позиция партикла
	ParticleManager:SetParticleControl(self.cast_particle, 1, Vector(self.radius, 0, 0))  -- CP 1 - (радиус, 0, 0)
	ParticleManager:SetParticleControl(self.cast_particle, 3, Vector(20, 0, 0))  -- CP 3 - (радиус символов, 0, 0) - начинаем с 20
	
	-- Follow mode uses faster tick for smooth movement; heal timer is tracked manually
	if self.follow_caster then
		self.heal_timer = 0
		self:StartIntervalThink(0.03)
	else
		self:StartIntervalThink(self.heal_interval)
	end
	
	-- Play custom ambient sound
	EmitSoundOn("Holy_Ground.Ambient", parent)
end

function modifier_holy_ground_thinker:OnIntervalThink()
	if not IsServer() then return end
	
	-- Follow caster: move particle emitter to caster position every tick
	if self.follow_caster then
		local caster = self:GetCaster()
		if caster and not caster:IsNull() and caster:IsAlive() then
			self.position = caster:GetAbsOrigin()
			if self.cast_particle then
				ParticleManager:SetParticleControl(self.cast_particle, 0, self.position)
			end
		end
		-- Advance heal timer; skip the heal/slow logic until interval is reached
		self.heal_timer = self.heal_timer + 0.03
		if self.heal_timer < self.heal_interval then
			return
		end
		self.heal_timer = 0
	end

	-- Create pulse effect
	local pulse_duration = 0.45
	local pulse_particle = ParticleManager:CreateParticle("particles/Omniknight/pulse_main.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(pulse_particle, 0, self.position)  -- CP 0 - позиция партикла
	ParticleManager:SetParticleControl(pulse_particle, 1, Vector(self.radius, self.radius / pulse_duration, 0))  -- CP 1 - (радиус, скорость, 0)
	ParticleManager:SetParticleControl(pulse_particle, 2, Vector(pulse_duration, 0, 0))  -- CP 2 - (длительность, 0, 0)
	table.insert(self.particles, pulse_particle)
	
	-- Find allied units in radius for healing
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
	
	-- Heal allies
	local healed_someone = false
	for _, ally in pairs(allies) do
		ally:Heal(self.total_heal, self:GetAbility())
		healed_someone = true
		
		-- Create heal particle effect
		local heal_particle = ParticleManager:CreateParticle("particles/Omniknight/omniknight_purification_custom.vpcf", PATTACH_ABSORIGIN_FOLLOW, ally)
		ParticleManager:SetParticleControl(heal_particle, 0, ally:GetAbsOrigin())  -- CP 0 - позиция партикла
		ParticleManager:SetParticleControl(heal_particle, 1, Vector(100, 0, 0))  -- CP 1 - (радиус, 0, 0)
		table.insert(self.particles, heal_particle)
	end
	
	-- Play custom bell sound only if someone was healed
	if healed_someone then
		EmitSoundOnLocationWithCaster(self.position, "Holy_Ground.Bell", self:GetCaster())
	end
	
	-- Apply/refresh slow debuff on enemies
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
	
	-- Destroy cast particle
	if self.cast_particle then
		ParticleManager:DestroyParticle(self.cast_particle, false)
		ParticleManager:ReleaseParticleIndex(self.cast_particle)
	end
	
	-- Destroy all other particles immediately
	if self.particles then
		for _, particle in pairs(self.particles) do
			ParticleManager:DestroyParticle(particle, true)
			ParticleManager:ReleaseParticleIndex(particle)
		end
		self.particles = {}
	end
	
	-- Stop custom ambient sound
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
	
	-- Get slow percent from kv or ability
	self.slow_percent = kv.slow_percent or 0
	if self.slow_percent == 0 then
		local ability = self:GetAbility()
		if ability then
			self.slow_percent = ability:GetSpecialValueFor("slow_percent") or 0
		end
	end
end
