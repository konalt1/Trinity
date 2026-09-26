LinkLuaModifier("modifier_trinity_item_inherit", "items/item_shop_rework_inherit", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_trinity_afterburn", "items/item_shop_rework_inherit", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_trinity_pollinate_aura", "items/item_shop_rework_inherit", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_trinity_pollinate_debuff", "items/item_shop_rework_inherit", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_trinity_orb_frost", "items/item_shop_rework_inherit", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_trinity_orb_venom", "items/item_shop_rework_inherit", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_trinity_spell_weakness_aura", "items/item_shop_rework_inherit", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_trinity_spell_weakness_debuff", "items/item_shop_rework_inherit", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_trinity_phylactery_slow", "items/item_shop_rework_inherit", LUA_MODIFIER_MOTION_NONE)

-- Статы компонентов + уникальные пассивки, которые C++ результата не читает.
-- Актив результата не дублируется второй кнопкой.

local INVENTORY_SLOT_END = 5
local EX_MACHINA_NAME = "item_ex_machina"

local ITEM_STAT_KEYS = {
	item_foragers_kit = { "bonus_all_stats", "bonus_health_regen" },
	item_essence_ring = { "bonus_strength", "bonus_health_regen" },
	item_psychic_headband = { "bonus_intellect", "bonus_health" },
	item_minotaur_horn = { "bonus_strength" },
	item_serrated_shiv = { "bonus_damage", "bonus_health", "bonus_mana_regen" },
	item_conjurers_catalyst = {
		"bonus_all_stats",
		"bonus_health_regen",
		"bonus_mana_regen",
		"bonus_health",
		"bonus_intellect",
		"spell_amp",
		"spell_lifesteal",
	},
	item_dezun_bloodrite = { "bonus_strength", "bonus_armor" },
	item_fallen_sky = { "bonus_all_stats", "mana_regen_multiplier" },
	item_divine_regalia = { "bonus_damage" },
	item_blade_mail = { "bonus_health_regen" },
	item_force_staff = { "cast_range" },
	item_hurricane_pike = { "cast_range" },
	item_radiance = { "bonus_armor", "magic_resistance" },
	item_rapier = { "outgoing_damage" },
	item_mind_breaker = {
		"bonus_damage",
		"bonus_health",
		"bonus_mana_regen",
		"bonus_intellect",
	},
	item_dragon_scale = { "bonus_armor" },
	item_mango_tree = { "bonus_all_stats" },
	item_ex_machina = { "bonus_health_regen", "bonus_mana_regen" },
	item_lotus_orb = { "bonus_all_stats" },
	item_hand_of_midas = { "bonus_armor" },
}

local AFTERBURN_ITEMS = {
	item_cloak_of_flames = true,
	item_radiance = true,
}

local ORB_ITEMS = {
	item_jidi_pollen_bag = true,
	item_shivas_guard = true,
}

local GUT_EM_ITEMS = {
	item_mind_breaker = true,
}

local JAVELIN_ITEMS = {
	item_serrated_shiv = true,
	item_mind_breaker = true,
}

local POLLINATE_ITEMS = {
	item_shivas_guard = true,
}

local SPELL_WEAKNESS_ITEMS = {
	item_conjurers_catalyst = true,
}

local PHYLACTERY_ITEMS = {
	item_conjurers_catalyst = true,
}

local REFLECT_ITEMS = {
	item_lotus_orb = true,
}

-- C++-интринсики компонентов. OnAttackLanded у item-модификаторов в Trinity не стреляет,
-- поэтому атаки дополнительно обрабатывает DamageFilter.
local CPP_INTRINSICS = {
	{
		items = JAVELIN_ITEMS,
		modifiers = { "modifier_item_javelin" },
		flag = "javelin",
	},
	{
		items = GUT_EM_ITEMS,
		modifiers = { "modifier_item_serrated_shiv", "modifier_item_serratedshiv" },
		flag = "gut_em",
	},
	{
		items = ORB_ITEMS,
		modifiers = { "modifier_item_orb_of_frost" },
		flag = "frost",
		phantom = "item_orb_of_frost",
	},
	{
		items = ORB_ITEMS,
		modifiers = { "modifier_item_orb_of_venom" },
		flag = "venom",
		phantom = "item_orb_of_venom",
	},
	{
		items = PHYLACTERY_ITEMS,
		modifiers = { "modifier_item_phylactery" },
		flag = "phylactery",
	},
	{
		items = REFLECT_ITEMS,
		modifiers = { "modifier_item_mirror_shield" },
		flag = "mirror",
	},
}

