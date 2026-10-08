CaravanLoot = CaravanLoot or {}

CaravanLoot.GOLD_PER_BAG = 50
CaravanLoot.PICK_COUNT = 10
CaravanLoot.GOLD_CHANCE = 67
CaravanLoot.AEGIS_DURATION = 120
CaravanLoot.AEGIS_MIN_STAGE = 2
CaravanLoot.MAX_STAGE = 5
CaravanLoot.HITS = { 1, 1, 2, 2, 3 }

-- Буны по стадиям: стат-курьер (boons = true) несёт один случайный бун из четырёх бунов своей стадии.
-- Выбор делается при спавне и хранится на курьере (courier.caravanLootData), дроп берёт его оттуда.
-- Караван берёт пул на CARAVAN_TIER_OFFSET выше своей стадии: буны 1-го уровня в караване не выпадают
-- (стадия 1 → пул 2, стадия 2 → пул 3, дальше пул 4). Лесные крипы (game_managers/neutral_boons.lua)
-- берут пулы без сдвига.
CaravanLoot.CARAVAN_TIER_OFFSET = 1

CaravanLoot.BOONS = {
    { "item_boon_belt_of_strength", "item_boon_boots_of_elves", "item_boon_robe", "item_boon_crown" },
    { "item_boon_might", "item_boon_bulwark", "item_boon_holy_locket", "item_boon_octarine" },
    { "item_boon_greaves", "item_boon_lens", "item_boon_vampirism", "item_boon_venomancer" },
    { "item_boon_twin_charges", "item_boon_kaya", "item_boon_daedalus", "item_boon_aegis" },
    -- Стадия 5 пока убрана: караван 5-й стадии берёт пул 4-й (GetStageData → последний ряд).
    -- Прежний пул: { "item_boon_aghanim", "item_boon_titan", "item_boon_resilience", "item_boon_colossus" }
}

CaravanLoot.COURIERS = {
    str = {
        unit_name = "npc_caravan_redhorn",
        model = "models/courier/ram/ram.vmdl",
        boons = true,
    },
    agi = {
        unit_name = "npc_caravan_taffied",
        model = "models/courier/winter2022/taffy_donkey_courier.vmdl",
        boons = true,
    },
    int = {
        unit_name = "npc_caravan_mango",
        model = "models/items/courier/mango_the_courier/mango_the_courier.vmdl",
        boons = true,
    },
    all = {
        unit_name = "npc_caravan_hatchling",
        model = "models/items/courier/blazing_hatchling_the_fortune_bringer_courier/blazing_hatchling_the_fortune_bringer_courier.vmdl",
        boons = true,
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
    if def.boons then
        local tier = math.min(stage + (self.CARAVAN_TIER_OFFSET or 0), #self.BOONS)
        local pool = self.BOONS[tier] or self.BOONS[#self.BOONS] or {}
        entry = #pool > 0 and pool[RandomInt(1, #pool)] or nil
    end
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
