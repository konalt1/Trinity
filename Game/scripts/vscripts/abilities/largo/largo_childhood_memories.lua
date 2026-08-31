require("modifiers/modifier_generic_arc_lua")
require("game_managers/custom_ability_tooltips")

LinkLuaModifier("modifier_largo_childhood_memories", "abilities/largo/largo_childhood_memories", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_largo_childhood_memories_hop", "abilities/largo/largo_childhood_memories", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_largo_mind_power", "abilities/largo/largo_childhood_memories", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_largo_song_fight_song_mind_power", "abilities/largo/largo_childhood_memories", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_generic_arc_lua", "modifiers/modifier_generic_arc_lua", 0)

largo_childhood_memories = class({})

local TOGGLE_MODIFIER = "modifier_largo_childhood_memories"
local HOP_MODIFIER = "modifier_largo_childhood_memories_hop"
local FIGHT_SONG_ABILITY = "largo_song_fight_song"
local FIGHT_SONG_BUFF = "modifier_largo_song_attack_burst"
local FIGHT_SONG_MP_BUFF = "modifier_largo_song_fight_song_mind_power"
local ARRIVE_DISTANCE = 24

local function IsValid(entity)
	return entity ~= nil and not entity:IsNull()
end

local function HorizontalVector(vector)
	return Vector(vector.x, vector.y, 0)
end

function largo_childhood_memories:Precache(context)
	if self:GetCaster() and self:GetCaster():IsIllusion() then
		return
	end

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_mirana.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_slark.vsndevts", context)
	PrecacheResource("particle", "particles/units/heroes/hero_slark/slark_pounce_trail.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_slark/slark_pounce_start.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_centaur/centaur_warstomp.vpcf", context)
end

function largo_childhood_memories:GetStunRadius()
	local radius = self:GetSpecialValueFor("stun_radius")
	if GetHeroBonusSpellAoE then
		radius = radius + (GetHeroBonusSpellAoE(self:GetCaster()) or 0)
	end
	return math.max(0, radius)
end

function largo_childhood_memories:GetAOERadius()
	return self:GetStunRadius()
end

function largo_childhood_memories:GetStompDamage()
	local caster = self:GetCaster()
	local mind_power = 0
	if caster and GetHeroMindPower then
		mind_power = GetHeroMindPower(caster) or 0
	end

	return math.max(0,
		self:GetSpecialValueFor("stomp_damage")
		+ mind_power * self:GetSpecialValueFor("mind_power_multiplier")
	)
end

function largo_childhood_memories:OnToggle()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	if self:GetToggleState() then
		caster:AddNewModifier(caster, self, TOGGLE_MODIFIER, {})
	else
		caster:RemoveModifierByName(TOGGLE_MODIFIER)
	end
end

function largo_childhood_memories:OnOwnerDied()
	if not IsServer() then
		return
	end

	if self:GetToggleState() then
		self:ToggleAbility()
	end
end

modifier_largo_childhood_memories = class({})

function modifier_largo_childhood_memories:IsHidden()
	return false
end

function modifier_largo_childhood_memories:IsPurgable()
	return false
end

function modifier_largo_childhood_memories:IsDebuff()
	return false
end

function modifier_largo_childhood_memories:RemoveOnDeath()
	return true
end

function modifier_largo_childhood_memories:GetTexture()
	return "largo_childhood_memories"
end

function modifier_largo_childhood_memories:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_ORDER,
		MODIFIER_PROPERTY_MOVESPEED_LIMIT,
	}
end

function modifier_largo_childhood_memories:CheckState()
	return {
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
	}
end

function modifier_largo_childhood_memories:GetModifierMoveSpeed_Limit()
	if self.ignore_ms_limit then
		return
	end
	if self.hopping or self:GetStackCount() > 0 then
		return 1
	end
end

function modifier_largo_childhood_memories:GetTrueMoveSpeed()
	local parent = self:GetParent()
	if not IsValid(parent) then
		return 0
	end

	self.ignore_ms_limit = true
	local ms = parent:GetIdealSpeed()
	self.ignore_ms_limit = false
	if not ms or ms < 0 then
		return 0
	end
	return ms
end

