LinkLuaModifier(
	"modifier_nevermore_requiem_trinity_debuff",
	"abilities/nevermore/nevermore_requiem_trinity",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_nevermore_requiem_trinity_death",
	"abilities/nevermore/nevermore_requiem_trinity",
	LUA_MODIFIER_MOTION_NONE
)

nevermore_requiem_trinity = class({})

local WINGS_PARTICLE = "particles/units/heroes/hero_nevermore/nevermore_wings.vpcf"
local SOULS_PARTICLE = "particles/units/heroes/hero_nevermore/nevermore_requiemofsouls_a.vpcf"
local GROUND_PARTICLE = "particles/units/heroes/hero_nevermore/nevermore_requiemofsouls.vpcf"
local LINE_PARTICLE = "particles/units/heroes/hero_nevermore/nevermore_requiemofsouls_line.vpcf"

local function GetMindPower(unit)
	if GetHeroMindPower then
		return GetHeroMindPower(unit) or 0
	end
	if unit and not unit:IsNull() and unit.GetIntellect then
		return unit:GetIntellect(false) or 0
	end
	return 0
end

function nevermore_requiem_trinity:Precache(context)
	PrecacheResource("particle", WINGS_PARTICLE, context)
	PrecacheResource("particle", SOULS_PARTICLE, context)
	PrecacheResource("particle", GROUND_PARTICLE, context)
	PrecacheResource("particle", LINE_PARTICLE, context)
end

function nevermore_requiem_trinity:GetIntrinsicModifierName()
	return "modifier_nevermore_requiem_trinity_death"
end

function nevermore_requiem_trinity:GetCooldown(level)
	local cooldown = self.BaseClass.GetCooldown(self, level)
	local caster = self:GetCaster()
	if caster and not caster:IsNull() and caster:HasScepter() then
		cooldown = cooldown - self:GetSpecialValueFor("scepter_cooldown_reduction")
	end
	return math.max(0, cooldown)
end

function nevermore_requiem_trinity:OnAbilityPhaseStart()
	local caster = self:GetCaster()
	caster:EmitSound("Hero_Nevermore.RequiemOfSoulsCast")
	caster:AddNewModifier(caster, self, "modifier_phased", {})

	self.wings_particle = ParticleManager:CreateParticle(WINGS_PARTICLE, PATTACH_ABSORIGIN_FOLLOW, caster)
	return true
end

function nevermore_requiem_trinity:OnAbilityPhaseInterrupted()
	local caster = self:GetCaster()
	caster:RemoveModifierByName("modifier_phased")
	caster:StopSound("Hero_Nevermore.RequiemOfSoulsCast")

	if self.wings_particle then
		ParticleManager:DestroyParticle(self.wings_particle, true)
		ParticleManager:ReleaseParticleIndex(self.wings_particle)
		self.wings_particle = nil
	end
end

function nevermore_requiem_trinity:GetSoulCount()
	local caster = self:GetCaster()
	local necromastery = caster:FindModifierByName("modifier_nevermore_necromastery")
	if necromastery then
		return necromastery:GetStackCount()
	end

	-- A stolen Requiem has no Necromastery modifier to read from.
	if caster:GetUnitName() == "npc_dota_hero_rubick" then
		return self:GetSpecialValueFor("max_soul_release")
	end

	return 0
end

function nevermore_requiem_trinity:GetDamagePerLine()
	local base_damage = self:GetSpecialValueFor("damage")
	local mind_multiplier = self:GetSpecialValueFor("mind_power_multiplier")
	return math.max(0, base_damage + GetMindPower(self:GetCaster()) * mind_multiplier)
end

function nevermore_requiem_trinity:OnSpellStart()
	if not IsServer() then return end
	self:ReleaseRequiem(self:GetSoulCount(), false)
end

function nevermore_requiem_trinity:ReleaseDeathRequiem(soul_count)
	if not IsServer() then return end

	-- Both Necromastery and the intrinsic modifier can observe the same death.
	-- Keep the intrinsic as a Rubick fallback, but release only once per death.
	local death_time = GameRules:GetGameTime()
	if self.last_death_requiem_time == death_time then return end
	self.last_death_requiem_time = death_time
	self:ReleaseRequiem(soul_count, true)
end

