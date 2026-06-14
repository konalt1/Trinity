LinkLuaModifier("modifier_ringmaster_tame_fear", "abilities/ringmaster/ringmaster_prototype", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_ringmaster_knives_slow", "abilities/ringmaster/ringmaster_prototype", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_ringmaster_knives_bleed", "abilities/ringmaster/ringmaster_prototype", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_ringmaster_box_thinker", "abilities/ringmaster/ringmaster_prototype", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_ringmaster_box_capture", "abilities/ringmaster/ringmaster_prototype", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_ringmaster_box_damage_tracker", "abilities/ringmaster/ringmaster_prototype", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_ringmaster_box_control", "abilities/ringmaster/ringmaster_prototype", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_ringmaster_krugger", "abilities/ringmaster/ringmaster_prototype", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_ringmaster_krugger_carried", "abilities/ringmaster/ringmaster_prototype", LUA_MODIFIER_MOTION_NONE)

local RINGMASTER_PARTICLES = {
	"particles/basic_explosion/basic_explosion.vpcf",
	"particles/basic_ambient/basic_ambient.vpcf",
	"particles/basic_projectile/basic_projectile.vpcf",
	"particles/basic_trail/basic_trail.vpcf",
	"particles/omniknight/pulse_main.vpcf",
	"particles/slark_shard_depth_shroud.vpcf",
}

local RINGMASTER_MODELS = {
	"models/heroes/ringmaster/ringmaster.vmdl",
	"models/heroes/ringmaster/ringmaster_wheel_decoy.vmdl",
	"models/heroes/ringmaster/ringmaster_whip.vmdl",
	"particles/units/heroes/hero_ringmaster/ringmaster_particle_dagger.vmdl",
	"models/heroes/ringmaster/ringmaster_box.vmdl",
}

local RINGMASTER_SOUNDS = {
	"soundevents/game_sounds_heroes/game_sounds_ringmaster.vsndevts",
}

local function PrecacheRingmasterPrototype(context)
	for _, particle in pairs(RINGMASTER_PARTICLES) do
		PrecacheResource("particle", particle, context)
	end

	for _, model in pairs(RINGMASTER_MODELS) do
		PrecacheResource("model", model, context)
	end

	for _, soundfile in pairs(RINGMASTER_SOUNDS) do
		PrecacheResource("soundfile", soundfile, context)
	end
end

local function SpawnRingmasterProp(caster, modelName, position, scale)
	local prop = CreateUnitByName("npc_dota_companion", position, false, nil, nil, caster:GetTeamNumber())
	if prop then
		prop:SetModel(modelName)
		prop:SetOriginalModel(modelName)
		if scale then
			prop:SetModelScale(scale)
		end
		prop:AddNewModifier(caster, nil, "modifier_invulnerable", {})
		prop:AddNewModifier(caster, nil, "modifier_unselectable", {})
		prop:AddNewModifier(caster, nil, "modifier_phased", {})
		prop:SetMoveCapability(DOTA_UNIT_CAP_MOVE_NONE)
	end
	return prop
end

ringmaster_tame_the_beasts_custom = class({})

function ringmaster_tame_the_beasts_custom:Precache(context)
	PrecacheRingmasterPrototype(context)
end

function ringmaster_tame_the_beasts_custom:GetChannelTime()
	return self:GetSpecialValueFor("max_channel_time")
end

function ringmaster_tame_the_beasts_custom:OnSpellStart()
	self.target_point = self:GetCursorPosition()
	self.channel_started = GameRules:GetGameTime()
	local caster = self:GetCaster()
	caster:EmitSound("Hero_Ringmaster.Tame.Cast")

	-- Spawn whip prop above caster
	local prop = SpawnRingmasterProp(caster, "models/heroes/ringmaster/ringmaster_whip.vmdl", caster:GetAbsOrigin() + Vector(0, 0, 120))
	if prop then
		prop:SetForwardVector(caster:GetForwardVector())
		prop:StartGesture(ACT_DOTA_CAST_ABILITY_1)
		self.whip_prop = prop

		-- Keep prop at caster's position
		Timers:CreateTimer("ringmaster_whip_timer_" .. prop:GetEntityIndex(), {
			useGameTime = true,
			callback = function()
				if not self:IsNull() and self.whip_prop and not self.whip_prop:IsNull() and caster and not caster:IsNull() and caster:IsChanneling() then
					self.whip_prop:SetAbsOrigin(caster:GetAbsOrigin() + Vector(0, 0, 120))
					self.whip_prop:SetForwardVector(caster:GetForwardVector())
					return 0.03
				else
					return nil
				end
			end
		})
	end
