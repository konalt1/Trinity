LinkLuaModifier("modifier_chen_barrack_producing", "abilities/chen/chen_barrack", LUA_MODIFIER_MOTION_NONE)

chen_barrack = class({})
chen_barrack_summon_t1 = class({})
chen_barrack_summon_t2 = class({})
chen_barrack_summon_t3 = class({})
chen_barrack_summon_ancient = class({})
chen_barrack_self_destruct = class({})
modifier_chen_barrack_producing = class({})

local BARRACK_MODEL = "models/props_structures/good_barracks_melee001.vmdl"

local function GetTalentValue(hero, talentName, valueName, fallback)
	if not hero or hero:IsNull() then
		return fallback or 0
	end

	local talent = hero:FindAbilityByName(talentName)
	if not talent or talent:IsNull() or talent:GetLevel() <= 0 then
		return fallback or 0
	end

	local value = 0
	if valueName then
		value = talent:GetSpecialValueFor(valueName)
	end
	if value == 0 then
		value = talent:GetSpecialValueFor("value")
	end

	return value or fallback or 0
end

local function HasScepterUpgrade(hero)
	if not hero or hero:IsNull() then
		return false
	end
	if hero.HasScepter and hero:HasScepter() then
		return true
	end
	return hero:HasModifier("modifier_item_ultimate_scepter") or hero:HasModifier("modifier_item_ultimate_scepter_consumed")
end

local CHEN_BARRACK_FAMILIES = {
	{ "centaur", { "npc_dota_neutral_kobold_taskmaster", "npc_dota_neutral_centaur_outrunner", "npc_dota_neutral_centaur_khan" } },
	{ "satyr", { "npc_dota_neutral_satyr_trickster", "npc_dota_neutral_satyr_soulstealer", "npc_dota_neutral_satyr_hellcaller", "npc_dota_neutral_prowler_shaman" } },
	{ "troll", { "npc_dota_neutral_forest_troll_berserker", "npc_dota_neutral_ogre_magi", "npc_dota_neutral_ogre_mauler", "npc_dota_neutral_ice_shaman" } },
	{ "wolf", { "npc_dota_neutral_vhoul_assassin", "npc_dota_neutral_giant_wolf", "npc_dota_neutral_alpha_wolf", "npc_dota_neutral_thunderhide" } },
	{ "golem", { "npc_dota_neutral_mud_golem_tiny", "npc_dota_neutral_mud_golem", "npc_dota_neutral_rock_golem", "npc_dota_neutral_granite_golem" } },
	{ "harpy", { "npc_dota_neutral_harpy_scout", "npc_dota_neutral_harpy_storm", "npc_dota_neutral_black_drake", "npc_dota_neutral_black_dragon" } },
	{ "dragon", { "npc_dota_neutral_harpy_scout", "npc_dota_neutral_harpy_storm", "npc_dota_neutral_black_drake", "npc_dota_neutral_black_dragon" } },
	{ "furbolg", { nil, "npc_dota_neutral_polar_furbolg_champion", "npc_dota_neutral_polar_furbolg_ursa_warrior" } },
	{ "bear", { nil, "npc_dota_neutral_polar_furbolg_champion", "npc_dota_neutral_polar_furbolg_ursa_warrior" } },
	{ "warpine", { nil, nil, "npc_dota_neutral_warpine_raider" } },
	{ "wildkin", { "npc_dota_neutral_wildkin", nil, "npc_dota_neutral_enraged_wildkin" } },
	{ "frog", { "npc_dota_neutral_froglet", "npc_dota_neutral_grown_frog", "npc_dota_neutral_grown_frog", "npc_dota_neutral_ancient_frog" } },
}

local function IsChenBarrackUnit(unit)
	if not unit or unit:IsNull() then
		return false
	end

	local unitName = unit:GetUnitName() or ""
	return string.find(unitName, "npc_chen_barrack", 1, true) == 1
end

local function IsChenTamedCreep(unit, caster)
	if not unit or unit:IsNull() or not unit:IsAlive() then
		return false
	end

	if not unit:IsCreep() or unit:IsHero() or unit:IsAncient() then
		return false
	end

	if IsChenBarrackUnit(unit) then
		return false
	end

	if unit:GetTeamNumber() ~= caster:GetTeamNumber() then
		return false
	end

	if unit:GetPlayerOwnerID() ~= caster:GetPlayerOwnerID() then
		return false
	end

	return unit:GetOwnerEntity() == caster
end

