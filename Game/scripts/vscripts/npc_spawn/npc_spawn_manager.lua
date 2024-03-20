require ("npc_spawn/phantom_assassin/spawn_handler")

NPCSpawnManager = NPCSpawnManager or class({})

function NPCSpawnManager:constructor()
    self.handlers_by_name = {}
    self:AddHandler(PASpawnHandler())
    -- self:AddHandler(...)

    ListenToGameEvent("npc_spawned", Dynamic_Wrap(NPCSpawnManager, "OnNPCSpawned"), self)
end

function NPCSpawnManager:OnNPCSpawned(event)
    local unit = EntIndexToHScript(event.entindex)
    local handler = self.handlers_by_name[unit:GetUnitName()]
    if handler ~= nil then
        handler:OnFirstTimeSpawned(unit)
        self.handlers_by_name[unit:GetUnitName()] = nil
    end
end

function NPCSpawnManager:AddHandler(handler)
    self.handlers_by_name[handler:GetNPCName()] = handler
end