end

function ringmaster_tame_the_beasts_custom:OnChannelFinish(interrupted)
	local caster = self:GetCaster()
	if self.whip_prop and not self.whip_prop:IsNull() then
		Timers:RemoveTimer("ringmaster_whip_timer_" .. self.whip_prop:GetEntityIndex())
		self.whip_prop:Destroy()
		self.whip_prop = nil
	end

	if not self.target_point then return end

	local max_channel = math.max(self:GetSpecialValueFor("max_channel_time"), 0.01)
	local elapsed = math.min(GameRules:GetGameTime() - (self.channel_started or GameRules:GetGameTime()), max_channel)
	local charge = math.max(elapsed / max_channel, 0)

	local max_radius = self:GetSpecialValueFor("max_radius")
	local min_radius = self:GetSpecialValueFor("min_radius")
	local radius = max_radius - ((max_radius - min_radius) * charge)

	local base_damage = self:GetSpecialValueFor("min_damage")
	local max_damage = self:GetSpecialValueFor("max_damage") + (GetHeroMindPower(caster) * self:GetSpecialValueFor("mind_power_damage"))
	local damage = base_damage + ((max_damage - base_damage) * charge)
	local fear_duration = self:GetSpecialValueFor("min_fear") + ((self:GetSpecialValueFor("max_fear") - self:GetSpecialValueFor("min_fear")) * charge)

	local particle = ParticleManager:CreateParticle("particles/basic_explosion/basic_explosion.vpcf", PATTACH_WORLDORIGIN, caster)
	ParticleManager:SetParticleControl(particle, 0, self.target_point)
	ParticleManager:SetParticleControl(particle, 1, Vector(radius, 0, 0))
	ParticleManager:ReleaseParticleIndex(particle)

	local enemies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		self.target_point,
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	for _, enemy in pairs(enemies) do
		ApplyDamage({
			victim = enemy,
			attacker = caster,
			damage = damage,
			damage_type = self:GetAbilityDamageType(),
			ability = self,
		})
		enemy:AddNewModifier(caster, self, "modifier_ringmaster_tame_fear", {
			duration = fear_duration * (1 - enemy:GetStatusResistance()),
			source_x = caster:GetAbsOrigin().x,
			source_y = caster:GetAbsOrigin().y,
		})
	end

	caster:EmitSound("Hero_Ringmaster.Tame.Impact")
end

modifier_ringmaster_tame_fear = class({})

function modifier_ringmaster_tame_fear:IsDebuff() return true end
function modifier_ringmaster_tame_fear:IsPurgable() return true end

function modifier_ringmaster_tame_fear:OnCreated(kv)
	if not IsServer() then return end
	self.source = Vector(kv.source_x or 0, kv.source_y or 0, 0)
	self:StartIntervalThink(0.1)
end

function modifier_ringmaster_tame_fear:OnIntervalThink()
	local parent = self:GetParent()
	local origin = parent:GetAbsOrigin()
	local direction = (origin - self.source):Normalized()
	parent:MoveToPosition(origin + direction * 450)
end

function modifier_ringmaster_tame_fear:CheckState()
	return {
		[MODIFIER_STATE_FEARED] = true,
		[MODIFIER_STATE_COMMAND_RESTRICTED] = true,
	}
end

function modifier_ringmaster_tame_fear:GetEffectName()
	return "particles/basic_ambient/basic_ambient.vpcf"
end

function modifier_ringmaster_tame_fear:GetEffectAttachType()
	return PATTACH_OVERHEAD_FOLLOW
end

ringmaster_knives_out_custom = class({})

function ringmaster_knives_out_custom:Precache(context)
	PrecacheRingmasterPrototype(context)
end

