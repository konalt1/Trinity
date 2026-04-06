require("modifiers/modifier_generic_arc_lua")

LinkLuaModifier("modifier_techies_suicide_custom", "abilities/techies/techies_suicide_custom", 0)
LinkLuaModifier("modifier_generic_arc_lua", "modifiers/modifier_generic_arc_lua", 0)

techies_suicide_custom = class({})

function techies_suicide_custom:Precache(context)
	if self:GetCaster() and self:GetCaster():IsIllusion() then
		return
	end
	PrecacheResource("particle", "particles/units/heroes/hero_techies/techies_blast_off_trail.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_techies/techies_suicide.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_techies/techies_blast_off.vpcf", context)
end

function techies_suicide_custom:GetAOERadius()
	return self:GetSpecialValueFor("radius")
end

function techies_suicide_custom:GetDamage()
	local caster = self:GetCaster()
	local base_damage = self:GetSpecialValueFor("damage")
	local mind_power_multiplier = self:GetSpecialValueFor("mind_power_multiplier")
	local mind_power = 0

	if GetHeroMindPower then
		mind_power = GetHeroMindPower(caster) or 0
	elseif caster and caster.GetIntellect then
		mind_power = caster:GetIntellect(false) or 0
	end

	return math.max(0, base_damage + (mind_power * mind_power_multiplier))
end

function techies_suicide_custom:OnSpellStart()
	if not IsServer() then
		return
	end
	local caster = self:GetCaster()
	local direction = self:GetCursorPosition() - caster:GetOrigin()
	direction.z = 0
	local length = direction:Length2D()
	direction = direction:Normalized()

	caster:AddNewModifier(caster, self, "modifier_techies_suicide_custom", {})

	local arc = caster:AddNewModifier(caster, self, "modifier_generic_arc_lua", {
		dir_x = direction.x,
		dir_y = direction.y,
		duration = 1.1,
		distance = length,
		height = 325,
		fix_end = false,
		isStun = 0,
		isForward = 1,
		activity = ACT_DOTA_OVERRIDE_ABILITY_2,
	})

	caster:EmitSound("Hero_Techies.BlastOff.Cast")

	arc:SetEndCallback(function(interrupted)
		local mod = caster:FindModifierByName("modifier_techies_suicide_custom")
		if mod then
			mod.interrupt = interrupted
			mod:Destroy()
		end
		caster:FadeGesture(ACT_DOTA_OVERRIDE_ABILITY_2)
	end)
end

modifier_techies_suicide_custom = class({})

function modifier_techies_suicide_custom:IsHidden()
	return true
end

function modifier_techies_suicide_custom:IsPurgable()
	return false
end

function modifier_techies_suicide_custom:IsPurgeException()
	return false
end

function modifier_techies_suicide_custom:RemoveOnDeath()
	return false
end

function modifier_techies_suicide_custom:OnCreated(kv)
	if not IsServer() then
		return
	end
	local nFXIndex = ParticleManager:CreateParticle("particles/units/heroes/hero_techies/techies_blast_off_trail.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
	ParticleManager:SetParticleControlEnt(nFXIndex, 1, self:GetParent(), PATTACH_POINT_FOLLOW, "attach_hitloc", self:GetParent():GetOrigin(), true)
	self:AddParticle(nFXIndex, false, false, -1, false, false)
end

function modifier_techies_suicide_custom:OnDestroy()
	if not IsServer() then
		return
	end
	if self.interrupt then
		return
	end

	local ability = self:GetAbility()
	local caster = self:GetCaster()
	local radius = ability:GetSpecialValueFor("radius")
	local damage = ability:GetDamage()
	local duration = ability:GetSpecialValueFor("stun_duration")
	local hp_cost = caster:GetHealth() / 100 * ability:GetSpecialValueFor("hp_cost")

	caster:EmitSound("Hero_Techies.Suicide")

	local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_techies/techies_blast_off.vpcf", PATTACH_WORLDORIGIN, self:GetParent())
	ParticleManager:SetParticleControl(particle, 0, self:GetParent():GetAbsOrigin())
	ParticleManager:ReleaseParticleIndex(particle)

	GridNav:DestroyTreesAroundPoint(caster:GetAbsOrigin(), radius, true)

	local units = FindUnitsInRadius(
		caster:GetTeamNumber(),
		caster:GetAbsOrigin(),
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
		FIND_ANY_ORDER,
		false
	)

	for _, unit in ipairs(units) do
		ApplyDamage({
			victim = unit,
			attacker = caster,
			ability = ability,
			damage = damage,
			damage_type = DAMAGE_TYPE_MAGICAL,
		})
		unit:AddNewModifier(caster, ability, "modifier_stunned", { duration = duration * (1 - unit:GetStatusResistance()) })
	end

	ApplyDamage({
		victim = caster,
		attacker = caster,
		ability = ability,
		damage = hp_cost,
		damage_type = DAMAGE_TYPE_PURE,
		damage_flags = DOTA_DAMAGE_FLAG_HPLOSS + DOTA_DAMAGE_FLAG_REFLECTION + DOTA_DAMAGE_FLAG_NO_DAMAGE_MULTIPLIERS + DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION,
	})
end

function modifier_techies_suicide_custom:CheckState()
	return {
		[MODIFIER_STATE_ROOTED] = true,
		[MODIFIER_STATE_DISARMED] = true,
	}
end

function modifier_techies_suicide_custom:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_IGNORE_CAST_ANGLE,
	}
end

function modifier_techies_suicide_custom:GetModifierIgnoreCastAngle()
	return 1
end
