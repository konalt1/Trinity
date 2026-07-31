LinkLuaModifier(
	"modifier_ember_fire_remnant_trinity_remnant",
	"abilities/ember_spirit/ember_fire_remnant_trinity",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_ember_activate_fire_remnant_trinity_travel",
	"abilities/ember_spirit/ember_fire_remnant_trinity",
	LUA_MODIFIER_MOTION_NONE
)

local REMNANT_UNIT = "npc_dota_ember_spirit_remnant_trinity"
local TRAIL_PARTICLE = "particles/units/heroes/hero_ember_spirit/ember_spirit_fire_remnant_trail.vpcf"
local REMNANT_PARTICLE = "particles/units/heroes/hero_ember_spirit/ember_spirit_fire_remnant.vpcf"
local HIT_PARTICLE = "particles/units/heroes/hero_ember_spirit/ember_spirit_hit.vpcf"
local DASH_PARTICLE = "particles/units/heroes/hero_ember_spirit/ember_spirit_remnant_dash.vpcf"

local ACTIVATE_ABILITY = "ember_spirit_activate_fire_remnant"

local function IsValidHandle(handle)
	return handle and not handle:IsNull()
end

local function GetMindPower(unit)
	if GetHeroMindPower then
		return GetHeroMindPower(unit) or 0
	end
	return 0
end

local function GetRemnantList(caster)
	caster.ember_fire_remnants_trinity = caster.ember_fire_remnants_trinity or {}
	return caster.ember_fire_remnants_trinity
end

local function RemoveFromRemnantList(caster, remnant)
	if not IsValidHandle(caster) or not caster.ember_fire_remnants_trinity then return end
	for index = #caster.ember_fire_remnants_trinity, 1, -1 do
		if caster.ember_fire_remnants_trinity[index] == remnant then
			table.remove(caster.ember_fire_remnants_trinity, index)
			break
		end
	end
end

