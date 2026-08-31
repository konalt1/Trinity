LinkLuaModifier(
	"modifier_pangolier_duelist_rhythm_trinity",
	"abilities/pangolier/pangolier_duelist_rhythm_trinity",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_pangolier_duelist_rhythm_trinity_combo",
	"abilities/pangolier/pangolier_duelist_rhythm_trinity",
	LUA_MODIFIER_MOTION_NONE
)

pangolier_duelist_rhythm_trinity = class({})

local PARTICLE_HIT = "particles/units/heroes/hero_pangolier/pangolier_swashbuckler.vpcf"
local PARTICLE_IMPACT = "particles/units/heroes/hero_pangolier/pangolier_luckyshot_disarm_cast.vpcf"
local COMBO_MODIFIER = "modifier_pangolier_duelist_rhythm_trinity_combo"

local STYLE_ATTACK = "attack"
local STYLE_SWASH = "swashbuckle"
local STYLE_SHIELD = "shield_crash"
local STYLE_ROLL = "rolling_thunder"

local STYLE_ABILITIES = {
	pangolier_swashbuckle = STYLE_SWASH,
	pangolier_shield_crash_trinity = STYLE_SHIELD,
	pangolier_gyroshell = STYLE_ROLL,
}

local function IsValid(entity)
	return entity ~= nil and not entity:IsNull()
end

function pangolier_duelist_rhythm_trinity:Precache(context)
	if self:GetCaster() and self:GetCaster():IsIllusion() then
		return
	end

	PrecacheResource("particle", PARTICLE_HIT, context)
	PrecacheResource("particle", PARTICLE_IMPACT, context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_pangolier.vsndevts", context)
end

function pangolier_duelist_rhythm_trinity:GetIntrinsicModifierName()
	return "modifier_pangolier_duelist_rhythm_trinity"
end

modifier_pangolier_duelist_rhythm_trinity = class({})

function modifier_pangolier_duelist_rhythm_trinity:IsHidden()
	return true
end

function modifier_pangolier_duelist_rhythm_trinity:IsPurgable()
	return false
end

function modifier_pangolier_duelist_rhythm_trinity:RemoveOnDeath()
	return false
end

function modifier_pangolier_duelist_rhythm_trinity:OnCreated()
	self:ResetCombo()
end

function modifier_pangolier_duelist_rhythm_trinity:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_ABILITY_EXECUTED,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
		MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE,
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
	}
end

function modifier_pangolier_duelist_rhythm_trinity:CanTrack()
	local parent = self:GetParent()
	local ability = self:GetAbility()
	if not IsValid(parent) or not IsValid(ability) then
		return false
	end
	if ability:GetLevel() <= 0 then
		return false
	end
	if parent:IsIllusion() then
		return false
	end
	if not parent:IsAlive() then
		return false
	end
	if parent.PassivesDisabled and parent:PassivesDisabled() then
		return false
	end
	return true
end

function modifier_pangolier_duelist_rhythm_trinity:IsCharged()
	if not self:CanTrack() then
		return false
	end

	local ability = self:GetAbility()
	local required = ability:GetSpecialValueFor("styles_required")
	if required <= 0 then
		required = 3
	end
	return (self.count or 0) >= required
end

function modifier_pangolier_duelist_rhythm_trinity:GetFlourishDamage()
	local ability = self:GetAbility()
	local parent = self:GetParent()
	if not IsValid(ability) then
		return 0
	end

	local max_styles = ability:GetSpecialValueFor("max_styles")
	if max_styles <= 0 then
		max_styles = 4
	end

	local key = "bonus_damage"
	if (self.count or 0) >= max_styles then
		key = "bonus_damage_max"
	end

	local base = ability:GetSpecialValueFor(key)
	local multiplier = ability:GetSpecialValueFor("mind_power_multiplier")
	local mind_power = 0
	if IsValid(parent) and GetHeroMindPower then
		mind_power = GetHeroMindPower(parent) or 0
	end

	return math.max(0, base + mind_power * multiplier)
end

function modifier_pangolier_duelist_rhythm_trinity:IsEnemyTarget(target)
	local parent = self:GetParent()
	if not IsValid(parent) or not IsValid(target) then
		return false
	end
	if target:GetTeamNumber() == parent:GetTeamNumber() then
		return false
	end
	if target:IsBuilding() or target:IsOther() then
		return false
	end
	return true
end

function modifier_pangolier_duelist_rhythm_trinity:IsSwashbuckleAttack(params)
	local parent = self:GetParent()
	if not IsValid(parent) then
		return false
	end
	if parent:HasModifier("modifier_pangolier_swashbuckle") then
		return true
	end
	if parent:HasModifier("modifier_pangolier_shield_crash_trinity_scepter") then
		return true
	end

	local inflictor = params and params.inflictor
	if IsValid(inflictor) and inflictor.GetAbilityName then
		local name = inflictor:GetAbilityName()
		if name == "pangolier_swashbuckle" then
			return true
		end
	end

	return false
end

function modifier_pangolier_duelist_rhythm_trinity:ShouldFlourish(params)
	if not self:IsCharged() then
		return false
	end
	if not params or params.attacker ~= self:GetParent() then
		return false
	end
	return self:IsEnemyTarget(params.target)
end

