LinkLuaModifier( "modifier_lich_spark_wraith_thinker", "abilities/lich/Lich_spark_wraith_custom", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_lich_spark_wraith_slow", "abilities/lich/Lich_spark_wraith_custom", LUA_MODIFIER_MOTION_NONE )

lich_spark_wraith = class({})

function lich_spark_wraith:Precache(context)
	if self:GetCaster() and self:GetCaster():IsIllusion() then return end

	PrecacheResource( "particle", "particles/units/heroes/hero_arc_warden/arc_warden_wraith_cast.vpcf", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_arc_warden/arc_warden_wraith.vpcf", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_arc_warden/arc_warden_wraith_prj.vpcf", context )
	PrecacheResource( "sound", "Hero_ArcWarden.SparkWraith.Cast", context )
	PrecacheResource( "sound", "Hero_ArcWarden.SparkWraith.Appear", context )
	PrecacheResource( "sound", "Hero_ArcWarden.SparkWraith.Loop", context )
	PrecacheResource( "sound", "Hero_ArcWarden.SparkWraith.Activate", context )
	PrecacheResource( "sound", "Hero_ArcWarden.SparkWraith.Damage", context )
end

function lich_spark_wraith:GetAOERadius()
	return self:GetSpecialValueFor("radius")
end

function lich_spark_wraith:GetAbilityTextureName()
	return "arc_warden_spark_wraith"
end

function lich_spark_wraith:GetDamage()
	return self:GetSpecialValueFor("spark_damage_base")
end

function lich_spark_wraith:OnAbilityPhaseStart()
	self:GetCaster():EmitSound("Hero_ArcWarden.SparkWraith.Cast")
	return true
end

function lich_spark_wraith:OnSpellStart()
	local caster = self:GetCaster()
	local cast_point = self:GetCursorPosition()

	local particle = "particles/units/heroes/hero_arc_warden/arc_warden_wraith_cast.vpcf"
	local cast_particle = ParticleManager:CreateParticle(particle, PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:SetParticleControl(cast_particle, 1, caster:GetAbsOrigin() + caster:GetForwardVector()*110)
	ParticleManager:ReleaseParticleIndex(cast_particle)

	EmitSoundOnLocationWithCaster(cast_point, "Hero_ArcWarden.SparkWraith.Appear", caster)

	local duration = self:GetSpecialValueFor("duration")

	CreateModifierThinker(caster, self, "modifier_lich_spark_wraith_thinker", {duration = duration}, cast_point + Vector(0, 0, 10), caster:GetTeamNumber(), false)
end 

function lich_spark_wraith:DealDamage(target, not_main)
	if not IsServer() then return end 

	local caster = self:GetCaster() 
	local damage = self:GetDamage()
	local slow_duration = self:GetSpecialValueFor("ministun_duration")

	local k = 1
	if not_main then 
		k = self:GetSpecialValueFor("damage_near")/100
	end

	target:EmitSound("Hero_ArcWarden.SparkWraith.Damage")

	-- Нанесение урона
	ApplyDamage({
		victim = target,
		damage = damage * k,
		damage_type = DAMAGE_TYPE_MAGICAL,
		attacker = caster,
		ability = self
	})

	-- Применение замедления
	target:AddNewModifier(caster, self, "modifier_lich_spark_wraith_slow", {
		duration = slow_duration * (1 - target:GetStatusResistance())
	})
end 

function lich_spark_wraith:LaunchSpark(target, source)
	if not IsServer() then return end 

	local caster = self:GetCaster()
	local speed = self:GetSpecialValueFor("wraith_speed_base")
	local wraith_vision_radius = self:GetSpecialValueFor("wraith_vision_radius")
	local origin = source:GetAbsOrigin()

	source:EmitSound("Hero_ArcWarden.SparkWraith.Activate")

	local proj_pfx = "particles/units/heroes/hero_arc_warden/arc_warden_wraith_prj.vpcf"

	ProjectileManager:CreateTrackingProjectile({
		EffectName = proj_pfx,
		Ability = self,
		Source = source,
		vSourceLoc = origin,
		Target = target,
		iMoveSpeed = speed,
		bDodgeable = false,
		bVisibleToEnemies = true,
		bProvidesVision = true,
		iVisionRadius = wraith_vision_radius,
		iVisionTeamNumber = caster:GetTeamNumber(),
	})
end 

function lich_spark_wraith:OnProjectileHit_ExtraData(target, location, ExtraData)
	if not target then return end

	local caster = self:GetCaster()
	local damage_radius = self:GetSpecialValueFor("damage_radius")

	AddFOWViewer(caster:GetTeamNumber(), location, self:GetSpecialValueFor("wraith_vision_radius"), self:GetSpecialValueFor("wraith_vision_duration"), true)

	-- Нанесение урона в области
	local enemies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		target:GetAbsOrigin(),
		nil,
		damage_radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	for _, unit in pairs(enemies) do 
		self:DealDamage(unit, unit ~= target)
	end

	return true
end

--------------------------------------------------------------------------------
-- Modifier: Thinker (Spark Wraith на земле)
--------------------------------------------------------------------------------
modifier_lich_spark_wraith_thinker = class({})

function modifier_lich_spark_wraith_thinker:IsHidden()
	return true
end

function modifier_lich_spark_wraith_thinker:IsPurgable()
	return false
end

function modifier_lich_spark_wraith_thinker:OnCreated(table)
	self.ability = self:GetAbility()
	self.parent = self:GetParent()
	self.caster = self:GetCaster()
	self.radius = self.ability:GetSpecialValueFor("radius")
	self.activation_delay = self.ability:GetSpecialValueFor("base_activation_delay")
	self.think_interval = self.ability:GetSpecialValueFor("think_interval")
	self.wraith_vision_radius = self.ability:GetSpecialValueFor("wraith_vision_radius")

	if not IsServer() then return end

	self.parent:EmitSound("Hero_ArcWarden.SparkWraith.Loop")

	local particle_name = "particles/units/heroes/hero_arc_warden/arc_warden_wraith.vpcf"
	self.wraith_particle = ParticleManager:CreateParticle(particle_name, PATTACH_ABSORIGIN_FOLLOW, self.parent)
	ParticleManager:SetParticleControl(self.wraith_particle, 1, Vector(self.radius, 1, 1))
	self:AddParticle(self.wraith_particle, false, false, -1, false, false)

	self.origin = self.parent:GetAbsOrigin()

	AddFOWViewer(self.caster:GetTeamNumber(), self.origin, self.wraith_vision_radius, self.activation_delay, false)

	self:StartIntervalThink(self.activation_delay)
end

function modifier_lich_spark_wraith_thinker:OnIntervalThink()
	if not IsServer() then return end 

	AddFOWViewer(self.caster:GetTeamNumber(), self.origin, self.wraith_vision_radius, self.think_interval, false)

	-- Поиск врагов в радиусе
	local enemies = FindUnitsInRadius(
		self.caster:GetTeamNumber(),
		self.origin,
		nil,
		self.radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_NO_INVIS,
		FIND_CLOSEST,
		false
	)

	if #enemies > 0 then
		self.ability:LaunchSpark(enemies[1], self.parent)
		self:Destroy()
		return
	end

	self:StartIntervalThink(self.think_interval)
end

function modifier_lich_spark_wraith_thinker:OnDestroy()
	if not IsServer() then return end
	self.parent:StopSound("Hero_ArcWarden.SparkWraith.Loop")
end

--------------------------------------------------------------------------------
-- Modifier: Slow (Замедление)
--------------------------------------------------------------------------------
modifier_lich_spark_wraith_slow = class({})

function modifier_lich_spark_wraith_slow:IsDebuff()
	return true
end

function modifier_lich_spark_wraith_slow:IsPurgable()
	return true
end

function modifier_lich_spark_wraith_slow:OnCreated()
	self.move_speed_slow_pct = self:GetAbility():GetSpecialValueFor("move_speed_slow_pct")
end

function modifier_lich_spark_wraith_slow:OnRefresh()
	self:OnCreated()
end

function modifier_lich_spark_wraith_slow:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE
	}
end

function modifier_lich_spark_wraith_slow:GetModifierMoveSpeedBonus_Percentage()
	return -self.move_speed_slow_pct
end

