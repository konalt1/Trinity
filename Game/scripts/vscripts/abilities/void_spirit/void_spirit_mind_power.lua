LinkLuaModifier(
	"modifier_void_spirit_mind_power",
	"abilities/void_spirit/void_spirit_mind_power",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_void_spirit_trinity_remnant_watch",
	"abilities/void_spirit/void_spirit_mind_power",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_void_spirit_trinity_remnant_pull",
	"abilities/void_spirit/void_spirit_mind_power",
	LUA_MODIFIER_MOTION_NONE
)

local WATCH_MODIFIER = "modifier_void_spirit_trinity_remnant_watch"
local PULL_MODIFIER = "modifier_void_spirit_trinity_remnant_pull"
local NATIVE_PULL_MODIFIER = "modifier_void_spirit_aether_remnant_pull"
local REMNANT_UNIT_NAME = "npc_dota_aether_remnant"

local PARTICLE_WATCH = "particles/units/heroes/hero_void_spirit/aether_remnant/void_spirit_aether_remnant_watch.vpcf"
local PARTICLE_PULL = "particles/units/heroes/hero_void_spirit/aether_remnant/void_spirit_aether_remnant_pull.vpcf"
local PARTICLE_STATUS = "particles/status_fx/status_effect_void_spirit_aether_remnant.vpcf"

local REMNANT_UNIT_MODIFIERS = {
	WATCH_MODIFIER,
	"modifier_void_spirit_aether_remnant_unit",
	"modifier_void_spirit_aether_remnant",
}

local REMNANT_THINKER_MODIFIERS = {
	"modifier_void_spirit_aether_remnant_thinker",
}

local SEARCH_FLAGS = DOTA_UNIT_TARGET_FLAG_INVULNERABLE
	+ DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES
	+ DOTA_UNIT_TARGET_FLAG_OUT_OF_WORLD

local function IsValidHandle(handle)
	return handle and (not handle.IsNull or not handle:IsNull())
end

local function IsNpcEntity(unit)
	return IsValidHandle(unit) and unit.HasModifier ~= nil and unit.GetAbsOrigin ~= nil
end

local function DeleteParticle(index, immediate)
	if not index then
		return
	end
	ParticleManager:DestroyParticle(index, immediate == true)
	ParticleManager:ReleaseParticleIndex(index)
end

local function UnitOwnedByCaster(unit, caster)
	if unit.GetOwnerEntity and unit:GetOwnerEntity() == caster then
		return true
	end
	if unit.GetOwner and unit:GetOwner() == caster then
		return true
	end
	return false
end

local function Normalize2D(vector, fallback)
	local copy = Vector(vector.x, vector.y, 0)
	if copy:Length2D() < 0.01 then
		if fallback then
			return Vector(fallback.x, fallback.y, 0):Normalized()
		end
		return Vector(1, 0, 0)
	end
	return copy:Normalized()
end

local function IsCasterRemnant(unit, caster, modifier_names)
	if not IsNpcEntity(unit) or unit == caster then
		return false
	end

	if unit.GetUnitName and unit:GetUnitName() == REMNANT_UNIT_NAME then
		if UnitOwnedByCaster(unit, caster) then
			return true
		end
		if caster.GetPlayerOwnerID and unit.GetPlayerOwnerID and unit:GetPlayerOwnerID() == caster:GetPlayerOwnerID() then
			return true
		end
	end

	for _, name in ipairs(modifier_names) do
		local modifier = unit:FindModifierByName(name)
		if modifier then
			local modifier_caster = modifier.GetCaster and modifier:GetCaster()
			if modifier_caster == caster or UnitOwnedByCaster(unit, caster) then
				return true
			end
		end
	end

	return false
end

