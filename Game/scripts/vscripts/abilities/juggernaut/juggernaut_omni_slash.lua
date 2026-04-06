LinkLuaModifier("modifier_juggernaut_omni_slash", "abilities/juggernaut/juggernaut_omni_slash", LUA_MODIFIER_MOTION_NONE)

juggernaut_omni_slash = class({})

local SLASH_INVALID_BLUR_MODIFIERS = {
	"modifier_phantom_assassin_blur_custom_active",
	"modifier_phantom_assassin_blur_active",
}

function juggernaut_omni_slash:IsSlashTargetValid(caster, unit)
	if not unit or not unit:IsAlive() or not IsValidEntity(unit) then
		return false
	end
	if not caster:CanEntityBeSeenByMyTeam(unit) then
		return false
	end
	for _, mod in ipairs(SLASH_INVALID_BLUR_MODIFIERS) do
		if unit:HasModifier(mod) then
			return false
		end
	end
	return true
end

function juggernaut_omni_slash:SyncLevelWithSwiftSlash()
	if not IsServer() then return end
	local caster = self:GetCaster()
	if not caster or caster:IsNull() then return end
	local swift = caster:FindAbilityByName("juggernaut_swift_slash_lua")
	if swift and not swift:IsNull() then
		local sl = swift:GetLevel()
		if self:GetLevel() ~= sl then
			self:SetLevel(sl)
		end
	end
end

function juggernaut_omni_slash:OnAbilityPhaseStart()
	self:SyncLevelWithSwiftSlash()
end

function juggernaut_omni_slash:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	if not target then return end

	self:SyncLevelWithSwiftSlash()
	if self:GetLevel() == 0 then return end

	local duration = self:GetSpecialValueFor("duration")
	local damage = self:GetSpecialValueFor("damage")
	local base_delay = self:GetSpecialValueFor("slash_delay") or 0.2
	local attack_speed = caster:GetAttackSpeed(true)
	local delay_multiplier = 1.0
	local jump_delay = (base_delay * delay_multiplier) / attack_speed

	caster:AddNewModifier(caster, self, "modifier_juggernaut_omni_slash", { duration = duration })

	self:PerformSlash(caster, target, {
		damage = damage,
		duration = duration,
		current_slashes = 0,
		jump_delay = jump_delay,
		start_time = GameRules:GetGameTime(),
	})

	EmitSoundOn("Hero_Juggernaut.OmniSlash", caster)
end

function juggernaut_omni_slash:PerformSlash(caster, target, data)
	if not target or not target:IsAlive() then return end

	if not self:IsSlashTargetValid(caster, target) then
		local elapsed_time = GameRules:GetGameTime() - data.start_time
		if elapsed_time < data.duration and caster and IsValidEntity(caster) and caster:IsAlive() then
			Timers:CreateTimer(data.jump_delay, function()
				if caster and IsValidEntity(caster) and caster:IsAlive() then
					local next_target = self:FindNextTarget(caster, target, data)
					self:PerformSlash(caster, next_target, data)
				end
			end)
		end
		return
	end

	data.current_slashes = data.current_slashes + 1

	FindClearSpaceForUnit(caster, target:GetAbsOrigin() + RandomVector(100), false)
	caster:SetForwardVector((target:GetAbsOrigin() - caster:GetAbsOrigin()):Normalized())

	caster:PerformAttack(target, true, true, true, false, false, false, true)

	local bonus_damage = data.damage
	ApplyDamage({
		victim = target,
		attacker = caster,
		damage = bonus_damage,
		damage_type = DAMAGE_TYPE_PHYSICAL,
		ability = self,
	})

	local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_juggernaut/juggernaut_omni_slash_tgt.vpcf", PATTACH_ABSORIGIN_FOLLOW, target)
	ParticleManager:SetParticleControlEnt(particle, 0, target, PATTACH_ABSORIGIN_FOLLOW, nil, target:GetAbsOrigin(), true)
	ParticleManager:ReleaseParticleIndex(particle)

	EmitSoundOn("Hero_Juggernaut.OmniSlash.Damage", target)

	local elapsed_time = GameRules:GetGameTime() - data.start_time
	if elapsed_time < data.duration then
		Timers:CreateTimer(data.jump_delay, function()
			if caster and IsValidEntity(caster) and caster:IsAlive() then
				local next_target = self:FindNextTarget(caster, target, data)
				self:PerformSlash(caster, next_target, data)
			end
		end)
	end
end

function juggernaut_omni_slash:FindNextTarget(caster, current_target, data)
	local search_radius = self:GetSpecialValueFor("slash_radius") or 425

	local enemies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		current_target:GetAbsOrigin(),
		nil,
		search_radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
		FIND_ANY_ORDER,
		false
	)

	local heroes = {}
	local creeps = {}

	for _, enemy in pairs(enemies) do
		if enemy:IsAlive() and self:IsSlashTargetValid(caster, enemy) then
			if enemy:IsConsideredHero() then
				table.insert(heroes, enemy)
			else
				table.insert(creeps, enemy)
			end
		end
	end

	local roll = RandomFloat(0, 100)
	local next_target = nil
	if self:IsSlashTargetValid(caster, current_target) then
		next_target = current_target
	end

	if roll <= 60 and #heroes > 0 then
		next_target = heroes[RandomInt(1, #heroes)]
	elseif roll <= 70 and #creeps > 0 then
		next_target = creeps[RandomInt(1, #creeps)]
	elseif roll > 70 and not next_target then
		if #heroes > 0 then
			next_target = heroes[RandomInt(1, #heroes)]
		elseif #creeps > 0 then
			next_target = creeps[RandomInt(1, #creeps)]
		end
	end

	return next_target
end

--------------------------------------------------------------------------------
modifier_juggernaut_omni_slash = class({})

function modifier_juggernaut_omni_slash:IsHidden()
	return false
end

function modifier_juggernaut_omni_slash:IsDebuff()
	return false
end

function modifier_juggernaut_omni_slash:IsPurgable()
	return false
end

function modifier_juggernaut_omni_slash:DestroyOnExpire()
	return true
end

function modifier_juggernaut_omni_slash:CheckState()
	return {
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
	}
end

function modifier_juggernaut_omni_slash:GetEffectName()
	return "particles/units/heroes/hero_juggernaut/juggernaut_omni_slash_blur.vpcf"
end

function modifier_juggernaut_omni_slash:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_juggernaut_omni_slash:GetTexture()
	return "juggernaut_omni_slash"
end
