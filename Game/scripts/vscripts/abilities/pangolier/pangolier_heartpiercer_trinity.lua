LinkLuaModifier(
	"modifier_pangolier_heartpiercer_trinity",
	"abilities/pangolier/pangolier_heartpiercer_trinity",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_pangolier_heartpiercer_trinity_mark",
	"abilities/pangolier/pangolier_heartpiercer_trinity",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_pangolier_mind_power",
	"abilities/pangolier/pangolier_heartpiercer_trinity",
	LUA_MODIFIER_MOTION_NONE
)

require("game_managers/custom_ability_tooltips")

pangolier_heartpiercer_trinity = class({})

local PARTICLE_HEARTPIERCER = "particles/pangolier/pangolier_heartpiercer_mark.vpcf"
local PARTICLE_PA_CRIT = "particles/units/heroes/hero_phantom_assassin/phantom_assassin_crit_impact.vpcf"
local MARK_MODIFIER = "modifier_pangolier_heartpiercer_trinity_mark"

local function IsValid(entity)
	return entity ~= nil and not entity:IsNull()
end

function pangolier_heartpiercer_trinity:Precache(context)
	if self:GetCaster() and self:GetCaster():IsIllusion() then
		return
	end

	PrecacheResource("particle", PARTICLE_HEARTPIERCER, context)
	PrecacheResource("particle", PARTICLE_PA_CRIT, context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_pangolier.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_phantom_assassin.vsndevts", context)
end

function pangolier_heartpiercer_trinity:GetIntrinsicModifierName()
	return "modifier_pangolier_heartpiercer_trinity"
end

function pangolier_heartpiercer_trinity:GetProcChance()
	local chance = self:GetSpecialValueFor("crit_chance") or 0
	local caster = self:GetCaster()
	if not IsValid(caster) then
		return chance
	end
	if not (HasShard and HasShard(caster)) then
		return chance
	end

	local per_hero = self:GetSpecialValueFor("shard_chance_per_hero")
	local radius = self:GetSpecialValueFor("shard_radius")
	if per_hero <= 0 or radius <= 0 then
		return chance
	end

	local heroes = FindUnitsInRadius(
		caster:GetTeamNumber(),
		caster:GetAbsOrigin(),
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO,
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_NOT_ILLUSIONS,
		FIND_ANY_ORDER,
		false
	)

	local count = 0
	for _, hero in ipairs(heroes) do
		if IsValid(hero) and hero:IsAlive() and hero:IsRealHero() and not hero:IsIllusion() then
			count = count + 1
		end
	end

	return math.min(100, chance + count * per_hero)
end

modifier_pangolier_heartpiercer_trinity = class({})

function modifier_pangolier_heartpiercer_trinity:IsHidden()
	return true
end

function modifier_pangolier_heartpiercer_trinity:IsPurgable()
	return false
end

function modifier_pangolier_heartpiercer_trinity:RemoveOnDeath()
	return false
end

function modifier_pangolier_heartpiercer_trinity:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
end

function modifier_pangolier_heartpiercer_trinity:GetModifierPreAttack_CriticalStrike(params)
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	local ability = self:GetAbility()
	if not IsValid(parent) or not IsValid(ability) or ability:GetLevel() <= 0 then
		return
	end
	if parent:PassivesDisabled() then
		return
	end
	if params.attacker ~= parent then
		return
	end

	local target = params.target
	if not IsValid(target) or target:GetTeamNumber() == parent:GetTeamNumber() then
		return
	end
	if target:IsBuilding() or target:IsOther() then
		return
	end

	if RandomInt(1, 100) > ability:GetProcChance() then
		return
	end

	self:ApplyArmorMark(target, parent, ability)

	self.proc_records = self.proc_records or {}
	if params.record then
		self.proc_records[params.record] = true
	else
		self.proc = true
	end
	return ability:GetSpecialValueFor("crit_multiplier")
end

function modifier_pangolier_heartpiercer_trinity:ApplyArmorMark(target, caster, ability)
	if not IsValid(target) or not IsValid(caster) or not IsValid(ability) then
		return
	end

	local duration = ability:GetSpecialValueFor("duration")
	if duration <= 0 then
		duration = 3
	end

	target:AddNewModifier(caster, ability, MARK_MODIFIER, { duration = duration })
end

function modifier_pangolier_heartpiercer_trinity:OnAttackLanded(params)
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if params.attacker ~= parent then
		return
	end

	local proc = false
	if params.record and self.proc_records and self.proc_records[params.record] then
		self.proc_records[params.record] = nil
		proc = true
	elseif self.proc then
		self.proc = false
		proc = true
	end

	if not proc then
		return
	end

	self:PlayProcEffects(params.target)
end

function modifier_pangolier_heartpiercer_trinity:PlayProcEffects(target)
	if not IsValid(target) then
		return
	end

	local parent = self:GetParent()
	local origin = target:GetAbsOrigin()

	local crit = ParticleManager:CreateParticle(PARTICLE_PA_CRIT, PATTACH_CUSTOMORIGIN, nil)
	ParticleManager:SetParticleControlEnt(crit, 0, target, PATTACH_POINT_FOLLOW, "attach_hitloc", origin, true)
	ParticleManager:SetParticleControl(crit, 1, origin)
	if IsValid(parent) then
		local forward = origin - parent:GetAbsOrigin()
		if forward:Length2D() > 1 then
			ParticleManager:SetParticleControlForward(crit, 1, Vector(forward.x, forward.y, 0):Normalized())
		end
	end
	ParticleManager:ReleaseParticleIndex(crit)

	EmitSoundOnLocationWithCaster(origin, "Hero_PhantomAssassin.CoupDeGrace", parent)
end

modifier_pangolier_heartpiercer_trinity_mark = class({})

function modifier_pangolier_heartpiercer_trinity_mark:IsHidden()
	return false
end

function modifier_pangolier_heartpiercer_trinity_mark:IsPurgable()
	return true
end

function modifier_pangolier_heartpiercer_trinity_mark:IsDebuff()
	return true
end

function modifier_pangolier_heartpiercer_trinity_mark:GetAttributes()
	return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end

function modifier_pangolier_heartpiercer_trinity_mark:GetTexture()
	return "pangolier_heartpiercer"
end

function modifier_pangolier_heartpiercer_trinity_mark:OnCreated()
	self:CacheValues()
end

function modifier_pangolier_heartpiercer_trinity_mark:OnRefresh()
	self:CacheValues()
end

function modifier_pangolier_heartpiercer_trinity_mark:CacheValues()
	local ability = self:GetAbility()
	self.armor_reduction = 0
	if IsValid(ability) then
		self.armor_reduction = ability:GetSpecialValueFor("armor_reduction")
	end
end

function modifier_pangolier_heartpiercer_trinity_mark:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
	}