local function GetBarrackOwnerHero(unit)
	if not unit or unit:IsNull() then
		return nil
	end

	local owner = unit:GetOwnerEntity()
	if owner and not owner:IsNull() and owner:IsRealHero() then
		return owner
	end

	if unit.chen_barrack_owner_entindex then
		local ownerFromIndex = EntIndexToHScript(unit.chen_barrack_owner_entindex)
		if ownerFromIndex and not ownerFromIndex:IsNull() and ownerFromIndex:IsRealHero() then
			return ownerFromIndex
		end
	end

	return nil
end

local function HasEnoughGold(hero, goldCost)
	if not hero or hero:IsNull() then
		return false
	end

	local playerID = hero:GetPlayerOwnerID()
	if playerID == nil or playerID < 0 then
		return false
	end

	return PlayerResource:GetGold(playerID) >= goldCost
end

local function SpendGold(hero, goldCost)
	if goldCost <= 0 then
		return
	end

	hero:ModifyGold(-goldCost, false, DOTA_ModifyGold_Unspecified)
end

local function GiveGoldToHero(hero, gold)
	if not hero or hero:IsNull() or not gold or gold <= 0 then
		return
	end

	hero:ModifyGold(gold, false, DOTA_ModifyGold_Unspecified)
end

local function LevelUnitAbilities(unit)
	if not unit or unit:IsNull() then
		return
	end

	for i = 0, 15 do
		local ab = unit:GetAbilityByIndex(i)
		if ab and not ab:IsNull() then
			local maxLv = ab:GetMaxLevel()
			if maxLv > 0 then
				ab:SetLevel(maxLv)
			end
		end
	end
end

local function LevelBarrackAbilities(barrack)
	for slot = 0, 5 do
		local ability = barrack:GetAbilityByIndex(slot)
		if ability and ability:GetLevel() == 0 then
			ability:SetLevel(1)
		end
	end
end

local function GetBarrackModel()
	return BARRACK_MODEL
end

local function GetFamilyUnitName(sourceUnitName, variant)
	if not sourceUnitName or sourceUnitName == "" then
		return nil
	end

	for _, family in ipairs(CHEN_BARRACK_FAMILIES) do
		if string.find(sourceUnitName:lower(), family[1], 1, true) then
			return family[2][variant]
		end
	end

	return nil
end

local function InitBarrackState(barrack)
	barrack.chen_production_queue = barrack.chen_production_queue or {}
	barrack.chen_reserved_gold = barrack.chen_reserved_gold or 0
	barrack.chen_production_active = barrack.chen_production_active or false
	barrack.chen_is_destroyed = barrack.chen_is_destroyed or false
end

local function GetBarrackQueuedCount(barrack)
	InitBarrackState(barrack)

	local count = #barrack.chen_production_queue
	if barrack.chen_production_active then
		count = count + 1
	end

	return count
end

local function RefundReservedGold(barrack)
	if not barrack or barrack:IsNull() then
		return
	end
	InitBarrackState(barrack)
	local ownerHero = GetBarrackOwnerHero(barrack)
	local reserved = barrack.chen_reserved_gold or 0
	if ownerHero and reserved > 0 then
		GiveGoldToHero(ownerHero, reserved)
	end
	barrack.chen_reserved_gold = 0
	barrack.chen_production_queue = {}
	barrack.chen_production_active = false
	barrack.chen_current_order = nil
end

local function CreateProductUnit(item, spawnPosition, ownerHero, teamNumber)
	local candidates = {
		item.unit_name,
		item.source_unit_name,
		item.fallback_unit_name,
	}

	for _, unitName in ipairs(candidates) do
		if unitName and unitName ~= "" then
			local summon = CreateUnitByName(unitName, spawnPosition, true, ownerHero, ownerHero, teamNumber)
			if summon then
				return summon
			end
		end
	end

	return nil
end

local function CompleteProduction(barrack, item)
	if not barrack or barrack:IsNull() or not barrack:IsAlive() or barrack.chen_is_destroyed then
		return
	end

	local ownerHero = GetBarrackOwnerHero(barrack)
	if not ownerHero then
		return
	end

	local playerID = ownerHero:GetPlayerOwnerID()
	local teamNumber = ownerHero:GetTeamNumber()
	local spawnDistance = item.spawn_distance or 200
	local spawnPosition = barrack:GetAbsOrigin() + barrack:GetForwardVector() * spawnDistance + RandomVector(80)
	local summon = CreateProductUnit(item, spawnPosition, ownerHero, teamNumber)

	if not summon then
		GiveGoldToHero(ownerHero, item.gold_cost or 0)
		barrack.chen_reserved_gold = math.max(0, (barrack.chen_reserved_gold or 0) - (item.gold_cost or 0))
		return
	end

	summon:SetOwner(ownerHero)
	summon:SetControllableByPlayer(playerID, true)
	if summon.SetPlayerID then
		summon:SetPlayerID(playerID)
	end
	summon.chen_barrack_spawned = true
	summon.chen_owner_entindex = ownerHero:entindex()
	LevelUnitAbilities(summon)
	FindClearSpaceForUnit(summon, spawnPosition, true)
	summon:Stop()

	barrack.chen_reserved_gold = math.max(0, (barrack.chen_reserved_gold or 0) - (item.gold_cost or 0))
	EmitSoundOn("Hero_Chen.TeleportLoop", summon)
