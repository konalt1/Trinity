LinkLuaModifier(
	"modifier_antimage_antimagic_mark_trinity",
	"abilities/antimage/antimage_antimagic_mark_trinity",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_antimage_antimagic_mark_trinity_debuff",
	"abilities/antimage/antimage_antimagic_mark_trinity",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_antimage_antimagic_mark_trinity_bash",
	"abilities/antimage/antimage_antimagic_mark_trinity",
	LUA_MODIFIER_MOTION_NONE
)

local PARTICLE_MARK = "particles/antimages/drow_arcana_v2_marksmanship_attack_triangles_frost.vpcf"
local PARTICLE_BURN = "particles/generic_gameplay/generic_manaburn.vpcf"
local PARTICLE_STUN = "particles/generic_gameplay/generic_stunned.vpcf"
local SOUND_FILE = "soundevents/game_sounds_heroes/game_sounds_antimage.vsndevts"
local MARK_MODIFIER = "modifier_antimage_antimagic_mark_trinity_debuff"
local BASH_MODIFIER = "modifier_antimage_antimagic_mark_trinity_bash"

local function IsValidHandle(handle)
	return handle and (not handle.IsNull or not handle:IsNull())
end

local function IsPassiveAbility(ability)
	if not IsValidHandle(ability) then
		return true
	end
	if ability.IsItem and ability:IsItem() then
		return true
	end
	if ability.IsPassive and ability:IsPassive() then
		return true
	end
	if ability.GetBehaviorInt then
		local behavior = ability:GetBehaviorInt()
		if DOTA_ABILITY_BEHAVIOR_PASSIVE
			and bit.band(behavior, DOTA_ABILITY_BEHAVIOR_PASSIVE) == DOTA_ABILITY_BEHAVIOR_PASSIVE
		then
			return true
		end
		if DOTA_ABILITY_BEHAVIOR_HIDDEN
			and bit.band(behavior, DOTA_ABILITY_BEHAVIOR_HIDDEN) == DOTA_ABILITY_BEHAVIOR_HIDDEN
		then
			return true
		end
	end
	return false
end

local function ReduceMana(unit, amount, ability)
	if not IsValidHandle(unit) or amount <= 0 then
		return
	end
	if unit.Script_ReduceMana then
		unit:Script_ReduceMana(amount, ability)
	elseif unit.ReduceMana then
		unit:ReduceMana(amount)
	end
end

antimage_antimagic_mark_trinity = class({})

function antimage_antimagic_mark_trinity:Precache(context)
	if self:GetCaster() and self:GetCaster():IsIllusion() then
		return
	end

	PrecacheResource("soundfile", SOUND_FILE, context)
	PrecacheResource("particle", PARTICLE_MARK, context)
	PrecacheResource("particle", PARTICLE_BURN, context)
	PrecacheResource("particle", PARTICLE_STUN, context)
end

function antimage_antimagic_mark_trinity:GetIntrinsicModifierName()
	return "modifier_antimage_antimagic_mark_trinity"
end

function antimage_antimagic_mark_trinity:GetAOERadius()
	return self:GetSpecialValueFor("radius")
end

function antimage_antimagic_mark_trinity:GetStunDuration()
	local stun = self:GetSpecialValueFor("stun_duration")
	if stun > 0 then
		return stun
	end

	local level = self:GetLevel()
	if level >= 3 then
		return 1.5
	end
	if level >= 2 then
		return 1.25
	end
	return 1.0
end

function antimage_antimagic_mark_trinity:ProcMarkedAttack(target)
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	if not IsValidHandle(caster) or not IsValidHandle(target) then
		return
	end
	if caster:IsIllusion() then
		return
	end

	local mark = target:FindModifierByNameAndCaster(MARK_MODIFIER, caster)
	if not IsValidHandle(mark) then
		mark = target:FindModifierByName(MARK_MODIFIER)
	end
	if not IsValidHandle(mark) then
		return
	end

	local stun = self:GetStunDuration()
	local resist = 0
	if target.GetStatusResistance then
		resist = target:GetStatusResistance() or 0
	end
	target:AddNewModifier(caster, self, BASH_MODIFIER, {
		duration = stun * (1 - resist),
	})
	target:EmitSound("Hero_Antimage.ManaVoid")

	if not target:IsMagicImmune() then
		local burn = mark.bonus_mana_burn or self:GetSpecialValueFor("bonus_mana_burn") or 0
		if burn > 0 then
			ReduceMana(target, burn, self)

			local pct = 60
			local mana_break = caster:FindAbilityByName("antimage_mana_break")
			if IsValidHandle(mana_break) then
				local from_break = mana_break:GetSpecialValueFor("percent_damage_per_burn")
				if from_break and from_break > 0 then
					pct = from_break
				end
			end

			local damage = burn * pct / 100
			if damage > 0 then
				ApplyDamage({
					victim = target,
					attacker = caster,
					damage = damage,
					damage_type = DAMAGE_TYPE_PHYSICAL,
					ability = self,
				})
			end

			local fx = ParticleManager:CreateParticle(PARTICLE_BURN, PATTACH_ABSORIGIN_FOLLOW, target)
			ParticleManager:ReleaseParticleIndex(fx)
		end
	end

	mark:Destroy()
