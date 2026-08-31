LinkLuaModifier(
	"modifier_pangolier_shield_crash_trinity_barrier",
	"abilities/pangolier/pangolier_shield_crash_trinity",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_pangolier_shield_crash_trinity_jump",
	"abilities/pangolier/pangolier_shield_crash_trinity",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_pangolier_shield_crash_trinity_scepter",
	"abilities/pangolier/pangolier_shield_crash_trinity",
	LUA_MODIFIER_MOTION_NONE
)

pangolier_shield_crash_trinity = class({})

local PARTICLE_CAST = "particles/units/heroes/hero_pangolier/pangolier_tailthump_cast.vpcf"
local PARTICLE_SMASH = "particles/units/heroes/hero_pangolier/pangolier_tailthump_hero.vpcf"
local PARTICLE_BUFF = "particles/units/heroes/hero_pangolier/pangolier_tailthump_buff.vpcf"
local PARTICLE_BUFF_EGG = "particles/units/heroes/hero_pangolier/pangolier_tailthump_buff_egg.vpcf"
local PARTICLE_BUFF_STREAKS = "particles/units/heroes/hero_pangolier/pangolier_tailthump_buff_streaks.vpcf"
local PARTICLE_SWASH = "particles/units/heroes/hero_pangolier/pangolier_swashbuckler.vpcf"

local GYROSHELL_MODIFIER = "modifier_pangolier_gyroshell"
local ROLLUP_MODIFIER = "modifier_pangolier_rollup"
local BARRIER_MODIFIER = "modifier_pangolier_shield_crash_trinity_barrier"
local JUMP_MODIFIER = "modifier_pangolier_shield_crash_trinity_jump"
local SCEPTER_MODIFIER = "modifier_pangolier_shield_crash_trinity_scepter"
local DEFAULT_ROLL_SPEED = 550
local SWASH_RANGE_FALLBACK = 850
local SWASH_WIDTH_FALLBACK = 155
local SWASH_INTERVAL_FALLBACK = 0.1
local SWASH_DAMAGE_FALLBACK = { 35, 65, 95, 125 }

local function IsValid(entity)
	return entity ~= nil and not entity:IsNull()
end

local function UnitForward(unit)
	if not IsValid(unit) or not unit.GetForwardVector then
		return Vector(1, 0, 0)
	end

	local forward = unit:GetForwardVector()
	if not forward then
		return Vector(1, 0, 0)
	end

	forward = Vector(forward.x or 0, forward.y or 0, 0)
	if forward:Length2D() < 0.01 then
		return Vector(1, 0, 0)
	end

	return forward:Normalized()
end

local function CardinalDirections(forward)
	forward = Vector((forward and forward.x) or 0, (forward and forward.y) or 0, 0)
	if forward:Length2D() < 0.01 then
		forward = Vector(1, 0, 0)
	else
		forward = forward:Normalized()
	end

	local right = Vector(-forward.y, forward.x, 0)
	if right:Length2D() < 0.01 then
		right = Vector(0, 1, 0)
	else
		right = right:Normalized()
	end

	return {
		forward,
		right,
		Vector(-forward.x, -forward.y, 0),
		Vector(-right.x, -right.y, 0),
	}
end

local function AbilitySpecial(ability, names, fallback)
	if not IsValid(ability) then
		return fallback
	end
	for _, name in ipairs(names) do
		local value = ability:GetSpecialValueFor(name)
		if value and value ~= 0 then
			return value
		end
	end
	return fallback
end