local function CollectRemnants(caster, modifier_names)
	local remnants = {}
	local seen = {}

	local function try_add(unit)
		if not IsCasterRemnant(unit, caster, modifier_names) then
			return
		end
		local index = unit:entindex()
		if seen[index] then
			return
		end
		seen[index] = true
		table.insert(remnants, unit)
	end

	local named = Entities:FindAllByName(REMNANT_UNIT_NAME)
	for _, unit in ipairs(named) do
		try_add(unit)
	end

	local additives = Entities:FindAllByClassname("npc_dota_base_additive")
	for _, unit in ipairs(additives) do
		if unit.GetUnitName and unit:GetUnitName() == REMNANT_UNIT_NAME then
			try_add(unit)
		end
	end

	local thinkers = Entities:FindAllByClassname("npc_dota_thinker")
	for _, thinker in ipairs(thinkers) do
		try_add(thinker)
	end

	local units = FindUnitsInRadius(
		caster:GetTeamNumber(),
		caster:GetAbsOrigin(),
		nil,
		25000,
		DOTA_UNIT_TARGET_TEAM_BOTH,
		DOTA_UNIT_TARGET_ALL,
		SEARCH_FLAGS,
		FIND_ANY_ORDER,
		false
	)
	for _, unit in ipairs(units) do
		try_add(unit)
	end

	return remnants
end

function GetVoidSpiritAstralRemnantList(caster)
	if not IsValidHandle(caster) then
		return {}
	end

	local remnants = CollectRemnants(caster, REMNANT_UNIT_MODIFIERS)
	if #remnants > 0 then
		return remnants
	end

	return CollectRemnants(caster, REMNANT_THINKER_MODIFIERS)
end

local function GetAbilitySpecial(ability, name, fallback)
	if not IsValidHandle(ability) then
		return fallback
	end
	local value = ability:GetSpecialValueFor(name)
	if not value or value == 0 then
		return fallback
	end
	return value
end

local function ResolveRemnantFacing(ability, caster, remnant)
	if IsValidHandle(ability) then
		if ability._trinity_remnant_dir and ability._trinity_remnant_dir:Length2D() > 0.01 then
			return Normalize2D(ability._trinity_remnant_dir, caster:GetForwardVector())
		end
		if ability.GetVectorTargetEndPosition then
			local start_pos = ability.GetVectorTargetStartPosition and ability:GetVectorTargetStartPosition()
			local end_pos = ability:GetVectorTargetEndPosition()
			if start_pos and end_pos then
				local dir = end_pos - start_pos
				if dir:Length2D() > 8 then
					return Normalize2D(dir, caster:GetForwardVector())
				end
			end
		end
	end

	local origin = remnant:GetAbsOrigin()
	local from_caster = origin - caster:GetAbsOrigin()
	if from_caster:Length2D() > 8 then
		return Normalize2D(from_caster, caster:GetForwardVector())
	end
	return Normalize2D(caster:GetForwardVector(), Vector(1, 0, 0))
end

local function CaptureVectorFromAbility(ability)
	if not IsValidHandle(ability) then
		return
	end
	if ability.GetVectorTargetEndPosition then
		local start_pos = ability.GetVectorTargetStartPosition and ability:GetVectorTargetStartPosition()
		local end_pos = ability:GetVectorTargetEndPosition()
		if start_pos and end_pos then
			local dir = end_pos - start_pos
			if dir:Length2D() > 8 then
				ability._trinity_remnant_dir = Normalize2D(dir, nil)
				ability._trinity_remnant_point = start_pos
			end
		end
	end
	if not ability._trinity_remnant_point then
		ability._trinity_remnant_point = ability:GetCursorPosition()
	end
end