function modifier_pangolier_duelist_rhythm_trinity:TryAddStyle(style)
	if not self:CanTrack() or not style then
		return false
	end
	if self.last_style == style then
		return false
	end

	self.last_style = style
	self.used = self.used or {}
	if self.used[style] then
		return false
	end

	local ability = self:GetAbility()
	local max_styles = ability:GetSpecialValueFor("max_styles")
	if max_styles <= 0 then
		max_styles = 4
	end
	if (self.count or 0) >= max_styles then
		return false
	end

	self.used[style] = true
	self.count = (self.count or 0) + 1
	self:SyncComboModifier()
	return true
end

function modifier_pangolier_duelist_rhythm_trinity:SyncComboModifier()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	local ability = self:GetAbility()
	if not IsValid(parent) or not IsValid(ability) then
		return
	end

	if (self.count or 0) < 1 then
		self.resetting = true
		parent:RemoveModifierByName(COMBO_MODIFIER)
		self.resetting = false
		return
	end

	local duration = ability:GetSpecialValueFor("combo_duration")
	if duration <= 0 then
		duration = 8
	end

	local combo = parent:FindModifierByName(COMBO_MODIFIER)
	if not IsValid(combo) then
		combo = parent:AddNewModifier(parent, ability, COMBO_MODIFIER, { duration = duration })
	elseif combo.SetDuration then
		combo:SetDuration(duration, true)
	end

	if IsValid(combo) then
		combo:SetStackCount(self.count)
	end
end

function modifier_pangolier_duelist_rhythm_trinity:ResetCombo()
	self.used = {}
	self.last_style = nil
	self.count = 0

	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if IsValid(parent) then
		self.resetting = true
		parent:RemoveModifierByName(COMBO_MODIFIER)
		self.resetting = false
	end
end

function modifier_pangolier_duelist_rhythm_trinity:OnComboExpired()
	if self.resetting then
		return
	end
	self:ResetCombo()
end

function modifier_pangolier_duelist_rhythm_trinity:OnAbilityExecuted(params)
	if not IsServer() then
		return
	end
	if not params or params.unit ~= self:GetParent() then
		return
	end

	local used = params.ability
	if not IsValid(used) or used.IsItem and used:IsItem() then
		return
	end
	if not used.GetAbilityName then
		return
	end

	local style = STYLE_ABILITIES[used:GetAbilityName()]
	if not style then
		return
	end

	self:TryAddStyle(style)
end

function modifier_pangolier_duelist_rhythm_trinity:GetModifierPreAttack_CriticalStrike(params)
	if not IsServer() then
		return
	end
	if not self:ShouldFlourish(params) then
		return
	end

	return self:GetAbility():GetSpecialValueFor("crit_multiplier")
end

function modifier_pangolier_duelist_rhythm_trinity:GetModifierPreAttack_BonusDamage(params)
	if not IsServer() then
		return 0
	end
	if not self:IsCharged() then
		return 0
	end
	if params and params.target and not self:IsEnemyTarget(params.target) then
		return 0
	end

	return self:GetFlourishDamage()
end

function modifier_pangolier_duelist_rhythm_trinity:OnAttackLanded(params)
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if params.attacker ~= parent then
		return
	end
	if not self:IsEnemyTarget(params.target) then
		return
	end

	if self:IsCharged() then
		self:PlayFlourish(params.target)
		self:ResetCombo()
		return
	end

	if self:IsSwashbuckleAttack(params) then
		return
	end

	self:TryAddStyle(STYLE_ATTACK)
end

function modifier_pangolier_duelist_rhythm_trinity:PlayFlourish(target)
	if not IsValid(target) then
		return
	end

	local parent = self:GetParent()
	local origin = target:GetAbsOrigin()

	local slash = ParticleManager:CreateParticle(PARTICLE_HIT, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(slash, 0, origin)
	ParticleManager:SetParticleControl(slash, 1, origin)
	ParticleManager:ReleaseParticleIndex(slash)

	local impact = ParticleManager:CreateParticle(PARTICLE_IMPACT, PATTACH_ABSORIGIN_FOLLOW, target)
	ParticleManager:SetParticleControl(impact, 0, origin)
	ParticleManager:ReleaseParticleIndex(impact)

	if IsValid(parent) then
		EmitSoundOnLocationWithCaster(origin, "Hero_Pangolier.Swashbuckle.Damage", parent)
		EmitSoundOnLocationWithCaster(origin, "Hero_Pangolier.LuckyShot", parent)
	end
end

modifier_pangolier_duelist_rhythm_trinity_combo = class({})

function modifier_pangolier_duelist_rhythm_trinity_combo:IsHidden()
	return false
end

function modifier_pangolier_duelist_rhythm_trinity_combo:IsPurgable()
	return false
end

function modifier_pangolier_duelist_rhythm_trinity_combo:IsDebuff()
	return false
end

function modifier_pangolier_duelist_rhythm_trinity_combo:GetTexture()
	return "pangolier_lucky_shot"
end

function modifier_pangolier_duelist_rhythm_trinity_combo:OnDestroy()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if not IsValid(parent) then
		return
	end

	local intrinsic = parent:FindModifierByName("modifier_pangolier_duelist_rhythm_trinity")
	if intrinsic and intrinsic.OnComboExpired then
		intrinsic:OnComboExpired()
	end
end