function pangolier_shield_crash_trinity:Precache(context)
	if self:GetCaster() and self:GetCaster():IsIllusion() then
		return
	end

	PrecacheResource("particle", PARTICLE_CAST, context)
	PrecacheResource("particle", "particles/units/heroes/hero_pangolier/pangolier_tailthump.vpcf", context)
	PrecacheResource("particle", PARTICLE_SMASH, context)
	PrecacheResource("particle", PARTICLE_BUFF, context)
	PrecacheResource("particle", PARTICLE_BUFF_EGG, context)
	PrecacheResource("particle", PARTICLE_BUFF_STREAKS, context)
	PrecacheResource("particle", PARTICLE_SWASH, context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_pangolier.vsndevts", context)
end

function pangolier_shield_crash_trinity:GetRadius()
	local radius = self:GetSpecialValueFor("radius")
	if GetHeroBonusSpellAoE then
		radius = radius + (GetHeroBonusSpellAoE(self:GetCaster()) or 0)
	end
	return math.max(0, radius)
end

function pangolier_shield_crash_trinity:GetAOERadius()
	return self:GetRadius()
end

function pangolier_shield_crash_trinity:GetDamage()
	local caster = self:GetCaster()
	local mind_power = 0
	if caster and GetHeroMindPower then
		mind_power = GetHeroMindPower(caster) or 0
	end

	return math.max(0,
		self:GetSpecialValueFor("damage")
		+ mind_power * self:GetSpecialValueFor("mind_power_multiplier")
	)
end

function pangolier_shield_crash_trinity:IsInBall()
	local caster = self:GetCaster()
	if not IsValid(caster) then
		return false, false
	end

	local rolled_up = caster:HasModifier(ROLLUP_MODIFIER)
	if rolled_up then
		return true, true
	end

	if caster:HasModifier(GYROSHELL_MODIFIER) then
		return true, false
	end

	if caster.FindAllModifiers then
		for _, modifier in pairs(caster:FindAllModifiers()) do
			if modifier and modifier.GetName then
				local name = modifier:GetName() or ""
				if string.find(name, "pangolier_gyroshell", 1, true)
					and not string.find(name, "stunned", 1, true)
					and not string.find(name, "timeout", 1, true)
				then
					return true, false
				end
			end
		end
	end

	return false, false
end

function pangolier_shield_crash_trinity:GetRollSpeed()
	local caster = self:GetCaster()
	if not IsValid(caster) then
		return DEFAULT_ROLL_SPEED
	end

	local gyroshell = caster:FindAbilityByName("pangolier_gyroshell")
	if IsValid(gyroshell) then
		local speed = AbilitySpecial(gyroshell, { "forward_move_speed", "roll_speed" }, 0)
		if speed > 0 then
			return speed
		end
	end

	return DEFAULT_ROLL_SPEED
end

function pangolier_shield_crash_trinity:ExtendBall(duration)
	local caster = self:GetCaster()
	if not IsValid(caster) then
		return
	end

	local gyro = caster:FindModifierByName(GYROSHELL_MODIFIER)
	if gyro and gyro.GetRemainingTime and gyro:GetRemainingTime() < duration and gyro.SetDuration then
		gyro:SetDuration(duration + 0.05, true)
	end
end

function pangolier_shield_crash_trinity:OnSpellStart()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	if not IsValid(caster) then
		return
	end

	local in_ball, rolled_up = self:IsInBall()
	local duration = self:GetSpecialValueFor(in_ball and "jump_duration_gyroshell" or "jump_duration")
	local height = self:GetSpecialValueFor(in_ball and "jump_height_gyroshell" or "jump_height")
	local distance = self:GetSpecialValueFor("jump_horizontal_distance")

	if in_ball and not rolled_up then
		distance = self:GetRollSpeed() * duration
		self:ExtendBall(duration)
	elseif rolled_up then
		distance = 1
	end

	if not in_ball and (caster:IsRooted() or caster:IsStunned() or (caster.IsLeashed and caster:IsLeashed())) then
		distance = 1
		height = height * 0.7
	end

	duration = math.max(0.05, duration)
	distance = math.max(1, distance)

	local existing = caster:FindModifierByName(JUMP_MODIFIER)
	if existing then
		existing:Destroy()
	end

	caster:StartGesture(ACT_DOTA_CAST_ABILITY_2)
	caster:EmitSound("Hero_Pangolier.TailThump.Cast")

	local forward = UnitForward(caster)
	caster:AddNewModifier(caster, self, JUMP_MODIFIER, {
		duration = duration,
		height = height,
		distance = distance,
		dir_x = forward.x,
		dir_y = forward.y,
		in_ball = in_ball and 1 or 0,
	})

	if caster:HasScepter() then
		self:CastScepterSwashbuckles(forward)
	end
end

function pangolier_shield_crash_trinity:CastScepterSwashbuckles(forward)
	local caster = self:GetCaster()
	if not IsValid(caster) then
		return
	end

	local swash = caster:FindAbilityByName("pangolier_swashbuckle")
	if not IsValid(swash) or swash:GetLevel() < 1 then
		return
	end

	forward = Vector((forward and forward.x) or 0, (forward and forward.y) or 0, 0)
	if forward:Length2D() < 0.01 then
		forward = UnitForward(caster)
	else
		forward = forward:Normalized()
	end

	local strikes = math.max(1, math.floor(self:GetSpecialValueFor("scepter_strikes") + 0.5))
	local damage_pct = self:GetSpecialValueFor("scepter_damage_pct")
	if damage_pct <= 0 then
		damage_pct = 75
	end

	local slash_range = AbilitySpecial(swash, { "range", "slash_range", "end_radius" }, SWASH_RANGE_FALLBACK)
	if slash_range < 200 then
		slash_range = SWASH_RANGE_FALLBACK
	end
	local slash_width = AbilitySpecial(swash, { "start_radius", "slash_width", "end_radius" }, SWASH_WIDTH_FALLBACK)
	local interval = AbilitySpecial(swash, { "attack_interval", "slash_interval" }, SWASH_INTERVAL_FALLBACK)
	local slash_damage = AbilitySpecial(swash, { "damage", "strike_damage" }, 0)
	if slash_damage <= 0 then
		slash_damage = SWASH_DAMAGE_FALLBACK[math.max(1, math.min(4, swash:GetLevel()))]
	end

	local existing = caster:FindModifierByName(SCEPTER_MODIFIER)
	if existing then
		existing:Destroy()
	end

	caster:AddNewModifier(caster, self, SCEPTER_MODIFIER, {
		duration = strikes * math.max(0.05, interval) + 0.15,
		slash_damage = slash_damage,
		outgoing_pct = damage_pct,
		strikes = strikes,
		slash_range = slash_range,
		slash_width = slash_width,
		interval = interval,
		slow_duration = AbilitySpecial(swash, { "slow_duration" }, 0.6),
		fwd_x = forward.x,
		fwd_y = forward.y,
	})
end

function pangolier_shield_crash_trinity:Land()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	if not IsValid(caster) or not caster:IsAlive() then
		return
	end

	caster:FadeGesture(ACT_DOTA_CAST_ABILITY_2)
	if not caster:HasModifier(GYROSHELL_MODIFIER) then
		caster:FadeGesture(ACT_DOTA_RUN)
	end

	local origin = GetGroundPosition(caster:GetAbsOrigin(), caster)
	if not caster:HasModifier(GYROSHELL_MODIFIER) then
		FindClearSpaceForUnit(caster, origin, false)
		origin = caster:GetAbsOrigin()
	end

	local radius = self:GetRadius()
	local damage = self:GetDamage()

	GridNav:DestroyTreesAroundPoint(origin, radius, false)

	local enemies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		origin,
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	local hit_hero = false
	for _, enemy in ipairs(enemies) do
		if IsValid(enemy) and enemy:IsAlive() then
			ApplyDamage({
				attacker = caster,
				victim = enemy,
				damage = damage,
				damage_type = DAMAGE_TYPE_PHYSICAL,
				ability = self,
			})
			if enemy:IsRealHero() then
				hit_hero = true
			end
		end
	end

	if hit_hero then
		self:AddBarrier()
	end

	local smash = ParticleManager:CreateParticle(PARTICLE_SMASH, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(smash, 0, origin)
	ParticleManager:SetParticleControl(smash, 1, Vector(radius, radius, radius))
	ParticleManager:ReleaseParticleIndex(smash)

	EmitSoundOnLocationWithCaster(origin, "Hero_Pangolier.TailThump", caster)
end

function pangolier_shield_crash_trinity:AddBarrier()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	if not IsValid(caster) then
		return
	end

	local existing = caster:FindModifierByName(BARRIER_MODIFIER)
	if existing then
		existing:Destroy()
	end

	caster:AddNewModifier(caster, self, BARRIER_MODIFIER, {
		duration = self:GetSpecialValueFor("duration"),
		shield_amount = self:GetSpecialValueFor("hero_stacks"),
	})
	caster:EmitSound("Hero_Pangolier.TailThump.Shield")
end

modifier_pangolier_shield_crash_trinity_jump = class({})

function modifier_pangolier_shield_crash_trinity_jump:IsHidden()
	return true
end

function modifier_pangolier_shield_crash_trinity_jump:IsPurgable()
	return false
end

function modifier_pangolier_shield_crash_trinity_jump:IsDebuff()
	return false
end

function modifier_pangolier_shield_crash_trinity_jump:GetAttributes()
	return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end

function modifier_pangolier_shield_crash_trinity_jump:OnCreated(kv)
	kv = kv or {}
	self.height = tonumber(kv.height) or 0
	self.distance = math.max(0, tonumber(kv.distance) or 0)
	self.in_ball = tonumber(kv.in_ball) == 1

	local dir = Vector(tonumber(kv.dir_x) or 0, tonumber(kv.dir_y) or 0, 0)
	if dir:Length2D() < 0.01 then
		dir = UnitForward(self:GetParent())
	end
	self.dir = dir:Normalized()

	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if not IsValid(parent) then
		self.origin = Vector(0, 0, 0)
		return
	end

	self.origin = parent:GetAbsOrigin()

	local cast_fx = ParticleManager:CreateParticle(PARTICLE_CAST, PATTACH_ABSORIGIN_FOLLOW, parent)
	self:AddParticle(cast_fx, false, false, -1, false, false)

	self:StartIntervalThink(1 / 120)
	self:OnIntervalThink()
end

function modifier_pangolier_shield_crash_trinity_jump:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_VISUAL_Z_DELTA,
		MODIFIER_PROPERTY_DISABLE_TURNING,
	}
end

function modifier_pangolier_shield_crash_trinity_jump:GetJumpHeightNow()
	local duration = self:GetDuration()
	if not duration or duration <= 0 then
		return 0
	end
	local t = math.min(1, math.max(0, self:GetElapsedTime() / duration))
	return (self.height or 0) * 4 * t * (1 - t)
end

function modifier_pangolier_shield_crash_trinity_jump:GetModifierVisualZDelta()
	return self:GetJumpHeightNow()
end

function modifier_pangolier_shield_crash_trinity_jump:GetModifierDisableTurning()
	return 1
end

function modifier_pangolier_shield_crash_trinity_jump:CheckState()
	return {
		[MODIFIER_STATE_STUNNED] = true,
		[MODIFIER_STATE_FLYING] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_FLYING_FOR_PATHING_PURPOSES_ONLY] = true,
	}
