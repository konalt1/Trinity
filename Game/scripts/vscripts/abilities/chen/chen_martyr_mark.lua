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

local function IsChenTamedCreep(unit, caster)
	if not unit or unit:IsNull() or not unit:IsAlive() then
		return false
	end
	if not unit:IsCreep() then
		return false
	end
	if unit:GetTeamNumber() ~= caster:GetTeamNumber() then
		return false
	end
	if unit:GetPlayerOwnerID() ~= caster:GetPlayerOwnerID() then
		return false
	end
	local owner = unit:GetOwnerEntity()
	if owner ~= caster then
		return false
	end
	return true
end

function chen_martyr_mark:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	if not target or target:IsNull() or not target:IsAlive() then
		return
	end

	if target:TriggerSpellAbsorb(self) then
		return
	end

	local damage = self:GetSpecialValueFor("damage")
	local duration = self:GetDuration()
	local radius = self:GetSpecialValueFor("creep_search_radius")
	local creep_haste_duration = self:GetSpecialValueFor("chen_creep_haste_duration")

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

	-- Deal damage
	ApplyDamage({
		victim = target,
		attacker = caster,
		damage = damage,
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability = self,
	})

	local allies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		caster:GetAbsOrigin(),
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	target:AddNewModifier(caster, self, "modifier_chen_martyr_mark_debuff", { duration = duration })

	for _, unit in pairs(allies) do
		if unit and not unit:IsNull() and unit:IsAlive() then
			unit:AddNewModifier(caster, self, "modifier_chen_martyr_mark_ally", { duration = duration })
			if IsChenTamedCreep(unit, caster) then
				unit:AddNewModifier(caster, self, "modifier_chen_martyr_mark_creep", {
					duration = duration,
					target_entindex = target:entindex(),
				})
				if creep_haste_duration > 0 then
					unit:AddNewModifier(caster, self, "modifier_chen_martyr_mark_creep_haste", {
						duration = creep_haste_duration,
					})
				end
			end
		end
	end

	EmitSoundOn("Hero_Chen.PenitenceCast", target)
end
