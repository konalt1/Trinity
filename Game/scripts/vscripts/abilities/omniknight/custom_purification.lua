custom_purification = class({})

--------------------------------------------------------------------------------
-- Ability Start
function custom_purification:OnSpellStart()
	-- unit identifier
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()

	-- load data
	local heal = self:GetSpecialValueFor("heal")
	local radius = self:GetSpecialValueFor("radius")
	local mind_power_multiplier = self:GetSpecialValueFor("mind_power_multiplier")
	
	-- Check for Aghanim's Shard
	local has_shard = caster:HasModifier("modifier_item_aghanims_shard")
	if has_shard then
		local shard_bonus_radius = self:GetSpecialValueFor("shard_bonus_radius")
		radius = radius + shard_bonus_radius
	end
	
	-- Get Mind Power
	local mind_power = 0
	if GetHeroMindPower then
		mind_power = GetHeroMindPower(caster) or 0
	else
		mind_power = caster:GetIntellect(false) or 0
	end
	
	-- Calculate bonus from Mind Power (applies to both heal and damage)
	local mind_power_bonus = mind_power * mind_power_multiplier
	local total_heal = math.max(0, heal + mind_power_bonus)
	local total_damage = math.max(0, heal + mind_power_bonus)
	
	-- Мгновенное исцеление основной цели (с бонусом от Mind Power)
	target:Heal(total_heal, self)
	
	-- Aghanim's Shard: исцеляем всех союзников в радиусе (кроме основной цели)
	if has_shard then
		local allies = FindUnitsInRadius(
			caster:GetTeamNumber(),
			target:GetAbsOrigin(),
			nil,
			radius,
			DOTA_UNIT_TARGET_TEAM_FRIENDLY,
			DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
			DOTA_UNIT_TARGET_FLAG_NONE,
			FIND_ANY_ORDER,
			false
		)
		
		for _, ally in pairs(allies) do
			if ally ~= target then
				ally:Heal(total_heal, self)
			end
		end
	end
	
	-- Найти всех врагов вокруг цели
	local enemies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		target:GetAbsOrigin(),
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)
	
	-- Нанести урон врагам (базовый урон + бонус от Mind Power)
	for _, enemy in pairs(enemies) do
		ApplyDamage({
			victim = enemy,
			attacker = caster,
			damage = total_damage,
			damage_type = DAMAGE_TYPE_MAGICAL,
			ability = self
		})
	end

	self:PlayEffects(target, radius)
end

--------------------------------------------------------------------------------
function custom_purification:PlayEffects(target, radius)
	
	-- Get Resources (оригинальные эффекты и звуки от Purification)
	local particle_cast = "particles/units/heroes/hero_omniknight/omniknight_purification_cast.vpcf"
	local particle_target = "particles/units/heroes/hero_omniknight/omniknight_purification.vpcf"
	local sound_cast = "Hero_Omniknight.Purification"

	-- Create particle effect on target with radius
	local effect_target = ParticleManager:CreateParticle(particle_target, PATTACH_ABSORIGIN_FOLLOW, target)
	ParticleManager:SetParticleControl(effect_target, 0, target:GetAbsOrigin())
	ParticleManager:SetParticleControl(effect_target, 1, Vector(radius, radius, radius))
	ParticleManager:ReleaseParticleIndex(effect_target)
	
	-- Play sound on target
	EmitSoundOn(sound_cast, target)

	-- Create beam effect from caster to target
	local effect_cast = ParticleManager:CreateParticle(particle_cast, PATTACH_ABSORIGIN_FOLLOW, self:GetCaster())
	ParticleManager:SetParticleControl(effect_cast, 0, self:GetCaster():GetAbsOrigin())
	ParticleManager:SetParticleControl(effect_cast, 1, target:GetAbsOrigin())
	ParticleManager:ReleaseParticleIndex(effect_cast)
end