local PHYLACTERY_STAT_KEYS = {
	bonus_all_stats = true,
	bonus_health_regen = true,
	bonus_mana_regen = true,
}

function EnsureShopReworkInherit(hero)
	if not hero or hero:IsNull() or not hero.IsRealHero or not hero:IsRealHero() then
		return
	end

	if hero.IsIllusion and hero:IsIllusion() then
		return
	end

	local modifier = hero:FindModifierByName("modifier_trinity_item_inherit")
	if modifier then
		modifier:ForceRefresh()
	else
		hero:AddNewModifier(hero, nil, "modifier_trinity_item_inherit", {})
	end
end

local function Special(item, key)
	if not item or item:IsNull() then
		return 0
	end

	return item:GetSpecialValueFor(key) or 0
end

local function EmptyStats()
	return {
		strength = 0,
		intellect = 0,
		all_stats = 0,
		health = 0,
		health_regen = 0,
		mana_regen = 0,
		armor = 0,
		magic_resistance = 0,
		damage = 0,
		spell_amp = 0,
		spell_lifesteal = 0,
		cast_range = 0,
		outgoing_damage = 0,
		mana_regen_multiplier = 0,
		attack_speed = 0,
		agility = 0,
		hp_regen_amp = 0,
	}
end

local function AddStat(stats, key, value)
	if key == "bonus_all_stats" then
		stats.all_stats = stats.all_stats + value
	elseif key == "bonus_strength" then
		stats.strength = stats.strength + value
	elseif key == "bonus_agility" then
		stats.agility = stats.agility + value
	elseif key == "bonus_intellect" then
		stats.intellect = stats.intellect + value
	elseif key == "bonus_health" then
		stats.health = stats.health + value
	elseif key == "bonus_health_regen" then
		stats.health_regen = stats.health_regen + value
	elseif key == "bonus_mana_regen" then
		stats.mana_regen = stats.mana_regen + value
	elseif key == "bonus_armor" then
		stats.armor = stats.armor + value
	elseif key == "magic_resistance" then
		stats.magic_resistance = stats.magic_resistance + value
	elseif key == "bonus_damage" then
		stats.damage = stats.damage + value
	elseif key == "spell_amp" then
		stats.spell_amp = stats.spell_amp + value
	elseif key == "spell_lifesteal" then
		stats.spell_lifesteal = stats.spell_lifesteal + value
	elseif key == "cast_range" then
		stats.cast_range = stats.cast_range + value
	elseif key == "outgoing_damage" then
		stats.outgoing_damage = stats.outgoing_damage + value
	elseif key == "mana_regen_multiplier" then
		stats.mana_regen_multiplier = stats.mana_regen_multiplier + value
	elseif key == "bonus_attack_speed" then
		stats.attack_speed = stats.attack_speed + value
	elseif key == "hp_regen_amp" then
		stats.hp_regen_amp = stats.hp_regen_amp + value
	end
end

local function FindNamedItem(hero, name_set)
	if not hero or hero:IsNull() then
		return nil
	end

	for slot = 0, INVENTORY_SLOT_END do
		local item = hero:GetItemInSlot(slot)
		if item and not item:IsNull() and name_set[item:GetAbilityName()] then
			return item
		end
	end

	return nil
end

local function IsCombatTarget(unit)
	if not unit or unit:IsNull() then
		return false
	end

	if unit.IsBuilding and unit:IsBuilding() then
		return false
	end

	if unit.IsOther and unit:IsOther() then
		return false
	end

	if unit.IsMagicImmune and unit:IsMagicImmune() then
		return false
	end

	return true
end

local function DealMagical(attacker, victim, item, damage)
	if damage <= 0 or not attacker or not victim then
		return
	end

	ApplyDamage({
		victim = victim,
		attacker = attacker,
		damage = damage,
		damage_type = DAMAGE_TYPE_MAGICAL,
		damage_flags = DOTA_DAMAGE_FLAG_NONE,
		ability = item,
	})
end

local function SyncAura(hero, modifier_name, item)
	local modifier = hero:FindModifierByName(modifier_name)
	if item then
		if not modifier then
			hero:AddNewModifier(hero, item, modifier_name, {})
		elseif modifier:GetAbility() ~= item then
			modifier:Destroy()
			hero:AddNewModifier(hero, item, modifier_name, {})
		end
	elseif modifier then
		modifier:Destroy()
	end
end

local function RefreshAbilityOrItem(ability)
	if not ability or ability:IsNull() then
		return
	end

	if ability.GetAbilityName and ability:GetAbilityName() == EX_MACHINA_NAME then
		return
	end

	ability:EndCooldown()
	if ability.RefreshCharges then
		ability:RefreshCharges()
	end