local function ConsiderNativeRemnant(unit, caster, seen, remnants)
	if not IsNpcEntity(unit) or unit == caster or unit:HasModifier(WATCH_MODIFIER) then
		return
	end

	local index = unit:entindex()
	if seen[index] then
		return
	end

	local name = unit.GetUnitName and unit:GetUnitName() or ""
	local is_remnant = name == REMNANT_UNIT_NAME
		or unit:HasModifier("modifier_void_spirit_aether_remnant_unit")
		or unit:HasModifier("modifier_void_spirit_aether_remnant")
		or unit:HasModifier("modifier_void_spirit_aether_remnant_thinker")
	if not is_remnant then
		return
	end
	if not UnitOwnedByCaster(unit, caster) then
		local modifier = unit:FindModifierByName("modifier_void_spirit_aether_remnant_unit")
			or unit:FindModifierByName("modifier_void_spirit_aether_remnant")
			or unit:FindModifierByName("modifier_void_spirit_aether_remnant_thinker")
		if not (modifier and modifier.GetCaster and modifier:GetCaster() == caster) then
			if not (caster.GetPlayerOwnerID and unit.GetPlayerOwnerID and unit:GetPlayerOwnerID() == caster:GetPlayerOwnerID()) then
				return
			end
		end
	end

	seen[index] = true
	table.insert(remnants, unit)
end

local function FindNativeRemnants(caster)
	local remnants = {}
	local seen = {}
	if not IsValidHandle(caster) then
		return remnants
	end

	for _, unit in ipairs(GetVoidSpiritAstralRemnantList(caster)) do
		ConsiderNativeRemnant(unit, caster, seen, remnants)
	end

	local named = Entities:FindAllByName(REMNANT_UNIT_NAME)
	for _, unit in ipairs(named) do
		ConsiderNativeRemnant(unit, caster, seen, remnants)
	end

	local additives = Entities:FindAllByClassname("npc_dota_base_additive")
	for _, unit in ipairs(additives) do
		ConsiderNativeRemnant(unit, caster, seen, remnants)
	end

	local thinkers = Entities:FindAllByClassname("npc_dota_thinker")
	for _, unit in ipairs(thinkers) do
		ConsiderNativeRemnant(unit, caster, seen, remnants)
	end

	return remnants
end

local function AttachWatch(caster, ability, remnant, use_parent_facing)
	if not IsNpcEntity(remnant) or remnant:HasModifier(WATCH_MODIFIER) then
		return
	end

	local facing = remnant:GetForwardVector()
	if facing:Length2D() < 0.01 then
		facing = ResolveRemnantFacing(ability, caster, remnant)
	end

	remnant:AddNewModifier(caster, ability, WATCH_MODIFIER, {
		duration = GetAbilitySpecial(ability, "duration", 17),
		dir_x = facing.x,
		dir_y = facing.y,
		hide_beam = 1,
		use_parent_facing = use_parent_facing and 1 or 0,
		skip_damage = 1,
	})
end

local function BindPullToNativeRemnants(caster, ability)
	if not IsServer() or not IsValidHandle(caster) or not IsValidHandle(ability) then
		return false
	end

	CaptureVectorFromAbility(ability)

	local bound = false
	for _, remnant in ipairs(FindNativeRemnants(caster)) do
		AttachWatch(caster, ability, remnant, true)
		bound = true
	end
	return bound
end

local function SpawnHiddenWatchThinker(caster, ability)
	if not IsValidHandle(caster) or not IsValidHandle(ability) then
		return
	end
	if ability._trinity_watch_thinker_time and (GameRules:GetGameTime() - ability._trinity_watch_thinker_time) < 0.5 then
		return
	end

	CaptureVectorFromAbility(ability)
	local facing = ability._trinity_remnant_dir
	if not facing or facing:Length2D() < 0.01 then
		return
	end

	local point = ability._trinity_remnant_point or ability:GetCursorPosition()
	if not point then
		return
	end

	ability._trinity_watch_thinker_time = GameRules:GetGameTime()
	CreateModifierThinker(
		caster,
		ability,
		WATCH_MODIFIER,
		{
			duration = GetAbilitySpecial(ability, "duration", 17),
			dir_x = facing.x,
			dir_y = facing.y,
			hide_beam = 1,
			use_parent_facing = 0,
			skip_damage = 1,
		},
		GetGroundPosition(point, nil),
		caster:GetTeamNumber(),
		false
	)
end