end

function modifier_pangolier_shield_crash_trinity_jump:OnIntervalThink()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if not IsValid(parent) then
		self:Destroy()
		return
	end

	local duration = math.max(0.05, self:GetDuration())
	local t = math.min(1, math.max(0, self:GetElapsedTime() / duration))
	local origin = self.origin or parent:GetAbsOrigin()
	local dir = self.dir or Vector(1, 0, 0)
	local pos = origin + dir * ((self.distance or 0) * t)
	pos.z = GetGroundHeight(pos, parent) + self:GetJumpHeightNow()
	parent:SetAbsOrigin(pos)
end

function modifier_pangolier_shield_crash_trinity_jump:OnDestroy()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	local ability = self:GetAbility()
	if IsValid(parent) then
		local pos = parent:GetAbsOrigin()
		pos.z = GetGroundHeight(pos, parent)
		parent:SetAbsOrigin(pos)
	end

	if IsValid(ability) and ability.Land then
		ability:Land()
	end
end

modifier_pangolier_shield_crash_trinity_scepter = class({})

function modifier_pangolier_shield_crash_trinity_scepter:IsHidden()
	return true
end

function modifier_pangolier_shield_crash_trinity_scepter:IsPurgable()
	return false
end

function modifier_pangolier_shield_crash_trinity_scepter:GetAttributes()
	return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end

