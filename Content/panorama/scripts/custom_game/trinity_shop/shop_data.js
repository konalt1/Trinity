// Trinity: данные нового магазина по категориям.
// Состав категорий правится в студии http://127.0.0.1:8080/?view=shop
// tier -1: цена ванильная, ценовой категории нет (угол карточки без цвета).
// Подключается в trinity_shop.xml ПЕРЕД trinity_shop.js.
"use strict";
var TRINITY_SHOP_DATA = {
    "tiers": [
        {
            "price": 2400,
            "color": "#5fae5a"
        },
        {
            "price": 3500,
            "color": "#4f86c6"
        },
        {
            "price": 4700,
            "color": "#9467c9"
        },
        {
            "price": 5500,
            "color": "#d98b3a"
        }
    ],
    "attributes": [
        {
            "id": "str",
            "token": "#trinity_shop_attr_str",
            "color": "#e0503f",
            "icon": "file://{images}/custom_game/trinity_shop/attr_str.png"
        },
        {
            "id": "agi",
            "token": "#trinity_shop_attr_agi",
            "color": "#4fc25f",
            "icon": "file://{images}/custom_game/trinity_shop/attr_agi.png"
        },
        {
            "id": "int",
            "token": "#trinity_shop_attr_int",
            "color": "#4a9be0",
            "icon": "file://{images}/custom_game/trinity_shop/attr_int.png"
        },
        {
            "id": "multi",
            "token": "#trinity_shop_attr_multi",
            "color": "#d6a84a",
            "icon": "file://{images}/custom_game/trinity_shop/attr_uni.png"
        }
    ],
    "categories": [
        {
            "id": "damage",
            "token": "#trinity_shop_cat_damage",
            "accent": "#f07a3a",
            "art": "file://{images}/custom_game/trinity_shop/cat_damage.png",
            "subcategories": [
                {
                    "id": "damage",
                    "token": "#trinity_shop_sub_damage_damage",
                    "icon": "item_greater_crit",
                    "color": "#e8634f",
                    "items": [
                        "item_quelling_blade",
                        "item_blades_of_attack",
                        "item_lesser_crit",
                        "item_greater_crit",
                        "item_radiance",
                        "item_revenants_brooch",
                        "item_rapier",
                        "item_satanic",
                        "item_armlet",
                        "item_nullifier",
                        "item_blade_mail",
                        "item_phase_boots",
                        "item_harpoon",
                        "item_invis_sword",
                        "item_silver_edge",
                        "item_dragon_lance"
                    ]
                },
                {
                    "id": "attack_speed",
                    "token": "#trinity_shop_sub_damage_attack_speed",
                    "icon": "item_moon_shard",
                    "color": "#f2c94c",
                    "items": [
                        "item_gloves",
                        "item_moon_shard",
                        "item_hand_of_midas",
                        "item_mask_of_madness",
                        "item_butterfly",
                        "item_assault",
                        "item_orchid",
                        "item_yasha_and_kaya",
                        "item_sange_and_yasha",
                        "item_manta",
                        "item_mage_slayer",
                        "item_solar_crest",
                        "item_power_treads",
                        "item_hurricane_pike",
                        "item_ancient_janggo",
                        "item_oblivion_staff",
                        "item_yasha"
                    ]
                },
                {
                    "id": "effects",
                    "token": "#trinity_shop_sub_damage_effects",
                    "icon": "item_desolator",
                    "color": "#ff8a4c",
                    "items": [
                        "item_javelin",
                        "item_blight_stone",
                        "item_orb_of_venom",
                        "item_orb_of_frost",
                        "item_orb_of_corrosion",
                        "item_monkey_king_bar",
                        "item_desolator",
                        "item_maelstrom",
                        "item_mjollnir",
                        "item_bfury",
                        "item_hydras_breath",
                        "item_specialists_array",
                        "item_echo_sabre",
                        "item_witch_blade",
                        "item_devastator",
                        "item_gungir",
                        "item_basher",
                        "item_abyssal_blade",
                        "item_bloodthorn",
                        "item_diffusal_blade"
                    ]
                }
            ]
        },
        {
            "id": "survival",
            "token": "#trinity_shop_cat_survival",
            "accent": "#9a6cf0",
            "art": "file://{images}/custom_game/trinity_shop/cat_survival.png",
            "subcategories": [
                {
                    "id": "health",
                    "token": "#trinity_shop_sub_survival_health",
                    "icon": "item_heart",
                    "color": "#3fbf8a",
                    "items": [
                        "item_fluffy_hat",
                        "item_ring_of_regen",
                        "item_satanic",
                        "item_armlet",
                        "item_mask_of_madness",
                        "item_skadi",
                        "item_kaya_and_sange",
                        "item_bloodstone",
                        "item_bottle",
                        "item_magic_stick",
                        "item_magic_wand",
                        "item_heart",
                        "item_crellas_crozier",
                        "item_overwhelming_blink",
                        "item_tranquil_boots",
                        "item_headdress",
                        "item_vladmir",
                        "item_bracer",
                        "item_sange",
                        "item_soul_booster",
                        "item_pers"
                    ]
                },
                {
                    "id": "armor",
                    "token": "#trinity_shop_sub_survival_armor",
                    "icon": "item_assault",
                    "color": "#e8963f",
                    "items": [
                        "item_ring_of_protection",
                        "item_chainmail",
                        "item_vanguard",
                        "item_ghost",
                        "item_butterfly",
                        "item_assault",
                        "item_nullifier",
                        "item_heavens_halberd",
                        "item_ethereal_blade",
                        "item_sange_and_yasha",
                        "item_blade_mail",
                        "item_shivas_guard",
                        "item_crimson_guard",
                        "item_pavise",
                        "item_solar_crest",
                        "item_buckler",
                        "item_mekansm",
                        "item_yasha"
                    ]
                },
                {
                    "id": "magic",
                    "token": "#trinity_shop_sub_survival_magic",
                    "icon": "item_black_king_bar",
                    "color": "#a77cf5",
                    "items": [
                        "item_shawl",
                        "item_infused_raindrop",
                        "item_consecrated_wraps",
                        "item_aeon_disk",
                        "item_black_king_bar",
                        "item_sphere",
                        "item_lotus_orb",
                        "item_manta",
                        "item_mage_slayer",
                        "item_glimmer_cape",
                        "item_pipe"
                    ]
                }
            ]
        },
        {
            "id": "magic",
            "token": "#trinity_shop_cat_magic",
            "accent": "#6d8cff",
            "art": "file://{images}/custom_game/trinity_shop/cat_magic.png",
            "subcategories": [
                {
                    "id": "damage",
                    "token": "#trinity_shop_sub_magic_damage",
                    "icon": "item_dagon",
                    "color": "#5b9bff",
                    "items": [
                        "item_rapier",
                        "item_witch_blade",
                        "item_devastator",
                        "item_gungir",
                        "item_rod_of_atos",
                        "item_wind_waker",
                        "item_meteor_hammer",
                        "item_dagon",
                        "item_veil_of_discord",
                        "item_kaya_and_sange",
                        "item_bloodstone",
                        "item_yasha_and_kaya",
                        "item_ethereal_blade",
                        "item_phylactery",
                        "item_angels_demise",
                        "item_arcane_blink",
                        "item_shivas_guard",
                        "item_null_talisman",
                        "item_kaya"
                    ]
                },
                {
                    "id": "mana",
                    "token": "#trinity_shop_sub_magic_mana",
                    "icon": "item_arcane_boots",
                    "color": "#3fc9d9",
                    "items": [
                        "item_sobi_mask",
                        "item_wizard_hat",
                        "item_soul_ring",
                        "item_falcon_blade",
                        "item_echo_sabre",
                        "item_sheepstick",
                        "item_cyclone",
                        "item_orchid",
                        "item_bottle",
                        "item_magic_stick",
                        "item_magic_wand",
                        "item_arcane_boots",
                        "item_ring_of_basilius",
                        "item_guardian_greaves",
                        "item_soul_booster",
                        "item_pers",
                        "item_oblivion_staff"
                    ]
                },
                {
                    "id": "abilities",
                    "token": "#trinity_shop_sub_magic_abilities",
                    "icon": "item_ultimate_scepter",
                    "color": "#c08af8",
                    "items": [
                        "item_ultimate_scepter",
                        "item_ultimate_scepter_2",
                        "item_aghanims_shard",
                        "item_octarine_core",
                        "item_refresher",
                        "item_aether_lens"
                    ]
                }
            ]
        },
        {
            "id": "mobility",
            "token": "#trinity_shop_cat_mobility",
            "accent": "#3fc9d9",
            "art": "file://{images}/custom_game/trinity_shop/cat_mobility.png",
            "subcategories": [
                {
                    "id": "speed",
                    "token": "#trinity_shop_sub_mobility_speed",
                    "icon": "item_travel_boots",
                    "color": "#76d13c",
                    "items": [
                        "item_wind_lace",
                        "item_boots",
                        "item_travel_boots",
                        "item_travel_boots_2",
                        "item_butterfly",
                        "item_cyclone",
                        "item_wind_waker",
                        "item_disperser",
                        "item_skadi",
                        "item_yasha_and_kaya",
                        "item_sange_and_yasha",
                        "item_manta",
                        "item_phase_boots",
                        "item_power_treads",
                        "item_tranquil_boots",
                        "item_arcane_boots",
                        "item_ancient_janggo",
                        "item_boots_of_bearing",
                        "item_guardian_greaves",
                        "item_wraith_band",
                        "item_yasha"
                    ]
                },
                {
                    "id": "dash",
                    "token": "#trinity_shop_sub_mobility_dash",
                    "icon": "item_blink",
                    "color": "#5b9bff",
                    "items": [
                        "item_blink",
                        "item_shadow_amulet",
                        "item_arcane_blink",
                        "item_overwhelming_blink",
                        "item_swift_blink",
                        "item_force_staff",
                        "item_hurricane_pike",
                        "item_harpoon",
                        "item_invis_sword",
                        "item_silver_edge"
                    ]
                }
            ]
        },
        {
            "id": "control",
            "token": "#trinity_shop_cat_control",
            "accent": "#f0506e",
            "art": "file://{images}/custom_game/trinity_shop/cat_control.png",
            "subcategories": [
                {
                    "id": "disable",
                    "token": "#trinity_shop_sub_control_disable",
                    "icon": "item_sheepstick",
                    "color": "#3fc9d9",
                    "items": [
                        "item_gungir",
                        "item_basher",
                        "item_abyssal_blade",
                        "item_sheepstick",
                        "item_rod_of_atos",
                        "item_cyclone",
                        "item_wind_waker",
                        "item_meteor_hammer"
                    ]
                },
                {
                    "id": "debuff",
                    "token": "#trinity_shop_sub_control_debuff",
                    "icon": "item_orchid",
                    "color": "#f2c94c",
                    "items": [
                        "item_orchid",
                        "item_bloodthorn",
                        "item_nullifier",
                        "item_diffusal_blade",
                        "item_disperser",
                        "item_heavens_halberd",
                        "item_skadi",
                        "item_ethereal_blade",
                        "item_phylactery",
                        "item_angels_demise",
                        "item_overwhelming_blink",
                        "item_shivas_guard",
                        "item_harpoon",
                        "item_silver_edge",
                        "item_spirit_vessel"
                    ]
                }
            ]
        },
        {
            "id": "support",
            "token": "#trinity_shop_cat_support",
            "accent": "#3fbf8a",
            "art": "file://{images}/custom_game/trinity_shop/cat_support.png",
            "subcategories": [
                {
                    "id": "aura",
                    "token": "#trinity_shop_sub_support_aura",
                    "icon": "item_vladmir",
                    "color": "#3fbf8a",
                    "items": [
                        "item_helm_of_the_dominator",
                        "item_helm_of_the_overlord",
                        "item_assault",
                        "item_pipe",
                        "item_arcane_boots",
                        "item_headdress",
                        "item_buckler",
                        "item_ring_of_basilius",
                        "item_ancient_janggo",
                        "item_boots_of_bearing",
                        "item_vladmir"
                    ]
                },
                {
                    "id": "heal",
                    "token": "#trinity_shop_sub_support_heal",
                    "icon": "item_mekansm",
                    "color": "#7ddc6a",
                    "items": [
                        "item_holy_locket",
                        "item_essence_distiller",
                        "item_urn_of_shadows",
                        "item_mekansm",
                        "item_guardian_greaves",
                        "item_spirit_vessel"
                    ]
                },
                {
                    "id": "save",
                    "token": "#trinity_shop_sub_support_save",
                    "icon": "item_glimmer_cape",
                    "color": "#c08af8",
                    "items": [
                        "item_gem",
                        "item_cyclone",
                        "item_wind_waker",
                        "item_disperser",
                        "item_ethereal_blade",
                        "item_sphere",
                        "item_lotus_orb",
                        "item_glimmer_cape",
                        "item_crimson_guard",
                        "item_pavise",
                        "item_solar_crest",
                        "item_force_staff",
                        "item_hurricane_pike"
                    ]
                }
            ]
        }
    ],
    "items": {
        "item_bfury": {
            "tier": 2,
            "price": 4700,
            "categories": [
                "damage"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_bfury"
        },
        "item_basher": {
            "tier": 0,
            "price": 2400,
            "categories": [
                "damage",
                "control"
            ],
            "attributes": [
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_basher"
        },
        "item_abyssal_blade": {
            "tier": 3,
            "price": 5500,
            "categories": [
                "damage",
                "control"
            ],
            "attributes": [
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_abyssal_blade"
        },
        "item_satanic": {
            "tier": 3,
            "price": 5500,
            "categories": [
                "damage",
                "survival"
            ],
            "attributes": [
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_satanic"
        },
        "item_desolator": {
            "tier": 1,
            "price": 3500,
            "categories": [
                "damage"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_desolator"
        },
        "item_radiance": {
            "tier": 2,
            "price": 4700,
            "categories": [
                "damage"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_radiance"
        },
        "item_greater_crit": {
            "tier": 3,
            "price": 5500,
            "categories": [
                "damage"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_greater_crit"
        },
        "item_monkey_king_bar": {
            "tier": 3,
            "price": 5500,
            "categories": [
                "damage"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_monkey_king_bar"
        },
        "item_maelstrom": {
            "tier": 1,
            "price": 3500,
            "categories": [
                "damage"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_maelstrom"
        },
        "item_invis_sword": {
            "tier": 1,
            "price": 3500,
            "categories": [
                "damage",
                "mobility"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_invis_sword"
        },
        "item_lesser_crit": {
            "tier": -1,
            "price": 2000,
            "categories": [
                "damage"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_lesser_crit"
        },
        "item_rapier": {
            "tier": -1,
            "price": 5600,
            "categories": [
                "damage",
                "magic"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_rapier"
        },
        "item_silver_edge": {
            "tier": -1,
            "price": 5700,
            "categories": [
                "damage",
                "mobility",
                "control"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_silver_edge"
        },
        "item_bloodthorn": {
            "tier": -1,
            "price": 6400,
            "categories": [
                "damage",
                "control"
            ],
            "attributes": [
                "int"
            ],
            "descToken": "#trinity_shop_desc_item_bloodthorn"
        },
        "item_revenants_brooch": {
            "tier": -1,
            "price": 3300,
            "categories": [
                "damage"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_revenants_brooch"
        },
        "item_harpoon": {
            "tier": -1,
            "price": 4700,
            "categories": [
                "damage",
                "mobility",
                "control"
            ],
            "attributes": [
                "agi",
                "int",
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_harpoon"
        },
        "item_echo_sabre": {
            "tier": -1,
            "price": 2700,
            "categories": [
                "damage",
                "magic"
            ],
            "attributes": [
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_echo_sabre"
        },
        "item_diffusal_blade": {
            "tier": -1,
            "price": 2500,
            "categories": [
                "damage",
                "control"
            ],
            "attributes": [
                "agi",
                "int"
            ],
            "descToken": "#trinity_shop_desc_item_diffusal_blade"
        },
        "item_disperser": {
            "tier": -1,
            "price": 6100,
            "categories": [
                "mobility",
                "control",
                "support"
            ],
            "attributes": [
                "agi",
                "int"
            ],
            "descToken": "#trinity_shop_desc_item_disperser"
        },
        "item_skadi": {
            "tier": -1,
            "price": 5900,
            "categories": [
                "survival",
                "mobility",
                "control"
            ],
            "attributes": [
                "agi",
                "int",
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_skadi"
        },
        "item_specialists_array": {
            "tier": -1,
            "price": 2550,
            "categories": [
                "damage"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_specialists_array"
        },
        "item_hydras_breath": {
            "tier": -1,
            "price": 5900,
            "categories": [
                "damage"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_hydras_breath"
        },
        "item_witch_blade": {
            "tier": -1,
            "price": 2775,
            "categories": [
                "damage",
                "magic"
            ],
            "attributes": [
                "int"
            ],
            "descToken": "#trinity_shop_desc_item_witch_blade"
        },
        "item_devastator": {
            "tier": -1,
            "price": 5975,
            "categories": [
                "damage",
                "magic"
            ],
            "attributes": [
                "int"
            ],
            "descToken": "#trinity_shop_desc_item_devastator"
        },
        "item_falcon_blade": {
            "tier": -1,
            "price": 1125,
            "categories": [
                "magic"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_falcon_blade"
        },
        "item_orb_of_corrosion": {
            "tier": -1,
            "price": 1050,
            "categories": [
                "damage"
            ],
            "attributes": [
                "agi"
            ],
            "descToken": "#trinity_shop_desc_item_orb_of_corrosion"
        },
        "item_butterfly": {
            "tier": 3,
            "price": 5500,
            "categories": [
                "damage",
                "survival",
                "mobility"
            ],
            "attributes": [
                "agi"
            ],
            "descToken": "#trinity_shop_desc_item_butterfly"
        },
        "item_mjollnir": {
            "tier": 3,
            "price": 5500,
            "categories": [
                "damage"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_mjollnir"
        },
        "item_manta": {
            "tier": 2,
            "price": 4700,
            "categories": [
                "damage",
                "survival",
                "mobility"
            ],
            "attributes": [
                "agi",
                "int",
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_manta"
        },
        "item_mask_of_madness": {
            "tier": -1,
            "price": 1900,
            "categories": [
                "damage",
                "survival"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_mask_of_madness"
        },
        "item_armlet": {
            "tier": -1,
            "price": 2500,
            "categories": [
                "damage",
                "survival"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_armlet"
        },
        "item_sange_and_yasha": {
            "tier": -1,
            "price": 4200,
            "categories": [
                "damage",
                "survival",
                "mobility"
            ],
            "attributes": [
                "agi",
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_sange_and_yasha"
        },
        "item_hand_of_midas": {
            "tier": 0,
            "price": 2400,
            "categories": [
                "damage"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_hand_of_midas"
        },
        "item_black_king_bar": {
            "tier": 2,
            "price": 4700,
            "categories": [
                "survival"
            ],
            "attributes": [
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_black_king_bar"
        },
        "item_sphere": {
            "tier": 2,
            "price": 4700,
            "categories": [
                "survival",
                "support"
            ],
            "attributes": [
                "agi",
                "int",
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_sphere"
        },
        "item_pipe": {
            "tier": 1,
            "price": 3500,
            "categories": [
                "survival",
                "support"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_pipe"
        },
        "item_glimmer_cape": {
            "tier": 0,
            "price": 2400,
            "categories": [
                "survival",
                "support"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_glimmer_cape"
        },
        "item_guardian_greaves": {
            "tier": 2,
            "price": 4700,
            "categories": [
                "magic",
                "mobility",
                "support"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_guardian_greaves"
        },
        "item_lotus_orb": {
            "tier": -1,
            "price": 3850,
            "categories": [
                "survival",
                "support"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_lotus_orb"
        },
        "item_consecrated_wraps": {
            "tier": -1,
            "price": 2600,
            "categories": [
                "survival"
            ],
            "attributes": [
                "agi",
                "int",
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_consecrated_wraps"
        },
        "item_mage_slayer": {
            "tier": -1,
            "price": 2800,
            "categories": [
                "damage",
                "survival"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_mage_slayer"
        },
        "item_heart": {
            "tier": 3,
            "price": 5500,
            "categories": [
                "survival"
            ],
            "attributes": [
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_heart"
        },
        "item_blade_mail": {
            "tier": 0,
            "price": 2400,
            "categories": [
                "damage",
                "survival"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_blade_mail"
        },
        "item_aeon_disk": {
            "tier": 1,
            "price": 3500,
            "categories": [
                "survival"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_aeon_disk"
        },
        "item_vanguard": {
            "tier": -1,
            "price": 1700,
            "categories": [
                "survival"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_vanguard"
        },
        "item_crimson_guard": {
            "tier": -1,
            "price": 3725,
            "categories": [
                "survival",
                "support"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_crimson_guard"
        },
        "item_assault": {
            "tier": -1,
            "price": 5125,
            "categories": [
                "damage",
                "survival",
                "support"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_assault"
        },
        "item_shivas_guard": {
            "tier": -1,
            "price": 4500,
            "categories": [
                "survival",
                "magic",
                "control"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_shivas_guard"
        },
        "item_heavens_halberd": {
            "tier": -1,
            "price": 3400,
            "categories": [
                "survival",
                "control"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_heavens_halberd"
        },
        "item_crellas_crozier": {
            "tier": -1,
            "price": 4800,
            "categories": [
                "survival"
            ],
            "attributes": [
                "agi",
                "int",
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_crellas_crozier"
        },
        "item_solar_crest": {
            "tier": -1,
            "price": 2575,
            "categories": [
                "damage",
                "survival",
                "support"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_solar_crest"
        },
        "item_pavise": {
            "tier": -1,
            "price": 1350,
            "categories": [
                "survival",
                "support"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_pavise"
        },
        "item_helm_of_the_dominator": {
            "tier": -1,
            "price": 2550,
            "categories": [
                "support"
            ],
            "attributes": [
                "agi",
                "int",
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_helm_of_the_dominator"
        },
        "item_helm_of_the_overlord": {
            "tier": -1,
            "price": 5650,
            "categories": [
                "support"
            ],
            "attributes": [
                "agi",
                "int",
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_helm_of_the_overlord"
        },
        "item_sheepstick": {
            "tier": 3,
            "price": 5500,
            "categories": [
                "magic",
                "control"
            ],
            "attributes": [
                "int"
            ],
            "descToken": "#trinity_shop_desc_item_sheepstick"
        },
        "item_cyclone": {
            "tier": 0,
            "price": 2400,
            "categories": [
                "magic",
                "mobility",
                "control",
                "support"
            ],
            "attributes": [
                "int"
            ],
            "descToken": "#trinity_shop_desc_item_cyclone"
        },
        "item_rod_of_atos": {
            "tier": 0,
            "price": 2400,
            "categories": [
                "magic",
                "control"
            ],
            "attributes": [
                "int"
            ],
            "descToken": "#trinity_shop_desc_item_rod_of_atos"
        },
        "item_hurricane_pike": {
            "tier": 2,
            "price": 4700,
            "categories": [
                "damage",
                "mobility",
                "support"
            ],
            "attributes": [
                "agi",
                "int",
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_hurricane_pike"
        },
        "item_gungir": {
            "tier": -1,
            "price": 4650,
            "categories": [
                "damage",
                "magic",
                "control"
            ],
            "attributes": [
                "int"
            ],
            "descToken": "#trinity_shop_desc_item_gungir"
        },
        "item_orchid": {
            "tier": -1,
            "price": 3275,
            "categories": [
                "damage",
                "magic",
                "control"
            ],
            "attributes": [
                "int"
            ],
            "descToken": "#trinity_shop_desc_item_orchid"
        },
        "item_nullifier": {
            "tier": -1,
            "price": 4350,
            "categories": [
                "damage",
                "survival",
                "control"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_nullifier"
        },
        "item_wind_waker": {
            "tier": -1,
            "price": 6800,
            "categories": [
                "magic",
                "mobility",
                "control",
                "support"
            ],
            "attributes": [
                "int"
            ],
            "descToken": "#trinity_shop_desc_item_wind_waker"
        },
        "item_ethereal_blade": {
            "tier": -1,
            "price": 5200,
            "categories": [
                "survival",
                "magic",
                "control",
                "support"
            ],
            "attributes": [
                "agi",
                "int",
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_ethereal_blade"
        },
        "item_meteor_hammer": {
            "tier": -1,
            "price": 2850,
            "categories": [
                "magic",
                "control"
            ],
            "attributes": [
                "agi",
                "int",
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_meteor_hammer"
        },
        "item_power_treads": {
            "tier": -1,
            "price": 1400,
            "categories": [
                "damage",
                "mobility"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_power_treads"
        },
        "item_phase_boots": {
            "tier": -1,
            "price": 1450,
            "categories": [
                "damage",
                "mobility"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_phase_boots"
        },
        "item_tranquil_boots": {
            "tier": -1,
            "price": 900,
            "categories": [
                "survival",
                "mobility"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_tranquil_boots"
        },
        "item_arcane_boots": {
            "tier": -1,
            "price": 1500,
            "categories": [
                "magic",
                "mobility",
                "support"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_arcane_boots"
        },
        "item_boots_of_bearing": {
            "tier": -1,
            "price": 4225,
            "categories": [
                "mobility",
                "support"
            ],
            "attributes": [
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_boots_of_bearing"
        },
        "item_ancient_janggo": {
            "tier": -1,
            "price": 1625,
            "categories": [
                "damage",
                "mobility",
                "support"
            ],
            "attributes": [
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_ancient_janggo"
        },
        "item_yasha_and_kaya": {
            "tier": -1,
            "price": 4200,
            "categories": [
                "damage",
                "magic",
                "mobility"
            ],
            "attributes": [
                "agi",
                "int"
            ],
            "descToken": "#trinity_shop_desc_item_yasha_and_kaya"
        },
        "item_blink": {
            "tier": 0,
            "price": 2400,
            "categories": [
                "mobility"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_blink"
        },
        "item_overwhelming_blink": {
            "tier": -1,
            "price": 6800,
            "categories": [
                "survival",
                "mobility",
                "control"
            ],
            "attributes": [
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_overwhelming_blink"
        },
        "item_swift_blink": {
            "tier": -1,
            "price": 6800,
            "categories": [
                "mobility"
            ],
            "attributes": [
                "agi"
            ],
            "descToken": "#trinity_shop_desc_item_swift_blink"
        },
        "item_arcane_blink": {
            "tier": -1,
            "price": 6800,
            "categories": [
                "magic",
                "mobility"
            ],
            "attributes": [
                "int"
            ],
            "descToken": "#trinity_shop_desc_item_arcane_blink"
        },
        "item_force_staff": {
            "tier": 0,
            "price": 2400,
            "categories": [
                "mobility",
                "support"
            ],
            "attributes": [
                "int"
            ],
            "descToken": "#trinity_shop_desc_item_force_staff"
        },
        "item_travel_boots": {
            "tier": -1,
            "price": 2500,
            "categories": [
                "mobility"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_travel_boots"
        },
        "item_travel_boots_2": {
            "tier": -1,
            "price": 4500,
            "categories": [
                "mobility"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_travel_boots_2"
        },
        "item_mekansm": {
            "tier": 0,
            "price": 2400,
            "categories": [
                "survival",
                "support"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_mekansm"
        },
        "item_holy_locket": {
            "tier": -1,
            "price": 2250,
            "categories": [
                "support"
            ],
            "attributes": [
                "agi",
                "int",
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_holy_locket"
        },
        "item_essence_distiller": {
            "tier": -1,
            "price": 1775,
            "categories": [
                "support"
            ],
            "attributes": [
                "agi",
                "int",
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_essence_distiller"
        },
        "item_spirit_vessel": {
            "tier": -1,
            "price": 2725,
            "categories": [
                "control",
                "support"
            ],
            "attributes": [
                "agi",
                "int",
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_spirit_vessel"
        },
        "item_urn_of_shadows": {
            "tier": -1,
            "price": 825,
            "categories": [
                "support"
            ],
            "attributes": [
                "agi",
                "int",
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_urn_of_shadows"
        },
        "item_vladmir": {
            "tier": -1,
            "price": 2200,
            "categories": [
                "survival",
                "support"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_vladmir"
        },
        "item_headdress": {
            "tier": -1,
            "price": 425,
            "categories": [
                "survival",
                "support"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_headdress"
        },
        "item_buckler": {
            "tier": -1,
            "price": 425,
            "categories": [
                "survival",
                "support"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_buckler"
        },
        "item_ring_of_basilius": {
            "tier": -1,
            "price": 425,
            "categories": [
                "magic",
                "support"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_ring_of_basilius"
        },
        "item_kaya_and_sange": {
            "tier": -1,
            "price": 4200,
            "categories": [
                "survival",
                "magic"
            ],
            "attributes": [
                "int",
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_kaya_and_sange"
        },
        "item_dagon": {
            "tier": -1,
            "price": 3000,
            "categories": [
                "magic"
            ],
            "attributes": [
                "agi",
                "int",
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_dagon"
        },
        "item_veil_of_discord": {
            "tier": -1,
            "price": 1700,
            "categories": [
                "magic"
            ],
            "attributes": [
                "int"
            ],
            "descToken": "#trinity_shop_desc_item_veil_of_discord"
        },
        "item_bloodstone": {
            "tier": -1,
            "price": 4700,
            "categories": [
                "survival",
                "magic"
            ],
            "attributes": [
                "int"
            ],
            "descToken": "#trinity_shop_desc_item_bloodstone"
        },
        "item_angels_demise": {
            "tier": -1,
            "price": 5600,
            "categories": [
                "magic",
                "control"
            ],
            "attributes": [
                "agi",
                "int",
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_angels_demise"
        },
        "item_phylactery": {
            "tier": -1,
            "price": 2600,
            "categories": [
                "magic",
                "control"
            ],
            "attributes": [
                "agi",
                "int",
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_phylactery"
        },
        "item_ultimate_scepter": {
            "tier": -1,
            "price": 4200,
            "categories": [
                "magic"
            ],
            "attributes": [
                "agi",
                "int",
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_ultimate_scepter"
        },
        "item_aghanims_shard": {
            "tier": -1,
            "price": 1400,
            "categories": [
                "magic"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_aghanims_shard"
        },
        "item_ultimate_scepter_2": {
            "tier": -1,
            "price": 5800,
            "categories": [
                "magic"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_ultimate_scepter_2"
        },
        "item_octarine_core": {
            "tier": -1,
            "price": 4900,
            "categories": [
                "magic"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_octarine_core"
        },
        "item_refresher": {
            "tier": -1,
            "price": 5000,
            "categories": [
                "magic"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_refresher"
        },
        "item_aether_lens": {
            "tier": -1,
            "price": 2275,
            "categories": [
                "magic"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_aether_lens"
        },
        "item_soul_ring": {
            "tier": -1,
            "price": 805,
            "categories": [
                "magic"
            ],
            "attributes": [
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_soul_ring"
        },
        "item_fluffy_hat": {
            "tier": -1,
            "price": 250,
            "categories": [
                "survival"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_fluffy_hat"
        },
        "item_wizard_hat": {
            "tier": -1,
            "price": 250,
            "categories": [
                "magic"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_wizard_hat"
        },
        "item_ring_of_regen": {
            "tier": -1,
            "price": 175,
            "categories": [
                "survival"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_ring_of_regen"
        },
        "item_sobi_mask": {
            "tier": -1,
            "price": 175,
            "categories": [
                "magic"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_sobi_mask"
        },
        "item_magic_stick": {
            "tier": -1,
            "price": 200,
            "categories": [
                "survival",
                "magic"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_magic_stick"
        },
        "item_magic_wand": {
            "tier": -1,
            "price": 460,
            "categories": [
                "survival",
                "magic"
            ],
            "attributes": [
                "str",
                "agi",
                "int"
            ],
            "descToken": "#trinity_shop_desc_item_magic_wand"
        },
        "item_ghost": {
            "tier": -1,
            "price": 1500,
            "categories": [
                "survival"
            ],
            "attributes": [
                "str",
                "agi",
                "int"
            ],
            "descToken": "#trinity_shop_desc_item_ghost"
        },
        "item_quelling_blade": {
            "tier": -1,
            "price": 100,
            "categories": [
                "damage"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_quelling_blade"
        },
        "item_blades_of_attack": {
            "tier": -1,
            "price": 450,
            "categories": [
                "damage"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_blades_of_attack"
        },
        "item_gloves": {
            "tier": -1,
            "price": 450,
            "categories": [
                "damage"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_gloves"
        },
        "item_javelin": {
            "tier": -1,
            "price": 900,
            "categories": [
                "damage"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_javelin"
        },
        "item_blight_stone": {
            "tier": -1,
            "price": 300,
            "categories": [
                "damage"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_blight_stone"
        },
        "item_orb_of_venom": {
            "tier": -1,
            "price": 350,
            "categories": [
                "damage"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_orb_of_venom"
        },
        "item_orb_of_frost": {
            "tier": -1,
            "price": 300,
            "categories": [
                "damage"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_orb_of_frost"
        },
        "item_shadow_amulet": {
            "tier": -1,
            "price": 900,
            "categories": [
                "mobility"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_shadow_amulet"
        },
        "item_ring_of_protection": {
            "tier": -1,
            "price": 175,
            "categories": [
                "survival"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_ring_of_protection"
        },
        "item_chainmail": {
            "tier": -1,
            "price": 500,
            "categories": [
                "survival"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_chainmail"
        },
        "item_shawl": {
            "tier": -1,
            "price": 450,
            "categories": [
                "survival"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_shawl"
        },
        "item_boots": {
            "tier": -1,
            "price": 500,
            "categories": [
                "mobility"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_boots"
        },
        "item_wind_lace": {
            "tier": -1,
            "price": 225,
            "categories": [
                "mobility"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_wind_lace"
        },
        "item_infused_raindrop": {
            "tier": -1,
            "price": 225,
            "categories": [
                "survival"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_infused_raindrop"
        },
        "item_bottle": {
            "tier": -1,
            "price": 675,
            "categories": [
                "survival",
                "magic"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_bottle"
        },
        "item_moon_shard": {
            "tier": -1,
            "price": 4000,
            "categories": [
                "damage"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_moon_shard"
        },
        "item_gem": {
            "tier": -1,
            "price": 900,
            "categories": [
                "support"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_gem"
        },
        "item_dragon_lance": {
            "tier": -1,
            "price": 1900,
            "categories": [
                "damage"
            ],
            "attributes": [
                "agi",
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_dragon_lance"
        },
        "item_yasha": {
            "tier": -1,
            "price": 2100,
            "categories": [
                "damage",
                "survival",
                "mobility"
            ],
            "attributes": [
                "agi"
            ],
            "descToken": "#trinity_shop_desc_item_yasha"
        },
        "item_sange": {
            "tier": -1,
            "price": 2100,
            "categories": [
                "survival"
            ],
            "attributes": [
                "str"
            ],
            "descToken": "#trinity_shop_desc_item_sange"
        },
        "item_kaya": {
            "tier": -1,
            "price": 2100,
            "categories": [
                "magic"
            ],
            "attributes": [
                "int"
            ],
            "descToken": "#trinity_shop_desc_item_kaya"
        },
        "item_soul_booster": {
            "tier": -1,
            "price": 3000,
            "categories": [
                "survival",
                "magic"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_soul_booster"
        },
        "item_pers": {
            "tier": -1,
            "price": 1400,
            "categories": [
                "survival",
                "magic"
            ],
            "attributes": [],
            "descToken": "#trinity_shop_desc_item_pers"
        },
        "item_oblivion_staff": {
            "tier": -1,
            "price": 1625,
            "categories": [
                "damage",
                "magic"
            ],
            "attributes": [
                "int"
            ],
            "descToken": "#trinity_shop_desc_item_oblivion_staff"
        },
        "item_bracer": {
            "tier": -1,
            "price": 505,
            "categories": [
                "survival"
            ],
            "attributes": [
                "str",
                "agi",
                "int"
            ],
            "descToken": "#trinity_shop_desc_item_bracer"
        },
        "item_wraith_band": {
            "tier": -1,
            "price": 505,
            "categories": [
                "mobility"
            ],
            "attributes": [
                "agi",
                "str",
                "int"
            ],
            "descToken": "#trinity_shop_desc_item_wraith_band"
        },
        "item_null_talisman": {
            "tier": -1,
            "price": 505,
            "categories": [
                "magic"
            ],
            "attributes": [
                "int",
                "str",
                "agi"
            ],
            "descToken": "#trinity_shop_desc_item_null_talisman"
        }
    },
    "recipes": {
        "item_abyssal_blade": {
            "price": 5500,
            "components": [
                "item_basher",
                "item_sange"
            ],
            "recipe": 1000
        },
        "item_aeon_disk": {
            "price": 3500,
            "components": [
                "item_vitality_booster",
                "item_energy_booster"
            ],
            "recipe": 1700
        },
        "item_aether_lens": {
            "price": 2275,
            "components": [
                "item_energy_booster",
                "item_void_stone"
            ],
            "recipe": 775
        },
        "item_aghanims_shard": {
            "price": 1400,
            "components": [],
            "recipe": 0
        },
        "item_ancient_janggo": {
            "price": 1625,
            "components": [
                "item_headdress",
                "item_belt_of_strength",
                "item_wind_lace"
            ],
            "recipe": 525
        },
        "item_angels_demise": {
            "price": 5600,
            "components": [
                "item_phylactery",
                "item_soul_booster"
            ],
            "recipe": 0
        },
        "item_arcane_blink": {
            "price": 6950,
            "components": [
                "item_blink",
                "item_mystic_staff"
            ],
            "recipe": 1750
        },
        "item_arcane_boots": {
            "price": 1500,
            "components": [
                "item_boots",
                "item_ring_of_basilius",
                "item_wizard_hat"
            ],
            "recipe": 325
        },
        "item_armlet": {
            "price": 2500,
            "components": [
                "item_helm_of_iron_will",
                "item_gloves",
                "item_blades_of_attack"
            ],
            "recipe": 625
        },
        "item_assault": {
            "price": 5125,
            "components": [
                "item_buckler",
                "item_hyperstone",
                "item_platemail"
            ],
            "recipe": 1300
        },
        "item_basher": {
            "price": 2400,
            "components": [
                "item_mithril_hammer",
                "item_belt_of_strength"
            ],
            "recipe": 350
        },
        "item_belt_of_strength": {
            "price": 450,
            "components": [],
            "recipe": 0
        },
        "item_bfury": {
            "price": 4700,
            "components": [
                "item_pers",
                "item_broadsword",
                "item_broadsword",
                "item_quelling_blade"
            ],
            "recipe": 1200
        },
        "item_black_king_bar": {
            "price": 4700,
            "components": [
                "item_mithril_hammer",
                "item_ogre_axe"
            ],
            "recipe": 2100
        },
        "item_blade_mail": {
            "price": 2400,
            "components": [
                "item_broadsword",
                "item_splintmail"
            ],
            "recipe": 450
        },
        "item_blade_of_alacrity": {
            "price": 1000,
            "components": [],
            "recipe": 0
        },
        "item_blades_of_attack": {
            "price": 450,
            "components": [],
            "recipe": 0
        },
        "item_blight_stone": {
            "price": 300,
            "components": [],
            "recipe": 0
        },
        "item_blink": {
            "price": 2400,
            "components": [],
            "recipe": 0
        },
        "item_blitz_knuckles": {
            "price": 1000,
            "components": [],
            "recipe": 0
        },
        "item_bloodstone": {
            "price": 4700,
            "components": [
                "item_veil_of_discord",
                "item_soul_booster"
            ],
            "recipe": 0
        },
        "item_bloodthorn": {
            "price": 6400,
            "components": [
                "item_orchid",
                "item_oblivion_staff",
                "item_javelin"
            ],
            "recipe": 600
        },
        "item_boots": {
            "price": 500,
            "components": [],
            "recipe": 0
        },
        "item_boots_of_bearing": {
            "price": 4225,
            "components": [
                "item_tranquil_boots",
                "item_ancient_janggo",
                "item_ring_of_tarrasque"
            ],
            "recipe": 0
        },
        "item_boots_of_elves": {
            "price": 450,
            "components": [],
            "recipe": 0
        },
        "item_branches": {
            "price": 55,
            "components": [],
            "recipe": 0
        },
        "item_broadsword": {
            "price": 1000,
            "components": [],
            "recipe": 0
        },
        "item_buckler": {
            "price": 425,
            "components": [
                "item_ring_of_protection"
            ],
            "recipe": 250
        },
        "item_butterfly": {
            "price": 5500,
            "components": [
                "item_eagle",
                "item_claymore",
                "item_talisman_of_evasion"
            ],
            "recipe": 50
        },
        "item_chainmail": {
            "price": 500,
            "components": [],
            "recipe": 0
        },
        "item_chasm_stone": {
            "price": 900,
            "components": [],
            "recipe": 0
        },
        "item_circlet": {
            "price": 155,
            "components": [],
            "recipe": 0
        },
        "item_claymore": {
            "price": 1350,
            "components": [],
            "recipe": 0
        },
        "item_cloak": {
            "price": 900,
            "components": [],
            "recipe": 0
        },
        "item_consecrated_wraps": {
            "price": 2600,
            "components": [
                "item_vitality_booster",
                "item_shawl",
                "item_crown"
            ],
            "recipe": 700
        },
        "item_crellas_crozier": {
            "price": 4800,
            "components": [
                "item_ghost",
                "item_soul_booster"
            ],
            "recipe": 300
        },
        "item_crimson_guard": {
            "price": 3725,
            "components": [
                "item_vanguard",
                "item_helm_of_iron_will"
            ],
            "recipe": 1050
        },
        "item_crown": {
            "price": 450,
            "components": [],
            "recipe": 0
        },
        "item_cyclone": {
            "price": 2400,
            "components": [
                "item_staff_of_wizardry",
                "item_void_stone",
                "item_wind_lace"
            ],
            "recipe": 475
        },
        "item_dagon": {
            "price": 3000,
            "components": [
                "item_point_booster",
                "item_crown",
                "item_wizard_hat"
            ],
            "recipe": 1100
        },
        "item_demon_edge": {
            "price": 2200,
            "components": [],
            "recipe": 0
        },
        "item_desolator": {
            "price": 3500,
            "components": [
                "item_mithril_hammer",
                "item_mithril_hammer",
                "item_blight_stone"
            ],
            "recipe": 0
        },
        "item_devastator": {
            "price": 5975,
            "components": [
                "item_witch_blade",
                "item_mystic_staff"
            ],
            "recipe": 400
        },
        "item_diadem": {
            "price": 1000,
            "components": [],
            "recipe": 0
        },
        "item_diffusal_blade": {
            "price": 2500,
            "components": [
                "item_blade_of_alacrity",
                "item_robe"
            ],
            "recipe": 1050
        },
        "item_disperser": {
            "price": 6100,
            "components": [
                "item_diffusal_blade",
                "item_eagle"
            ],
            "recipe": 800
        },
        "item_dragon_lance": {
            "price": 2000,
            "components": [
                "item_blade_of_alacrity",
                "item_belt_of_strength"
            ],
            "recipe": 550
        },
        "item_eagle": {
            "price": 2800,
            "components": [],
            "recipe": 0
        },
        "item_echo_sabre": {
            "price": 2700,
            "components": [
                "item_ogre_axe",
                "item_broadsword",
                "item_void_stone"
            ],
            "recipe": 0
        },
        "item_energy_booster": {
            "price": 800,
            "components": [],
            "recipe": 0
        },
        "item_essence_distiller": {
            "price": 1775,
            "components": [
                "item_urn_of_shadows",
                "item_chainmail",
                "item_wizard_hat"
            ],
            "recipe": 200
        },
        "item_ethereal_blade": {
            "price": 5200,
            "components": [
                "item_ultimate_orb",
                "item_ghost"
            ],
            "recipe": 900
        },
        "item_faerie_fire": {
            "price": 65,
            "components": [],
            "recipe": 0
        },
        "item_falcon_blade": {
            "price": 1125,
            "components": [
                "item_blades_of_attack",
                "item_fluffy_hat",
                "item_sobi_mask"
            ],
            "recipe": 250
        },
        "item_fluffy_hat": {
            "price": 250,
            "components": [],
            "recipe": 0
        },
        "item_force_staff": {
            "price": 2400,
            "components": [
                "item_staff_of_wizardry",
                "item_fluffy_hat"
            ],
            "recipe": 1150
        },
        "item_gauntlets": {
            "price": 140,
            "components": [],
            "recipe": 0
        },
        "item_ghost": {
            "price": 1500,
            "components": [],
            "recipe": 0
        },
        "item_glimmer_cape": {
            "price": 2400,
            "components": [
                "item_shadow_amulet",
                "item_shawl"
            ],
            "recipe": 1050
        },
        "item_gloves": {
            "price": 450,
            "components": [],
            "recipe": 0
        },
        "item_greater_crit": {
            "price": 5500,
            "components": [
                "item_lesser_crit",
                "item_demon_edge"
            ],
            "recipe": 1300
        },
        "item_guardian_greaves": {
            "price": 4700,
            "components": [
                "item_arcane_boots",
                "item_mekansm"
            ],
            "recipe": 800
        },
        "item_gungir": {
            "price": 4800,
            "components": [
                "item_rod_of_atos",
                "item_point_booster",
                "item_chasm_stone"
            ],
            "recipe": 300
        },
        "item_hand_of_midas": {
            "price": 2400,
            "components": [
                "item_gloves"
            ],
            "recipe": 1950
        },
        "item_harpoon": {
            "price": 4700,
            "components": [
                "item_echo_sabre",
                "item_diadem"
            ],
            "recipe": 1000
        },
        "item_headdress": {
            "price": 425,
            "components": [
                "item_ring_of_regen"
            ],
            "recipe": 250
        },
        "item_heart": {
            "price": 5500,
            "components": [
                "item_reaver",
                "item_ring_of_tarrasque"
            ],
            "recipe": 1000
        },
        "item_heavens_halberd": {
            "price": 3400,
            "components": [
                "item_talisman_of_evasion",
                "item_splintmail",
                "item_ring_of_health"
            ],
            "recipe": 450
        },
        "item_helm_of_iron_will": {
            "price": 975,
            "components": [],
            "recipe": 0
        },
        "item_helm_of_the_dominator": {
            "price": 2550,
            "components": [
                "item_helm_of_iron_will",
                "item_crown"
            ],
            "recipe": 1125
        },
        "item_helm_of_the_overlord": {
            "price": 5650,
            "components": [
                "item_helm_of_the_dominator",
                "item_ultimate_orb"
            ],
            "recipe": 300
        },
        "item_holy_locket": {
            "price": 2250,
            "components": [
                "item_magic_wand",
                "item_crown"
            ],
            "recipe": 1340
        },
        "item_hurricane_pike": {
            "price": 4700,
            "components": [
                "item_force_staff",
                "item_dragon_lance"
            ],
            "recipe": 300
        },
        "item_hydras_breath": {
            "price": 5900,
            "components": [
                "item_specialists_array",
                "item_dragon_lance",
                "item_orb_of_venom"
            ],
            "recipe": 1100
        },
        "item_hyperstone": {
            "price": 2000,
            "components": [],
            "recipe": 0
        },
        "item_invis_sword": {
            "price": 3500,
            "components": [
                "item_claymore",
                "item_blitz_knuckles",
                "item_shadow_amulet"
            ],
            "recipe": 250
        },
        "item_javelin": {
            "price": 900,
            "components": [],
            "recipe": 0
        },
        "item_kaya": {
            "price": 2100,
            "components": [
                "item_staff_of_wizardry",
                "item_robe"
            ],
            "recipe": 650
        },
        "item_kaya_and_sange": {
            "price": 4200,
            "components": [
                "item_sange",
                "item_kaya"
            ],
            "recipe": 0
        },
        "item_lesser_crit": {
            "price": 2000,
            "components": [
                "item_claymore",
                "item_blades_of_attack"
            ],
            "recipe": 200
        },
        "item_lifesteal": {
            "price": 900,
            "components": [],
            "recipe": 0
        },
        "item_lotus_orb": {
            "price": 3850,
            "components": [
                "item_pers",
                "item_platemail",
                "item_energy_booster"
            ],
            "recipe": 250
        },
        "item_maelstrom": {
            "price": 3500,
            "components": [
                "item_mithril_hammer",
                "item_javelin",
                "item_gloves"
            ],
            "recipe": 550
        },
        "item_mage_slayer": {
            "price": 2800,
            "components": [
                "item_pers",
                "item_cloak",
                "item_blades_of_attack",
                "item_orb_of_venom"
            ],
            "recipe": 0
        },
        "item_magic_stick": {
            "price": 200,
            "components": [],
            "recipe": 0
        },
        "item_magic_wand": {
            "price": 460,
            "components": [
                "item_magic_stick",
                "item_branches",
                "item_branches"
            ],
            "recipe": 150
        },
        "item_manta": {
            "price": 4700,
            "components": [
                "item_yasha",
                "item_diadem"
            ],
            "recipe": 1600
        },
        "item_mantle": {
            "price": 140,
            "components": [],
            "recipe": 0
        },
        "item_mask_of_madness": {
            "price": 1900,
            "components": [
                "item_broadsword",
                "item_lifesteal"
            ],
            "recipe": 0
        },
        "item_mekansm": {
            "price": 2400,
            "components": [
                "item_headdress",
                "item_chainmail"
            ],
            "recipe": 1475
        },
        "item_meteor_hammer": {
            "price": 2850,
            "components": [
                "item_crown",
                "item_kaya"
            ],
            "recipe": 300
        },
        "item_mithril_hammer": {
            "price": 1600,
            "components": [],
            "recipe": 0
        },
        "item_mjollnir": {
            "price": 5500,
            "components": [
                "item_maelstrom",
                "item_hyperstone"
            ],
            "recipe": 0
        },
        "item_monkey_king_bar": {
            "price": 5500,
            "components": [
                "item_demon_edge",
                "item_blitz_knuckles",
                "item_javelin"
            ],
            "recipe": 1400
        },
        "item_mystic_staff": {
            "price": 2800,
            "components": [],
            "recipe": 0
        },
        "item_null_talisman": {
            "price": 505,
            "components": [
                "item_circlet",
                "item_mantle"
            ],
            "recipe": 210
        },
        "item_nullifier": {
            "price": 4350,
            "components": [
                "item_relic",
                "item_splintmail"
            ],
            "recipe": 0
        },
        "item_oblivion_staff": {
            "price": 1625,
            "components": [
                "item_blitz_knuckles",
                "item_robe",
                "item_sobi_mask"
            ],
            "recipe": 0
        },
        "item_octarine_core": {
            "price": 4900,
            "components": [
                "item_soul_booster",
                "item_tiara_of_selemene"
            ],
            "recipe": 200
        },
        "item_ogre_axe": {
            "price": 1000,
            "components": [],
            "recipe": 0
        },
        "item_orb_of_corrosion": {
            "price": 1050,
            "components": [
                "item_boots_of_elves",
                "item_orb_of_frost",
                "item_blight_stone"
            ],
            "recipe": 0
        },
        "item_orb_of_frost": {
            "price": 300,
            "components": [],
            "recipe": 0
        },
        "item_orb_of_venom": {
            "price": 350,
            "components": [],
            "recipe": 0
        },
        "item_orchid": {
            "price": 3275,
            "components": [
                "item_oblivion_staff",
                "item_claymore"
            ],
            "recipe": 300
        },
        "item_overwhelming_blink": {
            "price": 6950,
            "components": [
                "item_blink",
                "item_reaver"
            ],
            "recipe": 1750
        },
        "item_pavise": {
            "price": 1350,
            "components": [
                "item_wizard_hat",
                "item_fluffy_hat",
                "item_ring_of_protection"
            ],
            "recipe": 675
        },
        "item_pers": {
            "price": 1400,
            "components": [
                "item_ring_of_health",
                "item_void_stone"
            ],
            "recipe": 0
        },
        "item_phase_boots": {
            "price": 1450,
            "components": [
                "item_boots",
                "item_chainmail",
                "item_blades_of_attack"
            ],
            "recipe": 0
        },
        "item_phylactery": {
            "price": 2600,
            "components": [
                "item_pers",
                "item_diadem"
            ],
            "recipe": 200
        },
        "item_pipe": {
            "price": 3500,
            "components": [
                "item_ring_of_tarrasque",
                "item_cloak",
                "item_shawl"
            ],
            "recipe": 450
        },
        "item_platemail": {
            "price": 1400,
            "components": [],
            "recipe": 0
        },
        "item_point_booster": {
            "price": 1200,
            "components": [],
            "recipe": 0
        },
        "item_power_treads": {
            "price": 1400,
            "components": [
                "item_boots",
                "item_gloves",
                "item_belt_of_strength"
            ],
            "recipe": 0
        },
        "item_quelling_blade": {
            "price": 100,
            "components": [],
            "recipe": 0
        },
        "item_radiance": {
            "price": 4700,
            "components": [
                "item_relic",
                "item_talisman_of_evasion"
            ],
            "recipe": 0
        },
        "item_rapier": {
            "price": 5600,
            "components": [
                "item_relic",
                "item_demon_edge"
            ],
            "recipe": 0
        },
        "item_reaver": {
            "price": 2800,
            "components": [],
            "recipe": 0
        },
        "item_recipe_travel_boots": {
            "price": 2000,
            "components": [],
            "recipe": 0
        },
        "item_refresher": {
            "price": 5000,
            "components": [
                "item_ring_of_tarrasque",
                "item_tiara_of_selemene"
            ],
            "recipe": 1600
        },
        "item_relic": {
            "price": 3400,
            "components": [],
            "recipe": 0
        },
        "item_revenants_brooch": {
            "price": 3300,
            "components": [
                "item_lesser_crit",
                "item_voodoo_mask"
            ],
            "recipe": 650
        },
        "item_ring_of_basilius": {
            "price": 425,
            "components": [
                "item_sobi_mask"
            ],
            "recipe": 250
        },
        "item_ring_of_health": {
            "price": 700,
            "components": [],
            "recipe": 0
        },
        "item_ring_of_protection": {
            "price": 175,
            "components": [],
            "recipe": 0
        },
        "item_ring_of_regen": {
            "price": 175,
            "components": [],
            "recipe": 0
        },
        "item_ring_of_tarrasque": {
            "price": 1700,
            "components": [],
            "recipe": 0
        },
        "item_robe": {
            "price": 450,
            "components": [],
            "recipe": 0
        },
        "item_rod_of_atos": {
            "price": 2400,
            "components": [
                "item_staff_of_wizardry",
                "item_vitality_booster"
            ],
            "recipe": 400
        },
        "item_sange": {
            "price": 2100,
            "components": [
                "item_ogre_axe",
                "item_belt_of_strength"
            ],
            "recipe": 650
        },
        "item_sange_and_yasha": {
            "price": 4200,
            "components": [
                "item_sange",
                "item_yasha"
            ],
            "recipe": 0
        },
        "item_satanic": {
            "price": 5500,
            "components": [
                "item_reaver",
                "item_claymore",
                "item_lifesteal"
            ],
            "recipe": 450
        },
        "item_shadow_amulet": {
            "price": 900,
            "components": [],
            "recipe": 0
        },
        "item_shawl": {
            "price": 450,
            "components": [],
            "recipe": 0
        },
        "item_sheepstick": {
            "price": 5500,
            "components": [
                "item_mystic_staff",
                "item_tiara_of_selemene"
            ],
            "recipe": 1000
        },
        "item_shivas_guard": {
            "price": 4500,
            "components": [
                "item_platemail",
                "item_splintmail",
                "item_chasm_stone"
            ],
            "recipe": 1350
        },
        "item_silver_edge": {
            "price": 5950,
            "components": [
                "item_invis_sword",
                "item_demon_edge"
            ],
            "recipe": 250
        },
        "item_skadi": {
            "price": 5900,
            "components": [
                "item_ultimate_orb",
                "item_ultimate_orb",
                "item_orb_of_frost"
            ],
            "recipe": 0
        },
        "item_sobi_mask": {
            "price": 175,
            "components": [],
            "recipe": 0
        },
        "item_solar_crest": {
            "price": 2575,
            "components": [
                "item_pavise",
                "item_chainmail",
                "item_wind_lace"
            ],
            "recipe": 500
        },
        "item_soul_booster": {
            "price": 3000,
            "components": [
                "item_point_booster",
                "item_vitality_booster",
                "item_energy_booster"
            ],
            "recipe": 0
        },
        "item_soul_ring": {
            "price": 805,
            "components": [
                "item_ring_of_protection",
                "item_gauntlets",
                "item_gauntlets"
            ],
            "recipe": 350
        },
        "item_specialists_array": {
            "price": 2550,
            "components": [
                "item_blade_of_alacrity",
                "item_broadsword"
            ],
            "recipe": 550
        },
        "item_sphere": {
            "price": 4700,
            "components": [
                "item_pers",
                "item_ultimate_orb"
            ],
            "recipe": 500
        },
        "item_spirit_vessel": {
            "price": 2725,
            "components": [
                "item_urn_of_shadows",
                "item_diadem"
            ],
            "recipe": 900
        },
        "item_splintmail": {
            "price": 950,
            "components": [],
            "recipe": 0
        },
        "item_staff_of_wizardry": {
            "price": 1000,
            "components": [],
            "recipe": 0
        },
        "item_swift_blink": {
            "price": 6950,
            "components": [
                "item_blink",
                "item_eagle"
            ],
            "recipe": 1750
        },
        "item_talisman_of_evasion": {
            "price": 1300,
            "components": [],
            "recipe": 0
        },
        "item_tango": {
            "price": 90,
            "components": [],
            "recipe": 0
        },
        "item_tiara_of_selemene": {
            "price": 1700,
            "components": [],
            "recipe": 0
        },
        "item_tranquil_boots": {
            "price": 900,
            "components": [
                "item_boots",
                "item_wind_lace",
                "item_ring_of_regen"
            ],
            "recipe": 0
        },
        "item_travel_boots": {
            "price": 2500,
            "components": [
                "item_boots"
            ],
            "recipe": 2000
        },
        "item_travel_boots_2": {
            "price": 4500,
            "components": [
                "item_travel_boots",
                "item_recipe_travel_boots"
            ],
            "recipe": 0
        },
        "item_ultimate_orb": {
            "price": 2800,
            "components": [],
            "recipe": 0
        },
        "item_ultimate_scepter": {
            "price": 4200,
            "components": [
                "item_point_booster",
                "item_staff_of_wizardry",
                "item_ogre_axe",
                "item_blade_of_alacrity"
            ],
            "recipe": 0
        },
        "item_ultimate_scepter_2": {
            "price": 5800,
            "components": [
                "item_ultimate_scepter"
            ],
            "recipe": 1600
        },
        "item_urn_of_shadows": {
            "price": 825,
            "components": [
                "item_sobi_mask",
                "item_ring_of_protection",
                "item_circlet"
            ],
            "recipe": 320
        },
        "item_vanguard": {
            "price": 1700,
            "components": [
                "item_vitality_booster",
                "item_ring_of_health"
            ],
            "recipe": 0
        },
        "item_veil_of_discord": {
            "price": 1700,
            "components": [
                "item_voodoo_mask",
                "item_robe",
                "item_fluffy_hat"
            ],
            "recipe": 350
        },
        "item_vitality_booster": {
            "price": 1000,
            "components": [],
            "recipe": 0
        },
        "item_vladmir": {
            "price": 2200,
            "components": [
                "item_buckler",
                "item_ring_of_basilius",
                "item_lifesteal",
                "item_blades_of_attack"
            ],
            "recipe": 0
        },
        "item_void_stone": {
            "price": 700,
            "components": [],
            "recipe": 0
        },
        "item_voodoo_mask": {
            "price": 650,
            "components": [],
            "recipe": 0
        },
        "item_wind_lace": {
            "price": 225,
            "components": [],
            "recipe": 0
        },
        "item_wind_waker": {
            "price": 6600,
            "components": [
                "item_cyclone",
                "item_mystic_staff"
            ],
            "recipe": 1400
        },
        "item_witch_blade": {
            "price": 2775,
            "components": [
                "item_oblivion_staff",
                "item_chainmail",
                "item_orb_of_venom"
            ],
            "recipe": 300
        },
        "item_wizard_hat": {
            "price": 250,
            "components": [],
            "recipe": 0
        },
        "item_yasha": {
            "price": 2100,
            "components": [
                "item_blade_of_alacrity",
                "item_boots_of_elves"
            ],
            "recipe": 650
        },
        "item_yasha_and_kaya": {
            "price": 4200,
            "components": [
                "item_kaya",
                "item_yasha"
            ],
            "recipe": 0
        },
        "item_slippers": {
            "price": 140,
            "components": [],
            "recipe": 0
        },
        "item_bracer": {
            "price": 505,
            "components": [
                "item_circlet",
                "item_gauntlets"
            ],
            "recipe": 210
        },
        "item_wraith_band": {
            "price": 505,
            "components": [
                "item_circlet",
                "item_slippers"
            ],
            "recipe": 210
        },
        "item_infused_raindrop": {
            "price": 225,
            "components": [],
            "recipe": 0
        },
        "item_bottle": {
            "price": 675,
            "components": [],
            "recipe": 0
        },
        "item_moon_shard": {
            "price": 4000,
            "components": [
                "item_hyperstone",
                "item_hyperstone"
            ],
            "recipe": 0
        },
        "item_gem": {
            "price": 900,
            "components": [],
            "recipe": 0
        }
    },
    "itemIds": {
        "item_abyssal_blade": 208,
        "item_aeon_disk": 256,
        "item_aether_lens": 232,
        "item_aghanims_shard": 609,
        "item_ancient_janggo": 185,
        "item_angels_demise": 1808,
        "item_arcane_blink": 604,
        "item_arcane_boots": 180,
        "item_armlet": 151,
        "item_assault": 112,
        "item_basher": 143,
        "item_belt_of_strength": 17,
        "item_bfury": 145,
        "item_black_king_bar": 116,
        "item_blade_mail": 127,
        "item_blade_of_alacrity": 22,
        "item_blades_of_attack": 2,
        "item_blight_stone": 240,
        "item_blink": 1,
        "item_blitz_knuckles": 485,
        "item_bloodstone": 121,
        "item_bloodthorn": 250,
        "item_boots": 29,
        "item_boots_of_bearing": 931,
        "item_boots_of_elves": 18,
        "item_branches": 16,
        "item_broadsword": 3,
        "item_buckler": 86,
        "item_butterfly": 139,
        "item_chainmail": 4,
        "item_chasm_stone": 1872,
        "item_circlet": 20,
        "item_claymore": 5,
        "item_cloak": 31,
        "item_consecrated_wraps": 1854,
        "item_crellas_crozier": 1856,
        "item_crimson_guard": 242,
        "item_crown": 261,
        "item_cyclone": 100,
        "item_dagon": 104,
        "item_demon_edge": 51,
        "item_desolator": 168,
        "item_devastator": 1806,
        "item_diadem": 1122,
        "item_diffusal_blade": 174,
        "item_disperser": 1097,
        "item_dragon_lance": 236,
        "item_eagle": 52,
        "item_echo_sabre": 252,
        "item_energy_booster": 59,
        "item_essence_distiller": 1852,
        "item_ethereal_blade": 176,
        "item_faerie_fire": 237,
        "item_falcon_blade": 596,
        "item_fluffy_hat": 593,
        "item_force_staff": 102,
        "item_gauntlets": 13,
        "item_ghost": 37,
        "item_glimmer_cape": 254,
        "item_gloves": 25,
        "item_greater_crit": 141,
        "item_guardian_greaves": 231,
        "item_gungir": 1466,
        "item_hand_of_midas": 65,
        "item_harpoon": 939,
        "item_headdress": 94,
        "item_heart": 114,
        "item_heavens_halberd": 210,
        "item_helm_of_iron_will": 6,
        "item_helm_of_the_dominator": 164,
        "item_helm_of_the_overlord": 635,
        "item_holy_locket": 269,
        "item_hurricane_pike": 263,
        "item_hydras_breath": 1858,
        "item_hyperstone": 55,
        "item_invis_sword": 152,
        "item_javelin": 7,
        "item_kaya": 259,
        "item_kaya_and_sange": 273,
        "item_lesser_crit": 149,
        "item_lifesteal": 26,
        "item_lotus_orb": 226,
        "item_maelstrom": 166,
        "item_mage_slayer": 598,
        "item_magic_stick": 34,
        "item_magic_wand": 36,
        "item_manta": 147,
        "item_mantle": 15,
        "item_mask_of_madness": 172,
        "item_mekansm": 79,
        "item_meteor_hammer": 223,
        "item_mithril_hammer": 8,
        "item_mjollnir": 158,
        "item_monkey_king_bar": 135,
        "item_mystic_staff": 58,
        "item_null_talisman": 77,
        "item_nullifier": 225,
        "item_oblivion_staff": 67,
        "item_octarine_core": 235,
        "item_ogre_axe": 21,
        "item_orb_of_corrosion": 569,
        "item_orb_of_frost": 1575,
        "item_orb_of_venom": 181,
        "item_orchid": 98,
        "item_overwhelming_blink": 600,
        "item_pavise": 1128,
        "item_pers": 69,
        "item_phase_boots": 50,
        "item_phylactery": 1107,
        "item_pipe": 90,
        "item_platemail": 9,
        "item_point_booster": 60,
        "item_power_treads": 63,
        "item_quelling_blade": 11,
        "item_radiance": 137,
        "item_rapier": 133,
        "item_reaver": 53,
        "item_recipe_travel_boots": 47,
        "item_refresher": 110,
        "item_relic": 54,
        "item_revenants_brooch": 911,
        "item_ring_of_basilius": 88,
        "item_ring_of_health": 56,
        "item_ring_of_protection": 12,
        "item_ring_of_regen": 27,
        "item_ring_of_tarrasque": 279,
        "item_robe": 19,
        "item_rod_of_atos": 206,
        "item_sange": 162,
        "item_sange_and_yasha": 154,
        "item_satanic": 156,
        "item_shadow_amulet": 215,
        "item_shawl": 1848,
        "item_sheepstick": 96,
        "item_shivas_guard": 119,
        "item_silver_edge": 249,
        "item_skadi": 160,
        "item_sobi_mask": 28,
        "item_solar_crest": 229,
        "item_soul_booster": 129,
        "item_soul_ring": 178,
        "item_specialists_array": 1076,
        "item_sphere": 123,
        "item_spirit_vessel": 267,
        "item_splintmail": 1847,
        "item_staff_of_wizardry": 23,
        "item_swift_blink": 603,
        "item_talisman_of_evasion": 32,
        "item_tango": 44,
        "item_tiara_of_selemene": 1802,
        "item_tranquil_boots": 214,
        "item_travel_boots": 48,
        "item_travel_boots_2": 220,
        "item_ultimate_orb": 24,
        "item_ultimate_scepter": 108,
        "item_ultimate_scepter_2": 271,
        "item_urn_of_shadows": 92,
        "item_vanguard": 125,
        "item_veil_of_discord": 190,
        "item_vitality_booster": 61,
        "item_vladmir": 81,
        "item_void_stone": 57,
        "item_voodoo_mask": 473,
        "item_wind_lace": 244,
        "item_wind_waker": 610,
        "item_witch_blade": 534,
        "item_wizard_hat": 1849,
        "item_yasha": 170,
        "item_yasha_and_kaya": 277,
        "item_slippers": 14,
        "item_bracer": 73,
        "item_wraith_band": 75,
        "item_infused_raindrop": 265,
        "item_bottle": 41,
        "item_moon_shard": 247,
        "item_gem": 30
    }
};