local function ScheduleNativeRemnantBind(caster, ability)
	if not IsValidHandle(ability) then
		return
	end

	CaptureVectorFromAbility(ability)
	BindPullToNativeRemnants(caster, ability)
	Timers:CreateTimer(0.1, function()
		BindPullToNativeRemnants(caster, ability)
		return nil
	end)
	Timers:CreateTimer(0.45, function()
		if not BindPullToNativeRemnants(caster, ability) then
			SpawnHiddenWatchThinker(caster, ability)
		end
		return nil
	end)
end

void_spirit_aether_remnant = class({})

function void_spirit_aether_remnant:GetIntrinsicModifierName()
	return "modifier_void_spirit_mind_power"
end

function void_spirit_aether_remnant:Precache(context)
	PrecacheResource("particle", PARTICLE_WATCH, context)
	PrecacheResource("particle", PARTICLE_PULL, context)
	PrecacheResource("particle", PARTICLE_STATUS, context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_void_spirit.vsndevts", context)
end

function VoidSpiritAetherRemnantHandleOrder(data)
	if not data or not data.entindex_ability then
		return true
	end

	local ability = EntIndexToHScript(data.entindex_ability)
	if not IsValidHandle(ability) or not ability.GetAbilityName then
		return true
	end
	if ability:GetAbilityName() ~= "void_spirit_aether_remnant" then
		return true
	end

	local pos = Vector(data.position_x or 0, data.position_y or 0, data.position_z or 0)
	ability._trinity_remnant_point = pos

	local end_x = data.position2_x or data.vector_target_x
	local end_y = data.position2_y or data.vector_target_y
	local end_z = data.position2_z or data.vector_target_z
	if end_x and end_y then
		local ending = Vector(end_x, end_y, end_z or 0)
		local dir = ending - pos
		if dir:Length2D() > 8 then
			ability._trinity_remnant_dir = Normalize2D(dir, nil)
		end
	end

	return true
end

-- Scales vanilla Aether Remnant impact_damage on the server without replacing the ability.
-- Native vector facing is not delivered in Trinity, so watch/pull are applied in Lua.
modifier_void_spirit_mind_power = class({})

function modifier_void_spirit_mind_power:IsHidden()
	return true
end

function modifier_void_spirit_mind_power:IsPurgable()
	return false
end

function modifier_void_spirit_mind_power:RemoveOnDeath()
	return false
end

function modifier_void_spirit_mind_power:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL,
		MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL_VALUE,
		MODIFIER_EVENT_ON_ABILITY_FULLY_CAST,
	}
end

function modifier_void_spirit_mind_power:GetModifierOverrideAbilitySpecial(params)
	if not IsServer() or self.computing_override or not params or not params.ability or params.ability:IsNull() then
		return 0
	end

	return CustomAbilityTooltips:IsNumericMindPowerMultiplier(
		params.ability:GetAbilityName(),
		params.ability_special_value
	) and 1 or 0
end

function modifier_void_spirit_mind_power:GetModifierOverrideAbilitySpecialValue(params)
	if not IsServer() or not params or not params.ability or params.ability:IsNull() then
		return 0
	end

	local ability = params.ability
	local special_value = params.ability_special_value
	local multiplier = CustomAbilityTooltips:GetMindPowerMultiplierKey(ability:GetAbilityName(), special_value)
	if type(multiplier) ~= "number" then
		return 0
	end

	self.computing_override = true
	local base_value = ability:GetSpecialValueFor(special_value)
	self.computing_override = false

	local parent = self:GetParent()
	local mind_power = 0
	if parent and not parent:IsNull() and GetHeroMindPower then
		mind_power = GetHeroMindPower(parent) or 0
	end

	return math.max(0, base_value + mind_power * multiplier)
end

function modifier_void_spirit_mind_power:OnAbilityFullyCast(event)
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if event.unit ~= parent or not IsValidHandle(event.ability) then
		return
	end
	if event.ability:GetAbilityName() ~= "void_spirit_aether_remnant" then
		return
	end

	local ability = event.ability
	ScheduleNativeRemnantBind(parent, ability)
end

modifier_void_spirit_trinity_remnant_watch = class({})