function modifier_pangolier_shield_crash_trinity_scepter:OnCreated(kv)
	kv = kv or {}
	self.slash_damage = tonumber(kv.slash_damage) or 0
	local outgoing = tonumber(kv.outgoing_pct) or 75
	self.outgoing_bonus = outgoing - 100
	self.strikes = math.max(1, math.floor((tonumber(kv.strikes) or 2) + 0.5))
	self.slash_range = tonumber(kv.slash_range) or SWASH_RANGE_FALLBACK
	self.slash_width = tonumber(kv.slash_width) or SWASH_WIDTH_FALLBACK
	self.interval = math.max(0.05, tonumber(kv.interval) or SWASH_INTERVAL_FALLBACK)
	self.slow_duration = tonumber(kv.slow_duration) or 0.6
	self.fwd_x = tonumber(kv.fwd_x) or 0
	self.fwd_y = tonumber(kv.fwd_y) or 0
	self.done = 0
	self.attack_adjust = 0
	self.fx = {}

	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	local current = 0
	if IsValid(parent) and parent.GetAverageTrueAttackDamage then
		current = parent:GetAverageTrueAttackDamage(nil) or 0
	end
	self.attack_adjust = self.slash_damage - current

	self:StrikeAll()
	if self.done < self.strikes then
		self:StartIntervalThink(self.interval)
	end
