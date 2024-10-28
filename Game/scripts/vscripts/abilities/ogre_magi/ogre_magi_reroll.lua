LinkLuaModifier('modifier_ogre_magi_reroll', 'abilities/ogre_magi/ogre_magi_reroll', LUA_MODIFIER_MOTION_NONE)

ogre_magi_reroll = class({})

local abilities = {
	"alchemist_chemical_rage",
	"antimage_mana_void",
	"axe_culling_blade",
	"bane_fiends_grip",
	"batrider_flaming_lasso",
	"beastmaster_primal_roar",
	"bloodseeker_rupture",
	"bounty_hunter_track",
	"broodmother_spawn_spiderlings",
	"centaur_stampede",
	"chen_hand_of_god",
	"clinkz_wind_walk",
	"crystal_maiden_freezing_field",
	"dark_seer_wall_of_replica",
	"dawnbreaker_solar_guardian",
	"death_prophet_exorcism",
	"disruptor_static_storm",
	"earthshaker_echo_slam",
	"elder_titan_earth_splitter",
	"enigma_black_hole",
	"faceless_void_chronosphere",
	"faceless_void_time_zone",
	"furion_wrath_of_nature",
	"grimstroke_soul_chain",
	"gyrocopter_call_down",
	"hoodwink_sharpshooter",
	"huskar_life_break",
	"jakiro_macropyre",
	"juggernaut_omni_slash",
	"kunkka_ghostship",
	"legion_commander_duel",
	"ability_ice_phylactery",
	"tinker_rearm_custom",
	"ability_chain_bomb",
	"lina_laguna_blade",
	"lion_finger_of_death",
	"lycan_shapeshift",
	"magnataur_reverse_polarity",
	"marci_unleash",
	"mars_arena_of_blood",
	"medusa_stone_gaze",
	"mirana_invis",
	"mirana_solar_flare",
	"monkey_king_wukongs_command",
	"muerta_pierce_the_veil",
	"naga_siren_song_of_the_siren",
	"necrolyte_reapers_scythe",
	"night_stalker_darkness",
	"nyx_assassin_vendetta",
	"obsidian_destroyer_sanity_eclipse",
	"omniknight_guardian_angel",
	"oracle_false_promise",
	"phoenix_supernova",
	"primal_beast_pulverize",
	"puck_dream_coil",
	"pudge_dismember",
	"pugna_life_drain",
	"queenofpain_sonic_wave",
	"rattletrap_hookshot",
	"razor_eye_of_the_storm",
	"ringmaster_wheel",
	"sandking_epicenter",
	"shadow_demon_demonic_purge",
	"shadow_shaman_mass_serpent_ward",
	"shredder_chakram",
	"silencer_global_silence",
	"skywrath_mage_mystic_flare",
	"slardar_amplify_damage",
	"slark_shadow_dance",
	"snapfire_mortimer_kisses",
	"sniper_assassinate",
	"sven_gods_strength",
	"templar_assassin_psionic_trap",
	"terrorblade_sunder",
	"tidehunter_ravage",
	"treant_overgrowth",
	"troll_warlord_battle_trance",
	"tusk_walrus_punch",
	"undying_flesh_golem",
	"ursa_enrage",
	"vengefulspirit_nether_swap",
	"venomancer_noxious_plague",
	"viper_viper_strike",
	"void_spirit_astral_step",
	"warlock_rain_of_chaos",
	"windrunner_focusfire",
	"winter_wyvern_winters_curse",
	"witch_doctor_death_ward",
	"zuus_thundergods_wrath",
}

function ogre_magi_reroll:OnSpellStart()
	local caster = self:GetCaster()

	self.newAbility = caster:AddAbility(abilities[RandomInt(1,#abilities)])

	self.newAbility:SetLevel( self:GetLevel() )

	caster:SwapAbilities(
		self:GetAbilityName(),
		self.newAbility:GetAbilityName(),
		false,
		true
	)

	caster:AddNewModifier(caster, self, "modifier_ogre_magi_reroll", {duration = self:GetSpecialValueFor("ability_duration")})
end

modifier_ogre_magi_reroll = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return false end,
	IsBuff                  = function(self) return true end,
	RemoveOnDeath 			= function(self) return false end,
	DeclareFunctions  		= function(self) return 
	{
		MODIFIER_PROPERTY_MANACOST_PERCENTAGE_STACKING,
	} end,
})
 
function modifier_ogre_magi_reroll:OnCreated()
	local ability = self:GetAbility()
	self.manacostReduction = ability:GetSpecialValueFor("manacost_reduction")
	if IsClient() then return end

	self.newAbilityName = ability.newAbility:GetAbilityName()
	self:SetHasCustomTransmitterData(true);
end

function modifier_ogre_magi_reroll:OnDestroy()
	if IsClient() then return end
	local parent = self:GetParent()
	local ability = self:GetAbility()
	local level = ability.newAbility:GetLevel()
	ability:SetLevel(level)
	parent:SwapAbilities(
		ability.newAbility:GetAbilityName(),
		ability:GetAbilityName(),
		false,
		true
	)

	parent:RemoveAbility(ability.newAbility:GetAbilityName())
end

function modifier_ogre_magi_reroll:AddCustomTransmitterData()
	return {
		newAbilityName = self.newAbilityName,
	}
end

function modifier_ogre_magi_reroll:HandleCustomTransmitterData(event)
    self.newAbilityName = event.newAbilityName
end
 
function modifier_ogre_magi_reroll:GetModifierPercentageManacostStacking(event)
	if event.ability:GetAbilityName() == self.newAbilityName then
		return self.manacostReduction 
	end
end