function modifier_void_spirit_trinity_remnant_watch:IsHidden()
	return true
end

function modifier_void_spirit_trinity_remnant_watch:IsPurgable()
	return false
end

function modifier_void_spirit_trinity_remnant_watch:OnCreated(kv)
	if not IsServer() then
		return
	end

	self.parent = self:GetParent()
	self.caster = self:GetCaster()
	self.ability = self:GetAbility()
	self.origin = self.parent:GetAbsOrigin()
	self.use_parent_facing = kv.use_parent_facing == 1
	self.hide_beam = kv.hide_beam == 1
	self.skip_damage = kv.skip_damage == 1
	if self.use_parent_facing then
		self.direction = Normalize2D(self.parent:GetForwardVector(), self.caster:GetForwardVector())
	else
		self.direction = Normalize2D(Vector(kv.dir_x or 0, kv.dir_y or 0, 0), self.caster:GetForwardVector())
	end
	self.distance = GetAbilitySpecial(self.ability, "remnant_watch_distance", 450)
	self.width = GetAbilitySpecial(self.ability, "remnant_watch_radius", 130)
	self.watch_vision = GetAbilitySpecial(self.ability, "watch_path_vision_radius", 200)
	self.pull_duration = GetAbilitySpecial(self.ability, "pull_duration", 1.2)
	self.pull = GetAbilitySpecial(self.ability, "pull_destination", 50)
	self.interval = GetAbilitySpecial(self.ability, "think_interval", 0.1)
	self.target = GetGroundPosition(self.origin + self.direction * self.distance, nil)
	self.watching = false

	local delay = 0.05
	if not self.hide_beam then
		delay = GetAbilitySpecial(self.ability, "activation_delay", 0.4)
	end
	self:StartIntervalThink(delay)
end

function modifier_void_spirit_trinity_remnant_watch:OnDestroy()
	if not IsServer() then
		return
	end
	DeleteParticle(self.effect_cast, false)
	if IsValidHandle(self.parent) then
		self.parent:StopSound("Hero_VoidSpirit.AetherRemnant.Spawn_lp")
	end
end

function modifier_void_spirit_trinity_remnant_watch:OnIntervalThink()
	if not self.watching then
		self.watching = true
		self:StartIntervalThink(self.interval)
		if not self.hide_beam then
			self.effect_cast = ParticleManager:CreateParticle(PARTICLE_WATCH, PATTACH_CUSTOMORIGIN, self.parent)
			ParticleManager:SetParticleControl(self.effect_cast, 0, self.origin)
			ParticleManager:SetParticleControl(self.effect_cast, 1, self.target)
			ParticleManager:SetParticleControlForward(self.effect_cast, 0, self.direction)
			ParticleManager:SetParticleControlForward(self.effect_cast, 2, self.direction)
			self.parent:EmitSound("Hero_VoidSpirit.AetherRemnant.Spawn_lp")
		end
		return
	end

	self:WatchLogic()
end