end

local StartNextProduction

StartNextProduction = function(barrack)
	if not barrack or barrack:IsNull() or not barrack:IsAlive() or barrack.chen_is_destroyed then
		return
	end

	InitBarrackState(barrack)

	if barrack.chen_production_active then
		return
	end

	local item = table.remove(barrack.chen_production_queue, 1)
	if not item then
		return
	end

	barrack.chen_production_active = true
	barrack.chen_current_order = item

	local productionTime = tonumber(item.production_time) or 10
	barrack:AddNewModifier(barrack, nil, "modifier_chen_barrack_producing", { duration = productionTime, production_time = productionTime })

	Timers:CreateTimer(item.production_time or 1, function()
		if barrack and not barrack:IsNull() and barrack:IsAlive() and not barrack.chen_is_destroyed then
			CompleteProduction(barrack, item)
			barrack.chen_production_active = false
			barrack.chen_current_order = nil
			StartNextProduction(barrack)
		end
	end)
end

local function QueueBarrackUnit(self, variant)
	if not IsServer() then
		return
	end

	local barrack = self:GetCaster()
	local ownerHero = GetBarrackOwnerHero(barrack)
	if not ownerHero then
		return
	end

	local ult = ownerHero:FindAbilityByName("chen_barrack")
	if not ult then
		return
	end

	local ultLevel = ult:GetLevel()
	if variant > ultLevel and not (variant == 4 and HasScepterUpgrade(ownerHero)) then
		return
	end

	local goldCost = self:GetSpecialValueFor("gold_cost")
	goldCost = math.max(0, goldCost - GetTalentValue(ownerHero, "special_bonus_unique_custom_chen_8", "gold_cost_reduction", 0))

	if not HasEnoughGold(ownerHero, goldCost) then
		return
	end

	InitBarrackState(barrack)

	local queueLimit = 5
	if GetBarrackQueuedCount(barrack) >= queueLimit then
		return
	end

	local sourceUnitName = barrack.chen_source_unit_name
	local unitName = GetFamilyUnitName(sourceUnitName, variant)

	if not unitName then
		return
	end

	local productionTime = self:GetSpecialValueFor("production_time")
	productionTime = math.max(1, productionTime - GetTalentValue(ownerHero, "special_bonus_unique_custom_chen_8", "production_time_reduction", 0))

	SpendGold(ownerHero, goldCost)
	barrack.chen_reserved_gold = (barrack.chen_reserved_gold or 0) + goldCost

	table.insert(barrack.chen_production_queue, {
		unit_name = unitName,
		source_unit_name = sourceUnitName,
		gold_cost = goldCost,
		production_time = productionTime,
		spawn_distance = self:GetSpecialValueFor("spawn_distance"),
	})

	EmitSoundOn("General.Buy", barrack)
	StartNextProduction(barrack)
end

local function BarrackSummonCastFilter(self, variant)
	local barrack = self:GetCaster()
	local ownerHero = GetBarrackOwnerHero(barrack)
	if not ownerHero or ownerHero:IsNull() then
		return UF_FAIL_CUSTOM
	end

	local ult = ownerHero:FindAbilityByName("chen_barrack")
	if not ult then
		return UF_FAIL_CUSTOM
	end

	local ultLevel = ult:GetLevel()
	if variant > ultLevel then
		if variant == 4 then
			if not HasScepterUpgrade(ownerHero) then
				return UF_FAIL_CUSTOM
			end
		else
			return UF_FAIL_CUSTOM
		end
	end

	local sourceUnitName = barrack.chen_source_unit_name
	local unitName = GetFamilyUnitName(sourceUnitName, variant)
	if not unitName then
		return UF_FAIL_CUSTOM
	end

	InitBarrackState(barrack)
	if GetBarrackQueuedCount(barrack) >= 5 then
		return UF_FAIL_CUSTOM
	end

	local goldCost = self:GetSpecialValueFor("gold_cost")
	goldCost = math.max(0, goldCost - GetTalentValue(ownerHero, "special_bonus_unique_custom_chen_8", "gold_cost_reduction", 0))

	if not HasEnoughGold(ownerHero, goldCost) then
		return UF_FAIL_CUSTOM
	end

	return UF_SUCCESS