function modifier_largo_childhood_memories:GetHopDistance()
	local ability = self:GetAbility()
	if not IsValid(ability) then
		return 0
	end

	local multiplier = ability:GetSpecialValueFor("ms_to_distance_multiplier")
	return math.max(0, self:GetTrueMoveSpeed() * multiplier)
end

function modifier_largo_childhood_memories:OnCreated()
	if not IsServer() then
		return
	end

	self.hopping = false
	self.next_hop_time = 0
	self:StartIntervalThink(0.03)
end

function modifier_largo_childhood_memories:OnDestroy()
	if not IsServer() then
		return
	end

	self:InterruptHop()
end

function modifier_largo_childhood_memories:OnOrder(params)
	if params.unit ~= self:GetParent() then
		return
	end
	if self.ignore_order then
		return
	end

	local order = params.order_type
	local ability = params.ability
	if IsValid(ability) and ability == self:GetAbility() then
		return
	end

	if order == DOTA_UNIT_ORDER_MOVE_TO_POSITION
		or order == DOTA_UNIT_ORDER_ATTACK_MOVE
		or order == DOTA_UNIT_ORDER_PATROL
		or order == DOTA_UNIT_ORDER_MOVE_TO_DIRECTION
	then
		self.dest = params.new_pos
		self.move_target = nil
		self.attack_target = nil
		return
	end

	if order == DOTA_UNIT_ORDER_MOVE_TO_TARGET
		or order == DOTA_UNIT_ORDER_PICKUP_ITEM
		or order == DOTA_UNIT_ORDER_PICKUP_RUNE
	then
		self.move_target = params.target
		self.attack_target = nil
		self.dest = nil
		return
	end

	if order == DOTA_UNIT_ORDER_ATTACK_TARGET then
		self.attack_target = params.target
		self.move_target = nil
		self.dest = nil
		return
	end

	if order == DOTA_UNIT_ORDER_STOP
		or order == DOTA_UNIT_ORDER_HOLD_POSITION
		or order == DOTA_UNIT_ORDER_CAST_POSITION
		or order == DOTA_UNIT_ORDER_CAST_TARGET
		or order == DOTA_UNIT_ORDER_CAST_TARGET_TREE
		or order == DOTA_UNIT_ORDER_CAST_NO_TARGET
		or order == DOTA_UNIT_ORDER_CAST_TOGGLE
		or order == DOTA_UNIT_ORDER_DROP_ITEM
		or order == DOTA_UNIT_ORDER_GIVE_ITEM
		or order == DOTA_UNIT_ORDER_GLYPH
		or order == DOTA_UNIT_ORDER_VECTOR_TARGET_POSITION
	then
		self.dest = nil
		self.move_target = nil
		self.attack_target = nil
	end
end

function modifier_largo_childhood_memories:OnIntervalThink()
	if not IsServer() then
		return
	end

	if self.hopping then
		return
	end

	local parent = self:GetParent()
	local ability = self:GetAbility()
	if not IsValid(parent) or not IsValid(ability) or not parent:IsAlive() then
		return
	end

	if GameRules:GetGameTime() < (self.next_hop_time or 0) then
		return
	end

	if parent:IsStunned() or parent:IsHexed() then
		return
	end
	if parent.IsNightmared and parent:IsNightmared() then
		return
	end
	if parent.IsFrozen and parent:IsFrozen() then
		return
	end
	if parent.IsOutOfGame and parent:IsOutOfGame() then
		return
	end

	if parent:IsRooted() then
		return
	end

	local goal, attack_target = self:GetMoveGoal()
	if not goal then
		return
	end

	local origin = parent:GetAbsOrigin()
	local offset = HorizontalVector(goal - origin)
	local remaining = offset:Length2D()
	local hop_distance = self:GetHopDistance()

	if attack_target then
		local attack_range = parent:Script_GetAttackRange()
		if remaining <= attack_range then
			self:SetStackCount(0)
			if parent:GetAttackTarget() ~= attack_target then
				self:IssueAttack(attack_target)
			end
			return
		end
		remaining = math.max(0, remaining - attack_range + 40)
	end

	if remaining <= ARRIVE_DISTANCE then
		self:SetStackCount(0)
		if not attack_target then
			self.dest = nil
			self.move_target = nil
		end
		return
	end

	if hop_distance < 1 or remaining < hop_distance then
		self:SetStackCount(0)
		if attack_target then
			self:IssueAttack(attack_target)
		elseif self.dest then
			self.ignore_order = true
			parent:MoveToPosition(self.dest)
			self.ignore_order = false
			self.dest = nil
			self.move_target = nil
		end
		return
	end

	local mana_cost = ability:GetSpecialValueFor("mana_per_hop")
	if mana_cost > 0 and parent:GetMana() < mana_cost then
		if ability:GetToggleState() then
			ability:ToggleAbility()
		end
		return
	end

	self:SetStackCount(1)
	local direction = offset:Normalized()
	self:StartHop(direction, hop_distance)
