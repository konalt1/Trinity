LinkLuaModifier(
	"modifier_void_spirit_dissimilate_trinity_phase",
	"abilities/void_spirit/void_spirit_dissimilate_trinity",
	LUA_MODIFIER_MOTION_NONE
)

local SOUND_FILE = "soundevents/game_sounds_heroes/game_sounds_void_spirit.vsndevts"
local PARTICLE_PORTAL = "particles/units/heroes/hero_void_spirit/dissimilate/void_spirit_dissimilate.vpcf"
local PARTICLE_PORTAL_ALT = "particles/units/heroes/hero_void_spirit/dissimilate/void_spirit_dissimilate_2.vpcf"
local PARTICLE_DMG = "particles/units/heroes/hero_void_spirit/dissimilate/void_spirit_dissimilate_dmg.vpcf"
local PARTICLE_EXIT = "particles/units/heroes/hero_void_spirit/dissimilate/void_spirit_dissimilate_exit.vpcf"
local PHASE_MODIFIER = "modifier_void_spirit_dissimilate_trinity_phase"
local order_listeners = {}

local function AddOrderListener(modifier)
	table.insert(order_listeners, modifier)
end

local function RemoveOrderListener(modifier)
	for index = #order_listeners, 1, -1 do
		if order_listeners[index] == modifier then
			table.remove(order_listeners, index)
		end
	end
end

local function IsValidHandle(handle)
	return handle and (not handle.IsNull or not handle:IsNull())
end

local function GetMindPower(unit)
	if GetHeroMindPower then
		return GetHeroMindPower(unit) or 0
	end
	return 0
end

local function DeleteParticle(index, immediate)
	if not index then
		return
	end
	ParticleManager:DestroyParticle(index, immediate == true)
	ParticleManager:ReleaseParticleIndex(index)
end

local function IsNearPoint(points, position, min_distance)
	for _, point in ipairs(points) do
		if (point - position):Length2D() <= min_distance then
			return true
		end
	end
	return false
end

void_spirit_dissimilate_trinity = class({})

function void_spirit_dissimilate_trinity:Precache(context)
	if self:GetCaster() and self:GetCaster():IsIllusion() then
		return
	end

	PrecacheResource("soundfile", SOUND_FILE, context)
	PrecacheResource("particle", PARTICLE_PORTAL, context)
	PrecacheResource("particle", PARTICLE_PORTAL_ALT, context)
	PrecacheResource("particle", PARTICLE_DMG, context)
	PrecacheResource("particle", PARTICLE_EXIT, context)
end

function void_spirit_dissimilate_trinity:GetAOERadius()
	return self:GetSpecialValueFor("damage_radius")
end

function void_spirit_dissimilate_trinity:GetExitDamage()
	local caster = self:GetCaster()
	return math.max(
		0,
		self:GetSpecialValueFor("damage")
			+ GetMindPower(caster) * self:GetSpecialValueFor("mind_power_multiplier")
	)
end

function void_spirit_dissimilate_trinity:OnSpellStart()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	caster:AddNewModifier(caster, self, PHASE_MODIFIER, {
		duration = self:GetSpecialValueFor("phase_duration"),
	})
	caster:EmitSound("Hero_VoidSpirit.Dissimilate.Cast")
end

modifier_void_spirit_dissimilate_trinity_phase = class({})

function modifier_void_spirit_dissimilate_trinity_phase:IsHidden()
	return false
end

function modifier_void_spirit_dissimilate_trinity_phase:IsPurgable()
	return false
end

function modifier_void_spirit_dissimilate_trinity_phase:GetTexture()
	return "void_spirit_dissimilate"
end

function modifier_void_spirit_dissimilate_trinity_phase:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_ORDER,
	}
end

function modifier_void_spirit_dissimilate_trinity_phase:CheckState()
	return {
		[MODIFIER_STATE_DISARMED] = true,
		[MODIFIER_STATE_ROOTED] = true,
		[MODIFIER_STATE_OUT_OF_GAME] = true,
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_MUTED] = true,
		[MODIFIER_STATE_SILENCED] = true,
	}
end