function ringmaster_knives_out_custom:OnSpellStart()
	local caster = self:GetCaster()
	local point = self:GetCursorPosition()
	local direction = (point - caster:GetAbsOrigin()):Normalized()
	direction.z = 0
	if direction:Length2D() == 0 then
		direction = caster:GetForwardVector()
		direction.z = 0
	end
	direction = direction:Normalized()

	local speed = self:GetSpecialValueFor("speed")
	local range = self:GetSpecialValueFor("range")
	local duration = range / speed
	local spawn_origin = caster:GetAbsOrigin() + Vector(0, 0, 80)
	local velocity = direction * speed

	ProjectileManager:CreateLinearProjectile({
		Ability = self,
		EffectName = "",
		vSpawnOrigin = caster:GetAbsOrigin(),
		fDistance = range,
		fStartRadius = self:GetSpecialValueFor("width"),
		fEndRadius = self:GetSpecialValueFor("width"),
		Source = caster,
		bHasFrontalCone = false,
		bReplaceExisting = false,
		iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
		iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_NONE,
		bDeleteOnHit = true,
		vVelocity = velocity,
		bProvidesVision = true,
		iVisionRadius = self:GetSpecialValueFor("width") * 2,
		iVisionTeamNumber = caster:GetTeamNumber(),
	})

	local dagger_prop = SpawnRingmasterProp(caster, "particles/units/heroes/hero_ringmaster/ringmaster_particle_dagger.vmdl", spawn_origin)
	if dagger_prop then
		dagger_prop:SetForwardVector(direction)
		local trail_pfx = ParticleManager:CreateParticle("particles/basic_trail/basic_trail.vpcf", PATTACH_ABSORIGIN_FOLLOW, dagger_prop)
		
		local start_time = GameRules:GetGameTime()
		
		Timers:CreateTimer(function()
			if dagger_prop and not dagger_prop:IsNull() then
				local elapsed = GameRules:GetGameTime() - start_time
				if elapsed >= duration then
					ParticleManager:DestroyParticle(trail_pfx, false)
					ParticleManager:ReleaseParticleIndex(trail_pfx)
					dagger_prop:Destroy()
					return nil
				end
				local new_pos = spawn_origin + velocity * elapsed
				dagger_prop:SetAbsOrigin(new_pos)
				return 0.03
			else
				if trail_pfx then
					ParticleManager:DestroyParticle(trail_pfx, false)
					ParticleManager:ReleaseParticleIndex(trail_pfx)
				end
				return nil
			end
		end)
	end

	caster:EmitSound("Hero_Ringmaster.Impale.Cast")
end

function ringmaster_knives_out_custom:OnProjectileHit(target, location)
	if not target then return true end
	local caster = self:GetCaster()

	local units = FindUnitsInRadius(
		caster:GetTeamNumber(),
		location,
		nil,
		150,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY + DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_ALL,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_CLOSEST,
		false
	)
	for _, unit in pairs(units) do
		if unit:GetUnitName() == "npc_dota_companion" and unit:GetModelName() == "particles/units/heroes/hero_ringmaster/ringmaster_particle_dagger.vmdl" then
			unit:Destroy()
			break
		end
	end

	local pfx = ParticleManager:CreateParticle("particles/basic_explosion/basic_explosion.vpcf", PATTACH_ABSORIGIN, target)
	ParticleManager:ReleaseParticleIndex(pfx)

	ApplyDamage({
		victim = target,
		attacker = caster,
		damage = self:GetSpecialValueFor("impact_damage"),
		damage_type = self:GetAbilityDamageType(),
		ability = self,
	})

	target:AddNewModifier(caster, self, "modifier_ringmaster_knives_slow", {
		duration = self:GetSpecialValueFor("slow_duration") * (1 - target:GetStatusResistance()),
	})
	target:AddNewModifier(caster, self, "modifier_ringmaster_knives_bleed", {
		duration = self:GetSpecialValueFor("bleed_duration") * (1 - target:GetStatusResistance()),
	})

	local capture = target:FindModifierByName("modifier_ringmaster_box_capture")
	if capture and caster:HasScepter() then
		capture:AddKnifeStack()
	end

	target:EmitSound("Hero_Ringmaster.Impale.Target")
	return true
end

modifier_ringmaster_knives_slow = class({})

function modifier_ringmaster_knives_slow:IsDebuff() return true end
function modifier_ringmaster_knives_slow:IsPurgable() return true end

function modifier_ringmaster_knives_slow:OnCreated()
	self.slow = -self:GetAbility():GetSpecialValueFor("move_slow_pct")
end

function modifier_ringmaster_knives_slow:DeclareFunctions()
	return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE }
end

function modifier_ringmaster_knives_slow:GetModifierMoveSpeedBonus_Percentage()
	return self.slow
end

modifier_ringmaster_knives_bleed = class({})

function modifier_ringmaster_knives_bleed:IsDebuff() return true end
function modifier_ringmaster_knives_bleed:IsPurgable() return true end

