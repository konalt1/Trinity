LinkLuaModifier(
	"modifier_chen_martyr_mark_debuff",
	"abilities/chen/modifier_chen_martyr_mark_debuff",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_chen_martyr_mark_creep",
	"abilities/chen/modifier_chen_martyr_mark_creep",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_chen_martyr_mark_ally",
	"abilities/chen/modifier_chen_martyr_mark_ally",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_chen_martyr_mark_creep_haste",
	"abilities/chen/modifier_chen_martyr_mark_creep_haste",
	LUA_MODIFIER_MOTION_NONE
)

chen_martyr_mark = class({})

local MARTYR_MARK_PROJECTILE = "particles/units/heroes/hero_chen/chen_martyrdom_proj_friendly.vpcf"
local MARTYR_MARK_PROJECTILE_SPEED = 1200

local function IsChenSubordinateCreep(unit, caster)
	if not unit or unit:IsNull() or not unit:IsAlive() then
		return false
	end
	if unit:IsHero() or unit:IsBuilding() then
		return false
	end
	if unit:GetTeamNumber() ~= caster:GetTeamNumber() then
		return false
	end

	local casterEntindex = caster:entindex()
	if unit.chen_owner_entindex == casterEntindex then
		return true
	end

	if unit:GetOwnerEntity() == caster then
		return true
	end

	return false
end

local function ApplyMartyrMarkEffects(ability, caster, target)
	local damage = ability:GetSpecialValueFor("damage")
	local duration = ability:GetDuration()
	local radius = ability:GetSpecialValueFor("creep_search_radius")
	local creep_haste_duration = ability:GetSpecialValueFor("chen_creep_haste_duration")

	ApplyDamage({
		victim = target,
		attacker = caster,
		damage = damage,
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability = ability,
	})

	local allies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		caster:GetAbsOrigin(),
		nil,
		FIND_UNITS_EVERYWHERE,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	local subordinateCreeps = FindUnitsInRadius(
		caster:GetTeamNumber(),
		target:GetAbsOrigin(),
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY,
		DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	target:AddNewModifier(caster, ability, "modifier_chen_martyr_mark_debuff", { duration = duration })

	for _, unit in pairs(allies) do
		if unit and not unit:IsNull() and unit:IsAlive() then
			unit:AddNewModifier(caster, ability, "modifier_chen_martyr_mark_ally", { duration = duration })
		end
	end

	for _, unit in pairs(subordinateCreeps) do
		if IsChenSubordinateCreep(unit, caster) then
			unit:AddNewModifier(caster, ability, "modifier_chen_martyr_mark_creep", {
				duration = duration,
				target_entindex = target:entindex(),
			})
			if creep_haste_duration > 0 then
				unit:AddNewModifier(caster, ability, "modifier_chen_martyr_mark_creep_haste", {
					duration = creep_haste_duration,
				})
			end
		end
	end

	EmitSoundOn("Hero_Chen.PenitenceCast", target)
end

function chen_martyr_mark:OnSpellStart()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	if not target or target:IsNull() or not target:IsAlive() then
		return
	end

	if target:TriggerSpellAbsorb(self) then
		return
	end

	ProjectileManager:CreateTrackingProjectile({
		EffectName = MARTYR_MARK_PROJECTILE,
		Ability = self,
		Source = caster,
		vSourceLoc = caster:GetAbsOrigin(),
		Target = target,
		iMoveSpeed = MARTYR_MARK_PROJECTILE_SPEED,
		bDodgeable = false,
		bVisibleToEnemies = true,
		bProvidesVision = false,
	})
end

function chen_martyr_mark:OnProjectileHit(target, location)
	if not IsServer() then
		return true
	end

	local caster = self:GetCaster()
	if not caster or caster:IsNull() then
		return true
	end

	if not target or target:IsNull() or not target:IsAlive() then
		return true
	end

	ApplyMartyrMarkEffects(self, caster, target)
	return true
end