end

local function RefreshAllCooldowns(hero)
	if not hero or hero:IsNull() then
		return
	end

	for i = 0, hero:GetAbilityCount() - 1 do
		RefreshAbilityOrItem(hero:GetAbilityByIndex(i))
	end

	for slot = 0, 15 do
		RefreshAbilityOrItem(hero:GetItemInSlot(slot))
	end
end

local function TryRefreshFromExMachina(hero)
	if not hero or hero:IsNull() then
		return
	end

	local now = GameRules:GetGameTime()
	if hero._trinity_ex_machina_refresh and now < hero._trinity_ex_machina_refresh + 0.2 then
		return
	end

	hero._trinity_ex_machina_refresh = now
	RefreshAllCooldowns(hero)
end

local function IsExMachinaAbility(ability)
	return ability and not ability:IsNull() and ability.GetAbilityName and ability:GetAbilityName() == EX_MACHINA_NAME
end

local function HasCpp(mod, flag)
	return mod and mod.cpp and type(mod.cpp[flag]) == "string"
end

local function PhantomItem(hero, name)
	if not hero or hero:IsNull() or not name then
		return nil
	end

	hero._trinity_phantoms = hero._trinity_phantoms or {}
	local item = hero._trinity_phantoms[name]
	if item and not item:IsNull() then
		return item
	end

	item = CreateItem(name, hero, hero)
	if not item then
		return nil
	end

	item:SetPurchaseTime(0)
	pcall(function()
		item:SetSellable(false)
		item:SetDroppable(false)
		item:SetCanBeUsedOutOfInventory(true)
	end)
	hero._trinity_phantoms[name] = item
	return item
end

local function TryAddCppModifier(hero, ability, names)
	if not hero or hero:IsNull() or not ability or ability:IsNull() then
		return nil
	end

	for _, name in ipairs(names) do
		local existing = hero:FindModifierByName(name)
		if existing then
			return name
		end

		local ok, modifier = pcall(function()
			return hero:AddNewModifier(hero, ability, name, {})
		end)
		if ok and modifier then
			return name
		end
	end

	return nil
end

local function SyncCppIntrinsics(hero, inherit_mod)
	if not inherit_mod then
		return
	end

	inherit_mod.cpp = inherit_mod.cpp or {}

	for _, spec in ipairs(CPP_INTRINSICS) do
		local source = FindNamedItem(hero, spec.items)
		if source then
			if not inherit_mod.cpp[spec.flag] then
				local ability = source
				if spec.phantom then
					ability = PhantomItem(hero, spec.phantom) or source
				end
				inherit_mod.cpp[spec.flag] = TryAddCppModifier(hero, ability, spec.modifiers) or false
			end
		else
			local added = inherit_mod.cpp[spec.flag]
			if type(added) == "string" then
				local modifier = hero:FindModifierByName(added)
				if modifier then
					local ability = modifier:GetAbility()
					local ability_name = ability and not ability:IsNull() and ability:GetAbilityName() or nil
					if not ability_name or spec.items[ability_name] or ability_name == spec.phantom then
						modifier:Destroy()
					end
				end
			end
			inherit_mod.cpp[spec.flag] = nil
		end
	end
end

