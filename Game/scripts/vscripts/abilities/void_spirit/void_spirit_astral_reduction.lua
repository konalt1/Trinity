LinkLuaModifier(
	"modifier_void_spirit_astral_reduction",
	"abilities/void_spirit/void_spirit_astral_reduction",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_void_spirit_astral_reduction_wave",
	"abilities/void_spirit/void_spirit_astral_reduction",
	LUA_MODIFIER_MOTION_NONE
)

local SOUND_FILE = "soundevents/game_sounds_heroes/game_sounds_void_spirit.vsndevts"
local PARTICLE_WAVE = "particles/units/heroes/hero_void_spirit/dissimilate/void_spirit_dissimilate_dmg.vpcf"
local PARTICLE_EXIT = "particles/units/heroes/hero_void_spirit/dissimilate/void_spirit_dissimilate_exit.vpcf"

local function IsValidHandle(handle)
	return handle and (not handle.IsNull or not handle:IsNull())
end

local function IsPassiveAbility(ability)
	if not ability or ability:IsNull() then
		return true
	end
	if ability.IsPassive and ability:IsPassive() then
		return true
	end
	if ability.GetBehaviorInt and DOTA_ABILITY_BEHAVIOR_PASSIVE then
		return bit.band(ability:GetBehaviorInt(), DOTA_ABILITY_BEHAVIOR_PASSIVE) == DOTA_ABILITY_BEHAVIOR_PASSIVE
	end
	return false
end

local function RewindCooldown(ability, rewind)
	if not IsValidHandle(ability) or rewind <= 0 then
		return
	end
	if not ability.GetCooldownTimeRemaining then
		return
	end

	local remaining = ability:GetCooldownTimeRemaining()
	if remaining <= 0 then
		return
	end

	local new_cooldown = remaining - rewind
	ability:EndCooldown()
	if new_cooldown > 0.01 then
		ability:StartCooldown(new_cooldown)
	end
end

void_spirit_astral_reduction = class({})

function void_spirit_astral_reduction:Precache(context)
	if self:GetCaster() and self:GetCaster():IsIllusion() then
		return
	end

	PrecacheResource("soundfile", SOUND_FILE, context)
	PrecacheResource("particle", PARTICLE_WAVE, context)
	PrecacheResource("particle", PARTICLE_EXIT, context)
end

function void_spirit_astral_reduction:GetIntrinsicModifierName()
	return "modifier_void_spirit_astral_reduction"
end

function void_spirit_astral_reduction:GetAOERadius()
	local caster = self:GetCaster()
	if caster and caster.HasScepter and caster:HasScepter() then
		return self:GetSpecialValueFor("scepter_wave_radius")
	end
	return 0
end

function void_spirit_astral_reduction:ReleaseScepterWave()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	if not IsValidHandle(caster) or not caster.HasScepter or not caster:HasScepter() then
		return
	end

	local origin = caster:GetAbsOrigin()
	local radius = self:GetSpecialValueFor("scepter_wave_radius")
	if GetHeroBonusSpellAoE then
		radius = radius + (GetHeroBonusSpellAoE(caster) or 0)
	end
	local duration = self:GetSpecialValueFor("scepter_slow_duration")

	local wave = ParticleManager:CreateParticle(PARTICLE_WAVE, PATTACH_WORLDORIGIN, caster)
	ParticleManager:SetParticleControl(wave, 0, origin)
	ParticleManager:SetParticleControl(wave, 1, Vector(radius, 0, 0))
	ParticleManager:ReleaseParticleIndex(wave)

	local exit = ParticleManager:CreateParticle(PARTICLE_EXIT, PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:ReleaseParticleIndex(exit)

	caster:EmitSound("Hero_VoidSpirit.Dissimilate.TeleportIn")

	local enemies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		origin,
		nil,
		radius,
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
			enemy:AddNewModifier(caster, self, "modifier_void_spirit_astral_reduction_wave", {
				duration = duration,
			})
		end
	end

	if hit > 0 then
		caster:EmitSound("Hero_VoidSpirit.Dissimilate.Stun")
	end
end

modifier_void_spirit_astral_reduction = class({})

function modifier_void_spirit_astral_reduction:IsHidden()
	return self:GetAbility() == nil or self:GetAbility():GetLevel() < 1
end

function modifier_void_spirit_astral_reduction:IsPurgable()
	return false
end

function modifier_void_spirit_astral_reduction:RemoveOnDeath()
	return false
end

function modifier_void_spirit_astral_reduction:GetTexture()
	return "faceless_void_time_dilation"
end

function modifier_void_spirit_astral_reduction:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_ABILITY_FULLY_CAST,
	}
end

function modifier_void_spirit_astral_reduction:OnAbilityFullyCast(event)
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	local reduction = self:GetAbility()
	if not IsValidHandle(parent) or not reduction or reduction:IsNull() then
		return
	end
	if reduction:GetLevel() < 1 then
		return
	end
	if event.unit ~= parent then
		return
	end

	local used = event.ability
	if not IsValidHandle(used) or used == reduction then
		return
	end
	if IsPassiveAbility(used) then
		return
	end

	local now = GameRules:GetGameTime()
	local used_index = used:entindex()
	if self.last_rewind_ent == used_index and self.last_rewind_time and (now - self.last_rewind_time) < 0.05 then
		return
	end
	self.last_rewind_ent = used_index
	self.last_rewind_time = now

	local rewind = reduction:GetSpecialValueFor("rewind_time")
	if rewind <= 0 then
		return
	end

	for slot = 0, parent:GetAbilityCount() - 1 do
		local ability = parent:GetAbilityByIndex(slot)
		if IsValidHandle(ability) and ability ~= reduction then
			local name = ability:GetAbilityName() or ""
			if not string.find(name, "special_bonus", 1, true) and name ~= "generic_hidden" then
				RewindCooldown(ability, rewind)
			end
		end
	end

	for slot = 0, 8 do
		RewindCooldown(parent:GetItemInSlot(slot), rewind)
	end
	RewindCooldown(parent:GetItemInSlot(DOTA_ITEM_TP_SCROLL or 15), rewind)
	RewindCooldown(parent:GetItemInSlot(DOTA_ITEM_NEUTRAL_SLOT or 16), rewind)

	if reduction.ReleaseScepterWave then
		reduction:ReleaseScepterWave()
	end
end

modifier_void_spirit_astral_reduction_wave = class({})

function modifier_void_spirit_astral_reduction_wave:IsHidden()
	return false
end

function modifier_void_spirit_astral_reduction_wave:IsDebuff()
	return true
end

function modifier_void_spirit_astral_reduction_wave:IsPurgable()
	return true
end

function modifier_void_spirit_astral_reduction_wave:GetTexture()
	return "void_spirit_dissimilate"
end

function modifier_void_spirit_astral_reduction_wave:OnCreated()
	local ability = self:GetAbility()
	self.slow = ability and ability:GetSpecialValueFor("scepter_slow_pct") or 0
end

function modifier_void_spirit_astral_reduction_wave:OnRefresh()
	self:OnCreated()
end

function modifier_void_spirit_astral_reduction_wave:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
	}
end

function modifier_void_spirit_astral_reduction_wave:GetModifierMoveSpeedBonus_Percentage()
	return -(self.slow or 0)
end