local function PrecacheRemnantResources(context)
	PrecacheResource("particle", TRAIL_PARTICLE, context)
	PrecacheResource("particle", REMNANT_PARTICLE, context)
	PrecacheResource("particle", HIT_PARTICLE, context)
	PrecacheResource("particle", DASH_PARTICLE, context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ember_spirit.vsndevts", context)
	PrecacheUnitByNameSync(REMNANT_UNIT, context)
end

local function SyncLinkedAbilities(ability)
	if not IsServer() then return end
	local caster = ability:GetCaster()
	if not IsValidHandle(caster) then return end

	local level = ability:GetLevel()
	local activate = caster:FindAbilityByName(ACTIVATE_ABILITY)
	if activate and activate:GetLevel() ~= level then activate:SetLevel(level) end
end

local function PlaceRemnant(ability)
	if not IsServer() then return end

	local caster = ability:GetCaster()
	local origin = caster:GetAbsOrigin()
	local target = ability:GetCursorPosition()
	local direction = target - origin
	direction.z = 0
	if direction:Length2D() < 1 then
		direction = caster:GetForwardVector()
		target = origin + direction
	end

	local remnant = CreateUnitByName(REMNANT_UNIT, origin, false, caster, caster, caster:GetTeamNumber())
	if not IsValidHandle(remnant) then return end

	remnant:SetOwner(caster)
	remnant:SetDayTimeVisionRange(700)
	remnant:SetNightTimeVisionRange(700)
	remnant.targets_hit = {}
	remnant:AddNewModifier(caster, ability, "modifier_ember_fire_remnant_trinity_remnant", {
		duration = ability:GetSpecialValueFor("duration"),
	})

	local move_speed = caster:GetMoveSpeedModifier(caster:GetBaseMoveSpeed(), false)
	local remnant_speed = move_speed * ability:GetSpecialValueFor("speed_multiplier") * 0.01
	local velocity = direction:Normalized() * remnant_speed

	local trail = ParticleManager:CreateParticle(TRAIL_PARTICLE, PATTACH_CUSTOMORIGIN, remnant)
	ParticleManager:SetParticleControl(trail, 0, origin)
	ParticleManager:SetParticleControl(trail, 1, velocity)
	ParticleManager:SetParticleShouldCheckFoW(trail, false)
	remnant.ember_trail_particle = trail

	ProjectileManager:CreateLinearProjectile({
		Ability = ability,
		Source = caster,
		vSpawnOrigin = origin,
		vVelocity = velocity,
		fDistance = direction:Length2D(),
		fStartRadius = 0,
		fEndRadius = 0,
		bDeleteOnHit = false,
		bProvidesVision = false,
		ExtraData = { remnant = remnant:entindex() },
	})

	caster:EmitSound("Hero_EmberSpirit.FireRemnant.Cast")
	local activate = caster:FindAbilityByName(ACTIVATE_ABILITY)
	if activate then activate:RefreshRemnants() end
end

ember_spirit_fire_remnant_trinity = class({})

function ember_spirit_fire_remnant_trinity:Precache(context) PrecacheRemnantResources(context) end

function ember_spirit_fire_remnant_trinity:OnSpellStart() PlaceRemnant(self) end

function ember_spirit_fire_remnant_trinity:OnUpgrade()
	SyncLinkedAbilities(self)
end

function ember_spirit_fire_remnant_trinity:OnProjectileThink_ExtraData(location, data)
	local remnant = EntIndexToHScript(tonumber(data.remnant) or -1)
	if IsValidHandle(remnant) then remnant:SetAbsOrigin(GetGroundPosition(location, remnant)) end
end

function ember_spirit_fire_remnant_trinity:OnProjectileHit_ExtraData(_, location, data)
	local remnant = EntIndexToHScript(tonumber(data.remnant) or -1)
	if not IsValidHandle(remnant) then return false end
	remnant:SetAbsOrigin(GetGroundPosition(location, remnant))
	local modifier = remnant:FindModifierByName("modifier_ember_fire_remnant_trinity_remnant")
	if modifier then modifier:SetArrived() end
	return false
end

modifier_ember_fire_remnant_trinity_remnant = class({})

function modifier_ember_fire_remnant_trinity_remnant:IsHidden() return true end
function modifier_ember_fire_remnant_trinity_remnant:IsPurgable() return false end

function modifier_ember_fire_remnant_trinity_remnant:OnCreated()
	if not IsServer() then return end
	self.parent = self:GetParent()
	self.caster = self:GetCaster()
	self.ability = self:GetAbility()
	table.insert(GetRemnantList(self.caster), self.parent)
	self:StartIntervalThink(1.0)
end

function modifier_ember_fire_remnant_trinity_remnant:SetArrived()
	if not IsServer() or self.arrived then return end
	self.arrived = true

	if self.parent.ember_trail_particle then
		ParticleManager:DestroyParticle(self.parent.ember_trail_particle, false)
		ParticleManager:ReleaseParticleIndex(self.parent.ember_trail_particle)
		self.parent.ember_trail_particle = nil
	end

	local particle = ParticleManager:CreateParticle(REMNANT_PARTICLE, PATTACH_CUSTOMORIGIN, self.parent)
	ParticleManager:SetParticleControl(particle, 0, self.parent:GetAbsOrigin())
	ParticleManager:SetParticleControlEnt(particle, 1, self.caster, PATTACH_ABSORIGIN_FOLLOW, nil, self.caster:GetAbsOrigin(), true)
	ParticleManager:SetParticleControl(particle, 2, Vector(RandomInt(23, 24), 0, 0))
	ParticleManager:SetParticleFoWProperties(particle, 0, -1, 450)
	self:AddParticle(particle, false, false, -1, false, false)
	self.parent:EmitSound("Hero_EmberSpirit.FireRemnant.Create")
end

function modifier_ember_fire_remnant_trinity_remnant:OnIntervalThink()
	if not self.caster:HasShard() then return end
	local damage = self.ability:GetSpecialValueFor("shard_damage_per_second")
	local radius = self.ability:GetSpecialValueFor("shard_radius")
	for _, enemy in pairs(FindUnitsInRadius(
		self.caster:GetTeamNumber(), self.parent:GetAbsOrigin(), nil, radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false
	)) do
		ApplyDamage({
			victim = enemy,
			attacker = self.caster,
			damage = damage,
			damage_type = DAMAGE_TYPE_MAGICAL,
			ability = self.ability,
		})
	end
end

function modifier_ember_fire_remnant_trinity_remnant:CheckState()
	return {
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_UNSELECTABLE] = true,
		[MODIFIER_STATE_OUT_OF_GAME] = true,
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
		[MODIFIER_STATE_ROOTED] = true,
		[MODIFIER_STATE_FORCED_FLYING_VISION] = true,
	}
end

