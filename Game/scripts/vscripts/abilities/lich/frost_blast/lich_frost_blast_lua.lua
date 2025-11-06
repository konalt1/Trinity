lich_frost_blast_lua = class({})
LinkLuaModifier( "modifier_lich_frost_blast_lua", "abilities/lich/frost_blast/modifier_lich_frost_blast_lua", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------------
-- Custom KV
-- AOE Radius
function lich_frost_blast_lua:GetAOERadius()
	return self:GetSpecialValueFor( "radius" )
end

--------------------------------------------------------------------------------
-- Ability Start
function lich_frost_blast_lua:OnSpellStart()
	-- unit identifier
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()

	-- cancel if linken
	if target:TriggerSpellAbsorb( self ) then
		self:PlayEffects()
		return
	end

	-- load data
	local damage = self:GetAbilityDamage()
	local duration = self:GetDuration()
	local damage_aoe = self:GetSpecialValueFor("aoe_damage")
	local radius = self:GetSpecialValueFor("radius")

	-- Fix: Get values from AbilitySpecial correctly
	if damage_aoe == 0 then
		damage_aoe = self:GetSpecialValueFor("04") -- aoe_damage is the 4th special value
	end
	if radius == 0 then
		radius = self:GetSpecialValueFor("01") -- radius is the 1st special value
	end
	
	-- Fallback values if still 0
	if damage_aoe == 0 then
		local level = self:GetLevel()
		if level == 1 then damage_aoe = 75
		elseif level == 2 then damage_aoe = 100
		elseif level == 3 then damage_aoe = 125
		elseif level == 4 then damage_aoe = 150
		end
	end
	if radius == 0 then
		radius = 200
	end

	-- get mind power bonus damage
	local mind_power_modifier = caster:FindModifierByName("modifier_mind_power")
	local mind_power_value = 0
	if mind_power_modifier then
		mind_power_value = mind_power_modifier:GetStackCount()
	end
	
	-- Get mind power multiplier from KV file
	local mind_power_multiplier = self:GetSpecialValueFor("mind_power_multiplier")
	if mind_power_multiplier == 0 then
		mind_power_multiplier = 0.5 -- fallback value
	end

	-- get enemies
	local enemies = FindUnitsInRadius(
		caster:GetTeamNumber(),	-- int, your team number
		target:GetOrigin(),	-- point, center point
		nil,	-- handle, cacheUnit. (not known)
		radius,	-- float, radius. or use FIND_UNITS_EVERYWHERE
		DOTA_UNIT_TARGET_TEAM_ENEMY,	-- int, team filter
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,	-- int, type filter
		0,	-- int, flag filter
		0,	-- int, order filter
		false	-- bool, can grow cache
	)

	-- damage table
	local damageTable = {
		attacker = caster,
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability = self, --Optional.
	}

	-- Calculate mind power bonus damage (applies to all targets)
	local mind_bonus_damage = mind_power_value * mind_power_multiplier

	-- damage and debuff all enemies in radius
	for _,enemy in pairs(enemies) do
		-- damage (main target gets both spell damage and AOE damage, others get only AOE damage)
		-- mind power bonus is added to both damage types
		damageTable.victim = enemy
		if enemy == target then
			damageTable.damage = damage + damage_aoe + mind_bonus_damage
		else
			damageTable.damage = damage_aoe + mind_bonus_damage
		end
		ApplyDamage( damageTable )
		
		-- debuff
		enemy:AddNewModifier(
			caster, -- player source
			self, -- ability source
			"modifier_lich_frost_blast_lua", -- modifier name
			{ duration = duration } -- kv
		)
	end

	-- effects
	self:PlayEffects( target, radius )
end

function lich_frost_blast_lua:PlayEffects( target, radius )
	-- Get Resources
	local particle_cast = "particles/units/heroes/hero_lich/lich_frost_nova.vpcf"
	local sound_target = "Ability.FrostNova"

	-- Create Particle
	local effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_ABSORIGIN_FOLLOW, target )
	ParticleManager:SetParticleControl( effect_cast, 1, Vector( radius, radius, radius ) )
	ParticleManager:ReleaseParticleIndex( effect_cast )

	-- Create Sound
	EmitSoundOn( sound_target, target )
end