end

function modifier_largo_childhood_memories:GetMoveGoal()
	if IsValid(self.attack_target) and self.attack_target:IsAlive() then
		return self.attack_target:GetAbsOrigin(), self.attack_target
	end
	self.attack_target = nil

	if IsValid(self.move_target) then
		return self.move_target:GetAbsOrigin(), nil
	end
	self.move_target = nil

	if self.dest then
		return self.dest, nil
	end

	return nil
end

function modifier_largo_childhood_memories:IssueAttack(target)
	local parent = self:GetParent()
	if not IsValid(parent) or not IsValid(target) then
		return
	end

	self.ignore_order = true
	parent:MoveToTargetToAttack(target)
	self.ignore_order = false
end

function modifier_largo_childhood_memories:StartHop(direction, distance)
	local parent = self:GetParent()
	local ability = self:GetAbility()
	if not IsValid(parent) or not IsValid(ability) then
		return
	end

	local duration = ability:GetSpecialValueFor("hop_duration")
	if duration < 0.08 then
		duration = 0.08
	end

	local height = 150 * math.max(0.5, math.min(1.6, distance / 400))

	local mana_cost = ability:GetSpecialValueFor("mana_per_hop")
	if mana_cost > 0 then
		parent:SpendMana(mana_cost, ability)
	end

	local start_pos = parent:GetAbsOrigin()
	self.hopping = true

	parent:AddNewModifier(parent, ability, HOP_MODIFIER, {
		duration = duration + 0.2,
		start_x = start_pos.x,
		start_y = start_pos.y,
		start_z = start_pos.z,
		dir_x = direction.x,
		dir_y = direction.y,
		distance = distance,
	})

	local arc = parent:AddNewModifier(parent, ability, "modifier_generic_arc_lua", {
		dir_x = direction.x,
		dir_y = direction.y,
		duration = duration,
		distance = distance,
		height = height,
		fix_end = false,
		isStun = 0,
		isForward = 1,
		activity = ACT_DOTA_RUN,
	})

	self.arc = arc
	if not arc then
		self.hopping = false
		parent:RemoveModifierByName(HOP_MODIFIER)
		return
	end

	parent:EmitSound("Hero_Mirana.Leap")

	local start_fx = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_slark/slark_pounce_start.vpcf",
		PATTACH_WORLDORIGIN,
		parent
	)
	ParticleManager:SetParticleControl(start_fx, 0, start_pos)
	ParticleManager:ReleaseParticleIndex(start_fx)

	if arc and arc.SetEndCallback then
		arc:SetEndCallback(function(interrupted)
			if not IsValid(parent) then
				return
			end

			self.hopping = false
			self.arc = nil
			local land_delay = 0.3
			local hop_ability = self:GetAbility()
			if hop_ability and not hop_ability:IsNull() then
				land_delay = hop_ability:GetSpecialValueFor("land_delay")
			end
			self.next_hop_time = GameRules:GetGameTime() + math.max(0, land_delay)

			local hop = parent:FindModifierByName(HOP_MODIFIER)
			if hop then
				hop.interrupted = interrupted
				hop:Destroy()
			end
		end)
	end
end