function modifier_void_spirit_trinity_remnant_watch:WatchLogic()
	if not IsValidHandle(self.caster) or not IsValidHandle(self.parent) then
		self:Destroy()
		return
	end

	if self.use_parent_facing then
		local facing = Normalize2D(self.parent:GetForwardVector(), self.direction)
		self.direction = facing
		self.origin = self.parent:GetAbsOrigin()
		self.target = GetGroundPosition(self.origin + self.direction * self.distance, nil)
	end

	AddFOWViewer(self.caster:GetTeamNumber(), self.origin, self.watch_vision, 0.1, true)
	AddFOWViewer(self.caster:GetTeamNumber(), self.origin + self.direction * self.distance / 2, self.watch_vision, 0.1, true)
	AddFOWViewer(self.caster:GetTeamNumber(), self.target, self.watch_vision, 0.1, true)

	local line_start = self.origin + self.direction * 150
	local enemies = FindUnitsInLine(
		self.caster:GetTeamNumber(),
		line_start,
		self.target,
		nil,
		self.width,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_BASIC + DOTA_UNIT_TARGET_HERO,
		DOTA_UNIT_TARGET_FLAG_NONE
	)

	local heroes = {}
	local others = {}
	for _, unit in pairs(enemies) do
		if IsValidHandle(unit)
			and unit:IsAlive()
			and not unit:IsMagicImmune()
			and not unit:IsInvulnerable()
			and not unit:HasModifier(PULL_MODIFIER)
			and not unit:HasModifier(NATIVE_PULL_MODIFIER)
		then
			if unit.IsRealHero and unit:IsRealHero() then
				table.insert(heroes, unit)
			else
				table.insert(others, unit)
			end
		end
	end

	local pool = #heroes > 0 and heroes or others
	if #pool == 0 then
		return
	end

	local closest
	local closest_distance = math.huge
	for _, enemy in pairs(pool) do
		local distance = (enemy:GetAbsOrigin() - line_start):Length2D()
		if distance < closest_distance then
			closest = enemy
			closest_distance = distance
		end
	end
	if not closest then
		return
	end

	self:StartIntervalThink(-1)
	self:PullTarget(closest)
end

function modifier_void_spirit_trinity_remnant_watch:PullTarget(closest)
	local resist = 0
	if closest.GetStatusResistance then
		resist = closest:GetStatusResistance() or 0
	end
	local stun_duration = self.pull_duration * (1 - resist)

	closest:AddNewModifier(self.caster, self.ability, PULL_MODIFIER, {
		duration = stun_duration,
		pos_x = self.origin.x,
		pos_y = self.origin.y,
		pull = self.pull,
		durat = self.pull_duration,
	})

	if not self.skip_damage then
		ApplyDamage({
			victim = closest,
			attacker = self.caster,
			damage = self.ability:GetSpecialValueFor("impact_damage"),
			damage_type = DAMAGE_TYPE_MAGICAL,
			ability = self.ability,
		})
	end

	DeleteParticle(self.effect_cast, false)
	self.effect_cast = ParticleManager:CreateParticle(PARTICLE_PULL, PATTACH_CUSTOMORIGIN, self.parent)
	ParticleManager:SetParticleControlEnt(
		self.effect_cast,
		0,
		self.caster,
		PATTACH_POINT_FOLLOW,
		"attach_hitloc",
		Vector(0, 0, 0),
		true
	)
	ParticleManager:SetParticleControlEnt(
		self.effect_cast,
		1,
		closest,
		PATTACH_POINT_FOLLOW,
		"attach_hitloc",
		closest:GetAbsOrigin(),
		true
	)
	ParticleManager:SetParticleControl(self.effect_cast, 2, closest:GetAbsOrigin() + Vector(0, 0, 150))
	ParticleManager:SetParticleControlForward(self.effect_cast, 2, -self.direction)
	ParticleManager:SetParticleControl(self.effect_cast, 3, self.origin)

	self.parent:EmitSound("Hero_VoidSpirit.AetherRemnant.Triggered")
	closest:EmitSound("Hero_VoidSpirit.AetherRemnant.Target")

	self:StartIntervalThink(-1)
	self:SetDuration(stun_duration, true)

	local remnant = self.parent
	Timers:CreateTimer(stun_duration, function()
		if IsValidHandle(remnant) then
			remnant:ForceKill(false)
			if IsValidHandle(remnant) then
				UTIL_Remove(remnant)
			end
		end
		return nil
	end)
end

modifier_void_spirit_trinity_remnant_pull = class({})

function modifier_void_spirit_trinity_remnant_pull:IsHidden()
	return false
end

function modifier_void_spirit_trinity_remnant_pull:IsStunDebuff()
	return true
end

function modifier_void_spirit_trinity_remnant_pull:IsPurgable()
	return true
end

function modifier_void_spirit_trinity_remnant_pull:GetTexture()
	return "void_spirit_aether_remnant"
end

function modifier_void_spirit_trinity_remnant_pull:GetStatusEffectName()
	return PARTICLE_STATUS