end

local function BarrackSummonCastError(self, variant)
	local barrack = self:GetCaster()
	local ownerHero = GetBarrackOwnerHero(barrack)
	if not ownerHero or ownerHero:IsNull() then
		return "#dota_hud_error_chen_barrack_no_owner"
	end

	local ult = ownerHero:FindAbilityByName("chen_barrack")
	if not ult then
		return "#dota_hud_error_chen_barrack_no_owner"
	end

	local ultLevel = ult:GetLevel()
	if variant > ultLevel then
		if variant == 4 then
			if not HasScepterUpgrade(ownerHero) then
				return "#dota_hud_error_chen_barrack_need_scepter"
			end
		else
			return "#dota_hud_error_chen_barrack_low_level"
		end
	end

	local sourceUnitName = barrack.chen_source_unit_name
	local unitName = GetFamilyUnitName(sourceUnitName, variant)
	if not unitName then
		return "#dota_hud_error_chen_barrack_no_unit_in_family"
	end

	InitBarrackState(barrack)
	if GetBarrackQueuedCount(barrack) >= 5 then
		return "#dota_hud_error_chen_barrack_queue_full"
	end

	local goldCost = math.max(0, self:GetSpecialValueFor("gold_cost") - GetTalentValue(ownerHero, "special_bonus_unique_custom_chen_8", "gold_cost_reduction", 0))

	if not HasEnoughGold(ownerHero, goldCost) then
		return "#dota_hud_error_not_enough_gold"
	end

	return ""
end

function chen_barrack:CastFilterResultTarget(target)
	if IsChenTamedCreep(target, self:GetCaster()) then
		return UF_SUCCESS
	end

	return UF_FAIL_CUSTOM
end

function chen_barrack:GetCustomCastErrorTarget(target)
	return "#dota_hud_error_chen_barrack_invalid_target"
end