function modifier_largo_childhood_memories:InterruptHop()
	local parent = self:GetParent()
	self.hopping = false

	local hop = IsValid(parent) and parent:FindModifierByName(HOP_MODIFIER)
	if hop then
		hop.interrupted = true
		hop:Destroy()
	end

	if self.arc and not self.arc:IsNull() then
		self.arc.interrupted = true
		self.arc:Destroy()
	end
	self.arc = nil

	if IsValid(parent) then
		FindClearSpaceForUnit(parent, GetGroundPosition(parent:GetAbsOrigin(), parent), true)
	end
end

modifier_largo_childhood_memories_hop = class({})

function modifier_largo_childhood_memories_hop:IsHidden()
	return true
end

function modifier_largo_childhood_memories_hop:IsPurgable()
	return false
end

function modifier_largo_childhood_memories_hop:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_TRANSLATE_ACTIVITY_MODIFIERS,
	}
end

function modifier_largo_childhood_memories_hop:GetActivityTranslationModifiers()
	return "haste"
end

function modifier_largo_childhood_memories_hop:CheckState()
	return {
		[MODIFIER_STATE_ROOTED] = true,
		[MODIFIER_STATE_DISARMED] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_FLYING_FOR_PATHING_PURPOSES_ONLY] = true,
	}
end

function modifier_largo_childhood_memories_hop:OnCreated(kv)
	if not IsServer() then
		return
	end

	self.start_pos = Vector(kv.start_x or 0, kv.start_y or 0, kv.start_z or 0)
	self.distance = kv.distance or 0
	self.direction = Vector(kv.dir_x or 0, kv.dir_y or 0, 0)

	local parent = self:GetParent()
	local trail = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_slark/slark_pounce_trail.vpcf",
		PATTACH_ABSORIGIN_FOLLOW,
		parent
	)
	ParticleManager:SetParticleControlEnt(
		trail,
		1,
		parent,
		PATTACH_POINT_FOLLOW,
		"attach_hitloc",
		parent:GetAbsOrigin(),
		true
	)
	self:AddParticle(trail, false, false, -1, false, false)
end

function modifier_largo_childhood_memories_hop:OnDestroy()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if not IsValid(parent) then
		return
	end

	local origin = GetGroundPosition(parent:GetAbsOrigin(), parent)
	FindClearSpaceForUnit(parent, origin, true)

	if self.interrupted then
		return
	end

	self:StunAlongHop(origin)
end

function modifier_largo_childhood_memories_hop:StunAlongHop(end_pos)
	local ability = self:GetAbility()
	local caster = self:GetCaster()
	if not IsValid(ability) or not IsValid(caster) then
		return
	end

	local radius = ability:GetStunRadius()
	local duration = ability:GetSpecialValueFor("stun_duration")
	local damage = ability:GetStompDamage()
	local start_pos = self.start_pos or end_pos
	local hit = {}

	local function TryStun(enemy)
		if not IsValid(enemy) or hit[enemy:entindex()] then
			return
		end
		if enemy:IsInvulnerable() or enemy:IsMagicImmune() or enemy:IsDebuffImmune() then
			return
		end

		hit[enemy:entindex()] = true
		if damage > 0 then
			ApplyDamage({
				victim = enemy,
				attacker = caster,
				damage = damage,
				damage_type = DAMAGE_TYPE_MAGICAL,
				ability = ability,
			})
		end
		local stun = duration
		if enemy.GetStatusResistance then
			stun = duration * (1 - enemy:GetStatusResistance())
		end
		enemy:AddNewModifier(caster, ability, "modifier_stunned", { duration = stun })
	end

	local line_units = FindUnitsInLine(
		caster:GetTeamNumber(),
		start_pos,
		end_pos,
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE
	)
	for _, enemy in pairs(line_units) do
		TryStun(enemy)
	end

	local landing_units = FindUnitsInRadius(
		caster:GetTeamNumber(),
		end_pos,
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)
	for _, enemy in ipairs(landing_units) do
		TryStun(enemy)
	end

	local land_fx = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_centaur/centaur_warstomp.vpcf",
		PATTACH_WORLDORIGIN,
		caster
	)
	ParticleManager:SetParticleControl(land_fx, 0, end_pos)
	ParticleManager:SetParticleControl(land_fx, 1, Vector(radius, 0, 0))
	ParticleManager:ReleaseParticleIndex(land_fx)

	EmitSoundOnLocationWithCaster(end_pos, "Hero_Slark.Pounce.Impact", caster)
