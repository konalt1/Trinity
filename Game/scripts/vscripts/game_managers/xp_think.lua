xp_think = xp_think or class({})

function xp_think:constructor()
    self.interval = 60.0    
    ListenToGameEvent(
        'game_rules_state_change', 
        Dynamic_Wrap(xp_think, 'OnGameStateChange'), 
        self
    )

    self.xp_table = {}
    self.xp_table[1] = 10
    local diff = 10
    for i = 2, 29 do
        self.xp_table[i] = self.xp_table[i - 1] + diff
        diff = diff + 3
    end

    self.times_called = 0
end

function xp_think:OnGameStateChange()
    if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
        GameRules:GetGameModeEntity():SetThink(
            "OnThink",
            self,
            "xp_think",
            self.interval
        )
    end
end

function xp_think:OnThink()
    self.times_called = self.times_called + 1

    for player_id = 0, (PlayerResource:GetPlayerCount() - 1) do
        local hero = PlayerResource:GetPlayer(player_id):GetAssignedHero()
        if hero ~= nil and hero:IsHero() then
            local xp = self.xp_table[self.times_called]
            hero:AddExperience(xp, DOTA_ModifyXP_Unspecified, false, false)
        end
    end

    return self.interval
end