end

function modifier_void_spirit_trinity_remnant_pull:StatusEffectPriority()
	return MODIFIER_PRIORITY_HIGH
end

function modifier_void_spirit_trinity_remnant_pull:OnCreated(kv)
	if not IsServer() then
		return
	end

	self.parent = self:GetParent()
	self.target = Vector(kv.pos_x, kv.pos_y, 0)
	local dist = (self.parent:GetOrigin() - self.target):Length2D()
	local duration = math.max(0.05, kv.durat or self:GetDuration())
	self.speed = ((kv.pull or 50) / 100) * dist / duration

	if not self.parent:IsDebuffImmune() then
		self.parent:MoveToPosition(self.target)
	end
end

function modifier_void_spirit_trinity_remnant_pull:OnDestroy()
	if not IsServer() then
		return
	end
	if IsValidHandle(self.parent) and not self.parent:IsDebuffImmune() then
		self.parent:Stop()
	end
end

function modifier_void_spirit_trinity_remnant_pull:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_ABSOLUTE,
	}
end

function modifier_void_spirit_trinity_remnant_pull:GetModifierMoveSpeed_Absolute()
	if IsServer() then
		return self.speed
	end
end

function modifier_void_spirit_trinity_remnant_pull:CheckState()
	return {
		[MODIFIER_STATE_COMMAND_RESTRICTED] = true,
		[MODIFIER_STATE_FLYING_FOR_PATHING_PURPOSES_ONLY] = true,
		[MODIFIER_STATE_TAUNTED] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_DISARMED] = true,
	}
end

if IsServer() and not _G._void_spirit_aether_used_listener then
	_G._void_spirit_aether_used_listener = true
	ListenToGameEvent("dota_player_used_ability", function(keys)
		if not keys then
			return
		end
		local ability_name = keys.abilityname or keys.abilityName
		if ability_name ~= "void_spirit_aether_remnant" then
			return
		end

		local player_id = keys.PlayerID or keys.player_id
		if player_id == nil then
			return
		end

		local hero = PlayerResource:GetSelectedHeroEntity(player_id)
		if not IsValidHandle(hero) then
			return
		end

		ScheduleNativeRemnantBind(hero, hero:FindAbilityByName("void_spirit_aether_remnant"))
	end, nil)

	ListenToGameEvent("npc_spawned", function(event)
		if not event then
			return
		end
		local unit = EntIndexToHScript(event.entindex or event.entindex_spawned or -1)
		if not IsNpcEntity(unit) then
			return
		end

		local function try_attach()
			if not IsNpcEntity(unit) then
				return
			end
			local name = unit.GetUnitName and unit:GetUnitName() or ""
			local looks_like_remnant = name == REMNANT_UNIT_NAME
				or unit:HasModifier("modifier_void_spirit_aether_remnant_unit")
				or unit:HasModifier("modifier_void_spirit_aether_remnant")
				or unit:HasModifier("modifier_void_spirit_aether_remnant_thinker")
			if not looks_like_remnant then
				return
			end

			local caster = unit.GetOwnerEntity and unit:GetOwnerEntity()
			if not IsNpcEntity(caster) then
				local modifier = unit:FindModifierByName("modifier_void_spirit_aether_remnant_unit")
					or unit:FindModifierByName("modifier_void_spirit_aether_remnant")
					or unit:FindModifierByName("modifier_void_spirit_aether_remnant_thinker")
				if modifier and modifier.GetCaster then
					caster = modifier:GetCaster()
				end
			end
			if not IsNpcEntity(caster) or not caster.FindAbilityByName then
				return
			end
			local ability = caster:FindAbilityByName("void_spirit_aether_remnant")
			if not IsValidHandle(ability) then
				return
			end
			AttachWatch(caster, ability, unit, true)
		end

		Timers:CreateTimer(0, function()
			try_attach()
			return nil
		end)
		Timers:CreateTimer(0.05, function()
			try_attach()
			return nil
		end)
	end, nil)
end
