modifier_juggernaut_blade_fury_lua = class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_juggernaut_blade_fury_lua:IsHidden()
	return false
end

function modifier_juggernaut_blade_fury_lua:IsDebuff()
	return false
end

function modifier_juggernaut_blade_fury_lua:IsPurgable()
	return false
end

function modifier_juggernaut_blade_fury_lua:DestroyOnExpire()
	return true
end


function modifier_juggernaut_blade_fury_lua:OnRefresh( kv )
	-- references
	self.tick = self:GetAbility():GetSpecialValueFor( "blade_fury_damage_tick" ) -- special value
	self.radius = self:GetAbility():GetSpecialValueFor( "blade_fury_radius" ) -- special value
	self.dps = self:GetAbility():GetSpecialValueFor( "blade_fury_damage" ) -- special value
	self.mind_power_multiplier = self:GetAbility():GetSpecialValueFor( "mind_power_multiplier" ) or 0.5 -- special value with fallback
	self.count = 0

	-- Note: Damage is calculated dynamically in OnIntervalThink, no need to pre-calculate here
end

function modifier_juggernaut_blade_fury_lua:OnDestroy( kv )
	-- Stop effects
	local sound_cast = "Hero_Juggernaut.BladeFuryStart"
	StopSoundOn( sound_cast, self:GetParent() )
	
	-- Stop animation
	if IsServer() then
		self:GetParent():RemoveGesture(ACT_DOTA_OVERRIDE_ABILITY_1)
	end
	
	-- Force stop all blade fury sounds to ensure sound stops
	if IsServer() then
		StopSoundOn("Hero_Juggernaut.BladeFuryStart", self:GetParent())
		StopSoundOn("Hero_Juggernaut.BladeFury", self:GetParent())
		StopSoundOn("Hero_Juggernaut.BladeFuryEnd", self:GetParent())
		
		-- Also try stopping with different approaches
		local parent = self:GetParent()
		if parent then
			EmitSoundOnLocationForPlayer("Hero_Juggernaut.BladeFuryEnd", parent:GetAbsOrigin(), parent:GetPlayerID())
		end
	end
end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_juggernaut_blade_fury_lua:DeclareFunctions()
	local funcs = {
	}

	return funcs
end

--------------------------------------------------------------------------------
-- Status Effects
function modifier_juggernaut_blade_fury_lua:CheckState()
	local state = {
		[MODIFIER_STATE_MAGIC_IMMUNE] = true
	}

	return state
end

--------------------------------------------------------------------------------
-- Animation Effects
function modifier_juggernaut_blade_fury_lua:OnCreated( kv )
	-- references
	self.tick = self:GetAbility():GetSpecialValueFor( "blade_fury_damage_tick" ) -- special value
	self.radius = self:GetAbility():GetSpecialValueFor( "blade_fury_radius" ) -- special value
	self.dps = self:GetAbility():GetSpecialValueFor( "blade_fury_damage" ) -- special value
	self.mind_power_multiplier = self:GetAbility():GetSpecialValueFor( "mind_power_multiplier" ) or 0.5 -- special value with fallback
	
	self.max_count = kv.duration/self.tick
	self.count = 0

	-- Start interval
	if IsServer() then
		-- Initialize damage table without damage value (will be calculated in OnIntervalThink)
		self.damageTable = {
			-- victim = target,
			attacker = self:GetParent(),
			damage = 0, -- Will be calculated in OnIntervalThink
			damage_type = DAMAGE_TYPE_MAGICAL,
			ability = self:GetAbility(), --Optional.
		}

		self:StartIntervalThink( self.tick )
	end

	-- Play animation
	if IsServer() then
		self:GetParent():StartGesture(ACT_DOTA_OVERRIDE_ABILITY_1)
	end

	-- PlayEffects
	self:PlayEffects()
end

--------------------------------------------------------------------------------
-- Interval Effects
function modifier_juggernaut_blade_fury_lua:OnIntervalThink()
	-- Calculate mind power bonus damage with error handling (every tick for dynamic scaling)
	local caster = self:GetParent()
	local mind_power = 0
	
	-- Safe call to GetHeroMindPower
	if GetHeroMindPower then
		mind_power = GetHeroMindPower(caster) or 0
	else
		mind_power = caster:GetIntellect(false) or 0
	end
	
	local mind_power_bonus = mind_power * self.mind_power_multiplier
	local total_damage = self.dps + mind_power_bonus
	local damage_per_tick = total_damage * self.tick
	
	-- Update damage table with current calculated damage
	self.damageTable.damage = damage_per_tick
	
	-- Find enemies in radius
	local enemies = FindUnitsInRadius(
		self:GetCaster():GetTeamNumber(),	-- int, your team number
		self:GetParent():GetOrigin(),	-- point, center point
		nil,	-- handle, cacheUnit. (not known)
		self.radius,	-- float, radius. or use FIND_UNITS_EVERYWHERE
		DOTA_UNIT_TARGET_TEAM_ENEMY,	-- int, team filter
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,	-- int, type filter
		0,	-- int, flag filter
		0,	-- int, order filter
		false	-- bool, can grow cache
	)

	-- damage enemies
	for _,enemy in pairs(enemies) do
		self.damageTable.victim = enemy
		ApplyDamage( self.damageTable )

		-- Play effects
		self:PlayEffects2( enemy )
	end

	-- counter
	self.count = self.count+1
	
	if self.count>= self.max_count then
		self:Destroy()
	end
end

--------------------------------------------------------------------------------
-- Graphics & Animations
function modifier_juggernaut_blade_fury_lua:PlayEffects()
	-- Get Resources
	local particle_cast = "particles/units/heroes/hero_juggernaut/juggernaut_blade_fury.vpcf"
	local sound_cast = "Hero_Juggernaut.BladeFuryStart"

	-- Create Particle
	local effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_ABSORIGIN_FOLLOW, self:GetParent() )
	ParticleManager:SetParticleControl( effect_cast, 5, Vector( self.radius, 0, 0 ) )

	-- buff particle
	self:AddParticle(
		effect_cast,
		false,
		false,
		-1,
		false,
		false
	)

	-- Emit sound
	EmitSoundOn( sound_cast, self:GetParent() )
end

function modifier_juggernaut_blade_fury_lua:PlayEffects2( target )
	local particle_cast = "particles/units/heroes/hero_juggernaut/juggernaut_blade_fury_tgt.vpcf"
	local effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_ABSORIGIN_FOLLOW, target )
	ParticleManager:ReleaseParticleIndex( effect_cast )
end