function modifier_ember_fire_remnant_trinity_remnant:OnDestroy()
	if not IsServer() then return end
	if self.parent.ember_trail_particle then
		ParticleManager:DestroyParticle(self.parent.ember_trail_particle, false)
		ParticleManager:ReleaseParticleIndex(self.parent.ember_trail_particle)
		self.parent.ember_trail_particle = nil
	end

	RemoveFromRemnantList(self.caster, self.parent)
	local particle = ParticleManager:CreateParticle(HIT_PARTICLE, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(particle, 0, self.parent:GetAbsOrigin())
	ParticleManager:ReleaseParticleIndex(particle)

	local activate = self.caster:FindAbilityByName(ACTIVATE_ABILITY)
	if activate then activate:RefreshRemnants() end
	UTIL_Remove(self.parent)
end

ember_spirit_activate_fire_remnant = class({})

function ember_spirit_activate_fire_remnant:Precache(context)
	PrecacheRemnantResources(context)
end

function ember_spirit_activate_fire_remnant:GetManaCost(level)
	if self:GetCaster():HasScepter() then
		return self:GetSpecialValueFor("scepter_mana_cost")
	end
	return self.BaseClass.GetManaCost(self, level)
end

function ember_spirit_activate_fire_remnant:GetCastPoint()
	if self:GetCaster():HasScepter() then return 0 end
	return self.BaseClass.GetCastPoint(self)
end

function ember_spirit_activate_fire_remnant:OnOwnerSpawned()
	if IsServer() then self:RefreshRemnants() end
end

function ember_spirit_activate_fire_remnant:RefreshRemnants()
	if not IsServer() then return end
	local remnants = GetRemnantList(self:GetCaster())
	for index = #remnants, 1, -1 do
		if not IsValidHandle(remnants[index])
			or not remnants[index]:HasModifier("modifier_ember_fire_remnant_trinity_remnant") then
			table.remove(remnants, index)
		end
	end
	self:SetActivated(#remnants > 0 and not self.travelling)
end

function ember_spirit_activate_fire_remnant:BuildRoute(cursor_position)
	local remnants = GetRemnantList(self:GetCaster())
	if #remnants == 0 then return {} end

	local final_remnant
	local closest_distance = math.huge
	for _, remnant in pairs(remnants) do
		local distance = (remnant:GetAbsOrigin() - cursor_position):Length2D()
		if distance < closest_distance then
			closest_distance = distance
			final_remnant = remnant
		end
	end

	local route = {}
	for _, remnant in pairs(remnants) do
		if remnant ~= final_remnant then table.insert(route, remnant) end
	end
	table.sort(route, function(left, right)
		return (left:GetAbsOrigin() - final_remnant:GetAbsOrigin()):Length2D()
			> (right:GetAbsOrigin() - final_remnant:GetAbsOrigin()):Length2D()
	end)
	table.insert(route, final_remnant)
	return route
end

function ember_spirit_activate_fire_remnant:OnSpellStart()
	if not IsServer() or self.travelling then return end
	self:RefreshRemnants()
	self.route = self:BuildRoute(self:GetCursorPosition())
	if #self.route == 0 then return end

	self.travelling = true
	self.route_index = 0
	self.leg_serial = 0
	self.last_location = self:GetCaster():GetAbsOrigin()
	self:SetActivated(false)
	self:GetCaster():AddNewModifier(
		self:GetCaster(), self, "modifier_ember_activate_fire_remnant_trinity_travel", {}
	)
	self:StartNextLeg()
end

function ember_spirit_activate_fire_remnant:StartNextLeg()
	if not IsServer() then return end
	self.route_index = self.route_index + 1
	local remnant = self.route[self.route_index]
	if not IsValidHandle(remnant)
		or not remnant:HasModifier("modifier_ember_fire_remnant_trinity_remnant") then
		if self.route_index <= #self.route then
			self:StartNextLeg()
		else
			self:FinishTravel()
		end
		return
	end

	local caster = self:GetCaster()
	local distance = (remnant:GetAbsOrigin() - caster:GetAbsOrigin()):Length2D()
	local speed = math.max(self:GetSpecialValueFor("speed"), distance / 0.4)
	self.current_remnant = remnant
	self.last_location = caster:GetAbsOrigin()
	self.leg_serial = self.leg_serial + 1
	remnant.targets_hit = {}

	ProjectileManager:CreateTrackingProjectile({
		Target = remnant,
		Source = caster,
		Ability = self,
		iMoveSpeed = speed,
		vSourceLoc = caster:GetAbsOrigin(),
		flExpireTime = GameRules:GetGameTime() + 10,
		bDodgeable = false,
		bProvidesVision = false,
		bReplaceExisting = true,
		ExtraData = { leg = self.leg_serial },
	})
end

function ember_spirit_activate_fire_remnant:GetDamage()
	return math.max(0,
		self:GetSpecialValueFor("damage")
		+ GetMindPower(self:GetCaster()) * self:GetSpecialValueFor("mind_power_multiplier")
	)
end

function ember_spirit_activate_fire_remnant:DamageTarget(target, remnant)
	if not IsValidHandle(target) or not IsValidHandle(remnant) then return end
	remnant.targets_hit = remnant.targets_hit or {}
	if remnant.targets_hit[target:entindex()] then return end
	remnant.targets_hit[target:entindex()] = true
	ApplyDamage({
		victim = target,
		attacker = self:GetCaster(),
		damage = self:GetDamage(),
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability = self,
	})
end

function ember_spirit_activate_fire_remnant:OnProjectileThink_ExtraData(location, data)
	if not self.travelling or tonumber(data.leg) ~= self.leg_serial then return end
	local caster = self:GetCaster()
	local remnant = self.current_remnant
	if not IsValidHandle(remnant) then return end

	location = GetGroundPosition(location, caster)
	GridNav:DestroyTreesAroundPoint(location, 200, false)
	for _, enemy in pairs(FindUnitsInLine(
		caster:GetTeamNumber(), self.last_location, location, nil,
		self:GetSpecialValueFor("radius") * 0.5,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE
	)) do
		self:DamageTarget(enemy, remnant)
	end

	caster:SetAbsOrigin(location)
	self.last_location = location
end

function ember_spirit_activate_fire_remnant:OnProjectileHit_ExtraData(_, location, data)
	if not self.travelling or tonumber(data.leg) ~= self.leg_serial then return true end
	local remnant = self.current_remnant
	if IsValidHandle(remnant) then
		location = remnant:GetAbsOrigin()
		self:ExplodeRemnant(remnant)
	end

	self.last_location = GetGroundPosition(location, nil)
	self:GetCaster():SetAbsOrigin(self.last_location)
	if self.route_index < #self.route then
		self:StartNextLeg()
	else
		self:FinishTravel()
	end
	return true
end

function ember_spirit_activate_fire_remnant:ExplodeRemnant(remnant)
	if not IsValidHandle(remnant) or remnant.ember_exploded then return end
	remnant.ember_exploded = true
	local caster = self:GetCaster()
	local point = remnant:GetAbsOrigin()
	for _, enemy in pairs(FindUnitsInRadius(
		caster:GetTeamNumber(), point, nil, self:GetSpecialValueFor("radius"),
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false
	)) do
		self:DamageTarget(enemy, remnant)
	end
	remnant:EmitSound("Hero_EmberSpirit.FireRemnant.Explode")
	remnant:RemoveModifierByName("modifier_ember_fire_remnant_trinity_remnant")
end

function ember_spirit_activate_fire_remnant:FinishTravel()
	if not IsServer() then return end
	local caster = self:GetCaster()
	self.travelling = false
	self.current_remnant = nil
	self.route = nil
	if IsValidHandle(caster) then
		caster:RemoveModifierByName("modifier_ember_activate_fire_remnant_trinity_travel")
		FindClearSpaceForUnit(caster, self.last_location or caster:GetAbsOrigin(), false)
	end
	self:RefreshRemnants()
end

modifier_ember_activate_fire_remnant_trinity_travel = class({})

function modifier_ember_activate_fire_remnant_trinity_travel:IsHidden() return true end
function modifier_ember_activate_fire_remnant_trinity_travel:IsPurgable() return false end

function modifier_ember_activate_fire_remnant_trinity_travel:OnCreated()
	if not IsServer() then return end
	self.parent = self:GetParent()
	self.parent:AddNoDraw()
	self.parent:EmitSound("Hero_EmberSpirit.FireRemnant.Activate")
	local particle = ParticleManager:CreateParticle(DASH_PARTICLE, PATTACH_ABSORIGIN_FOLLOW, self.parent)
	self:AddParticle(particle, false, false, -1, false, false)
end

function modifier_ember_activate_fire_remnant_trinity_travel:OnDestroy()
	if not IsServer() then return end
	self.parent:RemoveNoDraw()
	self.parent:StopSound("Hero_EmberSpirit.FireRemnant.Activate")
	self.parent:EmitSound("Hero_EmberSpirit.FireRemnant.Stop")
end

function modifier_ember_activate_fire_remnant_trinity_travel:CheckState()
	return {
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_OUT_OF_GAME] = true,
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
		[MODIFIER_STATE_DISARMED] = true,
		[MODIFIER_STATE_ROOTED] = true,
	}
end

function modifier_ember_activate_fire_remnant_trinity_travel:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_DISABLE_TURNING,
		MODIFIER_PROPERTY_IGNORE_CAST_ANGLE,
	}
end

function modifier_ember_activate_fire_remnant_trinity_travel:GetModifierDisableTurning() return 1 end
function modifier_ember_activate_fire_remnant_trinity_travel:GetModifierIgnoreCastAngle() return 1 end