end

function modifier_pangolier_shield_crash_trinity_scepter:OnIntervalThink()
	self:StrikeAll()
	if self.done >= self.strikes then
		self:StartIntervalThink(-1)
	end
end

function modifier_pangolier_shield_crash_trinity_scepter:StrikeAll()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if not IsValid(parent) or not parent:IsAlive() then
		self:Destroy()
		return
	end

	self.done = (self.done or 0) + 1

	local origin = GetGroundPosition(parent:GetAbsOrigin(), parent)
	local forward = Vector(self.fwd_x or 0, self.fwd_y or 0, 0)
	if forward:Length2D() < 0.01 then
		forward = UnitForward(parent)
		self.fwd_x = forward.x
		self.fwd_y = forward.y
	else
		forward = forward:Normalized()
	end

	local swash = parent:FindAbilityByName("pangolier_swashbuckle")
	local range = self.slash_range or SWASH_RANGE_FALLBACK
	local width = self.slash_width or SWASH_WIDTH_FALLBACK
	local slow_duration = self.slow_duration or 0

	for _, dir in ipairs(CardinalDirections(forward)) do
		local end_pos = origin + dir * range
		local fx = ParticleManager:CreateParticle(PARTICLE_SWASH, PATTACH_ABSORIGIN_FOLLOW, parent)
		ParticleManager:SetParticleControl(fx, 1, dir)
		self:AddParticle(fx, true, false, -1, false, false)
		self.fx = self.fx or {}
		table.insert(self.fx, fx)
		Timers:CreateTimer(0.2, function()
			ParticleManager:DestroyParticle(fx, true)
			ParticleManager:ReleaseParticleIndex(fx)
			return nil
		end)

		local enemies
		if FindUnitsInLine then
			enemies = FindUnitsInLine(
				parent:GetTeamNumber(),
				origin,
				end_pos,
				nil,
				width,
				DOTA_UNIT_TARGET_TEAM_ENEMY,
				DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
				DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES
			)
		else
			enemies = FindUnitsInRadius(
				parent:GetTeamNumber(),
				origin,
				nil,
				range,
				DOTA_UNIT_TARGET_TEAM_ENEMY,
				DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
				DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
				FIND_ANY_ORDER,
				false
			)
		end

		for _, enemy in ipairs(enemies) do
			if IsValid(enemy) and enemy:IsAlive() then
				parent:PerformAttack(enemy, true, true, true, false, false, false, true)
				if slow_duration > 0 and IsValid(swash) then
					enemy:AddNewModifier(parent, swash, "modifier_pangolier_swashbuckle_slow", {
						duration = slow_duration * (1 - (enemy.GetStatusResistance and enemy:GetStatusResistance() or 0)),
					})
				end
			end
		end
	end

	EmitSoundOnLocationWithCaster(origin, "Hero_Pangolier.Swashbuckle", parent)
end

function modifier_pangolier_shield_crash_trinity_scepter:OnDestroy()
	if not IsServer() then
		return
	end

	for _, fx in ipairs(self.fx or {}) do
		ParticleManager:DestroyParticle(fx, true)
		ParticleManager:ReleaseParticleIndex(fx)
	end
	self.fx = nil
end

function modifier_pangolier_shield_crash_trinity_scepter:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_DAMAGEOUTGOING_PERCENTAGE,
	}
end

function modifier_pangolier_shield_crash_trinity_scepter:GetModifierPreAttack_BonusDamage()
	return self.attack_adjust or 0
end

function modifier_pangolier_shield_crash_trinity_scepter:GetModifierDamageOutgoing_Percentage()
	return self.outgoing_bonus or -25
end

modifier_pangolier_shield_crash_trinity_barrier = class({})

function modifier_pangolier_shield_crash_trinity_barrier:IsHidden()
	return false
end

