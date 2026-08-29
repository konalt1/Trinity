LinkLuaModifier(
	"modifier_void_spirit_astral_step_trinity_mark",
	"abilities/void_spirit/void_spirit_astral_step_trinity",
	LUA_MODIFIER_MOTION_NONE
)

local PARTICLE_STEP = "particles/units/heroes/hero_void_spirit/astral_step/void_spirit_astral_step.vpcf"
local PARTICLE_IMPACT = "particles/units/heroes/hero_void_spirit/astral_step/void_spirit_astral_step_impact.vpcf"
local PARTICLE_DEBUFF = "particles/units/heroes/hero_void_spirit/astral_step/void_spirit_astral_step_debuff.vpcf"
local PARTICLE_POP = "particles/units/heroes/hero_void_spirit/astral_step/void_spirit_astral_step_dmg.vpcf"
local PARTICLE_STATUS = "particles/status_fx/status_effect_void_spirit_astral_step_debuff.vpcf"
local SOUND_FILE = "soundevents/game_sounds_heroes/game_sounds_void_spirit.vsndevts"

local function IsValidHandle(handle)
	return handle and (not handle.IsNull or not handle:IsNull())
end

local function GetMindPower(unit)
	if GetHeroMindPower then
		return GetHeroMindPower(unit) or 0
	end
	return 0
end

local function FindEnemiesOnPath(caster, start_pos, end_pos, radius)
	if FindUnitsInLine then
		return FindUnitsInLine(
			caster:GetTeamNumber(),
			start_pos,
			end_pos,
			nil,
			radius,
			DOTA_UNIT_TARGET_TEAM_ENEMY,
			DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
			DOTA_UNIT_TARGET_FLAG_NONE
		)
	end

	return FindUnitsInRadius(
		caster:GetTeamNumber(),
		start_pos + (end_pos - start_pos) * 0.5,
		nil,
		(end_pos - start_pos):Length2D() * 0.5 + radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)
end

void_spirit_astral_step_trinity = class({})

function void_spirit_astral_step_trinity:Precache(context)
	if self:GetCaster() and self:GetCaster():IsIllusion() then
		return
	end

	PrecacheResource("soundfile", SOUND_FILE, context)
	PrecacheResource("particle", PARTICLE_STEP, context)
	PrecacheResource("particle", PARTICLE_IMPACT, context)
	PrecacheResource("particle", PARTICLE_DEBUFF, context)
	PrecacheResource("particle", PARTICLE_POP, context)
	PrecacheResource("particle", PARTICLE_STATUS, context)
end

function void_spirit_astral_step_trinity:GetCastRange(_, _)
	return self:GetSpecialValueFor("max_travel_distance")
end

function void_spirit_astral_step_trinity:GetAOERadius()
	return self:GetSpecialValueFor("radius")
end

function void_spirit_astral_step_trinity:GetPopDamage()
	local caster = self:GetCaster()
	return math.max(
		0,
		self:GetSpecialValueFor("pop_damage")
			+ GetMindPower(caster) * self:GetSpecialValueFor("mind_power_multiplier")
	)
end

function void_spirit_astral_step_trinity:OnSpellStart()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	local origin = caster:GetAbsOrigin()
	local cursor = self:GetCursorPosition()
	local offset = cursor - origin
	offset.z = 0

	local direction
	if offset:Length2D() < 0.01 then
		direction = caster:GetForwardVector()
	else
		direction = offset:Normalized()
	end

	local distance = offset:Length2D()
	local min_distance = self:GetSpecialValueFor("min_travel_distance")
	local max_distance = self:GetSpecialValueFor("max_travel_distance")
	distance = math.max(min_distance, math.min(max_distance, distance))
	if offset:Length2D() < 0.01 then
		distance = min_distance
	end

	local destination = GetGroundPosition(origin + direction * distance, caster)
	local radius = self:GetSpecialValueFor("radius")
	if GetHeroBonusSpellAoE then
		radius = radius + GetHeroBonusSpellAoE(caster)
	end

	local step_fx = ParticleManager:CreateParticle(PARTICLE_STEP, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(step_fx, 0, origin)
	ParticleManager:SetParticleControl(step_fx, 1, destination)
	ParticleManager:ReleaseParticleIndex(step_fx)

	caster:EmitSound("Hero_VoidSpirit.AstralStep.Start")
	ProjectileManager:ProjectileDodge(caster)
	caster:SetAbsOrigin(destination)
	FindClearSpaceForUnit(caster, destination, false)
	caster:EmitSound("Hero_VoidSpirit.AstralStep.End")

	local delay = self:GetSpecialValueFor("pop_damage_delay")
	local enemies = FindEnemiesOnPath(caster, origin, destination, radius)
	for _, enemy in pairs(enemies) do
		if IsValidHandle(enemy) and enemy:IsAlive() and not enemy:IsMagicImmune() then
			local impact = ParticleManager:CreateParticle(PARTICLE_IMPACT, PATTACH_ABSORIGIN_FOLLOW, enemy)
			ParticleManager:ReleaseParticleIndex(impact)
			enemy:AddNewModifier(caster, self, "modifier_void_spirit_astral_step_trinity_mark", {
				duration = delay,
			})
		end
	end
end

modifier_void_spirit_astral_step_trinity_mark = class({})

function modifier_void_spirit_astral_step_trinity_mark:IsHidden()
	return false
end

function modifier_void_spirit_astral_step_trinity_mark:IsDebuff()
	return true
end

function modifier_void_spirit_astral_step_trinity_mark:IsPurgable()
	return true
end

function modifier_void_spirit_astral_step_trinity_mark:GetAttributes()
	return MODIFIER_ATTRIBUTE_MULTIPLE
end

function modifier_void_spirit_astral_step_trinity_mark:GetTexture()
	return "void_spirit_astral_step"
end

function modifier_void_spirit_astral_step_trinity_mark:GetEffectName()
	return PARTICLE_DEBUFF
end

function modifier_void_spirit_astral_step_trinity_mark:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_void_spirit_astral_step_trinity_mark:GetStatusEffectName()
	return PARTICLE_STATUS
end

function modifier_void_spirit_astral_step_trinity_mark:StatusEffectPriority()
	return MODIFIER_PRIORITY_HIGH
end

function modifier_void_spirit_astral_step_trinity_mark:OnCreated()
	self.slow = self:GetAbility() and self:GetAbility():GetSpecialValueFor("movement_slow_pct") or 0
end

function modifier_void_spirit_astral_step_trinity_mark:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
	}
end

function modifier_void_spirit_astral_step_trinity_mark:GetModifierMoveSpeedBonus_Percentage()
	return -self.slow
end

function modifier_void_spirit_astral_step_trinity_mark:OnDestroy()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	local caster = self:GetCaster()
	local ability = self:GetAbility()
	if not IsValidHandle(parent) or not IsValidHandle(caster) or not ability or ability:IsNull() then
		return
	end
	if not parent:IsAlive() then
		return
	end

	local pop = ParticleManager:CreateParticle(PARTICLE_POP, PATTACH_ABSORIGIN_FOLLOW, parent)
	ParticleManager:ReleaseParticleIndex(pop)
	parent:EmitSound("Hero_VoidSpirit.AstralStep.MarkExplosion")

	ApplyDamage({
		victim = parent,
		attacker = caster,
		damage = ability:GetPopDamage(),
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability = ability,
	})
end
