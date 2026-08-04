LinkLuaModifier('modifier_weaver_cucaracha', 'abilities/Weaver/Cucaracha', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_weaver_cucaracha_swarm_bug', 'abilities/Weaver/Cucaracha', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_weaver_cucaracha_swarm_debuff', 'abilities/Weaver/Cucaracha', LUA_MODIFIER_MOTION_NONE)

local CUCARACHA_SHARD_DEFAULT_RADIUS = 100
local CUCARACHA_SHARD_DEFAULT_SEARCH_INTERVAL = 0.1
local CUCARACHA_SHARD_DEFAULT_BEETLE_OFFSET = 15
local CUCARACHA_SHARD_DEFAULT_BEETLE_HITS = 3

local function GetCucarachaShardValue(ability, value_name, fallback)
	local value = ability and ability:GetSpecialValueFor(value_name) or 0
	if value and value > 0 then return value end
	return fallback
end

weaver_cucaracha = class({})

function weaver_cucaracha:Precache(context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_weaver.vsndevts", context)
	PrecacheUnitByNameSync("npc_dota_weaver_swarm", context)
end

function weaver_cucaracha:IsStealable()
	return false
end

function weaver_cucaracha:IsHidden()
	return false
end

function weaver_cucaracha:OnSpellStart()
	local caster = self:GetCaster()
	local duration = self:GetSpecialValueFor("duration")

	-- Прерываем анимацию восстановления размера, если она идет
	if caster.cucaracha_growing then
		caster.cucaracha_growing = nil
		caster.cucaracha_scale_step = nil
		caster.cucaracha_ability = nil
	end

	caster:AddNewModifier(caster, self, "modifier_weaver_cucaracha", { duration = duration })
	EmitSoundOn("Hero_Weaver.Shukuchi", caster)
end

-- Плавное восстановление размера после окончания эффекта
function weaver_cucaracha:StartGrowAnimation(hero, current_scale)
	if not hero or not IsValidEntity(hero) then return end
	if hero.cucaracha_growing then return end

	if current_scale >= 0.95 then
		hero:SetModelScale(1.0)
		return
	end

	hero.cucaracha_growing = true
	hero.cucaracha_current_scale = current_scale
	hero.cucaracha_scale_step = (1.0 - current_scale) / 15
	hero.cucaracha_ability = self

	Timers:CreateTimer(0.03, function()
		return self:GrowAnimationThink(hero)
	end)
end

function weaver_cucaracha:GrowAnimationThink(hero)
	if not hero or not IsValidEntity(hero) or not hero.cucaracha_growing then
		return nil
	end

	hero.cucaracha_current_scale = hero.cucaracha_current_scale + hero.cucaracha_scale_step

	if hero.cucaracha_current_scale >= 1.0 then
		hero.cucaracha_current_scale = 1.0
		hero:SetModelScale(1.0)
		hero.cucaracha_growing = nil
		hero.cucaracha_current_scale = nil
		hero.cucaracha_scale_step = nil
		hero.cucaracha_ability = nil
		return nil
	end

	hero:SetModelScale(hero.cucaracha_current_scale)
	return 0.03
end

--------------------------------------------------------------------------------
-- Modifier
--------------------------------------------------------------------------------
modifier_weaver_cucaracha = class({
	IsHidden = function(self) return false end,
	IsPurgable = function(self) return true end,
	IsBuff = function(self) return true end,
	RemoveOnDeath = function(self) return true end,
	GetAttributes = function(self) return MODIFIER_ATTRIBUTE_NONE end,
	DeclareFunctions = function(self) return
	{
		MODIFIER_PROPERTY_MOVESPEED_ABSOLUTE,
		MODIFIER_PROPERTY_TOOLTIP,
	} end,
})

function modifier_weaver_cucaracha:CheckState()
	return {
		[MODIFIER_STATE_NO_HEALTH_BAR_FOR_ENEMIES] = true,
	}
end

function modifier_weaver_cucaracha:OnCreated()
	local ability = self:GetAbility()
	if not ability then return end

	if not IsServer() then return end

	local parent = self:GetParent()

	self.move_speed = ability:GetSpecialValueFor("move_speed")
	self.target_scale = ability:GetSpecialValueFor("model_scale")

	self:SetStackCount(math.floor(self.move_speed))

	if parent and parent.cucaracha_current_scale then
		self.current_scale = parent.cucaracha_current_scale
		parent.cucaracha_current_scale = nil
	else
		self.current_scale = 1.0
	end

	-- Плавное уменьшение размера
	if self.target_scale and self.target_scale > 0 and self.current_scale > self.target_scale + 0.001 then
		self.scale_decrement = (self.current_scale - self.target_scale) / 15
		self:StartIntervalThink(0.03)
	else
		self.current_scale = self.target_scale or self.current_scale
		if parent and IsValidEntity(parent) and self.current_scale then
			parent:SetModelScale(self.current_scale)
		end
	end

	-- Shard: continuously look for enemies close enough to receive a Swarm beetle.
	if HasShard(parent) then
		self.swarm_radius = GetCucarachaShardValue(ability, "shard_swarm_radius", CUCARACHA_SHARD_DEFAULT_RADIUS)
		self.swarm_search_interval = GetCucarachaShardValue(ability, "shard_swarm_search_interval", CUCARACHA_SHARD_DEFAULT_SEARCH_INTERVAL)
		self:AttachSwarmBeetles()
		self.next_swarm_search = GameRules:GetGameTime() + self.swarm_search_interval
		if not self.scale_decrement then
			self:StartIntervalThink(self.swarm_search_interval)
		end
	end
end

function modifier_weaver_cucaracha:OnRefresh()
	if not IsServer() then return end

	local ability = self:GetAbility()
	if not ability then return end

	self.move_speed = ability:GetSpecialValueFor("move_speed")
	self:SetStackCount(math.floor(self.move_speed))

	local parent = self:GetParent()
	if HasShard(parent) and not self.swarm_search_interval then
		self.swarm_radius = GetCucarachaShardValue(ability, "shard_swarm_radius", CUCARACHA_SHARD_DEFAULT_RADIUS)
		self.swarm_search_interval = GetCucarachaShardValue(ability, "shard_swarm_search_interval", CUCARACHA_SHARD_DEFAULT_SEARCH_INTERVAL)
		self:AttachSwarmBeetles()
		self.next_swarm_search = GameRules:GetGameTime() + self.swarm_search_interval
		if not self.scale_decrement then
			self:StartIntervalThink(self.swarm_search_interval)
		end
	end
end

function modifier_weaver_cucaracha:OnIntervalThink()
	if not IsServer() then return end

	local parent = self:GetParent()
	if not parent or not IsValidEntity(parent) then return end

	if HasShard(parent) and not self.swarm_search_interval then
		local ability = self:GetAbility()
		self.swarm_radius = GetCucarachaShardValue(ability, "shard_swarm_radius", CUCARACHA_SHARD_DEFAULT_RADIUS)
		self.swarm_search_interval = GetCucarachaShardValue(ability, "shard_swarm_search_interval", CUCARACHA_SHARD_DEFAULT_SEARCH_INTERVAL)
		self:AttachSwarmBeetles()
		self.next_swarm_search = GameRules:GetGameTime() + self.swarm_search_interval
	end

	if HasShard(parent) and GameRules:GetGameTime() >= (self.next_swarm_search or 0) then
		self:AttachSwarmBeetles()
		self.next_swarm_search = GameRules:GetGameTime() + self.swarm_search_interval
	end

	if not self.scale_decrement or not self.target_scale then
		if not HasShard(parent) then
			self:StartIntervalThink(-1)
		end
		return
	end

	self.current_scale = self.current_scale - self.scale_decrement

	if self.current_scale <= self.target_scale then
		self.current_scale = self.target_scale
		parent:SetModelScale(self.current_scale)
		self.scale_decrement = nil
		if HasShard(parent) then
			self:StartIntervalThink(self.swarm_search_interval)
		else
			self:StartIntervalThink(-1)
		end
		return
	end

	parent:SetModelScale(self.current_scale)
end

function modifier_weaver_cucaracha:AttachSwarmBeetles()
	local parent = self:GetParent()
	local swarm = parent:FindAbilityByName("weaver_the_swarm")
	if not swarm or swarm:GetLevel() < 1 then return end

	local flags = DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES
		+ DOTA_UNIT_TARGET_FLAG_INVULNERABLE
		+ DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE
		+ DOTA_UNIT_TARGET_FLAG_NO_INVIS

	local enemies = FindUnitsInRadius(
		parent:GetTeamNumber(),
		parent:GetAbsOrigin(),
		nil,
		self.swarm_radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		flags,
		FIND_ANY_ORDER,
		false
	)
	for _, enemy in pairs(enemies) do
		if not enemy:IsCourier()
			and not enemy:HasModifier("modifier_weaver_swarm_debuff")
			and not enemy:HasModifier("modifier_weaver_cucaracha_swarm_debuff") then
			self:AttachSwarmBeetle(enemy, swarm)
		end
	end
end

function modifier_weaver_cucaracha:AttachSwarmBeetle(target, swarm)
	local parent = self:GetParent()
	local duration = swarm:GetSpecialValueFor("duration")
	local beetle_offset = GetCucarachaShardValue(
		self:GetAbility(),
		"shard_swarm_beetle_offset",
		CUCARACHA_SHARD_DEFAULT_BEETLE_OFFSET
	)
	local beetle_hits = GetCucarachaShardValue(
		self:GetAbility(),
		"shard_swarm_beetle_hits",
		CUCARACHA_SHARD_DEFAULT_BEETLE_HITS
	)
	local beetle_position = target:GetAbsOrigin() + target:GetForwardVector() * beetle_offset
	local beetle = CreateUnitByName(
		"npc_dota_weaver_swarm",
		beetle_position,
		false,
		parent,
		parent,
		parent:GetTeamNumber()
	)
	if not beetle then return end

	beetle:SetOwner(parent)
	beetle:SetForwardVector(target:GetForwardVector())

	local debuff = target:AddNewModifier(parent, swarm, "modifier_weaver_cucaracha_swarm_debuff", {
		duration = duration,
		beetle_entindex = beetle:entindex(),
	})

	if not debuff then
		UTIL_Remove(beetle)
		return
	end

	local bug_modifier = beetle:AddNewModifier(parent, swarm, "modifier_weaver_cucaracha_swarm_bug", {
		duration = duration,
		target_entindex = target:entindex(),
		position_offset = beetle_offset,
		attacks_to_destroy = beetle_hits,
	})
	if not bug_modifier then
		target:RemoveModifierByName("modifier_weaver_cucaracha_swarm_debuff")
		if not beetle:IsNull() then UTIL_Remove(beetle) end
		return
	end
end

function modifier_weaver_cucaracha:GetModifierMoveSpeed_Absolute()
	if IsServer() then
		return self.move_speed or 0
	end
	return self:GetStackCount()
end

function modifier_weaver_cucaracha:OnTooltip()
	if IsServer() then
		return self.move_speed or 0
	end
	return self:GetStackCount()
end

function modifier_weaver_cucaracha:GetTexture()
	return "weaver_shukuchi"
end

function modifier_weaver_cucaracha:OnDestroy()
	if not IsServer() then return end

	local parent = self:GetParent()
	if not parent or not IsValidEntity(parent) then return end
	local ability = self:GetAbility()
	if ability then
		ability:StartGrowAnimation(parent, self.current_scale or self.target_scale or 0.5)
	else
		parent:SetModelScale(1.0)
	end

	EmitSoundOn("Hero_Weaver.Shukuchi.End", parent)
end

--------------------------------------------------------------------------------
-- Shard: The Swarm beetle attached by Cucaracha
--------------------------------------------------------------------------------
modifier_weaver_cucaracha_swarm_bug = class({
	IsHidden = function(self) return true end,
	IsPurgable = function(self) return false end,
	IsDebuff = function(self) return false end,
	RemoveOnDeath = function(self) return true end,
	GetAttributes = function(self) return MODIFIER_ATTRIBUTE_NONE end,
})

function modifier_weaver_cucaracha_swarm_bug:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_ATTACKED,
		MODIFIER_PROPERTY_HEALTHBAR_PIPS,
		MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PHYSICAL,
		MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_MAGICAL,
		MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PURE,
	}