local function SyncPollinate(hero)
	local source = FindNamedItem(hero, POLLINATE_ITEMS)
	if not source then
		SyncAura(hero, "modifier_trinity_pollinate_aura", nil)
		return
	end

	if hero._trinity_pollinate_cpp == false then
		SyncAura(hero, "modifier_trinity_pollinate_aura", source)
		return
	end

	local radius = Special(source, "debuff_radius")
	if radius <= 0 then
		return
	end

	local enemies = FindUnitsInRadius(
		hero:GetTeamNumber(),
		hero:GetAbsOrigin(),
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	local used_cpp = false
	for _, enemy in ipairs(enemies) do
		if enemy and not enemy:IsNull() then
			local ok, modifier = pcall(function()
				return enemy:AddNewModifier(hero, source, "modifier_item_jidi_pollen_bag", { duration = 1.3 })
			end)
			if ok and modifier then
				used_cpp = true
			end
		end
	end

	if used_cpp then
		hero._trinity_pollinate_cpp = true
		SyncAura(hero, "modifier_trinity_pollinate_aura", nil)
	elseif #enemies > 0 then
		hero._trinity_pollinate_cpp = false
		SyncAura(hero, "modifier_trinity_pollinate_aura", source)
	end
end

local function ApplyInheritedAttack(attacker, target)
	if not attacker or attacker:IsNull() or not target or target:IsNull() then
		return
	end

	if target.GetTeamNumber and target:GetTeamNumber() == attacker:GetTeamNumber() then
		return
	end

	if target.IsOther and target:IsOther() then
		return
	end

	local inherit = attacker:FindModifierByName("modifier_trinity_item_inherit")
	if not inherit then
		return
	end

	local afterburn = FindNamedItem(attacker, AFTERBURN_ITEMS)
	if afterburn and (not target.IsMagicImmune or not target:IsMagicImmune() or (target.IsBuilding and target:IsBuilding())) then
		local duration = Special(afterburn, "duration")
		if duration > 0 then
			local ok, modifier = pcall(function()
				return target:AddNewModifier(attacker, afterburn, "modifier_dragon_scale_burn", { duration = duration })
			end)
			if not (ok and modifier) then
				target:AddNewModifier(attacker, afterburn, "modifier_trinity_afterburn", { duration = duration })
			end
		end
	end

	if not IsCombatTarget(target) then
		return
	end

	if not HasCpp(inherit, "frost") or not HasCpp(inherit, "venom") then
		local orbs = FindNamedItem(attacker, ORB_ITEMS)
		if orbs then
			if not HasCpp(inherit, "frost") then
				local frost_duration = Special(orbs, "frost_duration")
				if frost_duration > 0 then
					target:AddNewModifier(attacker, orbs, "modifier_trinity_orb_frost", { duration = frost_duration })
				end
			end

			if not HasCpp(inherit, "venom") then
				local poison_duration = Special(orbs, "poison_duration")
				if poison_duration > 0 then
					target:AddNewModifier(attacker, orbs, "modifier_trinity_orb_venom", { duration = poison_duration })
				end
			end
		end
	end

	if not HasCpp(inherit, "gut_em") then
		local now = GameRules:GetGameTime()
		local gut = FindNamedItem(attacker, GUT_EM_ITEMS)
		if gut and now >= (inherit.gut_em_ready or 0) then
			local chance = Special(gut, "proc_chance")
			if chance > 0 and RandomInt(1, 100) <= chance then
				inherit.gut_em_ready = now + 1.5
				local damage
				if target.IsRoshan and target:IsRoshan() then
					damage = Special(gut, "hp_dmg_rosh")
				else
					damage = target:GetHealth() * Special(gut, "hp_dmg") / 100
				end
				DealMagical(attacker, target, gut, damage)
			end
		end
	end

	if not HasCpp(inherit, "javelin") then
		local javelin = FindNamedItem(attacker, JAVELIN_ITEMS)
		if javelin then
			local chance = Special(javelin, "bonus_chance")
			if chance > 0 and RandomInt(1, 100) <= chance then
				DealMagical(attacker, target, javelin, Special(javelin, "bonus_chance_damage"))
			end
		end
	end
end

function TrinityItemInherit_DamageFilter(event)
	if not event then
		return true
	end

	local inflictor_idx = event.entindex_inflictor_const or event.entindex_inflictor
	if inflictor_idx and inflictor_idx ~= 0 then
		return true
	end

	local damage_type = event.damagetype_const or event.damage_type or event.damagetype
	if damage_type and damage_type ~= DAMAGE_TYPE_PHYSICAL then
		return true
	end

	local victim_idx = event.entindex_victim_const or event.entindex_victim
	local attacker_idx = event.entindex_attacker_const or event.entindex_attacker
	local victim = victim_idx and EntIndexToHScript(victim_idx) or nil
	local attacker = attacker_idx and EntIndexToHScript(attacker_idx) or nil
	if not victim or victim:IsNull() or not attacker or attacker:IsNull() then
		return true
	end

	if not attacker.IsRealHero or not attacker:IsRealHero() then
		return true
	end

	ApplyInheritedAttack(attacker, victim)
	return true
end

modifier_trinity_item_inherit = class({})

function modifier_trinity_item_inherit:IsHidden()
	return true
end

function modifier_trinity_item_inherit:IsPurgable()
	return false
end

function modifier_trinity_item_inherit:RemoveOnDeath()
	return false
end

function modifier_trinity_item_inherit:OnCreated()
	self.stats = EmptyStats()
	self.cpp = {}
	self.phylactery_ready = false
	self.gut_em_ready = 0
	self.reflect_ready = 0
	if not IsServer() then
		return
	end

	self:RefreshStats()
	self:StartIntervalThink(0.25)
end

function modifier_trinity_item_inherit:OnRefresh()
	self:RefreshStats()
	if IsServer() then
		self:StartIntervalThink(0.25)
	end
end

function modifier_trinity_item_inherit:OnIntervalThink()
	self:RefreshStats()
end

function modifier_trinity_item_inherit:RefreshStats()
	local stats = EmptyStats()
	local hero = self:GetParent()
	if not hero or hero:IsNull() then
		self.stats = stats
		return
	end

	if IsServer() then
		SyncCppIntrinsics(hero, self)
	end

	for slot = 0, INVENTORY_SLOT_END do
		local item = hero:GetItemInSlot(slot)
		if item and not item:IsNull() then
			local item_name = item:GetAbilityName()
			local keys = ITEM_STAT_KEYS[item_name]
			if keys then
				local skip_phylactery = item_name == "item_conjurers_catalyst" and hero:HasModifier("modifier_item_phylactery")
				local skip_mirror = item_name == "item_lotus_orb" and hero:HasModifier("modifier_item_mirror_shield")
				for _, key in ipairs(keys) do
					if skip_phylactery and PHYLACTERY_STAT_KEYS[key] then
					elseif skip_mirror and key == "bonus_all_stats" then
					else
						AddStat(stats, key, Special(item, key))
					end
				end
			end
		end
	end

	self.stats = stats

	if not IsServer() then
		return
	end

	SyncPollinate(hero)
	SyncAura(hero, "modifier_trinity_spell_weakness_aura", FindNamedItem(hero, SPELL_WEAKNESS_ITEMS))
end

function modifier_trinity_item_inherit:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
		MODIFIER_PROPERTY_HEALTH_BONUS,
		MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
		MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,
		MODIFIER_PROPERTY_CAST_RANGE_BONUS,
		MODIFIER_PROPERTY_DAMAGEOUTGOING_PERCENTAGE,
		MODIFIER_PROPERTY_MANA_REGEN_TOTAL_PERCENTAGE,
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_HP_REGEN_AMPLIFY_PERCENTAGE,
		MODIFIER_EVENT_ON_TAKEDAMAGE,
		MODIFIER_EVENT_ON_ABILITY_FULLY_CAST,
		MODIFIER_EVENT_ON_ABILITY_EXECUTED,
	}
