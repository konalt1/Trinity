LinkLuaModifier("modifier_chen_holy_persuasion_mind_hp", "modifiers/chen/modifier_chen_holy_persuasion_mind_hp", LUA_MODIFIER_MOTION_NONE)

-- После ванильного chen_holy_persuasion поднимает минимальное макс. HP крипа:
-- 400 + GetHeroMindPower(caster) * 10 (если движок выставил меньший потолок).

modifier_chen_holy_persuasion_mind_hp = class({})

function modifier_chen_holy_persuasion_mind_hp:IsHidden()
	return true
end

function modifier_chen_holy_persuasion_mind_hp:IsPurgable()
	return false
end

function modifier_chen_holy_persuasion_mind_hp:RemoveOnDeath()
	return false
end

local BASE_MIN_HP = 400
local MIND_POWER_MULT = 10

function modifier_chen_holy_persuasion_mind_hp:DeclareFunctions()
	return { MODIFIER_EVENT_ON_ABILITY_EXECUTED }
end

function modifier_chen_holy_persuasion_mind_hp:OnAbilityExecuted(params)
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if not parent or parent:IsNull() or params.unit ~= parent then
		return
	end

	local ability = params.ability
	local abName = ability:GetAbilityName()
	if abName ~= "chen_holy_persuasion" and abName ~= "chen_holy_persuasion_custom" then
		return
	end

	local target = params.target
	if not target or target:IsNull() or not target:IsAlive() or not target:IsCreep() then
		return
	end

	local mind = 0
	if GetHeroMindPower then
		mind = GetHeroMindPower(parent) or 0
	else
		mind = parent:GetIntellect(false) or 0
	end

	local desired_min = BASE_MIN_HP + mind * MIND_POWER_MULT

	Timers:CreateTimer(0, function()
		if not target or target:IsNull() or not target:IsAlive() then
			return
		end
		local cur_max = target:GetMaxHealth()
		if cur_max >= desired_min then
			return
		end
		local hp = target:GetHealth()
		local old_max = math.max(cur_max, 1)
		target:SetBaseMaxHealth(desired_min)
		target:SetMaxHealth(desired_min)
		local new_hp = math.min(desired_min, math.floor(hp * desired_min / old_max))
		target:SetHealth(math.max(1, new_hp))
	end)
end
