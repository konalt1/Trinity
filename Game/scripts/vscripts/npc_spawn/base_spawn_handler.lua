BaseSpawnHandler = BaseSpawnHandler or class({})

function BaseSpawnHandler:constructor()
end

function BaseSpawnHandler:GetNPCName()
    error("Unimplemented abstract method")
end

function BaseSpawnHandler:OnFirstTimeSpawned(npc)
    error("Unimplemented abstract method")
end