LinkLuaModifier("modifier_chen_martyr_mark_debuff", "abilities/chen/modifier_chen_martyr_mark_debuff", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_martyr_mark_creep", "abilities/chen/modifier_chen_martyr_mark_creep", LUA_MODIFIER_MOTION_NONE)

chen_martyr_mark = class({})

local function GetTalentValue(hero, talentName, valueName, fallback)
	if not hero or hero:IsNull() then
		return fallback or 0
	end

	local talent = hero:FindAbilityByName(talentName)
	if not talent or talent:IsNull() or talent:GetLevel() <= 0 then
		return fallback or 0
	end

	local value = 0
	if valueName then
		value = talent:GetSpecialValueFor(valueName)
	end
	if value == 0 then
		value = talent:GetSpecialValueFor("value")
	end

	return value or fallback or 0
end

local function IsValidAllyForPenitence(unit, caster)
	if not unit or unit:IsNull() or not unit:IsAlive() then
		return false
	end
	if unit:GetTeamNumber() ~= caster:GetTeamNumber() then
		return false
	end
	if unit:IsBuilding() or unit:IsAncient() then
		return false
	end
	if (unit:GetUnitName() or "") == "npc_chen_barrack" then
		return false
	end

	return unit:IsRealHero() or unit:IsCreep()
end

local function ShouldForceAttack(unit)
	return unit and not unit:IsNull() and unit:IsCreep() and not unit:IsHero() and not unit:IsBuilding() and not unit:IsAncient()
end

function chen_martyr_mark:GetPenitenceDuration()
	local duration = self:GetSpecialValueFor("duration")
	if duration <= 0 and self.GetDuration then
		duration = self:GetDuration()
	end
	if duration <= 0 then
		duration = 5
	end
	return duration
end

function chen_martyr_mark:OnSpellStart()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	if not caster or caster:IsNull() or not target or target:IsNull() or not target:IsAlive() then
		return
	end

	if target:GetTeamNumber() == caster:GetTeamNumber() then
		return
	end

	if target.TriggerSpellAbsorb and target:TriggerSpellAbsorb(self) then
		return
	end

	local duration = self:GetPenitenceDuration()
	local damage = self:GetSpecialValueFor("damage") + GetTalentValue(caster, "special_bonus_unique_custom_chen_1", "bonus_damage", 0)
	local slow_ms_pct = self:GetSpecialValueFor("slow_ms_pct")
	local attack_speed = self:GetSpecialValueFor("attack_speed")
	if attack_speed == 0 then
		attack_speed = self:GetSpecialValueFor("creep_bonus_as")
	end
	attack_speed = attack_speed + GetTalentValue(caster, "special_bonus_unique_custom_chen_2", "attack_speed", 0)

	local radius = self:GetSpecialValueFor("radius")
	if radius == 0 then
		radius = self:GetSpecialValueFor("creep_search_radius")
	end
	if radius == 0 then
		radius = 1200
	end

	ApplyDamage({
		victim = target,
		attacker = caster,
		damage = damage,
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability = self,
	})

	if target:IsNull() or not target:IsAlive() then
		EmitSoundOn("Hero_Chen.PenitenceCast", caster)
		return
	end

	target:AddNewModifier(caster, self, "modifier_chen_martyr_mark_debuff", {
		duration = duration,
		slow_ms_pct = slow_ms_pct,
	})

	local castParticle = ParticleManager:CreateParticle("particles/units/heroes/hero_enchantress/enchantress_enchant_cast.vpcf", PATTACH_ABSORIGIN_FOLLOW, target)
	ParticleManager:SetParticleControlEnt(castParticle, 0, target, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), true)
	ParticleManager:ReleaseParticleIndex(castParticle)

	local allies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		target:GetAbsOrigin(),
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	for _, unit in pairs(allies) do
		if IsValidAllyForPenitence(unit, caster) then
			unit:AddNewModifier(caster, self, "modifier_chen_martyr_mark_creep", {
				duration = duration,
				attack_speed = attack_speed,
				attack_refresh_interval = self:GetSpecialValueFor("attack_refresh_interval"),
				target_entindex = target:entindex(),
				force_attack = ShouldForceAttack(unit) and 1 or 0,
			})
		end
	end

	EmitSoundOn("Hero_Chen.PenitenceCast", caster)
end