end

function modifier_trinity_item_inherit:GetModifierBonusStats_Strength()
	local stats = self.stats or EmptyStats()
	return stats.strength + stats.all_stats
end

function modifier_trinity_item_inherit:GetModifierBonusStats_Agility()
	local stats = self.stats or EmptyStats()
	return stats.agility + stats.all_stats
end

function modifier_trinity_item_inherit:GetModifierBonusStats_Intellect()
	local stats = self.stats or EmptyStats()
	return stats.intellect + stats.all_stats
end

function modifier_trinity_item_inherit:GetModifierHealthBonus()
	return (self.stats or EmptyStats()).health
end

function modifier_trinity_item_inherit:GetModifierConstantHealthRegen()
	return (self.stats or EmptyStats()).health_regen
end

function modifier_trinity_item_inherit:GetModifierConstantManaRegen()
	return (self.stats or EmptyStats()).mana_regen
end

function modifier_trinity_item_inherit:GetModifierPhysicalArmorBonus()
	return (self.stats or EmptyStats()).armor
end

function modifier_trinity_item_inherit:GetModifierMagicalResistanceBonus()
	return (self.stats or EmptyStats()).magic_resistance
end

function modifier_trinity_item_inherit:GetModifierPreAttack_BonusDamage()
	return (self.stats or EmptyStats()).damage
end

function modifier_trinity_item_inherit:GetModifierSpellAmplify_Percentage()
	return (self.stats or EmptyStats()).spell_amp
end

function modifier_trinity_item_inherit:GetModifierCastRangeBonus()
	return (self.stats or EmptyStats()).cast_range
end

function modifier_trinity_item_inherit:GetModifierDamageOutgoing_Percentage()
	return (self.stats or EmptyStats()).outgoing_damage
end

function modifier_trinity_item_inherit:GetModifierTotalPercentageManaRegen()
	return (self.stats or EmptyStats()).mana_regen_multiplier
end

function modifier_trinity_item_inherit:GetModifierAttackSpeedBonus_Constant()
	return (self.stats or EmptyStats()).attack_speed
end

function modifier_trinity_item_inherit:GetModifierHPRegenAmplify_Percentage()
	return (self.stats or EmptyStats()).hp_regen_amp
end

