juggernaut_swift_slash_lua = class({})
LinkLuaModifier( "modifier_juggernaut_swift_slash_lua", "abilities/juggernaut/juggernaut_swift_slash_lua/modifier_juggernaut_swift_slash_lua", LUA_MODIFIER_MOTION_NONE )

--- Phantom Assassin (и ваниль): активный Blur делает цель невалидной для ударов — как в доте, омни не цепляется.
local SLASH_INVALID_BLUR_MODIFIERS = {
	"modifier_phantom_assassin_blur_custom_active",
	"modifier_phantom_assassin_blur_active",
}

--- Цель подходит, только если команда кастера её видит (туман/инвиз) и она не в активном Blur.
function juggernaut_swift_slash_lua:IsSlashTargetValid(caster, unit)
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

function juggernaut_swift_slash_lua:OnUpgrade()
	if not IsServer() then return end
	local caster = self:GetCaster()
	if not caster or caster:IsNull() or not caster:IsRealHero() then return end
	local omni = caster:FindAbilityByName("juggernaut_omni_slash")
	if omni and not omni:IsNull() then
		omni:SyncLevelWithSwiftSlash()
	end
end

--------------------------------------------------------------------------------
-- Ability Start
function juggernaut_swift_slash_lua:OnSpellStart()
	-- unit identifier
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()

	if not target then return end

	-- load data
	local duration = self:GetSpecialValueFor("duration")
	local damage = self:GetSpecialValueFor("damage")
	local base_delay = self:GetSpecialValueFor("slash_delay") or 0.2
	local max_targets = self:GetSpecialValueFor("max_targets") or 3
	
	-- use actual attack speed from the game
	local attack_speed = caster:GetAttackSpeed(true)
	local delay_multiplier = 1.0 -- increase this to make slashes slower
	local jump_delay = (base_delay * delay_multiplier) / attack_speed

	-- make caster invulnerable during swift slash
	caster:AddNewModifier(
		caster, -- player source
		self, -- ability source
		"modifier_juggernaut_swift_slash_lua", -- modifier name
		{ duration = duration } -- kv
	)

	-- start the slash sequence
	self:PerformSlash(caster, target, {
		damage = damage,
		duration = duration,
		current_slashes = 0,
		max_slashes = max_targets,
		jump_delay = jump_delay,
		start_time = GameRules:GetGameTime()
	})

	-- play sound
	EmitSoundOn("Hero_Juggernaut.OmniSlash", caster)
end

function juggernaut_swift_slash_lua:PerformSlash(caster, target, data)
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

	-- teleport to target and face them
	FindClearSpaceForUnit(caster, target:GetAbsOrigin() + RandomVector(100), false)
	caster:SetForwardVector((target:GetAbsOrigin() - caster:GetAbsOrigin()):Normalized())
	
	-- perform a full attack (like real omnislash)
	caster:PerformAttack(target, true, true, true, false, false, false, true)
	
	-- add bonus damage from ability on top of the attack
	local bonus_damage = data.damage
	local damageTable = {
		victim = target,
		attacker = caster,
		damage = bonus_damage,
		damage_type = DAMAGE_TYPE_PHYSICAL,
		ability = self
	}
	ApplyDamage(damageTable)

	-- visual effects
	local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_juggernaut/juggernaut_omni_slash_tgt.vpcf", PATTACH_ABSORIGIN_FOLLOW, target)
	ParticleManager:SetParticleControlEnt(particle, 0, target, PATTACH_ABSORIGIN_FOLLOW, nil, target:GetAbsOrigin(), true)
	ParticleManager:ReleaseParticleIndex(particle)

	-- sound effect
	EmitSoundOn("Hero_Juggernaut.OmniSlash.Damage", target)

	-- check if we should continue slashing (based on duration, not max slashes)
	local elapsed_time = GameRules:GetGameTime() - data.start_time
	if elapsed_time < data.duration then
		-- create a timer to find next target
		Timers:CreateTimer(data.jump_delay, function()
			if caster and IsValidEntity(caster) and caster:IsAlive() then
				local next_target = self:FindNextTarget(caster, target, data)
				self:PerformSlash(caster, next_target, data)
			end
		end)
	end
end

function juggernaut_swift_slash_lua:FindNextTarget(caster, current_target, data)
	local search_radius = self:GetSpecialValueFor("slash_radius") or 425
	
	-- find all enemies in radius
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

	-- separate heroes and creeps
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

	-- probability-based target selection
	local roll = RandomFloat(0, 100)
	local next_target = nil
	if self:IsSlashTargetValid(caster, current_target) then
		next_target = current_target
	end
	
	-- 60% chance to jump to a hero (if heroes available)
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