end

function modifier_weaver_cucaracha_swarm_bug:CheckState()
	return {
		[MODIFIER_STATE_MAGIC_IMMUNE] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_NO_TEAM_MOVE_TO] = true,
		[MODIFIER_STATE_NO_TEAM_SELECT] = true,
		[MODIFIER_STATE_NOT_ON_MINIMAP] = true,
	}
end

function modifier_weaver_cucaracha_swarm_bug:OnCreated(kv)
	self.attacks_to_destroy = tonumber(kv.attacks_to_destroy) or CUCARACHA_SHARD_DEFAULT_BEETLE_HITS
	if not IsServer() then return end

	self.target = EntIndexToHScript(kv.target_entindex or -1)
	self.attack_progress = 0
	self.position_offset = tonumber(kv.position_offset) or CUCARACHA_SHARD_DEFAULT_BEETLE_OFFSET
	local bug = self:GetParent()
	bug:SetBaseMaxHealth(self.attacks_to_destroy)
	bug:SetMaxHealth(self.attacks_to_destroy)
	bug:SetHealth(self.attacks_to_destroy)
	self:UpdatePosition()
	self:StartIntervalThink(0.03)
end

function modifier_weaver_cucaracha_swarm_bug:OnIntervalThink()
	if not self.target or self.target:IsNull() or not self.target:IsAlive() then
		self:Destroy()
		return
	end

	self:UpdatePosition()