end

function antimage_antimagic_mark_trinity:GetMarkRadius()
	local radius = self:GetSpecialValueFor("radius")
	local caster = self:GetCaster()
	if GetHeroBonusSpellAoE and IsValidHandle(caster) then
		radius = radius + (GetHeroBonusSpellAoE(caster) or 0)
	end
	return radius
end

function antimage_antimagic_mark_trinity:TryMarkUnit(unit)
	if not IsServer() then
		return
	end

	local parent = self:GetCaster()
	if not IsValidHandle(parent) or not IsValidHandle(unit) then
		return
	end
	if self:GetLevel() < 1 then
		return
	end
	if parent:IsIllusion() then
		return
	end
	if parent.PassivesDisabled and parent:PassivesDisabled() then
		return
	end
	if not parent:IsAlive() then
		return
	end
	if not unit:IsRealHero() or unit:IsIllusion() then
		return
	end
	if unit:GetTeamNumber() == parent:GetTeamNumber() then
		return
	end

	local radius = self:GetMarkRadius()
	if (unit:GetAbsOrigin() - parent:GetAbsOrigin()):Length2D() > radius then
		return
	end

	local now = GameRules:GetGameTime()
	local unit_index = unit:entindex()
	if self.last_mark_unit == unit_index
		and self.last_mark_time
		and (now - self.last_mark_time) < 0.05
	then
		return
	end
	self.last_mark_unit = unit_index
	self.last_mark_time = now

	unit:AddNewModifier(parent, self, MARK_MODIFIER, {
		duration = self:GetSpecialValueFor("duration"),
	})
end

modifier_antimage_antimagic_mark_trinity = class({})

function modifier_antimage_antimagic_mark_trinity:IsHidden()
	return true
end

function modifier_antimage_antimagic_mark_trinity:IsPurgable()
	return false
end

function modifier_antimage_antimagic_mark_trinity:RemoveOnDeath()
	return false
end

function modifier_antimage_antimagic_mark_trinity:GetTexture()
	return "antimage_mana_void"
end

function modifier_antimage_antimagic_mark_trinity:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_ABILITY_FULLY_CAST,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
end

function modifier_antimage_antimagic_mark_trinity:OnAbilityFullyCast(event)
	if not IsServer() then
		return
	end

	local mark = self:GetAbility()
	if not IsValidHandle(mark) then
		return
	end

	local used = event.ability
	if not IsValidHandle(used) or used == mark then
		return
	end
	if IsPassiveAbility(used) then
		return
	end

	local name = used.GetAbilityName and used:GetAbilityName() or ""
	if string.find(name, "special_bonus", 1, true) or name == "generic_hidden" then
		return
	end

	if mark.TryMarkUnit then
		mark:TryMarkUnit(event.unit)
	end
end

function modifier_antimage_antimagic_mark_trinity:OnAttackLanded(event)
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	local ability = self:GetAbility()
	if not IsValidHandle(parent) or not IsValidHandle(ability) then
		return
	end
	if ability:GetLevel() < 1 then
		return
	end
	if event.attacker ~= parent then
		return
	end
	if not IsValidHandle(event.target) then
		return
	end

	ability:ProcMarkedAttack(event.target)
end

modifier_antimage_antimagic_mark_trinity_debuff = class({})

function modifier_antimage_antimagic_mark_trinity_debuff:IsHidden()
	return false
end

function modifier_antimage_antimagic_mark_trinity_debuff:IsDebuff()
	return true
end

function modifier_antimage_antimagic_mark_trinity_debuff:IsPurgable()
	return false
end

