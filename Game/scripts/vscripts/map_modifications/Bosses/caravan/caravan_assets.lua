CaravanAssets = CaravanAssets or {}

CaravanAssets.AGHANIM_MODEL = "models/heroes/aghanim/aghanim_model.vmdl"

CaravanAssets.PARTICLE = {
    beam_channel = "particles/creatures/aghanim/aghanim_beam_channel.vpcf",
    staff_beam = "particles/creatures/aghanim/staff_beam.vpcf",
    staff_beam_tgt = "particles/creatures/aghanim/staff_beam_tgt.vpcf",
    staff_beam_linger = "particles/creatures/aghanim/staff_beam_linger.vpcf",
    laser_status = "particles/status_fx/status_effect_electrical.vpcf",
    crystal_trail = "particles/units/heroes/hero_ancient_apparition/ancient_apparition_chilling_touch_projectile.vpcf",
    crystal_impact = "particles/creatures/aghanim/aghanim_crystal_attack_impact.vpcf",
    crystal_telegraph = "particles/creatures/aghanim/aghanim_crystal_attack_telegraph_aoe.vpcf",
    shard_proj = "particles/units/heroes/hero_tusk/tusk_ice_shards_projectile.vpcf",
    spear = "particles/units/heroes/hero_mars/mars_spear.vpcf",
    spear_burst = "particles/units/heroes/hero_mars/mars_spear_impact.vpcf",
    spear_spawn = "particles/units/heroes/hero_mars/mars_shield_bash.vpcf",
}

CaravanAssets.SOUNDFILE = {
    "soundevents/soundevents_aghanim.vsndevts",
    "soundevents/game_sounds_heroes/game_sounds_crystalmaiden.vsndevts",
    "soundevents/game_sounds_heroes/game_sounds_leshrac.vsndevts",
    "soundevents/game_sounds_heroes/game_sounds_mars.vsndevts",
    "soundevents/game_sounds_heroes/game_sounds_ancient_apparition.vsndevts",
    "soundevents/game_sounds_heroes/game_sounds_tusk.vsndevts",
}

local ATTACH_CANDIDATES = {
    "attach_staff_fx",
    "attach_attack1",
    "attach_hitloc",
}

function CaravanAssets:GetAttachOrigin(unit, extraHeight)
    extraHeight = extraHeight or 0
    if not unit or unit:IsNull() then
        return Vector(0, 0, extraHeight)
    end

    if unit.ScriptLookupAttachment and unit.GetAttachmentOrigin then
        for _, name in ipairs(ATTACH_CANDIDATES) do
            local id = unit:ScriptLookupAttachment(name)
            if id and id > 0 then
                return unit:GetAttachmentOrigin(id)
            end
        end
    end

    return unit:GetAbsOrigin() + Vector(0, 0, 180 + extraHeight)
end

function CaravanAssets:GetAttachName(unit)
    if not unit or unit:IsNull() or not unit.ScriptLookupAttachment then
        return nil
    end

    for _, name in ipairs(ATTACH_CANDIDATES) do
        local id = unit:ScriptLookupAttachment(name)
        if id and id > 0 then
            return name
        end
    end

    return nil
end

local function PrecacheModelFile(path, context)
    if not path then
        return
    end

    PrecacheResource("model", path, context)
    if PrecacheModel then
        pcall(PrecacheModel, path, context)
    end
end

function CaravanAssets:Precache(context)
    PrecacheModelFile(self.AGHANIM_MODEL, context)
    PrecacheModelFile("models/props_gameplay/gold_bag.vmdl", context)
    PrecacheResource("particle", "particles/generic_gameplay/dropped_item.vpcf", context)

    for _, path in pairs(self.PARTICLE) do
        PrecacheResource("particle", path, context)
    end

    for _, path in ipairs(self.SOUNDFILE) do
        PrecacheResource("soundfile", path, context)
    end

    if CaravanLoot and CaravanLoot.COURIERS then
        for _, def in pairs(CaravanLoot.COURIERS) do
            PrecacheModelFile(def.model, context)
        end
    end

    PrecacheItemByNameSync("item_caravan_gold_bag", context)
    PrecacheUnitByNameSync("npc_caravan_aghanim", context)
    if CaravanLoot and CaravanLoot.COURIERS then
        for _, def in pairs(CaravanLoot.COURIERS) do
            if def.unit_name then
                PrecacheUnitByNameSync(def.unit_name, context)
            end
        end
    end
end

return CaravanAssets