end

function modifier_weaver_cucaracha_swarm_bug:UpdatePosition()
	if not self.target or self.target:IsNull() then return end

	local forward = self.target:GetForwardVector()
	local bug = self:GetParent()
	bug:SetAbsOrigin(self.target:GetAbsOrigin() + forward * self.position_offset)
	bug:SetForwardVector(forward)
end

function modifier_weaver_cucaracha_swarm_bug:OnAttacked(event)
	if not IsServer() then return end
	if event.target ~= self:GetParent() then return end

	self.attack_progress = self.attack_progress + 1
	local health_remaining = math.max(0, self.attacks_to_destroy - self.attack_progress)
	if self.attack_progress >= self.attacks_to_destroy then
		local attacker = event.attacker
		local bug = self:GetParent()
		bug:Kill(nil, attacker)
		if self.target and not self.target:IsNull() then
			self.target:RemoveModifierByName("modifier_weaver_cucaracha_swarm_debuff")
		end
	else
		self:GetParent():SetHealth(health_remaining)
	end
end

function modifier_weaver_cucaracha_swarm_bug:GetModifierHealthBarPips()
	return self.attacks_to_destroy or CUCARACHA_SHARD_DEFAULT_BEETLE_HITS
end

function modifier_weaver_cucaracha_swarm_bug:GetAbsoluteNoDamagePhysical() return 1 end
function modifier_weaver_cucaracha_swarm_bug:GetAbsoluteNoDamageMagical() return 1 end
function modifier_weaver_cucaracha_swarm_bug:GetAbsoluteNoDamagePure() return 1 end

