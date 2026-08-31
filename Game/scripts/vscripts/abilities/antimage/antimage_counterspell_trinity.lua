LinkLuaModifier(
	"modifier_antimage_counterspell_trinity",
	"abilities/antimage/antimage_counterspell_trinity",
	LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
	"modifier_antimage_counterspell_trinity_lock",
	"abilities/antimage/antimage_counterspell_trinity",
	LUA_MODIFIER_MOTION_NONE
)

local PARTICLE_SHIELD = "particles/units/heroes/hero_antimage/antimage_counter.vpcf"
local PARTICLE_STATUS = "particles/status_fx/status_effect_antimage_counter.vpcf"
local PARTICLE_MARK = "particles/antimages/drow_arcana_v2_marksmanship_attack_triangles_frost.vpcf"
local SOUND_FILE = "soundevents/game_sounds_heroes/game_sounds_antimage.vsndevts"
local LOCK_MODIFIER = "modifier_antimage_counterspell_trinity_lock"
local MARK_ABILITY = "antimage_antimagic_mark_trinity"
local SHIELD_RADIUS = 120

local function IsValidHandle(handle)
	return handle and (not handle.IsNull or not handle:IsNull())
end

local function IsCastOrder(order_type)
	return order_type == DOTA_UNIT_ORDER_CAST_POSITION
		or order_type == DOTA_UNIT_ORDER_CAST_TARGET
		or order_type == DOTA_UNIT_ORDER_CAST_TARGET_TREE
		or order_type == DOTA_UNIT_ORDER_CAST_NO_TARGET
		or order_type == DOTA_UNIT_ORDER_CAST_TOGGLE
		or order_type == DOTA_UNIT_ORDER_VECTOR_TARGET_POSITION
end

local function IsLockableAbility(ability)
	if not IsValidHandle(ability) then
		return false
	end
	if ability.IsItem and ability:IsItem() then
		return false
	end
	if ability.IsPassive and ability:IsPassive() then
		return false
	end
	if ability.IsHidden and ability:IsHidden() then
		return false
	end
	if ability.GetLevel and ability:GetLevel() < 1 then
		return false
	end
	if ability.IsCooldownReady and not ability:IsCooldownReady() then
		return false
	end
	if ability.IsFullyCastable and not ability:IsFullyCastable() then
		return false
	end

	local name = ability.GetAbilityName and ability:GetAbilityName() or ""
	if name == "" or name == "generic_hidden" then
		return false
	end
	if string.find(name, "special_bonus", 1, true) then
		return false
	end

	if ability.GetBehaviorInt then
		local behavior = ability:GetBehaviorInt()
		if DOTA_ABILITY_BEHAVIOR_PASSIVE
			and bit.band(behavior, DOTA_ABILITY_BEHAVIOR_PASSIVE) == DOTA_ABILITY_BEHAVIOR_PASSIVE
		then
			return false
		end
	end

	return true
end

function AntimageCounterspellHandleOrder(data)
	if not data or not IsCastOrder(data.order_type) then
		return true
	end

	local ability_index = tonumber(data.entindex_ability)
	if not ability_index or ability_index == 0 then
		return true
	end

	local ability = EntIndexToHScript(ability_index)
	if not IsLockableAbility(ability) then
		return true
	end

	local unit = ability.GetCaster and ability:GetCaster() or nil
	if not IsValidHandle(unit) then
		return true
	end

	local lock = unit:FindModifierByName(LOCK_MODIFIER)
	if not IsValidHandle(lock) then
		return true
	end

	local level = ability:GetLevel()
	local cooldown = 0
	if ability.GetEffectiveCooldown then
		cooldown = ability:GetEffectiveCooldown(level - 1)
	elseif ability.GetCooldown then
		cooldown = ability:GetCooldown(level - 1)
	end
	if cooldown <= 0 then
		cooldown = 0.1
	end
	local am = lock:GetCaster()
	ability:StartCooldown(cooldown)

	unit:EmitSound("Hero_Antimage.Counterspell.Absorb")
	lock:Destroy()

	if IsValidHandle(am) then
		local mark = am:FindAbilityByName(MARK_ABILITY)
		if IsValidHandle(mark) and mark.TryMarkUnit then
			mark:TryMarkUnit(unit)
		end
	end
	return false
