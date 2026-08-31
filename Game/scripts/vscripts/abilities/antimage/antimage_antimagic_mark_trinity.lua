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

local PARTICLE_MARK = "particles/units/heroes/hero_demonartist/demonartist_soulchain_marker_tgt.vpcf"
local PARTICLE_BURN = "particles/generic_gameplay/generic_manaburn.vpcf"
local SOUND_FILE = "soundevents/game_sounds_heroes/game_sounds_antimage.vsndevts"
local MARK_MODIFIER = "modifier_antimage_antimagic_mark_trinity_debuff"

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
end

function antimage_antimagic_mark_trinity:GetIntrinsicModifierName()
	return "modifier_antimage_antimagic_mark_trinity"
end

function antimage_antimagic_mark_trinity:GetAOERadius()
	return self:GetSpecialValueFor("radius")
end

function antimage_antimagic_mark_trinity:GetMarkRadius()
	local radius = self:GetSpecialValueFor("radius")
	local caster = self:GetCaster()
	if GetHeroBonusSpellAoE and IsValidHandle(caster) then
		radius = radius + (GetHeroBonusSpellAoE(caster) or 0)
	end
	return radius
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
	}
end

function modifier_antimage_antimagic_mark_trinity:OnAbilityFullyCast(event)
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	local mark = self:GetAbility()
	if not IsValidHandle(parent) or not IsValidHandle(mark) then
		return
	end
	if mark:GetLevel() < 1 then
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

	local unit = event.unit
	if not IsValidHandle(unit) then
		return
	end
	if not unit:IsRealHero() or unit:IsIllusion() then
		return
	end
	if unit:GetTeamNumber() == parent:GetTeamNumber() then
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

	local now = GameRules:GetGameTime()
	local used_index = used:entindex()
	local unit_index = unit:entindex()
	if self.last_mark_ent == used_index
		and self.last_mark_unit == unit_index
		and self.last_mark_time
		and (now - self.last_mark_time) < 0.05
	then
		return
	end
	self.last_mark_ent = used_index
	self.last_mark_unit = unit_index
	self.last_mark_time = now

	local radius = mark.GetMarkRadius and mark:GetMarkRadius() or mark:GetSpecialValueFor("radius")
	if (unit:GetAbsOrigin() - parent:GetAbsOrigin()):Length2D() > radius then
		return
	end

	unit:AddNewModifier(parent, mark, MARK_MODIFIER, {
		duration = mark:GetSpecialValueFor("duration"),
	})
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

	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	local caster = self:GetCaster()
	if IsValidHandle(parent) and IsValidHandle(caster) then
		parent:AddNewModifier(caster, ability, "modifier_truesight", {
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

function modifier_antimage_antimagic_mark_trinity_debuff:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_PROVIDES_FOW_POSITION,
		MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
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

function modifier_antimage_antimagic_mark_trinity_debuff:OnAttackLanded(event)
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	local caster = self:GetCaster()
	local ability = self:GetAbility()
	if not IsValidHandle(parent) or not IsValidHandle(caster) or not IsValidHandle(ability) then
		return
	end
	if event.target ~= parent or event.attacker ~= caster then
		return
	end
	if parent:IsMagicImmune() then
		return
	end

	local burn = self.bonus_mana_burn or 0
	if burn <= 0 then
		return
	end

	ReduceMana(parent, burn, ability)

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
			victim = parent,
			attacker = caster,
			damage = damage,
			damage_type = DAMAGE_TYPE_PHYSICAL,
			ability = ability,
		})
	end

	local fx = ParticleManager:CreateParticle(PARTICLE_BURN, PATTACH_ABSORIGIN_FOLLOW, parent)
	ParticleManager:ReleaseParticleIndex(fx)
end
