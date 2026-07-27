LinkLuaModifier('modifier_ogre_magi_reroll', 'abilities/ogre_magi/ogre_magi_reroll', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_ogre_magi_reroll_passive', 'abilities/ogre_magi/ogre_magi_reroll', LUA_MODIFIER_MOTION_NONE)

ogre_magi_reroll = class({})

function HideOgreBorrowedAbilityUntilCooldownEnds(ability)
	if not ability or ability:IsNull() then
		return
	end

	ability.ogre_cooldown_hide_id = (ability.ogre_cooldown_hide_id or 0) + 1
	local hide_id = ability.ogre_cooldown_hide_id

	-- The ability-executed event can arrive just before the engine starts cooldown.
	Timers:CreateTimer(0, function()
		if not ability or ability:IsNull() or ability.ogre_cooldown_hide_id ~= hide_id then
			return
		end

		if ability:GetCooldownTimeRemaining() <= 0 then
			ability:SetHidden(false)
			return
		end

		ability:SetHidden(true)
		return 0.1
	end)
end

local function OgreBorrowedAbilityHasActiveEffect(parent, ability, named_modifier)
	if named_modifier and parent:HasModifier(named_modifier) then
		return true
	end

	local units = FindUnitsInRadius(
		parent:GetTeamNumber(),
		parent:GetAbsOrigin(),
		nil,
		FIND_UNITS_EVERYWHERE,
		DOTA_UNIT_TARGET_TEAM_BOTH,
		DOTA_UNIT_TARGET_ALL,
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_INVULNERABLE,
		FIND_ANY_ORDER,
		false
	)

	for _, unit in ipairs(units) do
		for _, modifier in ipairs(unit:FindAllModifiers()) do
			if modifier:GetAbility() == ability then
				return true
			end
		end
	end

	return false
end

local function RemoveOgreBorrowedAbilityAfterEffect(parent, ability, ability_name, named_modifier)
	Timers:CreateTimer(0.1, function()
		if not IsValidEntity(parent) or not ability or ability:IsNull() then
			return
		end

		if parent:FindAbilityByName(ability_name) ~= ability then
			return
		end

		local is_channeling = ability.IsChanneling and ability:IsChanneling()
		if is_channeling or OgreBorrowedAbilityHasActiveEffect(parent, ability, named_modifier) then
			return 0.1
		end

		parent:RemoveAbility(ability_name)
	end)
end

function ogre_magi_reroll:GetIntrinsicModifierName()
	return "modifier_ogre_magi_reroll_passive"
end

abilities = {
	"axe_culling_blade",
	"beastmaster_primal_roar",
	"centaur_stampede",
	"chen_hand_of_god",
	"crystal_maiden_freezing_field",
	{name = "death_prophet_exorcism", modifier = "modifier_death_prophet_exorcism"},
	"earthshaker_echo_slam",
	"enigma_black_hole",
	"faceless_void_chronosphere",
	"jakiro_macropyre",
	"kunkka_ghostship",
	"ability_ice_phylactery",
	"lina_laguna_blade",
	"lion_finger_of_death",
	"lycan_shapeshift",
	"magnataur_reverse_polarity",
	"naga_siren_song_of_the_siren",
	"necrolyte_reapers_scythe",
	"oracle_false_promise",
	"pugna_life_drain",
	"queenofpain_sonic_wave",
	"sandking_epicenter",
	{name =	"snapfire_mortimer_kisses", modifier = "modifier_snapfire_mortimer_kisses"},	-- "sniper_assassinate",
	"sven_gods_strength",
	"tidehunter_ravage",
	"ursa_enrage",
	"winter_wyvern_winters_curse",
	"witch_doctor_death_ward",
	"zuus_thundergods_wrath",
}

function ogre_magi_reroll:Precache(context)
	-- Precache Ogre Magi particles
	PrecacheResource("particle", "particles/units/heroes/hero_ogre_magi/ogre_magi_bloodlust.vpcf", context)
	PrecacheResource("particle", "particles/units/neutral_creeps/ogre_bruiser_smash.vpcf", context)
	PrecacheResource("particle", "particles/creatures/ogre/ogre_bruiser_smash.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_ogre_magi/ogre_bruiser_smash.vpcf", context)
	
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_axe.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_axe.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_axe", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_beastmaster.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_beastmaster.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_beastmaster", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_centaur.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_centaur.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_centaur", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_chen.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_chen.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_chen", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_crystal_maiden.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_crystal_maiden.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_crystal_maiden", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_death_prophet.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_death_prophet.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_death_prophet", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_earthshaker.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_earthshaker.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_earthshaker", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_enigma.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_enigma.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_enigma", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_faceless_void.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_faceless_void.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_faceless_void", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_jakiro.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_jakiro.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_jakiro", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_kunkka.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_kunkka.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_kunkka", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_lina.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_lina.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_lina", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_lion.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_lion.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_lion", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_lycan.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_lycan.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_lycan", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_magnataur.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_magnataur.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_magnataur", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_naga_siren.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_naga_siren.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_naga_siren", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_necrolyte.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_necrolyte.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_necrolyte", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_oracle.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_oracle.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_oracle", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_pugna.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_pugna.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_pugna", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_queenofpain.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_queenofpain.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_queenofpain", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_sandking.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_sandking.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_sandking", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_shadow_shaman.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_shadow_shaman.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_shadow_shaman", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_snapfire.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_snapfire.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_snapfire", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_sven.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_sven.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_sven", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_tidehunter.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_tidehunter.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_tidehunter", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ursa.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_ursa.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_ursa", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_winter_wyvern.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_winter_wyvern.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_winter_wyvern", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_witch_doctor.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_witch_doctor.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_witch_doctor", context)
	PrecacheUnitByNameSync("npc_dota_witch_doctor_death_ward", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_zuus.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_zuus.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_zuus", context)
end

function ogre_magi_reroll:OnSpellStart()
	local caster = self:GetCaster()
	local randomAbility = abilities[RandomInt(1,#abilities)]


	-- Найдем пустой слот (Ability4)
	local emptySlot = caster:GetAbilityByIndex(3) -- Ability4 имеет индекс 3
	
	-- Если в слоте уже есть способность, удаляем её
	if emptySlot then
		local oldAbilityName = emptySlot:GetAbilityName()
		if oldAbilityName ~= "0" and oldAbilityName ~= "" then
			caster:RemoveAbility(oldAbilityName)
		end
	end

	-- Добавляем новую способность
	local abilityName = type(randomAbility) == "table" and randomAbility.name or randomAbility
	self.newAbility = caster:AddAbility(abilityName)
	self.newAbilityModifier = type(randomAbility) == "table" and randomAbility.modifier or nil
	-- Новая копия может унаследовать кулдаун ранее удалённой способности с тем же именем.
	-- Рефрешим только выданную способность, не затрагивая остальные скиллы и предметы героя.
	self.newAbility:EndCooldown()
	-- Устанавливаем уровень способности в соответствии с уровнем ульты
	self.newAbility:SetLevel(self:GetLevel())
	-- Отключаем возможность прокачки полученной способности
	self.newAbility:SetUpgradeRecommended(false)
	
	
	
	-- Перемещаем новую способность в слот 4 (индекс 3)
	caster:SwapAbilities(
		abilityName,
		caster:GetAbilityByIndex(3):GetAbilityName(),
		true,
		true
	)

	caster:AddNewModifier(caster, self, "modifier_ogre_magi_reroll", {duration = self:GetSpecialValueFor("ability_duration")})
	
end

modifier_ogre_magi_reroll = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return false end,
	IsBuff                  = function(self) return true end,
	RemoveOnDeath 			= function(self) return false end,
	DeclareFunctions  		= function(self) return {} end,
})
 
function modifier_ogre_magi_reroll:OnCreated()
	if IsClient() then return end

	local ability = self:GetAbility()
	self.newAbilityName = ability.newAbility:GetAbilityName()
	self.newAbilityModifier = ability.newAbilityModifier
	self:SetHasCustomTransmitterData(true);
end

function modifier_ogre_magi_reroll:OnDestroy()
	if IsClient() then return end
	local parent = self:GetParent()

	-- Сразу прячем и отключаем именно ту ульту, которую выдал этот модификатор.
	-- Это не дает ей оставаться в панели или повторно кастоваться после истечения таймера.
	local expiredAbilityName = self.newAbilityName
	local expiredAbilityModifier = self.newAbilityModifier
	local expiredAbility = expiredAbilityName and parent:FindAbilityByName(expiredAbilityName) or nil
	if expiredAbility and not expiredAbility:IsNull() then
		expiredAbility:SetActivated(false)
		expiredAbility:SetHidden(true)
	end

	-- Если способность не была использована, удаляем её после окна выдачи.
	-- Использованная способность уже ожидает завершения своего эффекта в OnAbilityExecuted.
	if expiredAbility and not self.borrowedAbilityCleanupStarted then
		RemoveOgreBorrowedAbilityAfterEffect(parent, expiredAbility, expiredAbilityName, expiredAbilityModifier)
	end
end

function modifier_ogre_magi_reroll:AddCustomTransmitterData()
	return {
		newAbilityName = self.newAbilityName,
	}
end

function modifier_ogre_magi_reroll:HandleCustomTransmitterData(event)
    self.newAbilityName = event.newAbilityName
end

-- Пассивный модификатор для уменьшения кулдауна при атаках
modifier_ogre_magi_reroll_passive = class({
	IsHidden 				= function(self) return true end,
	IsPurgable 				= function(self) return false end,
	IsBuff                  = function(self) return true end,
	RemoveOnDeath 			= function(self) return false end,
	DeclareFunctions  		= function(self) return {
		MODIFIER_EVENT_ON_ATTACK_LANDED,
		MODIFIER_EVENT_ON_ABILITY_EXECUTED,
		MODIFIER_PROPERTY_MANACOST_PERCENTAGE_STACKING,
	} end,
})

function modifier_ogre_magi_reroll_passive:OnAbilityExecuted(event)
	if not IsServer() or event.unit ~= self:GetParent() then
		return
	end

	local borrowed = event.ability
	local active_roll = self:GetParent():FindModifierByName("modifier_ogre_magi_reroll")
	if not borrowed or not active_roll or borrowed:GetAbilityName() ~= active_roll.newAbilityName then
		return
	end

	HideOgreBorrowedAbilityUntilCooldownEnds(borrowed)

	if not active_roll.borrowedAbilityCleanupStarted then
		active_roll.borrowedAbilityCleanupStarted = true
		RemoveOgreBorrowedAbilityAfterEffect(
			self:GetParent(),
			borrowed,
			active_roll.newAbilityName,
			active_roll.newAbilityModifier
		)
	end
end

function modifier_ogre_magi_reroll_passive:GetModifierPercentageManacostStacking(params)
	local ability = params.ability
	local abilityName = ability:GetAbilityName()
	
	-- Проверяем, что это одна из возможных полученных способностей
	for _, possibleAbility in ipairs(abilities) do
		local name = type(possibleAbility) == "table" and possibleAbility.name or possibleAbility
		if abilityName == name then
			-- Возвращаем 100 для 100% уменьшения стоимости маны (бесплатная способность)
			return 100
		end
	end
	
	return 0
end

function modifier_ogre_magi_reroll_passive:OnAttackLanded(event)
	if IsServer() then
		local attacker = event.attacker
		local target = event.target
		
		-- Проверяем, что атакующий - наш герой
		if attacker ~= self:GetParent() then return end
		
		-- Проверяем, что цель - вражеский герой или крип
		if target:GetTeamNumber() == attacker:GetTeamNumber() then return end
		
		-- Получаем способность reroll
		local ability = self:GetAbility()
		if not ability then return end
		
		local is_reduced_target = target:IsCreep()
			or target:IsNeutralUnitType()
			or (target:IsBuilding() and not target:IsFort() and string.find(target:GetUnitName(), "tower"))
		local cooldownReduction = is_reduced_target
			and ability:GetSpecialValueFor("cooldown_reduction_per_attack_creep")
			or ability:GetSpecialValueFor("cooldown_reduction_per_attack")
		
		local currentCooldown = ability:GetCooldownTimeRemaining()
		if currentCooldown > 0 then
			local newCooldown = math.max(0, currentCooldown - cooldownReduction)
			ability:EndCooldown()
			if newCooldown > 0 then
				ability:StartCooldown(newCooldown)
			end
		end
	end
end
