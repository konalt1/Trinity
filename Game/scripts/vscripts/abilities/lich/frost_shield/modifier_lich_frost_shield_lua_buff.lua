modifier_lich_frost_shield_lua_buff = class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_lich_frost_shield_lua_buff:IsHidden()
	return false
end

function modifier_lich_frost_shield_lua_buff:IsDebuff()
	return false
end

function modifier_lich_frost_shield_lua_buff:GetAttributes()
	return MODIFIER_ATTRIBUTE_INVULNERABLE 
end

function modifier_lich_frost_shield_lua_buff:IsPurgable()
	return true
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_lich_frost_shield_lua_buff:OnCreated( kv )
	-- references
	self.damage_reduction = self:GetAbility():GetSpecialValueFor( "damage_reduction" )
	self.radius = self:GetAbility():GetSpecialValueFor( "radius" )
	self.damage = self:GetAbility():GetSpecialValueFor( "damage" )
	self.slow_duration = self:GetAbility():GetSpecialValueFor( "slow_duration" )
	self.slow_movespeed = self:GetAbility():GetSpecialValueFor( "slow_movespeed" )
	self.interval = self:GetAbility():GetSpecialValueFor( "interval" )
	self.health_regen = self:GetAbility():GetSpecialValueFor( "health_regen" )
	self.mind_power_multiplier = self:GetAbility():GetSpecialValueFor( "mind_power_damage_multiplier" )

	-- Apply talent bonuses
	local caster = self:GetCaster()
	local damage_reduction_talent = caster:FindAbilityByName("special_bonus_unique_lich_frost_shield_damage_reduction")
	if damage_reduction_talent and damage_reduction_talent:GetLevel() > 0 then
		self.damage_reduction = self.damage_reduction + damage_reduction_talent:GetSpecialValueFor("value")
	end
	
	local health_regen_talent = caster:FindAbilityByName("special_bonus_unique_lich_frost_shield_health_regen")
	if health_regen_talent and health_regen_talent:GetLevel() > 0 then
		self.health_regen = self.health_regen + health_regen_talent:GetSpecialValueFor("value")
	end

	-- Start thinking
	if IsServer() then
		self:StartIntervalThink( self.interval )
	end

	-- Create particle effect using AddParticle
	local particle_index = ParticleManager:CreateParticle("particles/lich/lich_ice_age.vpcf", 1, self:GetParent())
	ParticleManager:SetParticleControlEnt(particle_index, 1, self:GetParent(), PATTACH_ABSORIGIN_FOLLOW, nil, self:GetParent():GetAbsOrigin(), true)
	
	-- Add particle to modifier (will be automatically destroyed with modifier)
	self:AddParticle(
		particle_index,  -- index
		false,           -- destroyImmediately
		false,           -- statusEffect
		1,               -- priority
		false,           -- heroEffect
		false            -- overheadEffect
	)

	-- Play sound effect 
	if IsServer() then
		local sound_cast = "Hero_Lich.IceAge.Tick"
		EmitSoundOn(sound_cast, self:GetParent())
	end
end

function modifier_lich_frost_shield_lua_buff:OnRefresh( kv )
	-- references
	self.damage_reduction = self:GetAbility():GetSpecialValueFor( "damage_reduction" )
	self.radius = self:GetAbility():GetSpecialValueFor( "radius" )
	self.damage = self:GetAbility():GetSpecialValueFor( "damage" )
	self.slow_duration = self:GetAbility():GetSpecialValueFor( "slow_duration" )
	self.slow_movespeed = self:GetAbility():GetSpecialValueFor( "slow_movespeed" )
	self.interval = self:GetAbility():GetSpecialValueFor( "interval" )
	self.health_regen = self:GetAbility():GetSpecialValueFor( "health_regen" )
	self.mind_power_multiplier = self:GetAbility():GetSpecialValueFor( "mind_power_damage_multiplier" )

	-- Apply talent bonuses
	local caster = self:GetCaster()
	local damage_reduction_talent = caster:FindAbilityByName("special_bonus_unique_lich_frost_shield_damage_reduction")
	if damage_reduction_talent and damage_reduction_talent:GetLevel() > 0 then
		self.damage_reduction = self.damage_reduction + damage_reduction_talent:GetSpecialValueFor("value")
	end
	
	local health_regen_talent = caster:FindAbilityByName("special_bonus_unique_lich_frost_shield_health_regen")
	if health_regen_talent and health_regen_talent:GetLevel() > 0 then
		self.health_regen = self.health_regen + health_regen_talent:GetSpecialValueFor("value")
	end
