CaravanLoot = CaravanLoot or {}

CaravanLoot.GOLD_PER_BAG = 50
CaravanLoot.PICK_COUNT = 10
CaravanLoot.GOLD_CHANCE = 67
CaravanLoot.AEGIS_DURATION = 120
CaravanLoot.AEGIS_MIN_STAGE = 2
CaravanLoot.MAX_STAGE = 5
CaravanLoot.HITS = { 1, 1, 2, 2, 3 }

CaravanLoot.COURIERS = {
    str = {
        unit_name = "npc_caravan_redhorn",
        model = "models/courier/ram/ram.vmdl",
        items = {
            "item_gauntlets",
            "item_belt_of_strength",
            "item_ogre_axe",
            "item_sange",
            "item_reaver",
        },
    },
    agi = {
        unit_name = "npc_caravan_taffied",
        model = "models/courier/winter2022/taffy_donkey_courier.vmdl",
        items = {
            "item_slippers",
            "item_boots_of_elves",
            "item_blade_of_alacrity",
            "item_yasha",
            "item_eagle",
        },
    },
    int = {
        unit_name = "npc_caravan_mango",
        model = "models/items/courier/mango_the_courier/mango_the_courier.vmdl",
        items = {
            "item_mantle",
            "item_robe",
            "item_staff_of_wizardry",
            "item_kaya",
            "item_mystic_staff",
        },
    },
    all = {
        unit_name = "npc_caravan_hatchling",
        model = "models/items/courier/blazing_hatchling_the_fortune_bringer_courier/blazing_hatchling_the_fortune_bringer_courier.vmdl",
        items = {
            "item_circlet",
            "item_crown",
            "item_diadem",
            "item_ghost",
            "item_ultimate_orb",
        },
    },
    gold = {
        unit_name = "npc_caravan_flopjaw",
        model = "models/courier/flopjaw/flopjaw.vmdl",
        skin = 1,
        material_group = "1",
        particle = "particles/econ/courier/courier_flopjaw_gold/courier_flopjaw_ambient_gold.vpcf",
        gold_bags = { 4, 7, 10, 13, 16 },
        items = {},
    },
    aegis = {
        unit_name = "npc_caravan_baby_roshan",
        model = "models/courier/baby_rosh/babyroshan.vmdl",
        material_group = "desert_sands",
        particle = "particles/econ/courier/courier_roshan_desert_sands/baby_roshan_desert_sands_ambient.vpcf",
        items = {
            {},
            "item_caravan_aegis",
            "item_caravan_aegis",
            "item_caravan_aegis",
            "item_caravan_aegis",
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

function CaravanLoot:HitsForStage(stage)
    stage = self:ClampStage(stage)
    return self.HITS[stage] or self.HITS[#self.HITS] or stage
end

function CaravanLoot:ClampStage(stage)
    local maxStage = self.MAX_STAGE or 5
    return math.min(maxStage, math.max(1, math.floor(tonumber(stage) or 1)))
end

function CaravanLoot:GetStageData(id, stage)
    local def = self.COURIERS[id]
    if not def then
        return nil
    end

    stage = self:ClampStage(stage)
    local items = {}
    local entry = def.items and def.items[stage]
    local function addItem(name)
        if type(name) == "string" and name ~= "" then
            table.insert(items, { name = name, count = 1 })
        end
    end
    if type(entry) == "string" then
        addItem(entry)
    elseif type(entry) == "table" then
        for _, name in ipairs(entry) do
            addItem(name)
        end
    end

    local bags = 0
    if def.gold_bags then
        bags = def.gold_bags[stage] or def.gold_bags[#def.gold_bags] or 0
    end

    return {
        hits = self:HitsForStage(stage),
        items = items,
        gold_bags = bags,
    }
end

function CaravanLoot:PickRandomIds(count, stage)
    count = count or self.PICK_COUNT
    stage = self:ClampStage(stage)
    local aegisMinStage = self.AEGIS_MIN_STAGE or 2
    local allowAegis = stage >= aegisMinStage

    local others = {}
    for _, id in ipairs(self:GetAllIds()) do
        if id ~= "gold" and (id ~= "aegis" or allowAegis) then
            table.insert(others, id)
        end
    end

    local picked = {}
    local goldChance = math.max(0, math.min(100, tonumber(self.GOLD_CHANCE) or 0))
    for i = 1, count do
        if self.COURIERS.gold and RandomInt(1, 100) <= goldChance then
            picked[i] = "gold"
        elseif #others > 0 then
            local index = RandomInt(1, #others)
            local id = others[index]
            picked[i] = id
            if id == "aegis" then
                table.remove(others, index)
            end
        elseif self.COURIERS.gold then
            picked[i] = "gold"
        end
    end
    return picked
end

function CaravanLoot:ApplyLook(courier, def)
    if not courier or courier:IsNull() or not def then
        return
    end

    if def.skin ~= nil and courier.SetSkin then
        courier:SetSkin(def.skin)
    end
    if def.material_group and courier.SetMaterialGroup then
        courier:SetMaterialGroup(tostring(def.material_group))
    end
    if def.particle then
        local fx = ParticleManager:CreateParticle(def.particle, PATTACH_ABSORIGIN_FOLLOW, courier)
        courier.caravanAmbientFx = fx
    end
end

return CaravanLoot