end

-- Scales remaining vanilla Largo magical damage specials (Fight Song) on the server.
-- Also replaces Fight Song spell amp with a flat Mind Power buff on the same allies.
modifier_largo_mind_power = class({})

function modifier_largo_mind_power:IsHidden()
	return true
end

function modifier_largo_mind_power:IsPurgable()
	return false
end

function modifier_largo_mind_power:RemoveOnDeath()
	return false
end

function modifier_largo_mind_power:OnCreated()
	if not IsServer() then
		return
	end

	self:StartIntervalThink(0.03)
	self:SyncFightSongMindPower()
end

function modifier_largo_mind_power:OnIntervalThink()
	self:SyncFightSongMindPower()
end

function modifier_largo_mind_power:SyncFightSongMindPower()
	local parent = self:GetParent()
	if not parent or parent:IsNull() then
		return
	end

	local song = parent:FindAbilityByName(FIGHT_SONG_ABILITY)
	if not song or song:IsNull() then
		return
	end

	local bonus = song:GetSpecialValueFor("mind_power_bonus") or 0
	local heroes = HeroList and HeroList.GetAllHeroes and HeroList:GetAllHeroes() or {}

	for _, hero in pairs(heroes) do
		if hero and not hero:IsNull() and hero:GetTeamNumber() == parent:GetTeamNumber() then
			local song_buff = hero:FindModifierByName(FIGHT_SONG_BUFF)
			if bonus > 0 and song_buff and not song_buff:IsNull() then
				local remaining = song_buff.GetRemainingTime and song_buff:GetRemainingTime() or 0
				if remaining <= 0 then
					remaining = 0.05
				end

				local mp_buff = hero:FindModifierByName(FIGHT_SONG_MP_BUFF)
				if not mp_buff or mp_buff:IsNull() then
					mp_buff = hero:AddNewModifier(parent, song, FIGHT_SONG_MP_BUFF, { duration = remaining })
				elseif mp_buff.SetDuration then
					mp_buff:SetDuration(remaining, true)
				end

				if mp_buff and not mp_buff:IsNull() then
					mp_buff:SetStackCount(bonus)
				end
			else
				local mp_buff = hero:FindModifierByName(FIGHT_SONG_MP_BUFF)
				if mp_buff and not mp_buff:IsNull() then
					mp_buff:Destroy()
				end
			end
		end
	end
end

function modifier_largo_mind_power:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL,
		MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL_VALUE,
	}
end

function modifier_largo_mind_power:GetModifierOverrideAbilitySpecial(params)
	if not IsServer() or self.computing_override or not params or not params.ability or params.ability:IsNull() then
		return 0
	end

	if params.ability:GetAbilityName() == FIGHT_SONG_ABILITY and params.ability_special_value == "spell_amp_bonus" then
		return 1
	end

	return CustomAbilityTooltips:IsNumericMindPowerMultiplier(
		params.ability:GetAbilityName(),
		params.ability_special_value
	) and 1 or 0
end

function modifier_largo_mind_power:GetModifierOverrideAbilitySpecialValue(params)
	if not IsServer() or not params or not params.ability or params.ability:IsNull() then
		return 0
	end

	local ability = params.ability
	local special_value = params.ability_special_value
	if ability:GetAbilityName() == FIGHT_SONG_ABILITY and special_value == "spell_amp_bonus" then
		return 0
	end

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

modifier_largo_song_fight_song_mind_power = class({})

function modifier_largo_song_fight_song_mind_power:IsHidden()
	return true
end

function modifier_largo_song_fight_song_mind_power:IsPurgable()
	return true
end

function modifier_largo_song_fight_song_mind_power:IsDebuff()
	return false
end

function modifier_largo_song_fight_song_mind_power:GetTexture()
	return "largo_song_fight_song"
end

MIND_POWER_MODIFIER_REGISTRY = MIND_POWER_MODIFIER_REGISTRY or {}
MIND_POWER_MODIFIER_REGISTRY["modifier_largo_song_fight_song_mind_power"] = function(modifier)
	return modifier:GetStackCount()
end
