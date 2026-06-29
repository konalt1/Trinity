LinkLuaModifier("modifier_ringmaster_knives_slow", "abilities/ringmaster/ringmaster_prototype", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_ringmaster_knives_bleed", "abilities/ringmaster/ringmaster_prototype", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_ringmaster_knives_charge", "abilities/ringmaster/ringmaster_prototype", LUA_MODIFIER_MOTION_NONE)
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
	"particles/units/heroes/hero_hoodwink/hoodwink_sharpshooter_range_finder.vpcf",
	"particles/units/heroes/hero_ringmaster/ringmaster_impalement_projectile.vpcf",
}

local RINGMASTER_MODELS = {
	"models/heroes/ringmaster/ringmaster.vmdl",
	"models/heroes/ringmaster/ringmaster_wheel_decoy.vmdl",
	"models/heroes/ringmaster/ringmaster_dagger_model.vmdl",
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
	local unitName = "npc_dummy_unit"
	if modelName == "models/heroes/ringmaster/ringmaster_box.vmdl" then
		unitName = "npc_ringmaster_box"
	elseif modelName == "models/heroes/ringmaster/ringmaster_dagger_model.vmdl" then
		unitName = "npc_ringmaster_dagger"
	end

	print("[Ringmaster Prop Debug] Spawning model: " .. tostring(modelName) .. " using unit: " .. tostring(unitName))

	local prop = CreateUnitByName(unitName, position, false, nil, nil, caster:GetTeamNumber())
	if prop then
		print("[Ringmaster Prop Debug] Successfully created unit: " .. tostring(prop:GetUnitName()) .. ", index: " .. tostring(prop:GetEntityIndex()))
		if unitName == "npc_dummy_unit" then
			prop:SetModel(modelName)
			prop:SetOriginalModel(modelName)
		end
		if scale then
			prop:SetModelScale(scale)
		end
		prop:AddNewModifier(caster, nil, "modifier_invulnerable", {})
		prop:AddNewModifier(caster, nil, "modifier_unselectable", {})
		prop:AddNewModifier(caster, nil, "modifier_phased", {})
		prop:SetMoveCapability(DOTA_UNIT_CAP_MOVE_NONE)
	else
		print("[Ringmaster Prop Debug] FAILED to spawn unit: " .. tostring(unitName))
	end
	return prop
end

-- Spawnирует prop и через 1 тик запускает анимацию (движку нужен 1 тик на инициализацию)
local function SpawnRingmasterPropWithAnim(caster, modelName, position, scale, animName, callback)
	local prop = SpawnRingmasterProp(caster, modelName, position, scale)
	if prop then
		print("[Ringmaster Prop Debug] Scheduling animation reset for sequence: " .. tostring(animName))
		Timers:CreateTimer(0.1, function()
			if prop and not prop:IsNull() then
				print("[Ringmaster Prop Debug] Calling ResetSequence: " .. tostring(animName) .. " on unit index: " .. tostring(prop:GetEntityIndex()))
				prop:ResetSequence(animName)
				prop:SetCycle(0)
				-- Force animation to play
				prop:SetPlaybackRate(1.0)
				if callback then callback(prop) end
			else
				print("[Ringmaster Prop Debug] Cannot reset sequence, prop is nil or destroyed")
			end
		end)
	end
	return prop
end

ringmaster_knives_out_custom = class({})

function ringmaster_knives_out_custom:Precache(context)
	PrecacheRingmasterPrototype(context)
end

function ringmaster_knives_out_custom:GetManaCost(level)
	if self:GetCaster():HasModifier("modifier_ringmaster_knives_charge") then
		return 0
	end
	return self.BaseClass.GetManaCost(self, level)
end

function ringmaster_knives_out_custom:GetCooldown(level)
	return 0
end

function ringmaster_knives_out_custom:OnSpellStart()
	local caster = self:GetCaster()
	local modifier = caster:FindModifierByName("modifier_ringmaster_knives_charge")

	if not modifier then
		-- Первое нажатие: активируем режим прицеливания
		local duration = self:GetSpecialValueFor("charge_duration") or 15.0
		caster:AddNewModifier(caster, self, "modifier_ringmaster_knives_charge", { duration = duration })
		caster:EmitSound("Hero_Ringmaster.Impale.Cast")
	else
		-- Повторное нажатие: бросаем кинжал в текущем направлении стрелки
		local direction = modifier.current_direction or caster:GetForwardVector()
		self:ThrowKnife(direction)
		caster:StartGesture(ACT_DOTA_CAST_ABILITY_2)

		modifier:DecrementStackCount()
		if modifier:GetStackCount() <= 0 then
			modifier.cooldown_triggered = true
			modifier:Destroy()
			local cd = self:GetLevelSpecialValueFor("AbilityCooldown", self:GetLevel() - 1)
			self:StartCooldown(cd)
		end
	end
end

function ringmaster_knives_out_custom:ThrowKnife(direction)
	local caster = self:GetCaster()
	local speed = self:GetSpecialValueFor("speed")
	local range = self:GetSpecialValueFor("range") or 2000
	local duration = range / speed
	local spawn_origin = caster:GetAbsOrigin() + Vector(0, 0, 80)
	local velocity = direction * speed

	-- Спавним визуальную модель кинжала (без анимации)
	local dagger_prop = SpawnRingmasterProp(caster, "models/heroes/ringmaster/ringmaster_dagger_model.vmdl", spawn_origin, 2.2)
	if dagger_prop then
		dagger_prop:SetForwardVector(direction)
		-- Фиксируем на кадре 0 (никаких анимаций)
		dagger_prop:ResetSequence("idle")
		dagger_prop:SetCycle(0)

		local start_time = GameRules:GetGameTime()
		Timers:CreateTimer(function()
			if not dagger_prop or dagger_prop:IsNull() then return nil end
			local elapsed = GameRules:GetGameTime() - start_time
			if elapsed >= duration then return nil end
			dagger_prop:SetAbsOrigin(spawn_origin + velocity * elapsed)
			return 0.03
		end)
	end

	local dagger_entindex = dagger_prop and dagger_prop:GetEntityIndex() or -1

	ProjectileManager:CreateLinearProjectile({
		Ability = self,
		EffectName = "",
		vSpawnOrigin = spawn_origin,
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
		ExtraData = { dagger_entindex = dagger_entindex }
	})

	caster:EmitSound("Hero_Ringmaster.Impale.Cast")
end

function ringmaster_knives_out_custom:OnProjectileHit_ExtraData(target, location, extraData)
	local caster = self:GetCaster()

	-- Удаляем визуальный проп кинжала (и при попадании, и при промахе)
	if extraData and extraData.dagger_entindex and extraData.dagger_entindex ~= -1 then
		local prop = EntIndexToHScript(extraData.dagger_entindex)
		if prop and not prop:IsNull() then
			prop:Destroy()
		end
	end

	if not target then return true end

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
		duration = (self:GetSpecialValueFor("slow_duration") or 3.0) * (1 - target:GetStatusResistance()),
	})

	target:AddNewModifier(caster, self, "modifier_ringmaster_knives_bleed", {
		duration = (self:GetSpecialValueFor("bleed_duration") or 4.0) * (1 - target:GetStatusResistance()),
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
	self.slow = -80
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

modifier_ringmaster_knives_charge = class({})

function modifier_ringmaster_knives_charge:IsDebuff() return false end
function modifier_ringmaster_knives_charge:IsPurgable() return false end

function modifier_ringmaster_knives_charge:GetTexture()
	return "ringmaster_impalement"
end

function modifier_ringmaster_knives_charge:DecrementStackCount()
	if not IsServer() then return end
	local current = self:GetStackCount()
	self:SetStackCount(current - 1)
end

function modifier_ringmaster_knives_charge:OnCreated()
	if not IsServer() then return end
	self.caster = self:GetCaster()
	self.ability = self:GetAbility()
	
	self:SetStackCount(4)
	self.cooldown_triggered = false
	
	self.start_time = GameRules:GetGameTime()
	self.sweep_speed = 3.5
	self.current_direction = self.caster:GetForwardVector()
	self.indicator_range = self.ability:GetSpecialValueFor("range") or 2000
	
	local particle_cast = "particles/units/heroes/hero_hoodwink/hoodwink_sharpshooter_range_finder.vpcf"
	self.effect_cast = ParticleManager:CreateParticleForPlayer(particle_cast, PATTACH_ABSORIGIN_FOLLOW, self.caster, self.caster:GetPlayerOwner())
	ParticleManager:SetParticleControl(self.effect_cast, 0, self.caster:GetAbsOrigin())
	ParticleManager:SetParticleControl(self.effect_cast, 1, self.caster:GetAbsOrigin() + self.current_direction * self.indicator_range)
	ParticleManager:SetParticleControl(self.effect_cast, 15, Vector(255, 240, 80))
	ParticleManager:SetParticleControl(self.effect_cast, 16, Vector(4, 4, 4))
	
	self:StartIntervalThink(0.03)
end

function modifier_ringmaster_knives_charge:OnIntervalThink()
	if not IsServer() then return end
	local elapsed = GameRules:GetGameTime() - self.start_time
	
	local forward = self.caster:GetForwardVector()
	forward.z = 0
	forward = forward:Normalized()
	
	local angle = math.sin(elapsed * self.sweep_speed) * 60.0
	local direction = RotatePosition(Vector(0,0,0), QAngle(0, angle, 0), forward)
	direction.z = 0
	direction = direction:Normalized()
	
	self.current_direction = direction
	
	local startpos = self.caster:GetAbsOrigin()
	local endpos = startpos + direction * self.indicator_range
	ParticleManager:SetParticleControl(self.effect_cast, 0, startpos)
	ParticleManager:SetParticleControl(self.effect_cast, 1, endpos)
end

function modifier_ringmaster_knives_charge:OnDestroy()
	if not IsServer() then return end
	
	if self.effect_cast then
		ParticleManager:DestroyParticle(self.effect_cast, true)
		ParticleManager:ReleaseParticleIndex(self.effect_cast)
	end
	
	if not self.cooldown_triggered then
		if self.ability and not self.ability:IsNull() then
			local cd = self.ability:GetLevelSpecialValueFor("AbilityCooldown", self.ability:GetLevel() - 1)
			self.ability:StartCooldown(cd)
		end
	end
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
	local box_prop = SpawnRingmasterPropWithAnim(
		caster,
		"models/heroes/ringmaster/ringmaster_box.vmdl",
		parent:GetAbsOrigin(),
		1.2,
		"rm_box_spawn",
		function(bp)
			self.box_prop = bp
			-- Wait for spawn animation to finish, then play idle
			Timers:CreateTimer(1.0, function()
				if bp and not bp:IsNull() then
					bp:ResetSequence("rm_box_idle")
					bp:SetCycle(0)
					bp:SetPlaybackRate(1.0)
				end
			end)
		end
	)
	if box_prop then
		self.box_prop = box_prop
	end

	self:StartIntervalThink(0.1)
end

function modifier_ringmaster_box_thinker:OnDestroy()
	if not IsServer() then return end
	if self.box_prop and not self.box_prop:IsNull() then
		local prop = self.box_prop
		self.box_prop = nil
		
		prop:ResetSequence("rm_box_die")
		prop:SetCycle(0)
		
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
