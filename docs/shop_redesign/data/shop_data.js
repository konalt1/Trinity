// Trinity: данные нового магазина по категориям.
// Сгенерировано из макета (Claude Design, «Магазин предметов Trinity»).
// Подключается в trinity_shop.xml ПЕРЕД trinity_shop.js: переменная общая для скриптов одного layout.
// price должен совпадать с ItemCost из KV (см. data/npc_items_price_overrides.txt).
// attributes: какие статы даёт предмет (по данным OpenDota); multi = 2+ стата. Сверить с KV игры.
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
          "id": "melee",
          "token": "#trinity_shop_sub_damage_melee",
          "icon": "item_bfury",
          "color": "#e8634f",
          "items": [
            "item_bfury",
            "item_basher",
            "item_abyssal_blade",
            "item_satanic",
            "item_desolator",
            "item_radiance",
            "item_manta"
          ]
        },
        {
          "id": "ranged",
          "token": "#trinity_shop_sub_damage_ranged",
          "icon": "item_greater_crit",
          "color": "#5b9bff",
          "items": [
            "item_greater_crit",
            "item_monkey_king_bar",
            "item_butterfly",
            "item_maelstrom",
            "item_mjollnir",
            "item_invis_sword",
            "item_desolator"
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
          "id": "magic",
          "token": "#trinity_shop_sub_survival_magic",
          "icon": "item_black_king_bar",
          "color": "#a77cf5",
          "items": [
            "item_black_king_bar",
            "item_sphere",
            "item_pipe",
            "item_glimmer_cape",
            "item_manta",
            "item_guardian_greaves"
          ]
        },
        {
          "id": "physical",
          "token": "#trinity_shop_sub_survival_physical",
          "icon": "item_blade_mail",
          "color": "#e8963f",
          "items": [
            "item_butterfly",
            "item_satanic",
            "item_heart",
            "item_blade_mail",
            "item_aeon_disk"
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
          "id": "attack",
          "token": "#trinity_shop_sub_control_attack",
          "icon": "item_basher",
          "color": "#f2c94c",
          "items": [
            "item_basher",
            "item_abyssal_blade",
            "item_monkey_king_bar"
          ]
        },
        {
          "id": "magic",
          "token": "#trinity_shop_sub_control_magic",
          "icon": "item_sheepstick",
          "color": "#3fc9d9",
          "items": [
            "item_sheepstick",
            "item_cyclone",
            "item_rod_of_atos",
            "item_hurricane_pike"
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
          "icon": "item_guardian_greaves",
          "color": "#76d13c",
          "items": [
            "item_guardian_greaves",
            "item_invis_sword",
            "item_cyclone"
          ]
        },
        {
          "id": "dash",
          "token": "#trinity_shop_sub_mobility_dash",
          "icon": "item_blink",
          "color": "#5b9bff",
          "items": [
            "item_blink",
            "item_force_staff",
            "item_hurricane_pike"
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
          "id": "heal",
          "token": "#trinity_shop_sub_support_heal",
          "icon": "item_mekansm",
          "color": "#3fbf8a",
          "items": [
            "item_mekansm",
            "item_guardian_greaves"
          ]
        },
        {
          "id": "help",
          "token": "#trinity_shop_sub_support_help",
          "icon": "item_glimmer_cape",
          "color": "#c08af8",
          "items": [
            "item_pipe",
            "item_glimmer_cape",
            "item_force_staff",
            "item_sphere"
          ]
        }
      ]
    },
    {
      "id": "farm",
      "token": "#trinity_shop_cat_farm",
      "accent": "#e0b040",
      "art": "file://{images}/custom_game/trinity_shop/cat_farm.png",
      "subcategories": [
        {
          "id": "gpm",
          "token": "#trinity_shop_sub_farm_gpm",
          "icon": "item_hand_of_midas",
          "color": "#ffcc33",
          "items": [
            "item_hand_of_midas"
          ]
        },
        {
          "id": "farm",
          "token": "#trinity_shop_sub_farm_farm",
          "icon": "item_bfury",
          "color": "#e8634f",
          "items": [
            "item_bfury",
            "item_maelstrom",
            "item_mjollnir",
            "item_radiance"
          ]
        }
      ]
    }
  ],
  "items": {
    "item_greater_crit": {
      "tier": 3,
      "price": 5500,
      "categories": [
        "damage"
      ],
      "attributes": [],
      "descToken": "#trinity_shop_desc_item_greater_crit"
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
    "item_monkey_king_bar": {
      "tier": 3,
      "price": 5500,
      "categories": [
        "damage",
        "control"
      ],
      "attributes": [],
      "descToken": "#trinity_shop_desc_item_monkey_king_bar"
    },
    "item_bfury": {
      "tier": 2,
      "price": 4700,
      "categories": [
        "damage",
        "farm"
      ],
      "attributes": [],
      "descToken": "#trinity_shop_desc_item_bfury"
    },
    "item_butterfly": {
      "tier": 3,
      "price": 5500,
      "categories": [
        "damage",
        "survival"
      ],
      "attributes": [
        "agi"
      ],
      "descToken": "#trinity_shop_desc_item_butterfly"
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
    "item_maelstrom": {
      "tier": 1,
      "price": 3500,
      "categories": [
        "damage",
        "farm"
      ],
      "attributes": [],
      "descToken": "#trinity_shop_desc_item_maelstrom"
    },
    "item_mjollnir": {
      "tier": 3,
      "price": 5500,
      "categories": [
        "farm",
        "damage"
      ],
      "attributes": [],
      "descToken": "#trinity_shop_desc_item_mjollnir"
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
        "control",
        "damage"
      ],
      "attributes": [
        "str"
      ],
      "descToken": "#trinity_shop_desc_item_abyssal_blade"
    },
    "item_invis_sword": {
      "tier": 1,
      "price": 3500,
      "categories": [
        "mobility",
        "damage"
      ],
      "attributes": [],
      "descToken": "#trinity_shop_desc_item_invis_sword"
    },
    "item_radiance": {
      "tier": 2,
      "price": 4700,
      "categories": [
        "farm",
        "damage"
      ],
      "attributes": [],
      "descToken": "#trinity_shop_desc_item_radiance"
    },
    "item_manta": {
      "tier": 2,
      "price": 4700,
      "categories": [
        "survival",
        "damage"
      ],
      "attributes": [
        "agi",
        "int",
        "str"
      ],
      "descToken": "#trinity_shop_desc_item_manta"
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
    "item_blade_mail": {
      "tier": 0,
      "price": 2400,
      "categories": [
        "survival"
      ],
      "attributes": [
        "int"
      ],
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
    "item_sheepstick": {
      "tier": 3,
      "price": 5500,
      "categories": [
        "control"
      ],
      "attributes": [
        "int"
      ],
      "descToken": "#trinity_shop_desc_item_sheepstick"
    },
    "item_rod_of_atos": {
      "tier": 0,
      "price": 2400,
      "categories": [
        "control"
      ],
      "attributes": [
        "int"
      ],
      "descToken": "#trinity_shop_desc_item_rod_of_atos"
    },
    "item_cyclone": {
      "tier": 0,
      "price": 2400,
      "categories": [
        "control",
        "mobility"
      ],
      "attributes": [
        "int"
      ],
      "descToken": "#trinity_shop_desc_item_cyclone"
    },
    "item_hurricane_pike": {
      "tier": 2,
      "price": 4700,
      "categories": [
        "mobility",
        "control"
      ],
      "attributes": [
        "agi",
        "int",
        "str"
      ],
      "descToken": "#trinity_shop_desc_item_hurricane_pike"
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
    "item_glimmer_cape": {
      "tier": 0,
      "price": 2400,
      "categories": [
        "support",
        "survival"
      ],
      "attributes": [],
      "descToken": "#trinity_shop_desc_item_glimmer_cape"
    },
    "item_mekansm": {
      "tier": 0,
      "price": 2400,
      "categories": [
        "support"
      ],
      "attributes": [],
      "descToken": "#trinity_shop_desc_item_mekansm"
    },
    "item_guardian_greaves": {
      "tier": 2,
      "price": 4700,
      "categories": [
        "support",
        "survival",
        "mobility"
      ],
      "attributes": [],
      "descToken": "#trinity_shop_desc_item_guardian_greaves"
    },
    "item_pipe": {
      "tier": 1,
      "price": 3500,
      "categories": [
        "support",
        "survival"
      ],
      "attributes": [
        "agi",
        "int",
        "str"
      ],
      "descToken": "#trinity_shop_desc_item_pipe"
    },
    "item_hand_of_midas": {
      "tier": 0,
      "price": 2400,
      "categories": [
        "farm"
      ],
      "attributes": [],
      "descToken": "#trinity_shop_desc_item_hand_of_midas"
    }
  }
};