function modifier_trinity_item_inherit:OnTakeDamage(params)
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	local flags = params.damage_flags or 0
	local reflected = bit.band(flags, DOTA_DAMAGE_FLAG_REFLECTION) ~= 0

	if params.attacker == parent and params.unit ~= parent and params.inflictor and params.damage > 0 then
		if not (params.unit.IsBuilding and params.unit:IsBuilding()) then
			local stats = self.stats or EmptyStats()
			if stats.spell_lifesteal > 0 then
				local pct = stats.spell_lifesteal
				if params.unit and not params.unit:IsHero() then
					pct = pct * 0.2
				end
				parent:Heal(params.damage * pct / 100, params.inflictor)
			end

			if self.phylactery_ready and not HasCpp(self, "phylactery") and params.unit and params.unit.IsHero and params.unit:IsHero() then
				local phylactery = FindNamedItem(parent, PHYLACTERY_ITEMS)
				if phylactery and not reflected then
					self.phylactery_ready = false
					self.phylactery_ready_at = GameRules:GetGameTime() + Special(phylactery, "phylactery_cooldown")
					DealMagical(parent, params.unit, phylactery, Special(phylactery, "bonus_spell_damage"))
					local slow_duration = Special(phylactery, "slow_duration")
					if slow_duration > 0 then
						params.unit:AddNewModifier(parent, phylactery, "modifier_trinity_phylactery_slow", {
							duration = slow_duration,
						})
					end
				end
			end
		end
	end

	if reflected or params.unit ~= parent or params.attacker == parent or params.damage <= 0 or not params.inflictor then
		return
	end

	if HasCpp(self, "mirror") then
		return
	end

	local reflect_item = FindNamedItem(parent, REFLECT_ITEMS)
	if not reflect_item then
		return
	end

	local now = GameRules:GetGameTime()
	if now < (self.reflect_ready or 0) then
		return
	end

	if RandomInt(1, 100) > Special(reflect_item, "reflect_chance") then
		return
	end

	self.reflect_ready = now + Special(reflect_item, "block_cooldown")
	ApplyDamage({
		victim = params.attacker,
		attacker = parent,
		damage = params.original_damage or params.damage,
		damage_type = params.damage_type or DAMAGE_TYPE_MAGICAL,
		damage_flags = DOTA_DAMAGE_FLAG_REFLECTION + DOTA_DAMAGE_FLAG_NO_SPELL_LIFESTEAL,
		ability = reflect_item,
	})
end

function modifier_trinity_item_inherit:TryChargePhylactery(ability)
	if not ability or ability:IsNull() or ability.IsItem and ability:IsItem() then
		return
	end

	if HasCpp(self, "phylactery") then
		return
	end

	local phylactery = FindNamedItem(self:GetParent(), PHYLACTERY_ITEMS)
	if not phylactery then
		return
	end

	if GameRules:GetGameTime() < (self.phylactery_ready_at or 0) then
		return
	end

	self.phylactery_ready = true
end

function modifier_trinity_item_inherit:OnAbilityFullyCast(params)
	if not IsServer() then
		return
	end

	if params.unit ~= self:GetParent() then
		return
	end

	if IsExMachinaAbility(params.ability) then
		TryRefreshFromExMachina(self:GetParent())
	end

	self:TryChargePhylactery(params.ability)
end

function modifier_trinity_item_inherit:OnAbilityExecuted(params)
	if not IsServer() then
		return
	end

	if params.unit ~= self:GetParent() then
		return
	end

	if IsExMachinaAbility(params.ability) then
		TryRefreshFromExMachina(self:GetParent())
	end

	self:TryChargePhylactery(params.ability)
end

modifier_trinity_afterburn = class({})

function modifier_trinity_afterburn:IsHidden()
	return false
end

function modifier_trinity_afterburn:IsDebuff()
	return true
end

function modifier_trinity_afterburn:IsPurgable()
	return true
end

function modifier_trinity_afterburn:GetTexture()
	return "item_dragon_scale"
end

function modifier_trinity_afterburn:OnCreated()
	self.dps = self:GetAbility() and self:GetAbility():GetSpecialValueFor("damage_per_sec") or 0
	if IsServer() then
		self:StartIntervalThink(1)
	end
end

function modifier_trinity_afterburn:OnRefresh()
	self.dps = self:GetAbility() and self:GetAbility():GetSpecialValueFor("damage_per_sec") or self.dps or 0
end

function modifier_trinity_afterburn:OnIntervalThink()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	local parent = self:GetParent()
	if not caster or caster:IsNull() or not parent or parent:IsNull() then
		return
	end

	DealMagical(caster, parent, self:GetAbility(), self.dps or 0)
end

modifier_trinity_pollinate_aura = class({})

