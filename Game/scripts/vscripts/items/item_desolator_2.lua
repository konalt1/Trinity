LinkLuaModifier("modifier_item_desolator_2_trinity_crit", "items/item_desolator_2", LUA_MODIFIER_MOTION_NONE)

-- Нативный item_desolator_2 оставляет порчу. Этот модификатор добавляет крит
-- Crystalys и накопление урона Desolator, которые C++ дезолятора-2 не читает.

function EnsureStygianDesolatorCrit(hero)
	if not hero or hero:IsNull() or not hero.IsRealHero or not hero:IsRealHero() then
		return
	end

	local modifier = hero:FindModifierByName("modifier_item_desolator_2_trinity_crit")
	if modifier then
		modifier:ForceRefresh()
	else
		hero:AddNewModifier(hero, nil, "modifier_item_desolator_2_trinity_crit", {})
	end
end

local function FindStygianItem(hero)
	if not hero or hero:IsNull() then
		return nil
	end

	for slot = 0, 5 do
		local item = hero:GetItemInSlot(slot)
		if item and not item:IsNull() and item:GetAbilityName() == "item_desolator_2" then
			return item
		end
	end

	return nil
end

local function AddStygianKillDamage(hero, amount)
	local item = FindStygianItem(hero)
	if not item or amount <= 0 then
		return
	end

	local max_damage = item:GetSpecialValueFor("max_damage")
	if max_damage <= 0 then
		max_damage = 30
	end

	item._trinity_kill_damage = math.min(max_damage, (item._trinity_kill_damage or 0) + amount)
end

modifier_item_desolator_2_trinity_crit = class({})

function modifier_item_desolator_2_trinity_crit:IsHidden()
	return true
end

function modifier_item_desolator_2_trinity_crit:IsPurgable()
	return false
end

function modifier_item_desolator_2_trinity_crit:RemoveOnDeath()
	return false
end

function modifier_item_desolator_2_trinity_crit:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE,
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
	}
end

function modifier_item_desolator_2_trinity_crit:GetModifierPreAttack_CriticalStrike()
	if not IsServer() then
		return 0
	end

	local item = FindStygianItem(self:GetParent())
	if not item then
		return 0
	end

	local chance = item:GetSpecialValueFor("crit_chance")
	if chance <= 0 then
		return 0
	end

	if RandomInt(1, 100) <= chance then
		return item:GetSpecialValueFor("crit_multiplier")
	end

	return 0
end

function modifier_item_desolator_2_trinity_crit:GetModifierPreAttack_BonusDamage()
	local item = FindStygianItem(self:GetParent())
	if not item then
		return 0
	end

	return item._trinity_kill_damage or 0
end

if IsServer() and not _G._trinity_stygian_kill_listener then
	_G._trinity_stygian_kill_listener = true
	ListenToGameEvent("entity_killed", function(keys)
		local killed = EntIndexToHScript(keys.entindex_killed or 0)
		local attacker = EntIndexToHScript(keys.entindex_attacker or 0)
		if not killed or killed:IsNull() or not killed.IsRealHero or not killed:IsRealHero() then
			return
		end

		if killed.IsIllusion and killed:IsIllusion() then
			return
		end

		if not attacker or attacker:IsNull() or not attacker.IsRealHero or not attacker:IsRealHero() then
			return
		end

		local kill_item = FindStygianItem(attacker)
		if kill_item then
			AddStygianKillDamage(attacker, kill_item:GetSpecialValueFor("bonus_damage_per_kill"))
		end

		local killed_origin = killed:GetAbsOrigin()
		local heroes = HeroList:GetAllHeroes()
		for _, hero in pairs(heroes) do
			if hero and not hero:IsNull() and hero ~= attacker and hero:GetTeamNumber() == attacker:GetTeamNumber() then
				local assist_item = FindStygianItem(hero)
				if assist_item and (hero:GetAbsOrigin() - killed_origin):Length2D() <= 2200 then
					AddStygianKillDamage(hero, assist_item:GetSpecialValueFor("bonus_damage_per_assist"))
				end
			end
		end
	end, nil)
end

if IsServer() and PlayerResource then
	for player_id = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		EnsureStygianDesolatorCrit(PlayerResource:GetSelectedHeroEntity(player_id))
	end
end
