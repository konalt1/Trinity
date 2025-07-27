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
	self.count = 0

	if IsServer() then
		self.damageTable.damage = self.dps * self.tick
	end
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
	end
end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_juggernaut_blade_fury_lua:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_PROCATTACK_BONUS_DAMAGE_PHYSICAL,
	}

	return funcs
end

function modifier_juggernaut_blade_fury_lua:GetModifierProcAttack_BonusDamage_Physical( params )
	return -params.damage
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
	
	self.max_count = kv.duration/self.tick
	self.count = 0
	
	if IsServer() then
		print("Blade Fury: Duration=" .. kv.duration .. ", Tick=" .. self.tick .. ", MaxCount=" .. self.max_count)
	end

	-- Start interval
	if IsServer() then
		-- precache damagetable
		self.damageTable = {
			-- victim = target,
			attacker = self:GetParent(),
			damage = self.dps * self.tick,
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
		if IsServer() then
			print("Blade Fury: Destroying modifier after " .. self.count .. " ticks (max: " .. self.max_count .. ")")
		end
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