end

function modifier_lich_frost_shield_lua_buff:OnDestroy( kv )
	if IsServer() then
		-- Play destruction effect
		local sound_cast = "Hero_Lich.FrostArmorDamage"
		EmitSoundOn( sound_cast, self:GetParent() )
	end
	-- Particle is automatically destroyed by AddParticle system
end

--------------------------------------------------------------------------------
-- Interval Effects
function modifier_lich_frost_shield_lua_buff:OnIntervalThink()
	if IsServer() then
		-- Find enemies in radius
		local enemies = FindUnitsInRadius(
			self:GetParent():GetTeamNumber(),
			self:GetParent():GetOrigin(),
			nil,
			self.radius,
			DOTA_UNIT_TARGET_TEAM_ENEMY,
			DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
			0,
			0,
			false
		)

		-- Damage and slow enemies
		for _, enemy in pairs(enemies) do
			-- Calculate damage with intelligence scaling
			local base_damage = self.damage
			local caster = self:GetCaster()
			
			-- Получаем значение mind power используя вспомогательную функцию
			local mind_power = GetHeroMindPower(caster)
			
			local mind_power_bonus = mind_power * self.mind_power_multiplier
			local total_damage = base_damage + mind_power_bonus
			
			-- Deal damage
			local damage_table = {
				victim = enemy,
				attacker = caster,
				damage = total_damage,
				damage_type = DAMAGE_TYPE_MAGICAL,
				ability = self:GetAbility(),
			}
			ApplyDamage(damage_table)

			-- Apply slow
			enemy:AddNewModifier(
				caster,
				self:GetAbility(),
				"modifier_lich_frost_shield_lua_debuff",
				{
					duration = self.slow_duration,
					slow_movespeed = self.slow_movespeed,
				}
			)
		end

		-- Play periodic effect
		self:PlayPeriodicEffect()
	end
end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_lich_frost_shield_lua_buff:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
		MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
	}

	return funcs
end

function modifier_lich_frost_shield_lua_buff:GetModifierIncomingDamage_Percentage()
	return -self.damage_reduction
end

function modifier_lich_frost_shield_lua_buff:GetModifierConstantHealthRegen()
	return self.health_regen
end

--------------------------------------------------------------------------------
-- Graphics & Animations
function modifier_lich_frost_shield_lua_buff:GetStatusEffectName()
	return "particles/status_fx/status_effect_frost_lich.vpcf"
end

function modifier_lich_frost_shield_lua_buff:PlayPeriodicEffect()
	-- Get Resources
	local particle_cast = "particles/lich/lich_ice_age_dmg.vpcf"
	local sound_cast = "Hero_Lich.IceAge.Tick"

	-- Create Particle
	local effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_ABSORIGIN_FOLLOW, self:GetParent() )
	ParticleManager:SetParticleControl(effect_cast, 0, self:GetParent():GetAbsOrigin())
	ParticleManager:SetParticleControlEnt(effect_cast, 1, self:GetParent(), PATTACH_ABSORIGIN_FOLLOW, nil, self:GetParent():GetAbsOrigin(), true)
	ParticleManager:ReleaseParticleIndex(effect_cast)
	
	-- Play sound effect
	if IsServer() then
		EmitSoundOn(sound_cast, self:GetParent())
	end
end 