function modifier_pangolier_shield_crash_trinity_barrier:IsDebuff()
	return false
end

function modifier_pangolier_shield_crash_trinity_barrier:IsPurgable()
	return true
end

function modifier_pangolier_shield_crash_trinity_barrier:GetTexture()
	return "pangolier_shield_crash"
end

function modifier_pangolier_shield_crash_trinity_barrier:OnCreated(kv)
	self.max_shield = 0
	self.current_shield = 0
	self:InitShield(kv)

	if not IsServer() then
		return
	end

	self:SetHasCustomTransmitterData(true)
	self:SyncShield(true)
	self:CreateBarrierParticles()
end

function modifier_pangolier_shield_crash_trinity_barrier:OnRefresh(kv)
	self:InitShield(kv)
	if IsServer() then
		self:SyncShield(true)
	end
end

function modifier_pangolier_shield_crash_trinity_barrier:InitShield(kv)
	local amount = tonumber(kv and kv.shield_amount)
	if not amount or amount < 0 then
		local ability = self:GetAbility()
		amount = ability and ability:GetSpecialValueFor("hero_stacks") or 0
	end
	self.max_shield = math.max(0, math.floor(amount))
	self.current_shield = self.max_shield
end

function modifier_pangolier_shield_crash_trinity_barrier:SyncShield(push_to_clients)
	if not IsServer() then
		return
	end
	self:SetStackCount(math.max(0, math.floor(self.current_shield or 0)))
	if push_to_clients then
		self:SendBuffRefreshToClients()
	end
end

function modifier_pangolier_shield_crash_trinity_barrier:AddCustomTransmitterData()
	return {
		max_shield = self.max_shield or 0,
		current_shield = self.current_shield or 0,
	}
end

function modifier_pangolier_shield_crash_trinity_barrier:HandleCustomTransmitterData(data)
	self.max_shield = data.max_shield or 0
	self.current_shield = data.current_shield or 0
end

function modifier_pangolier_shield_crash_trinity_barrier:CreateBarrierParticles()
	local parent = self:GetParent()
	if not IsValid(parent) then
		return
	end

	local buff = ParticleManager:CreateParticle(PARTICLE_BUFF, PATTACH_ABSORIGIN_FOLLOW, parent)
	ParticleManager:SetParticleControlEnt(buff, 1, parent, PATTACH_ABSORIGIN_FOLLOW, nil, Vector(0, 0, 0), false)
	ParticleManager:SetParticleControl(buff, 3, Vector(255, 255, 255))
	self:AddParticle(buff, false, false, -1, true, false)

	local egg = ParticleManager:CreateParticle(PARTICLE_BUFF_EGG, PATTACH_ABSORIGIN_FOLLOW, parent)
	ParticleManager:SetParticleControlEnt(egg, 1, parent, PATTACH_ABSORIGIN_FOLLOW, nil, Vector(0, 0, 0), false)
	self:AddParticle(egg, false, false, -1, true, false)

	local streaks = ParticleManager:CreateParticle(PARTICLE_BUFF_STREAKS, PATTACH_ABSORIGIN_FOLLOW, parent)
	ParticleManager:SetParticleControlEnt(streaks, 1, parent, PATTACH_ABSORIGIN_FOLLOW, nil, Vector(0, 0, 0), false)
	self:AddParticle(streaks, false, false, -1, true, false)
end

function modifier_pangolier_shield_crash_trinity_barrier:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_INCOMING_DAMAGE_CONSTANT,
		MODIFIER_PROPERTY_TOOLTIP,
	}
end

function modifier_pangolier_shield_crash_trinity_barrier:GetModifierIncomingDamageConstant(params)
	if not IsServer() then
		if params and params.report_max then
			return self.max_shield or 0
		end
		return math.max(0, self:GetStackCount())
	end

	if not params then
		return 0
	end

	local parent = self:GetParent()
	if params.target and params.target ~= parent then
		return 0
	end

	if (self.current_shield or 0) <= 0 then
		return 0
	end

	local blocked = math.min(params.damage, self.current_shield)
	self.current_shield = self.current_shield - blocked
	self:SyncShield(false)

	if self.current_shield <= 0 then
		self:Destroy()
	end

	return -blocked
end

function modifier_pangolier_shield_crash_trinity_barrier:OnTooltip()
	return math.max(0, self:GetStackCount())
end