end

function modifier_pangolier_heartpiercer_trinity_mark:GetModifierPhysicalArmorBonus()
	return -(self.armor_reduction or 0)
end

function modifier_pangolier_heartpiercer_trinity_mark:GetEffectName()
	return PARTICLE_HEARTPIERCER
end

function modifier_pangolier_heartpiercer_trinity_mark:GetEffectAttachType()
	return PATTACH_OVERHEAD_FOLLOW
end

-- Scales vanilla Rolling Thunder flat damage on the server without replacing the ability.
-- Also shows native Roll Up only while Pangolier is in the ball.
modifier_pangolier_mind_power = class({})

local ROLLUP_ABILITY = "pangolier_rollup"
local GYROSHELL_MODIFIER = "modifier_pangolier_gyroshell"
local ROLLUP_MODIFIER = "modifier_pangolier_rollup"

function modifier_pangolier_mind_power:IsHidden()
	return true
end

function modifier_pangolier_mind_power:IsPurgable()
	return false
end

function modifier_pangolier_mind_power:RemoveOnDeath()
	return false
end

function modifier_pangolier_mind_power:OnCreated()
	if not IsServer() then
		return
	end

	self:StartIntervalThink(0.03)
	self:SyncRollUp()
end

function modifier_pangolier_mind_power:OnIntervalThink()
	self:SyncRollUp()
end

function modifier_pangolier_mind_power:IsInBall()
	local parent = self:GetParent()
	if not parent or parent:IsNull() then
		return false
	end

	if parent:HasModifier(GYROSHELL_MODIFIER) or parent:HasModifier(ROLLUP_MODIFIER) then
		return true
	end

	if parent.FindAllModifiers then
		for _, modifier in pairs(parent:FindAllModifiers()) do
			if modifier and modifier.GetName then
				local name = modifier:GetName() or ""
				if string.find(name, "pangolier_gyroshell", 1, true)
					and not string.find(name, "stunned", 1, true)
					and not string.find(name, "timeout", 1, true)
				then
					return true
				end
			end
		end
	end

	return false
end

function modifier_pangolier_mind_power:SyncRollUp()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if not parent or parent:IsNull() then
		return
	end

	local rollup = parent:FindAbilityByName(ROLLUP_ABILITY)
	if not rollup or rollup:IsNull() then
		return
	end

	if rollup:GetLevel() < 1 then
		rollup:SetLevel(1)
	end

	-- Native SwapAbilities hides Roll Up and shows Stop. Do not fight that.
	if parent:HasModifier(ROLLUP_MODIFIER) then
		return
	end

	local show = self:IsInBall()
	if show then
		if rollup:IsHidden() then
			rollup:SetHidden(false)
		end
	elseif not rollup:IsHidden() then
		rollup:SetHidden(true)
	end
end

function modifier_pangolier_mind_power:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL,
		MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL_VALUE,
	}
end

function modifier_pangolier_mind_power:GetModifierOverrideAbilitySpecial(params)
	if not IsServer() or self.computing_override or not params or not params.ability or params.ability:IsNull() then
		return 0
	end

	return CustomAbilityTooltips:IsNumericMindPowerMultiplier(
		params.ability:GetAbilityName(),
		params.ability_special_value
	) and 1 or 0
end

function modifier_pangolier_mind_power:GetModifierOverrideAbilitySpecialValue(params)
	if not IsServer() or not params or not params.ability or params.ability:IsNull() then
		return 0
	end

	local ability = params.ability
	local special_value = params.ability_special_value
	local multiplier = CustomAbilityTooltips:GetMindPowerMultiplierKey(ability:GetAbilityName(), special_value)
	if type(multiplier) ~= "number" then
		return 0
	end

	self.computing_override = true
	local base_value = ability:GetSpecialValueFor(special_value)
	self.computing_override = false

	local parent = self:GetParent()
	local mind_power = 0
	if parent and not parent:IsNull() and GetHeroMindPower then
		mind_power = GetHeroMindPower(parent) or 0
	end

	return math.max(0, base_value + mind_power * multiplier)
end
