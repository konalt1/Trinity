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

chen_martyr_mark = class({})

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
		DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	target:AddNewModifier(caster, self, "modifier_chen_martyr_mark_debuff", { duration = duration })

	for _, unit in pairs(allies) do
		if IsChenTamedCreep(unit, caster) then
			unit:AddNewModifier(caster, self, "modifier_chen_martyr_mark_creep", {
				duration = duration,
				target_entindex = target:entindex(),
			})
		end
	end

	EmitSoundOn("Hero_Chen.PenitenceCast", target)
end