function modifier_void_spirit_dissimilate_trinity_phase:OnCreated()
	self.parent = self:GetParent()
	self.ability = self:GetAbility()
	self.portals = math.floor(self.ability:GetSpecialValueFor("portals_per_ring") + 0.5)
	self.angle = self.ability:GetSpecialValueFor("angle_per_ring_portal")
	self.radius = self.ability:GetSpecialValueFor("damage_radius")
	self.distance = self.ability:GetSpecialValueFor("first_ring_distance_offset")
	self.target_radius = self.ability:GetSpecialValueFor("destination_fx_radius")

	if GetHeroBonusSpellAoE then
		local bonus = GetHeroBonusSpellAoE(self.parent)
		self.radius = self.radius + bonus
		self.distance = self.distance + bonus
	end

	if self.portals > 0 and (not self.angle or self.angle <= 0) then
		self.angle = 360 / self.portals
	end

	if not IsServer() then
		return
	end

	self.selected = 1
	self.exited = false
	self.points = {}
	self.effects = {}

	local origin = self.parent:GetOrigin()
	local direction = self.parent:GetForwardVector()
	local zero = Vector(0, 0, 0)

	table.insert(self.points, origin)
	table.insert(self.effects, self:PlayEffects1(origin, true))

	for i = 1, self.portals do
		local new_direction = RotatePosition(zero, QAngle(0, self.angle * i, 0), direction)
		local point = GetGroundPosition(origin + new_direction * self.distance, nil)
		table.insert(self.points, point)
		table.insert(self.effects, self:PlayEffects1(point, false))
		AddFOWViewer(self.parent:GetTeamNumber(), point, self.radius, self:GetRemainingTime(), false)
	end

	self:CreateRemnantPortals()
	self.parent:AddNoDraw()
	AddOrderListener(self)
end

function modifier_void_spirit_dissimilate_trinity_phase:CreateRemnantPortals()
	local has_shard = HasShard and HasShard(self.parent)
		or (self.parent.HasModifier and self.parent:HasModifier("modifier_item_aghanims_shard"))
	if not has_shard then
		return
	end
	if not GetVoidSpiritAstralRemnantList then
		return
	end

	for _, remnant in ipairs(GetVoidSpiritAstralRemnantList(self.parent)) do
		if IsValidHandle(remnant) then
			local point = GetGroundPosition(remnant:GetAbsOrigin(), nil)
			if not IsNearPoint(self.points, point, 80) then
				table.insert(self.points, point)
				table.insert(self.effects, self:PlayEffects1(point, false))
				AddFOWViewer(self.parent:GetTeamNumber(), point, self.radius, self:GetRemainingTime(), false)
			end
		end
	end
end

function modifier_void_spirit_dissimilate_trinity_phase:PlayEffects1(point, main)
	local radius = self.radius + 25
	local effect_cast = ParticleManager:CreateParticle(PARTICLE_PORTAL, PATTACH_WORLDORIGIN, self.parent)
	ParticleManager:SetParticleControl(effect_cast, 0, point)
	ParticleManager:SetParticleControl(effect_cast, 1, Vector(radius, 0, 1))
	if main then
		ParticleManager:SetParticleControl(effect_cast, 2, Vector(1, 0, 0))
	end
	self:AddParticle(effect_cast, false, false, -1, false, false)
	EmitSoundOnLocationWithCaster(point, "Hero_VoidSpirit.Dissimilate.Portals", self.parent)
	return effect_cast
end

function modifier_void_spirit_dissimilate_trinity_phase:ChangeEffects(old, new)
	if self.effects[old] then
		ParticleManager:SetParticleControl(self.effects[old], 2, Vector(0, 0, 0))
	end
	if self.effects[new] then
		ParticleManager:SetParticleControl(self.effects[new], 2, Vector(1, 0, 0))
	end
end

function modifier_void_spirit_dissimilate_trinity_phase:OrderEvent(params)
	if params.order_type == DOTA_UNIT_ORDER_MOVE_TO_POSITION
		or params.order_type == DOTA_UNIT_ORDER_ATTACK_MOVE
		or params.order_type == DOTA_UNIT_ORDER_MOVE_TO_DIRECTION
	then
		if params.pos then
			self:SetValidTarget(params.pos)
		end
	elseif (params.order_type == DOTA_UNIT_ORDER_MOVE_TO_TARGET
		or params.order_type == DOTA_UNIT_ORDER_ATTACK_TARGET)
		and params.target
		and (not params.target.IsNull or not params.target:IsNull())
	then
		self:SetValidTarget(params.target:GetOrigin())
	end
