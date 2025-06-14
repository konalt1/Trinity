LinkLuaModifier('modifier_ogre_magi_reroll', 'abilities/ogre_magi/ogre_magi_reroll', LUA_MODIFIER_MOTION_NONE)

ogre_magi_reroll = class({})

abilities = {
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
	{name = "death_prophet_exorcism", modifier = "modifier_death_prophet_exorcism"},
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
	{name =	"snapfire_mortimer_kisses", modifier = "modifier_snapfire_mortimer_kisses"},	-- "sniper_assassinate",
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

function ogre_magi_reroll:Precache(context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_alchemist.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_alchemist.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_alchemist", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_antimage.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_antimage.vsndevts", context) 
	PrecacheResource("particle_folder", "particles/units/heroes/hero_antimage", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_axe.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_axe.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_axe", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_bane.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_bane.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_bane", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_batrider.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_batrider.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_batrider", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_beastmaster.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_beastmaster.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_beastmaster", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_bloodseeker.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_bloodseeker.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_bloodseeker", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_bounty_hunter.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_bounty_hunter.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_bounty_hunter", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_broodmother.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_broodmother.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_broodmother", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_centaur.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_centaur.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_centaur", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_chen.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_chen.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_chen", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_clinkz.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_clinkz.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_clinkz", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_crystal_maiden.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_crystal_maiden.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_crystal_maiden", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_dark_seer.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_dark_seer.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_dark_seer", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_dawnbreaker.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_dawnbreaker.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_dawnbreaker", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_death_prophet.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_death_prophet.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_death_prophet", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_disruptor.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_disruptor.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_disruptor", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_earthshaker.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_earthshaker.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_earthshaker", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_elder_titan.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_elder_titan.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_elder_titan", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_enigma.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_enigma.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_enigma", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_faceless_void.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_faceless_void.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_faceless_void", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_furion.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_furion.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_furion", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_grimstroke.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_grimstroke.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_grimstroke", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_gyrocopter.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_gyrocopter.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_gyrocopter", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_hoodwink.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_hoodwink.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_hoodwink", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_huskar.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_huskar.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_huskar", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_jakiro.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_jakiro.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_jakiro", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_juggernaut.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_juggernaut.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_juggernaut", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_kunkka.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_kunkka.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_kunkka", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_legion_commander.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_legion_commander.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_legion_commander", context)

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

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_marci.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_marci.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_marci", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_mars.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_mars.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_mars", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_medusa.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_medusa.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_medusa", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_mirana.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_mirana.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_mirana", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_monkey_king.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_monkey_king.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_monkey_king", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_muerta.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_muerta.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_muerta", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_naga_siren.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_naga_siren.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_naga_siren", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_necrolyte.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_necrolyte.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_necrolyte", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_night_stalker.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_night_stalker.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_night_stalker", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_nyx_assassin.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_nyx_assassin.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_nyx_assassin", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_obsidian_destroyer.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_obsidian_destroyer.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_obsidian_destroyer", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_omniknight.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_omniknight.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_omniknight", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_oracle.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_oracle.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_oracle", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_phoenix.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_phoenix.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_phoenix", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_primal_beast.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_primal_beast.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_primal_beast", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_puck.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_puck.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_puck", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_pudge.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_pudge.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_pudge", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_pugna.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_pugna.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_pugna", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_queenofpain.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_queenofpain.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_queenofpain", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_rattletrap.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_rattletrap.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_rattletrap", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_razor.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_razor.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_razor", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_sandking.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_sandking.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_sandking", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_shadow_demon.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_shadow_demon.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_shadow_demon", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_shadow_shaman.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_shadow_shaman.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_shadow_shaman", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_shredder.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_shredder.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_shredder", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_silencer.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_silencer.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_silencer", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_skywrath_mage.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_skywrath_mage.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_skywrath_mage", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_slardar.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_slardar.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_slardar", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_slark.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_slark.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_slark", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_snapfire.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_snapfire.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_snapfire", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_sniper.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_sniper.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_sniper", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_sven.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_sven.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_sven", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_templar_assassin.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_templar_assassin.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_templar_assassin", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_terrorblade.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_terrorblade.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_terrorblade", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_tidehunter.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_tidehunter.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_tidehunter", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_treant.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_treant.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_treant", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_troll_warlord.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_troll_warlord.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_troll_warlord", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_tusk.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_tusk.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_tusk", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_undying.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_undying.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_undying", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ursa.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_ursa.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_ursa", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_vengefulspirit.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_vengefulspirit.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_vengefulspirit", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_venomancer.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_venomancer.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_venomancer", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_viper.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_viper.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_viper", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_void_spirit.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_void_spirit.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_void_spirit", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_warlock.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_warlock.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_warlock", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_windrunner.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_windrunner.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_windrunner", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_winter_wyvern.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_winter_wyvern.vsndevts", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_winter_wyvern", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_witch_doctor.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_witch_doctor.vsndevts", context)
end

function ogre_magi_reroll:OnSpellStart()
	local caster = self:GetCaster()
	local randomAbility = abilities[RandomInt(1,#abilities)]

	self.newAbility = caster:AddAbility(type(randomAbility) == "table" and randomAbility.name or randomAbility)
	self.newAbilityModifier = type(randomAbility) == "table" and randomAbility.modifier or nil
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
	self.newAbilityModifier = ability.newAbilityModifier
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
	parent:InterruptChannel()

	if self.newAbilityModifier then parent:RemoveModifierByName(self.newAbilityModifier) end

	Timers:CreateTimer(0.1, function()
		parent:RemoveAbility(ability.newAbility:GetAbilityName())
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
 
function modifier_ogre_magi_reroll:GetModifierPercentageManacostStacking(event)
	if event.ability:GetAbilityName() == self.newAbilityName then
		return self.manacostReduction 
	end
end