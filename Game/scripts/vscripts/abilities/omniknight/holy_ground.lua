holy_ground = class({})

LinkLuaModifier("modifier_holy_ground_thinker", "abilities/omniknight/holy_ground", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_holy_ground_slow", "abilities/omniknight/holy_ground", LUA_MODIFIER_MOTION_NONE)

--------------------------------------------------------------------------------
-- AOE Radius
function holy_ground:GetAOERadius()
	return self:GetSpecialValueFor( "radius" )
end

--------------------------------------------------------------------------------
-- Ability Start
function holy_ground:OnSpellStart()
	-- unit identifier
	local caster = self:GetCaster()
	local point = self:GetCursorPosition()

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
	local total_heal = heal_amount + mind_power_bonus

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
			heal_interval = heal_interval
		}, -- kv
		point, -- location
		caster:GetTeamNumber(), -- team number
		false  -- force create
	)

	-- Play cast effects
	self:PlayCastEffects(point, radius)
end

function holy_ground:PlayCastEffects(point, radius)
	-- Play custom cast sound
	EmitSoundOn("Holy_Ground.Cast", self:GetCaster())
	
	-- Create cast particle effect
	local particle_cast = ParticleManager:CreateParticle("particles/units/heroes/hero_omniknight/omniknight_guardian_angel_cast.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(particle_cast, 0, point)
	ParticleManager:SetParticleControl(particle_cast, 1, Vector(radius, radius, radius))
	ParticleManager:SetParticleControl(particle_cast, 2, Vector(radius, 0, 0))
	ParticleManager:ReleaseParticleIndex(particle_cast)
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
	
	-- Create visual effect for the holy ground
	self.particle = ParticleManager:CreateParticle("particles/econ/items/omniknight/omni_2021_immortal/omni_2021_immortal_buff_ring.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(self.particle, 0, self.position)
	-- Настраиваем масштаб для отображения полного радиуса способности (450 единиц)
	-- Пробуем разные коэффициенты масштабирования
	local scale_factor = self.radius / 100  -- Базовый масштаб относительно 100 единиц
	ParticleManager:SetParticleControl(self.particle, 1, Vector(scale_factor, scale_factor, scale_factor))
	ParticleManager:SetParticleControl(self.particle, 2, Vector(scale_factor, 0, 0))
	ParticleManager:SetParticleControl(self.particle, 3, Vector(scale_factor, 0, 0))
	ParticleManager:SetParticleControl(self.particle, 4, Vector(scale_factor, 0, 0))
	
	-- Create additional boundary effect to show exact area
	self.boundary_particle = ParticleManager:CreateParticle("particles/units/heroes/hero_omniknight/omniknight_degen_aura.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(self.boundary_particle, 0, self.position)
	-- Уменьшаем размер круга до точного радиуса способности
	ParticleManager:SetParticleControl(self.boundary_particle, 1, Vector(self.radius * 0.7, 0, 0))
	ParticleManager:SetParticleControl(self.boundary_particle, 2, Vector(self.radius * 0.7, 0, 0))
	
	-- Start healing timer
	self:StartIntervalThink(self.heal_interval)
	
	-- Play custom ambient sound
	EmitSoundOn("Holy_Ground.Ambient", parent)
end

function modifier_holy_ground_thinker:OnIntervalThink()
	if not IsServer() then return end
	
	-- Play custom bell sound
	EmitSoundOnLocationWithCaster(self.position, "Holy_Ground.Bell", self:GetCaster())
	
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
	for _, ally in pairs(allies) do
		ally:Heal(self.total_heal, self:GetAbility())
		
		-- Create heal particle effect
		local heal_particle = ParticleManager:CreateParticle("particles/units/heroes/hero_omniknight/omniknight_purification.vpcf", PATTACH_ABSORIGIN_FOLLOW, ally)
		ParticleManager:SetParticleControl(heal_particle, 1, Vector(200, 200, 200))
		ParticleManager:ReleaseParticleIndex(heal_particle)
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
	
	-- Remove visual effects
	if self.particle then
		ParticleManager:DestroyParticle(self.particle, false)
		ParticleManager:ReleaseParticleIndex(self.particle)
	end
	
	if self.boundary_particle then
		ParticleManager:DestroyParticle(self.boundary_particle, false)
		ParticleManager:ReleaseParticleIndex(self.boundary_particle)
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

function modifier_holy_ground_slow:GetEffectName()
	return "particles/units/heroes/hero_omniknight/omniknight_degen_aura_debuff.vpcf"
end

function modifier_holy_ground_slow:GetEffectAttachType()
	return PATTACH_OVERHEAD_FOLLOW
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