end

function modifier_void_spirit_dissimilate_trinity_phase:OnOrder(params)
	if not IsServer() then
		return
	end
	if params.unit ~= self.parent then
		return
	end
	self:OrderEvent({
		order_type = params.order_type,
		pos = params.new_pos,
		target = params.target,
	})
end

function modifier_void_spirit_dissimilate_trinity_phase:SetValidTarget(location)
	if not location or not self.points or not self.points[1] then
		return
	end

	local max_dist = (location - self.points[1]):Length2D()
	local max_point = 1
	for i, point in pairs(self.points) do
		local dist = (location - point):Length2D()
		if dist < max_dist then
			max_dist = dist
			max_point = i
		end
	end

	local old_select = self.selected
	self.selected = max_point
	self:ChangeEffects(old_select, self.selected)
end

function modifier_void_spirit_dissimilate_trinity_phase:PlayEffects2(point, hit)
	local effect_cast = ParticleManager:CreateParticle(PARTICLE_DMG, PATTACH_WORLDORIGIN, self.parent)
	ParticleManager:SetParticleControl(effect_cast, 0, point)
	ParticleManager:SetParticleControl(effect_cast, 1, Vector(self.target_radius, 0, 0))
	DeleteParticle(effect_cast, false)

	effect_cast = ParticleManager:CreateParticle(PARTICLE_EXIT, PATTACH_ABSORIGIN_FOLLOW, self.parent)
	DeleteParticle(effect_cast, false)

	self.parent:StartGesture(ACT_DOTA_CAST_ABILITY_3_END)
	self.parent:EmitSound("Hero_VoidSpirit.Dissimilate.TeleportIn")
	if hit > 0 then
		self.parent:EmitSound("Hero_VoidSpirit.Dissimilate.Stun")
	end
end

function modifier_void_spirit_dissimilate_trinity_phase:OnDestroy()
	if not IsServer() then
		return
	end

	RemoveOrderListener(self)
	self.parent:RemoveNoDraw()

	for _, effect in pairs(self.effects or {}) do
		DeleteParticle(effect, self:GetRemainingTime() > 0.1)
	end
	self.effects = {}

	if self.exited then
		return
	end
	self.exited = true

	if not self.ability or self.ability:IsNull() or not IsValidHandle(self.parent) then
		return
	end

	local point = self.points[self.selected] or self.parent:GetAbsOrigin()
	FindClearSpaceForUnit(self.parent, point, true)

	local damage = self.ability:GetExitDamage()
	local enemies = FindUnitsInRadius(
		self.parent:GetTeamNumber(),
		point,
		nil,
		self.radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	local hit = 0
	for _, enemy in pairs(enemies) do
		if IsValidHandle(enemy) and enemy:IsAlive() and not enemy:IsMagicImmune() then
			hit = hit + 1
			ApplyDamage({
				victim = enemy,
				attacker = self.parent,
				damage = damage,
				damage_type = DAMAGE_TYPE_MAGICAL,
				ability = self.ability,
			})
		end
	end

	self:PlayEffects2(point, hit)
end

function VoidSpiritDissimilateHandleOrder(data)
	if not data then
		return true
	end

	local target
	if data.entindex_target and data.entindex_target ~= 0 then
		target = EntIndexToHScript(data.entindex_target)
	end

	local params = {
		order_type = data.order_type,
		pos = Vector(data.position_x or 0, data.position_y or 0, data.position_z or 0),
		target = target,
	}

	local player_id = data.issuer_player_id_const
	for index = #order_listeners, 1, -1 do
		local modifier = order_listeners[index]
		if not modifier or (modifier.IsNull and modifier:IsNull()) then
			table.remove(order_listeners, index)
		elseif modifier.OrderEvent then
			local parent = modifier.parent or modifier:GetParent()
			local matches_player = IsValidHandle(parent)
				and player_id ~= nil
				and player_id >= 0
				and parent:GetPlayerOwnerID() == player_id
			if matches_player then
				modifier:OrderEvent(params)
			end
		end
	end

	return true
end
