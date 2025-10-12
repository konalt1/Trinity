LinkLuaModifier('modifier_ogre_magi_reroll', 'abilities/ogre_magi/ogre_magi_reroll', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_ogre_magi_reroll_passive', 'abilities/ogre_magi/ogre_magi_reroll', LUA_MODIFIER_MOTION_NONE)

ogre_magi_reroll = class({})

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
	"shadow_shaman_mass_serpent_ward",
	{name =	"snapfire_mortimer_kisses", modifier = "modifier_snapfire_mortimer_kisses"},	-- "sniper_assassinate",
	"sven_gods_strength",
	"tidehunter_ravage",
	"ursa_enrage",
	"winter_wyvern_winters_curse",
	"witch_doctor_death_ward",
	"zuus_thundergods_wrath",
}

function ogre_magi_reroll:Precache(context)
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
	self.newAbility:SetLevel(1) -- Всегда 1 уровень для получаемых способностей
	
	
	
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
	local ability = self:GetAbility()
	
	parent:InterruptChannel()

	-- Удаляем модификатор полученной способности если он есть
	if self.newAbilityModifier then 
		parent:RemoveModifierByName(self.newAbilityModifier) 
	end

	-- Удаляем полученную способность из слота 4
	Timers:CreateTimer(0.1, function()
		if ability.newAbility and IsValidEntity(ability.newAbility) then
			parent:RemoveAbility(ability.newAbility:GetAbilityName())
		end
	end)
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
	} end,
})

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
		
		-- Уменьшаем кулдаун в зависимости от уровня способности (3/4/5 секунд)
		local cooldownReduction = ability:GetSpecialValueFor("cooldown_reduction_per_attack")
		
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

 