function modifier_ringmaster_knives_bleed:OnCreated()
	if not IsServer() then return end
	self:StartIntervalThink(1.0)
end

function modifier_ringmaster_knives_bleed:OnIntervalThink()
	local parent = self:GetParent()
	local ability = self:GetAbility()
	local damage = ability:GetSpecialValueFor("creep_bleed_damage")

	if parent:IsHero() then
		damage = parent:GetMaxHealth() * ability:GetSpecialValueFor("hero_bleed_pct") * 0.01
	end

	ApplyDamage({
		victim = parent,
		attacker = self:GetCaster(),
		damage = damage,
		damage_type = ability:GetAbilityDamageType(),
		ability = ability,
	})
end

function modifier_ringmaster_knives_bleed:GetEffectName()
	return "particles/basic_trail/basic_trail.vpcf"
end

function modifier_ringmaster_knives_bleed:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

ringmaster_box_game_custom = class({})

function ringmaster_box_game_custom:Precache(context)
	PrecacheRingmasterPrototype(context)
end

function ringmaster_box_game_custom:GetIntrinsicModifierName()
	return "modifier_ringmaster_box_damage_tracker"
end

function ringmaster_box_game_custom:OnSpellStart()
	local caster = self:GetCaster()
	local point = self:GetCursorPosition()

	if HasShard(caster) and self:TryTeleportToBox(point) then
		return
	end

	CreateModifierThinker(
		caster,
		self,
		"modifier_ringmaster_box_thinker",
		{ duration = self:GetSpecialValueFor("box_duration") },
		point,
		caster:GetTeamNumber(),
		false
	)

	caster:EmitSound("Hero_Ringmaster.EscapeAct.Cast")
end

function ringmaster_box_game_custom:TryTeleportToBox(point)
	local caster = self:GetCaster()
	local tracker = caster:FindModifierByName("modifier_ringmaster_box_damage_tracker")
	local last_damage = tracker and tracker.last_damage_time or -999
	if GameRules:GetGameTime() - last_damage < self:GetSpecialValueFor("shard_damage_cooldown") then
		return false
	end

	local thinkers = Entities:FindAllByClassnameWithin("npc_dota_thinker", point, self:GetSpecialValueFor("teleport_select_radius"))
	for _, thinker in pairs(thinkers) do
		if thinker:HasModifier("modifier_ringmaster_box_thinker") and thinker:GetTeamNumber() == caster:GetTeamNumber() then
			FindClearSpaceForUnit(caster, thinker:GetAbsOrigin(), true)
			caster:EmitSound("Hero_Ringmaster.EscapeAct.Cast")
			return true
		end
	end

	return false
end

modifier_ringmaster_box_damage_tracker = class({})

function modifier_ringmaster_box_damage_tracker:IsHidden() return true end
function modifier_ringmaster_box_damage_tracker:IsPurgable() return false end

function modifier_ringmaster_box_damage_tracker:DeclareFunctions()
	return { MODIFIER_EVENT_ON_TAKEDAMAGE }
end

function modifier_ringmaster_box_damage_tracker:OnTakeDamage(event)
	if not IsServer() then return end
	if event.unit == self:GetParent() and event.damage > 0 then
		self.last_damage_time = GameRules:GetGameTime()
	end
end

modifier_ringmaster_box_thinker = class({})

function modifier_ringmaster_box_thinker:IsHidden() return true end
function modifier_ringmaster_box_thinker:IsPurgable() return false end