end

antimage_counterspell_trinity = class({})

function antimage_counterspell_trinity:Precache(context)
	if self:GetCaster() and self:GetCaster():IsIllusion() then
		return
	end

	PrecacheResource("soundfile", SOUND_FILE, context)
	PrecacheResource("particle", PARTICLE_SHIELD, context)
	PrecacheResource("particle", PARTICLE_STATUS, context)
	PrecacheResource("particle", PARTICLE_MARK, context)
end

function antimage_counterspell_trinity:GetIntrinsicModifierName()
	return "modifier_antimage_counterspell_trinity"
end

function antimage_counterspell_trinity:GetCastRange(_, _)
	return self:GetSpecialValueFor("AbilityCastRange")
end

function antimage_counterspell_trinity:OnSpellStart()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	if not IsValidHandle(caster) or not IsValidHandle(target) then
		return
	end
	if target:TriggerSpellAbsorb(self) then
		return
	end

	local duration = self:GetSpecialValueFor("duration")
	if duration <= 0 then
		duration = 3
	end
	if target.GetStatusResistance then
		duration = duration * (1 - (target:GetStatusResistance() or 0))
	end

	target:AddNewModifier(caster, self, LOCK_MODIFIER, { duration = duration })
	caster:EmitSound("Hero_Antimage.Counterspell.Cast")
	target:EmitSound("Hero_Antimage.Counterspell.Target")
end

modifier_antimage_counterspell_trinity = class({})

function modifier_antimage_counterspell_trinity:IsHidden()
	return true
end

function modifier_antimage_counterspell_trinity:IsPurgable()
	return false
end

function modifier_antimage_counterspell_trinity:RemoveOnDeath()
	return false
end

function modifier_antimage_counterspell_trinity:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
	}
end

function modifier_antimage_counterspell_trinity:GetModifierMagicalResistanceBonus()
	local parent = self:GetParent()
	local ability = self:GetAbility()
	if not IsValidHandle(parent) or not IsValidHandle(ability) then
		return 0
	end
	if ability:GetLevel() < 1 then
		return 0
	end
	if parent.PassivesDisabled and parent:PassivesDisabled() then
		return 0
	end
	return ability:GetSpecialValueFor("magic_resistance")
end

modifier_antimage_counterspell_trinity_lock = class({})

function modifier_antimage_counterspell_trinity_lock:IsHidden()
	return false
end

function modifier_antimage_counterspell_trinity_lock:IsDebuff()
	return true
end

function modifier_antimage_counterspell_trinity_lock:IsPurgable()
	return true
end

function modifier_antimage_counterspell_trinity_lock:GetTexture()
	return "antimage_counterspell"
end

function modifier_antimage_counterspell_trinity_lock:GetStatusEffectName()
	return PARTICLE_STATUS
end

function modifier_antimage_counterspell_trinity_lock:StatusEffectPriority()
	return MODIFIER_PRIORITY_HIGH
end

function modifier_antimage_counterspell_trinity_lock:OnCreated()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if not IsValidHandle(parent) then
		return
	end

	local origin = parent:GetAbsOrigin()
	local radius = Vector(SHIELD_RADIUS, 0, 0)

	local shield = ParticleManager:CreateParticle(PARTICLE_SHIELD, PATTACH_ABSORIGIN_FOLLOW, parent)
	ParticleManager:SetParticleControlEnt(shield, 0, parent, PATTACH_POINT_FOLLOW, "attach_hitloc", origin, true)
	ParticleManager:SetParticleControl(shield, 1, radius)
	self:AddParticle(shield, false, false, -1, false, false)
end