function modifier_weaver_cucaracha_swarm_bug:OnDestroy()
	if not IsServer() then return end
	local bug = self:GetParent()
	if bug and IsValidEntity(bug) and bug:IsAlive() then
		UTIL_Remove(bug)
	end
end

--------------------------------------------------------------------------------
-- Shard: The Swarm debuff attached by Cucaracha
--------------------------------------------------------------------------------
modifier_weaver_cucaracha_swarm_debuff = class({
	IsHidden = function(self) return false end,
	IsPurgable = function(self) return false end,
	IsDebuff = function(self) return true end,
	RemoveOnDeath = function(self) return true end,
})

function modifier_weaver_cucaracha_swarm_debuff:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_PROPERTY_PROVIDES_FOW_POSITION,
	}
end

function modifier_weaver_cucaracha_swarm_debuff:OnCreated(kv)
	local ability = self:GetAbility()
	if not ability then return end

	self.damage = ability:GetSpecialValueFor("damage")
	self.armor_reduction = ability:GetSpecialValueFor("armor_reduction")
	self.attack_rate = ability:GetSpecialValueFor("attack_rate")

	if not IsServer() then return end
	self.beetle = EntIndexToHScript(kv.beetle_entindex or -1)
	self:StartIntervalThink(self.attack_rate)
	self:OnIntervalThink()
end

function modifier_weaver_cucaracha_swarm_debuff:OnIntervalThink()
	local parent = self:GetParent()
	local caster = self:GetCaster()
	if not caster or caster:IsNull() or not parent:IsAlive() then
		self:Destroy()
		return
	end

	self:IncrementStackCount()
	ApplyDamage({
		victim = parent,
		attacker = caster,
		damage = self.damage,
		damage_type = DAMAGE_TYPE_PHYSICAL,
		damage_flags = DOTA_DAMAGE_FLAG_BYPASSES_BLOCK,
		ability = self:GetAbility(),
	})
end

function modifier_weaver_cucaracha_swarm_debuff:GetModifierPhysicalArmorBonus()
	return -(self.armor_reduction or 0) * self:GetStackCount()
end

function modifier_weaver_cucaracha_swarm_debuff:GetModifierProvidesFOWVision()
	return 1
end

function modifier_weaver_cucaracha_swarm_debuff:OnDestroy()
	if not IsServer() then return end
	if self.beetle and not self.beetle:IsNull() and self.beetle:IsAlive() then
		UTIL_Remove(self.beetle)
	end
end

function modifier_weaver_cucaracha_swarm_debuff:GetTexture()
	return "weaver_the_swarm"
end
