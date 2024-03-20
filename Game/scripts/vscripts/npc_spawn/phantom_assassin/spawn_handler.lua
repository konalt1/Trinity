require ("npc_spawn/base_spawn_handler")

PASpawnHandler = PASpawnHandler or class({}, {}, BaseSpawnHandler)

function PASpawnHandler:constructor()
    BaseSpawnHandler.constructor(self)
end

function PASpawnHandler:GetNPCName()
    return "npc_dota_hero_phantom_assassin"
end

function PASpawnHandler:OnFirstTimeSpawned(hero)
    local ability = hero:AddAbility("ability_coup_de_foudre")
    if ability ~= nil then
        ability:SetLevel(ability:GetMaxLevel())
    end
end