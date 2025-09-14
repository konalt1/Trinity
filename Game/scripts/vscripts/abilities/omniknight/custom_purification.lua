custom_purification = class({})

--------------------------------------------------------------------------------
-- AOE Radius
function custom_purification:GetAOERadius()
	return self:GetSpecialValueFor( "radius" )
end

--------------------------------------------------------------------------------
-- Ability Start
function custom_purification:OnSpellStart()
	-- unit identifier
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()

	-- load data
	local base_heal = self:GetSpecialValueFor("heal")
	local radius = self:GetSpecialValueFor("radius")
	local mind_power_multiplier = self:GetSpecialValueFor("mind_power_multiplier")
	
	-- Calculate Mind Power bonus
	local mind_power = 0
	if GetHeroMindPower then
		mind_power = GetHeroMindPower(caster) or 0
	else
		mind_power = caster:GetIntellect(false) or 0
	end
	
	-- Calculate total heal and damage with Mind Power scaling
	local mind_power_bonus = mind_power * mind_power_multiplier
	local total_heal = base_heal + mind_power_bonus
	
	-- Debug output
	print("Custom Purification: Base=" .. base_heal .. ", Mind Power=" .. mind_power .. ", Bonus=" .. mind_power_bonus .. ", Total=" .. total_heal)

	-- heal
	target:Heal( total_heal, self )

	-- Find Units in Radius
	local enemies = FindUnitsInRadius(
		self:GetCaster():GetTeamNumber(),	-- int, your team number
		target:GetOrigin(),	-- point, center point
		nil,	-- handle, cacheUnit. (not known)
		radius,	-- float, radius. or use FIND_UNITS_EVERYWHERE
		DOTA_UNIT_TARGET_TEAM_ENEMY,	-- int, team filter
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,	-- int, type filter
		0,	-- int, flag filter
		0,	-- int, order filter
		false	-- bool, can grow cache
	)

	-- Apply Damage	 
	local damageTable = {
		attacker = caster,
		damage = total_heal, -- Используем то же значение что и для лечения
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability = self, --Optional.
	}
	for _,enemy in pairs(enemies) do
		damageTable.victim = enemy
		ApplyDamage(damageTable)
		self:PlayEffects2( target, enemy )
	end

	self:PlayEffects1( target, radius )
end

--------------------------------------------------------------------------------
function custom_purification:PlayEffects1( target, radius )
	-- Get Resources
	local particle_cast = "particles/units/heroes/hero_omniknight/omniknight_purification_cast.vpcf"
	local particle_target = "particles/units/heroes/hero_omniknight/omniknight_purification.vpcf"
	local sound_target = "Hero_Omniknight.Purification"

	-- Create Target Effects
	local effect_target = ParticleManager:CreateParticle( particle_target, PATTACH_ABSORIGIN_FOLLOW, target )
	ParticleManager:SetParticleControl( effect_target, 1, Vector( radius, radius, radius ) )
	ParticleManager:ReleaseParticleIndex( effect_target )
	EmitSoundOn( sound_target, target )

	-- Create Caster Effects
	local effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_ABSORIGIN_FOLLOW, self:GetCaster() )
	ParticleManager:SetParticleControl( effect_cast, 0, self:GetCaster():GetOrigin() )
	ParticleManager:SetParticleControl( effect_cast, 1, target:GetOrigin() )
	ParticleManager:ReleaseParticleIndex( effect_cast )
end

function custom_purification:PlayEffects2( origin, target )
	local particle_target = "particles/units/heroes/hero_omniknight/omniknight_purification_hit.vpcf"
	local effect_target = ParticleManager:CreateParticle( particle_target, PATTACH_ABSORIGIN_FOLLOW, target )
	ParticleManager:SetParticleControl( effect_target, 0, origin:GetOrigin() )
	ParticleManager:SetParticleControl( effect_target, 1, target:GetOrigin() )
	ParticleManager:ReleaseParticleIndex( effect_target )
end