function chen_barrack:OnSpellStart()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	if not IsChenTamedCreep(target, caster) then
		return
	end

	local teamNumber = caster:GetTeamNumber()
	local units = FindUnitsInRadius(
		teamNumber,
		caster:GetAbsOrigin(),
		nil,
		FIND_UNITS_EVERYWHERE,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY,
		DOTA_UNIT_TARGET_ALL,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	local existingBarracks = {}
	for _, unit in pairs(units) do
		if unit and not unit:IsNull() and unit:IsAlive() and unit:GetUnitName() == "npc_chen_barrack" then
			if unit.chen_barrack_owner_entindex == caster:entindex() then
				table.insert(existingBarracks, unit)
			end
		end
	end

	table.sort(existingBarracks, function(a, b)
		return (a.chen_barrack_created_time or 0) < (b.chen_barrack_created_time or 0)
	end)

	local maxBarracks = self:GetSpecialValueFor("max_barracks")
	if HasScepterUpgrade(caster) then
		maxBarracks = maxBarracks + self:GetSpecialValueFor("scepter_bonus_barracks")
	end

	while #existingBarracks >= maxBarracks do
		local oldest = table.remove(existingBarracks, 1)
		if oldest and not oldest:IsNull() then
			oldest.chen_is_destroyed = true
			RefundReservedGold(oldest)
			oldest:Kill(nil, oldest)
		end
	end

	local origin = target:GetAbsOrigin()
	local forward = target:GetForwardVector()
	local playerID = caster:GetPlayerOwnerID()
	local targetMaxHealth = math.max(target:GetMaxHealth(), target:GetHealth())
	local bonusHealth = self:GetSpecialValueFor("bonus_health")
	local minimumBarrackHealth = self:GetSpecialValueFor("minimum_barrack_health")
	local tamedSourceUnitName = target:GetUnitName()

	if target:IsAlive() then
		target:ForceKill(false)
	end
	UTIL_Remove(target)

	local barrack = CreateUnitByName("npc_chen_barrack", origin, true, caster, caster, teamNumber)
	if not barrack then
		return
	end

	barrack.chen_barrack_owner_entindex = caster:entindex()
	barrack.chen_barrack_created_time = GameRules:GetGameTime()
	barrack.chen_source_unit_name = tamedSourceUnitName
	barrack:SetOwner(caster)
	barrack:SetControllableByPlayer(playerID, true)
	barrack:SetForwardVector(forward)
	barrack:SetMoveCapability(DOTA_UNIT_CAP_MOVE_NONE)

	local barrackMaxHealth = math.max(minimumBarrackHealth, targetMaxHealth + bonusHealth)
	barrack:SetBaseMaxHealth(barrackMaxHealth)
	barrack:SetMaxHealth(barrackMaxHealth)
	barrack:SetHealth(barrackMaxHealth)

	local model = GetBarrackModel()
	barrack:SetModel(model)
	barrack:SetOriginalModel(model)

	LevelBarrackAbilities(barrack)

	EmitSoundOn("Hero_Chen.HolyPersuasionEnemy", barrack)
end

function chen_barrack_summon_t1:CastFilterResult()
	return BarrackSummonCastFilter(self, 1)
end

function chen_barrack_summon_t1:GetCustomCastError()
	return BarrackSummonCastError(self, 1)
end

function chen_barrack_summon_t1:OnSpellStart()
	QueueBarrackUnit(self, 1)
end

function chen_barrack_summon_t2:CastFilterResult()
	return BarrackSummonCastFilter(self, 2)
end

function chen_barrack_summon_t2:GetCustomCastError()
	return BarrackSummonCastError(self, 2)
end

function chen_barrack_summon_t2:OnSpellStart()
	QueueBarrackUnit(self, 2)
end

function chen_barrack_summon_t3:CastFilterResult()
	return BarrackSummonCastFilter(self, 3)
end

function chen_barrack_summon_t3:GetCustomCastError()
	return BarrackSummonCastError(self, 3)
end

function chen_barrack_summon_t3:OnSpellStart()
	QueueBarrackUnit(self, 3)
end

function chen_barrack_summon_ancient:CastFilterResult()
	return BarrackSummonCastFilter(self, 4)
end

function chen_barrack_summon_ancient:GetCustomCastError()
	return BarrackSummonCastError(self, 4)
end

function chen_barrack_summon_ancient:OnSpellStart()
	QueueBarrackUnit(self, 4)
end

function chen_barrack_self_destruct:CastFilterResult()
	local barrack = self:GetCaster()
	if not barrack or barrack:IsNull() then
		return UF_FAIL_CUSTOM
	end
	if barrack:GetUnitName() ~= "npc_chen_barrack" then
		return UF_FAIL_CUSTOM
	end
	if barrack.chen_is_destroyed then
		return UF_FAIL_CUSTOM
	end
	return UF_SUCCESS
end

function chen_barrack_self_destruct:GetCustomCastError()
	local barrack = self:GetCaster()
	if not barrack or barrack:IsNull() or barrack:GetUnitName() ~= "npc_chen_barrack" then
		return "#dota_hud_error_chen_barrack_self_destruct_invalid_target"
	end
	if barrack.chen_is_destroyed then
		return "#dota_hud_error_chen_barrack_self_destruct_dead"
	end
	return ""
end

function chen_barrack_self_destruct:OnSpellStart()
	if not IsServer() then
		return
	end

	local barrack = self:GetCaster()
	local owner = GetBarrackOwnerHero(barrack)
	local radius = self:GetSpecialValueFor("radius")
	local damage = self:GetSpecialValueFor("damage")
	local origin = barrack:GetAbsOrigin()
	local team = barrack:GetTeamNumber()

	RefundReservedGold(barrack)

	local enemies = FindUnitsInRadius(
		team,
		origin,
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	local attacker = owner or barrack
	for _, u in pairs(enemies) do
		if u and not u:IsNull() and u:IsAlive() then
			ApplyDamage({
				victim = u,
				attacker = attacker,
				damage = damage,
				damage_type = DAMAGE_TYPE_MAGICAL,
				ability = self,
			})
		end
	end

	EmitSoundOnLocationWithCaster(origin, "Hero_Techies.RemoteMine.Detonate", barrack)

	local pid = ParticleManager:CreateParticle("particles/units/heroes/hero_techies/techies_remote_mines_detonate.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(pid, 0, origin)
	ParticleManager:ReleaseParticleIndex(pid)

	barrack.chen_is_destroyed = true
	barrack:ForceKill(false)
end

function modifier_chen_barrack_producing:IsHidden()
	return false
end

function modifier_chen_barrack_producing:IsDebuff()
	return true
end

function modifier_chen_barrack_producing:IsPurgable()
	return false
end

function modifier_chen_barrack_producing:RemoveOnDeath()
	return true
end

function modifier_chen_barrack_producing:GetTexture()
	return "chen_penitence"
end