function modifier_trinity_pollinate_aura:IsHidden()
	return true
end

function modifier_trinity_pollinate_aura:IsPurgable()
	return false
end

function modifier_trinity_pollinate_aura:RemoveOnDeath()
	return false
end

function modifier_trinity_pollinate_aura:IsAura()
	return true
end

function modifier_trinity_pollinate_aura:GetAuraRadius()
	return self:GetAbility() and self:GetAbility():GetSpecialValueFor("debuff_radius") or 0
end

function modifier_trinity_pollinate_aura:GetAuraSearchTeam()
	return DOTA_UNIT_TARGET_TEAM_ENEMY
end

function modifier_trinity_pollinate_aura:GetAuraSearchType()
	return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC
end

function modifier_trinity_pollinate_aura:GetAuraSearchFlags()
	return DOTA_UNIT_TARGET_FLAG_NONE
end

function modifier_trinity_pollinate_aura:GetModifierAura()
	return "modifier_trinity_pollinate_debuff"
end

modifier_trinity_pollinate_debuff = class({})

function modifier_trinity_pollinate_debuff:IsHidden()
	return false
end

function modifier_trinity_pollinate_debuff:IsDebuff()
	return true
end

function modifier_trinity_pollinate_debuff:IsPurgable()
	return false
end

function modifier_trinity_pollinate_debuff:GetTexture()
	return "item_jidi_pollen_bag"
end

function modifier_trinity_pollinate_debuff:OnCreated()
	self.health_regen_loss = self:GetAbility() and self:GetAbility():GetSpecialValueFor("health_regen_loss") or 0
	self.hp_damage = self:GetAbility() and self:GetAbility():GetSpecialValueFor("hp_damage") or 0
	local interval = self:GetAbility() and self:GetAbility():GetSpecialValueFor("damage_interval") or 1
	if IsServer() then
		self:StartIntervalThink(interval > 0 and interval or 1)
	end
end

function modifier_trinity_pollinate_debuff:OnRefresh()
	self.health_regen_loss = self:GetAbility() and self:GetAbility():GetSpecialValueFor("health_regen_loss") or self.health_regen_loss or 0
	self.hp_damage = self:GetAbility() and self:GetAbility():GetSpecialValueFor("hp_damage") or self.hp_damage or 0
end

function modifier_trinity_pollinate_debuff:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_HP_REGEN_AMPLIFY_PERCENTAGE,
	}
end

function modifier_trinity_pollinate_debuff:GetModifierHPRegenAmplify_Percentage()
	return -(self.health_regen_loss or 0)
end

function modifier_trinity_pollinate_debuff:OnIntervalThink()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	local caster = self:GetCaster()
	if not parent or parent:IsNull() or not caster or caster:IsNull() then
		return
	end

	DealMagical(caster, parent, self:GetAbility(), parent:GetMaxHealth() * (self.hp_damage or 0) / 100)
end

modifier_trinity_orb_frost = class({})

function modifier_trinity_orb_frost:IsHidden()
	return false
end

function modifier_trinity_orb_frost:IsDebuff()
	return true
end

function modifier_trinity_orb_frost:IsPurgable()
	return true
end

function modifier_trinity_orb_frost:GetTexture()
	return "item_orb_of_frost"
end

function modifier_trinity_orb_frost:OnCreated()
	local ability = self:GetAbility()
	local caster = self:GetCaster()
	self.heal_reduction = ability and ability:GetSpecialValueFor("heal_reduction") or 0
	if caster and caster.IsRangedAttacker and caster:IsRangedAttacker() then
		self.slow = ability and ability:GetSpecialValueFor("slow_ranged") or 0
	else
		self.slow = ability and ability:GetSpecialValueFor("slow_melee") or 0
	end
end

function modifier_trinity_orb_frost:OnRefresh()
	self:OnCreated()
end

function modifier_trinity_orb_frost:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_HP_REGEN_AMPLIFY_PERCENTAGE,
		MODIFIER_PROPERTY_HEAL_AMPLIFY_PERCENTAGE_TARGET,
		MODIFIER_PROPERTY_LIFESTEAL_AMPLIFY_PERCENTAGE,
	}
end

function modifier_trinity_orb_frost:GetModifierMoveSpeedBonus_Percentage()
	return self.slow or 0
end

function modifier_trinity_orb_frost:GetModifierHPRegenAmplify_Percentage()
	return -(self.heal_reduction or 0)
end

function modifier_trinity_orb_frost:GetModifierHealAmplify_PercentageTarget()
	return -(self.heal_reduction or 0)
end