function nevermore_requiem_trinity:ReleaseRequiem(soul_count, death_cast)
	if not IsServer() then return end

	local caster = self:GetCaster()
	local max_souls = self:GetSpecialValueFor("max_soul_release")
	local souls_per_line = math.max(1, self:GetSpecialValueFor("requiem_soul_conversion"))
	local lines = math.floor(math.min(math.max(0, soul_count or 0), max_souls) / souls_per_line)
	local origin = caster:GetAbsOrigin()
	local damage = self:GetDamagePerLine()

	caster:RemoveModifierByName("modifier_phased")
	caster:StopSound("Hero_Nevermore.RequiemOfSoulsCast")
	caster:EmitSound("Hero_Nevermore.RequiemOfSouls")

	if self.wings_particle then
		ParticleManager:ReleaseParticleIndex(self.wings_particle)
		self.wings_particle = nil
	end

	local souls_particle = ParticleManager:CreateParticle(SOULS_PARTICLE, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(souls_particle, 0, origin)
	ParticleManager:SetParticleControl(souls_particle, 1, Vector(lines, 0, 0))
	ParticleManager:SetParticleControl(souls_particle, 2, origin)
	ParticleManager:ReleaseParticleIndex(souls_particle)

	local ground_particle = ParticleManager:CreateParticle(GROUND_PARTICLE, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(ground_particle, 0, origin)
	ParticleManager:SetParticleControl(ground_particle, 1, Vector(lines, 0, 0))
	ParticleManager:ReleaseParticleIndex(ground_particle)

	if lines <= 0 then return end

	local forward = caster:GetForwardVector()
	local angle_step = 360 / lines
	for index = 0, lines - 1 do
		local direction = RotatePosition(Vector(0, 0, 0), QAngle(0, angle_step * index, 0), forward):Normalized()
		self:CreateSoulLine(origin, direction, damage, death_cast, caster:HasScepter() and not death_cast)
	end
end

function nevermore_requiem_trinity:CreateSoulLine(origin, direction, damage, death_cast, create_return_line)
	local caster = self:GetCaster()
	local distance = self:GetSpecialValueFor("requiem_radius")
	local start_width = self:GetSpecialValueFor("requiem_line_width_start")
	local end_width = self:GetSpecialValueFor("requiem_line_width_end")
	local speed = self:GetSpecialValueFor("requiem_line_speed")
	local spawn_origin = origin + direction * 105
	local velocity = direction * speed

	ProjectileManager:CreateLinearProjectile({
		Ability = self,
		vSpawnOrigin = spawn_origin,
		fDistance = distance,
		fStartRadius = start_width,
		fEndRadius = end_width,
		Source = caster,
		bHasFrontalCone = false,
		bReplaceExisting = false,
		iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
		iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_NONE,
		iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		bDeleteOnHit = false,
		vVelocity = velocity,
		bProvidesVision = false,
		ExtraData = {
			damage = damage,
			death_cast = death_cast and 1 or 0,
			return_line = 0,
		},
	})

	local line_particle = ParticleManager:CreateParticle(LINE_PARTICLE, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(line_particle, 0, spawn_origin)
	ParticleManager:SetParticleControl(line_particle, 1, velocity)
	ParticleManager:SetParticleControl(line_particle, 2, Vector(0, distance / speed, 0))
	ParticleManager:ReleaseParticleIndex(line_particle)

	if create_return_line then
		Timers:CreateTimer(distance / speed, function()
			if not self or self:IsNull() then return nil end
			self:CreateReturningSoulLine(spawn_origin + direction * distance, damage)
			return nil
		end)
	end
end

function nevermore_requiem_trinity:CreateReturningSoulLine(spawn_origin, outgoing_damage)
	local caster = self:GetCaster()
	if not caster or caster:IsNull() then return end

	-- Vanilla locks the return trajectory onto Nevermore's position at the
	-- moment the outward wave reaches its maximum range.
	local to_caster = caster:GetAbsOrigin() - spawn_origin
	to_caster.z = 0
	local distance = to_caster:Length2D()
	if distance < 1 then return end

	local speed = self:GetSpecialValueFor("requiem_line_speed")
	local direction = to_caster:Normalized()
	local velocity = direction * speed
	local damage = outgoing_damage * self:GetSpecialValueFor("scepter_return_damage_pct") * 0.01

	ProjectileManager:CreateLinearProjectile({
		Ability = self,
		vSpawnOrigin = spawn_origin,
		fDistance = distance,
		fStartRadius = self:GetSpecialValueFor("requiem_line_width_end"),
		fEndRadius = self:GetSpecialValueFor("requiem_line_width_start"),
		Source = caster,
		bHasFrontalCone = false,
		bReplaceExisting = false,
		iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
		iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_NONE,
		iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		bDeleteOnHit = false,
		vVelocity = velocity,
		bProvidesVision = false,
		ExtraData = {
			damage = damage,
			death_cast = 0,
			return_line = 1,
		},
	})

	local line_particle = ParticleManager:CreateParticle(LINE_PARTICLE, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(line_particle, 0, spawn_origin)
	ParticleManager:SetParticleControl(line_particle, 1, velocity)
	ParticleManager:SetParticleControl(line_particle, 2, Vector(0, distance / speed, 0))
	ParticleManager:ReleaseParticleIndex(line_particle)
end

function nevermore_requiem_trinity:OnProjectileHit_ExtraData(target, location, extra_data)
	if not target or target:IsNull() then return false end

	target:EmitSound("Hero_Nevermore.RequiemOfSouls.Damage")
	local damage_dealt = ApplyDamage({
		victim = target,
		attacker = self:GetCaster(),
		damage = tonumber(extra_data.damage) or self:GetDamagePerLine(),
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability = self,
	})

	if tonumber(extra_data.return_line) == 1 and damage_dealt > 0 then
		local caster = self:GetCaster()
		if caster and not caster:IsNull() and caster:IsAlive() then
			local heal_pct = self:GetSpecialValueFor("scepter_return_heal_pct")
			caster:Heal(damage_dealt * heal_pct * 0.01, self)
		end
	end

	-- Vanilla death Requiem deals damage, but does not apply the control effects.
	if tonumber(extra_data.death_cast) ~= 1 then
		self:AddRequiemDebuffs(target)
	end

	return false
end

function nevermore_requiem_trinity:AddRequiemDebuffs(target)
	local duration_per_line = self:GetSpecialValueFor("requiem_slow_duration")
	local max_duration = self:GetSpecialValueFor("requiem_slow_duration_max")
	local status_multiplier = 1 - target:GetStatusResistance()
	local added_duration = duration_per_line * status_multiplier
	local duration_cap = max_duration * status_multiplier

	local function AddOrExtend(modifier_name)
		local modifier = target:FindModifierByName(modifier_name)
		if modifier and not modifier:IsNull() then
			modifier:SetDuration(math.min(modifier:GetRemainingTime() + added_duration, duration_cap), true)
			return modifier
		end
		return target:AddNewModifier(self:GetCaster(), self, modifier_name, { duration = added_duration })
	end

	AddOrExtend("modifier_nevermore_requiem_fear")
	AddOrExtend("modifier_nevermore_requiem_trinity_debuff")
end

modifier_nevermore_requiem_trinity_debuff = class({})

function modifier_nevermore_requiem_trinity_debuff:IsHidden() return false end
function modifier_nevermore_requiem_trinity_debuff:IsDebuff() return true end
function modifier_nevermore_requiem_trinity_debuff:IsPurgable() return true end

function modifier_nevermore_requiem_trinity_debuff:OnCreated()
	local ability = self:GetAbility()
	if not ability or ability:IsNull() then return end
	self.move_slow = ability:GetSpecialValueFor("requiem_reduction_ms")
	self.magic_resistance = ability:GetSpecialValueFor("requiem_reduction_mres")
end

function modifier_nevermore_requiem_trinity_debuff:OnRefresh()
	self:OnCreated()
end

function modifier_nevermore_requiem_trinity_debuff:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
	}
end

function modifier_nevermore_requiem_trinity_debuff:GetModifierMoveSpeedBonus_Percentage()
	return self.move_slow or 0
end

function modifier_nevermore_requiem_trinity_debuff:GetModifierMagicalResistanceBonus()
	return self.magic_resistance or 0
end

modifier_nevermore_requiem_trinity_death = class({})

function modifier_nevermore_requiem_trinity_death:IsHidden() return true end
function modifier_nevermore_requiem_trinity_death:IsPurgable() return false end
function modifier_nevermore_requiem_trinity_death:RemoveOnDeath() return false end

function modifier_nevermore_requiem_trinity_death:GetPriority()
	return MODIFIER_PRIORITY_SUPER_ULTRA
end

function modifier_nevermore_requiem_trinity_death:DeclareFunctions()
	return { MODIFIER_EVENT_ON_DEATH }
end

function modifier_nevermore_requiem_trinity_death:OnDeath(params)
	if not IsServer() or params.unit ~= self:GetParent() then return end
	if self:GetParent():IsReincarnating() then return end

	local ability = self:GetAbility()
	if not ability or ability:IsNull() or ability:GetLevel() <= 0 then return end
	ability:ReleaseDeathRequiem(ability:GetSoulCount())
end