function modifier_antimage_antimagic_mark_trinity_debuff:GetTexture()
	return "antimage_mana_void"
end

function modifier_antimage_antimagic_mark_trinity_debuff:GetEffectName()
	return PARTICLE_MARK
end

function modifier_antimage_antimagic_mark_trinity_debuff:GetEffectAttachType()
	return PATTACH_OVERHEAD_FOLLOW
end

function modifier_antimage_antimagic_mark_trinity_debuff:GetPriority()
	return MODIFIER_PRIORITY_ULTRA
end

function modifier_antimage_antimagic_mark_trinity_debuff:CheckState()
	return {
		[MODIFIER_STATE_INVISIBLE] = false,
	}
end

function modifier_antimage_antimagic_mark_trinity_debuff:OnCreated()
	local ability = self:GetAbility()
	self.bonus_damage_pct = ability and ability:GetSpecialValueFor("bonus_damage_pct") or 0
	self.bonus_mana_burn = ability and ability:GetSpecialValueFor("bonus_mana_burn") or 0
	self.vision_radius = ability and ability:GetSpecialValueFor("vision_radius") or 400
	self.stun_duration = ability and ability:GetSpecialValueFor("stun_duration") or 0

	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	local caster = self:GetCaster()
	if IsValidHandle(self.truesight_modifier) then
		self.truesight_modifier:Destroy()
		self.truesight_modifier = nil
	end
	if IsValidHandle(parent) and IsValidHandle(caster) then
		self.truesight_modifier = parent:AddNewModifier(caster, ability, "modifier_truesight", {
			duration = self:GetDuration(),
		})
		parent:EmitSound("Hero_Antimage.Counterspell.Cast")
	end

	self:StartIntervalThink(0.2)
	self:OnIntervalThink()
end

function modifier_antimage_antimagic_mark_trinity_debuff:OnRefresh()
	self:OnCreated()
end

function modifier_antimage_antimagic_mark_trinity_debuff:OnIntervalThink()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	local caster = self:GetCaster()
	if not IsValidHandle(parent) or not IsValidHandle(caster) then
		return
	end

	AddFOWViewer(caster:GetTeamNumber(), parent:GetAbsOrigin(), self.vision_radius or 400, 0.25, false)
end

function modifier_antimage_antimagic_mark_trinity_debuff:OnDestroy()
	if not IsServer() then
		return
	end

	if IsValidHandle(self.truesight_modifier) then
		self.truesight_modifier:Destroy()
		self.truesight_modifier = nil
	end
end

function modifier_antimage_antimagic_mark_trinity_debuff:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_PROVIDES_FOW_POSITION,
		MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
	}
end

function modifier_antimage_antimagic_mark_trinity_debuff:GetModifierProvidesFOWVision()
	return 1
end

function modifier_antimage_antimagic_mark_trinity_debuff:GetModifierIncomingDamage_Percentage(params)
	if not params or not params.attacker then
		return 0
	end

	local caster = self:GetCaster()
	if not IsValidHandle(caster) or params.attacker ~= caster then
		return 0
	end

	return self.bonus_damage_pct or 0
end

modifier_antimage_antimagic_mark_trinity_bash = class({})

function modifier_antimage_antimagic_mark_trinity_bash:IsHidden()
	return false
end

function modifier_antimage_antimagic_mark_trinity_bash:IsDebuff()
	return true
end

function modifier_antimage_antimagic_mark_trinity_bash:IsStunDebuff()
	return true
end

function modifier_antimage_antimagic_mark_trinity_bash:IsPurgable()
	return true
end

function modifier_antimage_antimagic_mark_trinity_bash:GetTexture()
	return "antimage_mana_void"
end

function modifier_antimage_antimagic_mark_trinity_bash:GetAttributes()
	return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end

function modifier_antimage_antimagic_mark_trinity_bash:CheckState()
	return {
		[MODIFIER_STATE_STUNNED] = true,
	}
end

function modifier_antimage_antimagic_mark_trinity_bash:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_OVERRIDE_ANIMATION,
	}
end

function modifier_antimage_antimagic_mark_trinity_bash:GetOverrideAnimation()
	return ACT_DOTA_DISABLED
end

function modifier_antimage_antimagic_mark_trinity_bash:GetEffectName()
	return PARTICLE_STUN
end

function modifier_antimage_antimagic_mark_trinity_bash:GetEffectAttachType()
	return PATTACH_OVERHEAD_FOLLOW
end
