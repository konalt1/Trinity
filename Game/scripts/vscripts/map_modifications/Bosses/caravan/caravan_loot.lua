CaravanLoot = CaravanLoot or {}

CaravanLoot.DEFAULT_GOLD_BAGS = { 1, 2, 4 }
CaravanLoot.GOLD_PER_BAG = 50
CaravanLoot.PICK_COUNT = 10

CaravanLoot.COURIERS = {
    bearzky = {
        unit_name = "npc_caravan_bearzky",
        model = "models/items/courier/bearzky/bearzky.vmdl",
        stages = {
            { hp = 300, items = { { name = "item_blades_of_attack", count = 1 } } },
            { hp = 500, items = { { name = "item_broadsword", count = 1 } } },
            { hp = 700, items = { { name = "item_claymore", count = 1 } } },
        },
    },
    shagbark = {
        unit_name = "npc_caravan_shagbark",
        model = "models/items/courier/shagbark/shagbark.vmdl",
        stages = {
            { hp = 100, items = { { name = "item_circlet", count = 1 } } },
            { hp = 300, items = { { name = "item_crown", count = 1 } } },
            { hp = 500, items = { { name = "item_diadem", count = 1 } } },
        },
    },
    huntling = {
        unit_name = "npc_caravan_huntling",
        model = "models/courier/huntling/huntling.vmdl",
        stages = {
            { hp = 200, items = { { name = "item_wind_lace", count = 1 } } },
            { hp = 400, items = { { name = "item_boots", count = 1 } } },
            { hp = 600, items = {} },
        },
    },
    seekling = {
        unit_name = "npc_caravan_seekling",
        model = "models/courier/seekling/seekling.vmdl",
        stages = {
            { hp = 300, items = { { name = "item_ring_of_regen", count = 1 } } },
            { hp = 500, items = { { name = "item_ring_of_health", count = 1 } } },
            { hp = 700, items = { { name = "item_ring_of_tarrasque", count = 1 } } },
        },
    },
    venling = {
        unit_name = "npc_caravan_venling",
        model = "models/courier/venoling/venoling.vmdl",
        stages = {
            { hp = 300, items = { { name = "item_orb_of_venom", count = 1 } } },
            { hp = 500, items = { { name = "item_orb_of_corrosion", count = 1 } } },
            { hp = 700, items = { { name = "item_oblivion_staff", count = 1 } } },
        },
    },
    faceless_rex = {
        unit_name = "npc_caravan_faceless_rex",
        model = "models/items/courier/faceless_rex/faceless_rex.vmdl",
        stages = {
            { hp = 300, items = { { name = "item_gloves", count = 1 } } },
            { hp = 500, items = { { name = "item_blitz_knuckles", count = 1 } } },
            { hp = 900, items = { { name = "item_hyperstone", count = 1 } } },
        },
    },
    pudgling = {
        unit_name = "npc_caravan_pudgling",
        model = "models/items/courier/butch_pudge_dog/butch_pudge_dog.vmdl",
        stages = {
            { hp = 300, items = { { name = "item_belt_of_strength", count = 1 } } },
            { hp = 500, items = { { name = "item_ogre_axe", count = 1 } } },
            { hp = 1000, items = { { name = "item_reaver", count = 1 } } },
        },
    },
    devourling = {
        unit_name = "npc_caravan_devourling",
        model = "models/items/courier/devourling/devourling.vmdl",
        stages = {
            { hp = 300, items = { { name = "item_robe", count = 1 } } },
            { hp = 500, items = { { name = "item_staff_of_wizardry", count = 1 } } },
            { hp = 1000, items = { { name = "item_mystic_staff", count = 1 } } },
        },
    },
    doomling = {
        unit_name = "npc_caravan_doomling",
        model = "models/courier/imp/imp.vmdl",
        stages = {
            { hp = 100, items = { { name = "item_blood_grenade", count = 3 } } },
            { hp = 300, items = { { name = "item_fluffy_hat", count = 2 } } },
            { hp = 500, items = { { name = "item_vitality_booster", count = 1 } } },
        },
    },
    krobeling = {
        unit_name = "npc_caravan_krobeling",
        model = "models/items/courier/krobeling/krobeling.vmdl",
        stages = {
            { hp = 300, items = { { name = "item_boots_of_elves", count = 1 } } },
            { hp = 500, items = { { name = "item_blade_of_alacrity", count = 1 } } },
            { hp = 1000, items = { { name = "item_eagle", count = 1 } } },
        },
    },
    skip = {
        unit_name = "npc_caravan_skip",
        model = "models/courier/frog/frog.vmdl",
        stages = {
            { hp = 300, items = { { name = "item_shawl", count = 1 } } },
            { hp = 500, items = { { name = "item_cloak", count = 1 } } },
            { hp = 700, items = { { name = "item_talisman_of_evasion", count = 1 } } },
        },
    },
    axolotl = {
        unit_name = "npc_caravan_axolotl",
        model = "models/items/courier/axolotl/axolotl.vmdl",
        stages = {
            { hp = 300, items = { { name = "item_sobi_mask", count = 2 } } },
            { hp = 400, items = { { name = "item_void_stone", count = 1 } } },
            { hp = 700, items = { { name = "item_tiara_of_selemene", count = 1 } } },
        },
    },
    flopjaw = {
        unit_name = "npc_caravan_flopjaw",
        model = "models/courier/flopjaw/flopjaw.vmdl",
        gold_bags = { 4, 8, 16 },
        stages = {
            { hp = 300, items = {} },
            { hp = 600, items = {} },
            { hp = 1200, items = {} },
        },
    },
}

function CaravanLoot:GetAllIds()
    local ids = {}
    for id in pairs(self.COURIERS) do
        table.insert(ids, id)
    end
    table.sort(ids)
    return ids
end

function CaravanLoot:GetCourier(id)
    return self.COURIERS[id]
end

function CaravanLoot:HitsFromHp(hp)
    return math.max(1, math.floor((tonumber(hp) or 100) / 100))
end

function CaravanLoot:ClampStage(stage)
    return math.min(3, math.max(1, math.floor(tonumber(stage) or 1)))
end

function CaravanLoot:GetStageData(id, stage)
    local def = self.COURIERS[id]
    if not def then
        return nil
    end

    stage = self:ClampStage(stage)
    local row = def.stages[stage]
    if not row then
        return nil
    end

    local bags = def.gold_bags or self.DEFAULT_GOLD_BAGS
    return {
        hp = row.hp,
        hits = self:HitsFromHp(row.hp),
        items = row.items or {},
        gold_bags = bags[stage] or bags[#bags] or 1,
    }
end

function CaravanLoot:PickRandomIds(count)
    count = count or self.PICK_COUNT
    local pool = self:GetAllIds()
    for i = #pool, 2, -1 do
        local j = RandomInt(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end

    local picked = {}
    for i = 1, math.min(count, #pool) do
        picked[i] = pool[i]
    end
    return picked
end

return CaravanLoot