function modifier_trinity_orb_frost:GetModifierLifestealRegenAmplify_Percentage()
	return -(self.heal_reduction or 0)
end

modifier_trinity_orb_venom = class({})

function modifier_trinity_orb_venom:IsHidden()
	return false
end

function modifier_trinity_orb_venom:IsDebuff()
	return true
end

function modifier_trinity_orb_venom:IsPurgable()
	return true
end

function modifier_trinity_orb_venom:GetTexture()
	return "item_orb_of_venom"
end

function modifier_trinity_orb_venom:OnCreated()
	self.damage = self:GetAbility() and self:GetAbility():GetSpecialValueFor("venom_damage") or 0
	if IsServer() then
		self:StartIntervalThink(1)
	end
end

function modifier_trinity_orb_venom:OnRefresh()
	self.damage = self:GetAbility() and self:GetAbility():GetSpecialValueFor("venom_damage") or self.damage or 0
end

function modifier_trinity_orb_venom:OnIntervalThink()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	local parent = self:GetParent()
	if not caster or caster:IsNull() or not parent or parent:IsNull() then
		return
	end

	DealMagical(caster, parent, self:GetAbility(), self.damage or 0)
end

modifier_trinity_spell_weakness_aura = class({})

function modifier_trinity_spell_weakness_aura:IsHidden()
	return true
end

function modifier_trinity_spell_weakness_aura:IsPurgable()
	return false
end

function modifier_trinity_spell_weakness_aura:RemoveOnDeath()
	return false
end

function modifier_trinity_spell_weakness_aura:IsAura()
	return true
end

function modifier_trinity_spell_weakness_aura:GetAuraRadius()
	return self:GetAbility() and self:GetAbility():GetSpecialValueFor("aura_radius") or 0
end

function modifier_trinity_spell_weakness_aura:GetAuraSearchTeam()
	return DOTA_UNIT_TARGET_TEAM_ENEMY
end

function modifier_trinity_spell_weakness_aura:GetAuraSearchType()
	return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC
end

function modifier_trinity_spell_weakness_aura:GetModifierAura()
	return "modifier_trinity_spell_weakness_debuff"
end

modifier_trinity_spell_weakness_debuff = class({})

function modifier_trinity_spell_weakness_debuff:IsHidden()
	return false
end

function modifier_trinity_spell_weakness_debuff:IsDebuff()
	return true
end

function modifier_trinity_spell_weakness_debuff:IsPurgable()
	return false
end

function modifier_trinity_spell_weakness_debuff:GetTexture()
	return "item_bloodstone"
end

function modifier_trinity_spell_weakness_debuff:OnCreated()
	self.weakness = self:GetAbility() and self:GetAbility():GetSpecialValueFor("aura_spell_vulnerability") or 0
end

function modifier_trinity_spell_weakness_debuff:OnRefresh()
	self:OnCreated()
end

function modifier_trinity_spell_weakness_debuff:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
	}
end

function modifier_trinity_spell_weakness_debuff:GetModifierIncomingDamage_Percentage(params)
	if params and params.damage_type == DAMAGE_TYPE_MAGICAL then
		return self.weakness or 0
	end

	return 0
end

modifier_trinity_phylactery_slow = class({})

function modifier_trinity_phylactery_slow:IsHidden()
	return false
end

function modifier_trinity_phylactery_slow:IsDebuff()
	return true
end

function modifier_trinity_phylactery_slow:IsPurgable()
	return true
end

function modifier_trinity_phylactery_slow:GetTexture()
	return "item_phylactery"
end

function modifier_trinity_phylactery_slow:OnCreated()
	self.slow = self:GetAbility() and self:GetAbility():GetSpecialValueFor("slow") or 0
end

function modifier_trinity_phylactery_slow:OnRefresh()
	self:OnCreated()
end

function modifier_trinity_phylactery_slow:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
	}
end

function modifier_trinity_phylactery_slow:GetModifierMoveSpeedBonus_Percentage()
	return -(self.slow or 0)
end

if IsServer() and not _G._trinity_ex_machina_listener then
	_G._trinity_ex_machina_listener = true
	ListenToGameEvent("dota_player_used_ability", function(event)
		if not event or event.abilityname ~= EX_MACHINA_NAME then
			return
		end

		local player_id = event.PlayerID
		if player_id == nil then
			return
		end

		TryRefreshFromExMachina(PlayerResource:GetSelectedHeroEntity(player_id))
	end, nil)
end

if IsServer() and PlayerResource then
	for player_id = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		EnsureShopReworkInherit(PlayerResource:GetSelectedHeroEntity(player_id))
	end
end