function modifier_ringmaster_box_thinker:OnCreated()
	if not IsServer() then return end
	local parent = self:GetParent()
	local caster = self:GetCaster()
	self.radius = self:GetAbility():GetSpecialValueFor("trigger_radius")
	self.triggered = false

	self.particle = ParticleManager:CreateParticle("particles/basic_ambient/basic_ambient.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(self.particle, 0, parent:GetAbsOrigin())
	self:AddParticle(self.particle, false, false, -1, false, false)

	-- Spawn Box prop
	local box_prop = SpawnRingmasterProp(caster, "models/heroes/ringmaster/ringmaster_box.vmdl", parent:GetAbsOrigin())
	if box_prop then
		self.box_prop = box_prop
		box_prop:StartGesture(ACT_DOTA_SPAWN)
		
		-- Wait for spawn animation to finish, then play idle
		Timers:CreateTimer(0.8, function()
			if box_prop and not box_prop:IsNull() then
				box_prop:FadeGesture(ACT_DOTA_SPAWN)
				box_prop:StartGesture(ACT_DOTA_IDLE)
			end
		end)
	end

	self:StartIntervalThink(0.1)
end

function modifier_ringmaster_box_thinker:OnDestroy()
	if not IsServer() then return end
	if self.box_prop and not self.box_prop:IsNull() then
		local prop = self.box_prop
		self.box_prop = nil
		
		prop:FadeGesture(ACT_DOTA_IDLE)
		prop:StartGesture(ACT_DOTA_DIE)
		
		Timers:CreateTimer(0.8, function()
			if prop and not prop:IsNull() then
				prop:Destroy()
			end
		end)
	end
end

function modifier_ringmaster_box_thinker:OnIntervalThink()
	if self.triggered then return end
	local caster = self:GetCaster()
	local parent = self:GetParent()
	local enemies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		parent:GetAbsOrigin(),
		nil,
		self.radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_CLOSEST,
		false
	)

	local target = enemies[1]
	if not target then return end

	self.triggered = true
	target:AddNewModifier(caster, self:GetAbility(), "modifier_ringmaster_box_capture", {
		duration = self:GetAbility():GetSpecialValueFor("capture_duration") * (1 - target:GetStatusResistance()),
		origin_x = target:GetAbsOrigin().x,
		origin_y = target:GetAbsOrigin().y,
	})

	ApplyDamage({
		victim = target,
		attacker = caster,
		damage = self:GetAbility():GetSpecialValueFor("capture_damage"),
		damage_type = self:GetAbility():GetAbilityDamageType(),
		ability = self:GetAbility(),
	})

	parent:EmitSound("Hero_Ringmaster.EscapeAct.Target")
	self:Destroy()
end

modifier_ringmaster_box_capture = class({})

function modifier_ringmaster_box_capture:IsDebuff() return true end
function modifier_ringmaster_box_capture:IsPurgable() return true end

function modifier_ringmaster_box_capture:OnCreated(kv)
	if not IsServer() then return end
	self.origin = Vector(kv.origin_x or self:GetParent():GetAbsOrigin().x, kv.origin_y or self:GetParent():GetAbsOrigin().y, self:GetParent():GetAbsOrigin().z)
	self.knives = 0
	self:StartIntervalThink(0.1)
end

function modifier_ringmaster_box_capture:OnIntervalThink()
	local parent = self:GetParent()
	if (parent:GetAbsOrigin() - self.origin):Length2D() > self:GetAbility():GetSpecialValueFor("forced_move_break_distance") then
		ApplyDamage({
			victim = parent,
			attacker = self:GetCaster(),
			damage = self:GetAbility():GetSpecialValueFor("forced_move_damage"),
			damage_type = self:GetAbility():GetAbilityDamageType(),
			ability = self:GetAbility(),
		})
		self:Destroy()
	end
end

function modifier_ringmaster_box_capture:AddKnifeStack()
	if not IsServer() then return end
	self.knives = self.knives + 1
	self:SetStackCount(self.knives)

	if self.knives >= self:GetAbility():GetSpecialValueFor("scepter_knives_required") then
		self:GetParent():AddNewModifier(self:GetCaster(), self:GetAbility(), "modifier_ringmaster_box_control", {
			duration = self:GetAbility():GetSpecialValueFor("scepter_control_duration"),
		})
		self:Destroy()
	end
end

function modifier_ringmaster_box_capture:CheckState()
	return {
		[MODIFIER_STATE_ROOTED] = true,
		[MODIFIER_STATE_DISARMED] = true,
	}
end

function modifier_ringmaster_box_capture:GetEffectName()
	return "particles/omniknight/pulse_main.vpcf"
end

function modifier_ringmaster_box_capture:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

modifier_ringmaster_box_control = class({})

function modifier_ringmaster_box_control:IsDebuff() return true end
function modifier_ringmaster_box_control:IsPurgable() return false end

function modifier_ringmaster_box_control:OnCreated()
	if not IsServer() then return end
	local caster = self:GetCaster()
	local parent = self:GetParent()
	self.previous_owner = parent:GetPlayerOwnerID()
	if caster and caster.GetPlayerOwnerID then
		parent:SetControllableByPlayer(caster:GetPlayerOwnerID(), true)
	end
end

function modifier_ringmaster_box_control:OnDestroy()
	if not IsServer() then return end
	if self.previous_owner and self.previous_owner >= 0 then
		self:GetParent():SetControllableByPlayer(self.previous_owner, true)
	end
end

function modifier_ringmaster_box_control:CheckState()
	return {
		[MODIFIER_STATE_DOMINATED] = true,
	}
end

ringmaster_krugger_custom = class({})

function ringmaster_krugger_custom:Precache(context)
	PrecacheRingmasterPrototype(context)
end

function ringmaster_krugger_custom:OnSpellStart()
	self:GetCaster():AddNewModifier(self:GetCaster(), self, "modifier_ringmaster_krugger", {
		duration = self:GetSpecialValueFor("duration"),
	})
	self:GetCaster():EmitSound("Hero_Ringmaster.Wheel.Cast")
end

modifier_ringmaster_krugger = class({})

function modifier_ringmaster_krugger:IsBuff() return true end
function modifier_ringmaster_krugger:IsPurgable() return false end

function modifier_ringmaster_krugger:OnCreated()
	if not IsServer() then return end
	self.captured = nil
	self:StartIntervalThink(0.05)
end

function modifier_ringmaster_krugger:OnIntervalThink()
	local parent = self:GetParent()
	local ability = self:GetAbility()
	local vision = ability:GetSpecialValueFor("vision_range")

	AddFOWViewer(DOTA_TEAM_GOODGUYS, parent:GetAbsOrigin(), vision, 0.15, false)
	AddFOWViewer(DOTA_TEAM_BADGUYS, parent:GetAbsOrigin(), vision, 0.15, false)

	if self.captured and not self.captured:IsNull() and self.captured:IsAlive() then return end

	local enemies = FindUnitsInRadius(
		parent:GetTeamNumber(),
		parent:GetAbsOrigin(),
		nil,
		ability:GetSpecialValueFor("grab_radius"),
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO,
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
		FIND_CLOSEST,
		false
	)

	local target = enemies[1]
	if not target then return end

	self.captured = target
	target:AddNewModifier(parent, ability, "modifier_ringmaster_krugger_carried", {
		duration = ability:GetSpecialValueFor("grab_duration") * (1 - target:GetStatusResistance()),
	})
	ApplyDamage({
		victim = target,
		attacker = parent,
		damage = ability:GetSpecialValueFor("grab_damage"),
		damage_type = ability:GetAbilityDamageType(),
		ability = ability,
	})
	parent:EmitSound("Hero_Ringmaster.Wheel.Target")
end

function modifier_ringmaster_krugger:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_TURN_RATE_PERCENTAGE,
		MODIFIER_PROPERTY_BONUS_DAY_VISION,
		MODIFIER_PROPERTY_BONUS_NIGHT_VISION,
	}
end

function modifier_ringmaster_krugger:GetModifierMoveSpeedBonus_Constant()
	return self:GetAbility():GetSpecialValueFor("bonus_speed")
end

function modifier_ringmaster_krugger:GetModifierTurnRate_Percentage()
	return -self:GetAbility():GetSpecialValueFor("turn_rate_slow_pct")
end

function modifier_ringmaster_krugger:GetBonusDayVision()
	return self:GetAbility():GetSpecialValueFor("vision_range")
end

function modifier_ringmaster_krugger:GetBonusNightVision()
	return self:GetAbility():GetSpecialValueFor("vision_range")
end

function modifier_ringmaster_krugger:CheckState()
	return {
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
	}
end

function modifier_ringmaster_krugger:GetEffectName()
	return "particles/slark_shard_depth_shroud.vpcf"
end

function modifier_ringmaster_krugger:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

modifier_ringmaster_krugger_carried = class({})

function modifier_ringmaster_krugger_carried:IsDebuff() return true end
function modifier_ringmaster_krugger_carried:IsPurgable() return false end

function modifier_ringmaster_krugger_carried:OnCreated()
	if not IsServer() then return end
	self:StartIntervalThink(FrameTime())
end

function modifier_ringmaster_krugger_carried:OnIntervalThink()
	local caster = self:GetCaster()
	if not caster or caster:IsNull() then
		self:Destroy()
		return
	end

	local point = caster:GetAbsOrigin() - caster:GetForwardVector() * 90
	FindClearSpaceForUnit(self:GetParent(), point, false)
end

function modifier_ringmaster_krugger_carried:OnDestroy()
	if not IsServer() then return end
	FindClearSpaceForUnit(self:GetParent(), self:GetParent():GetAbsOrigin(), true)
end

function modifier_ringmaster_krugger_carried:CheckState()
	return {
		[MODIFIER_STATE_STUNNED] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
	}
end
