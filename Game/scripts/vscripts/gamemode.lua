if GameMode == nil then
	_G.GameMode = class({})
end

GameMode.current_units = {}
GameMode.line_interval = {}
GameMode.wave_number = 0

GameMode.wave_list = {
	[1]={reward_gold=250,reward_exp=500,
			units={["npc_line_creep_1"]=6,["npc_line_creep_2"]=2}},
	[2]={reward_gold=500,reward_exp=1000,
			units={["npc_line_creep_3"]=6,["npc_line_creep_4"]=2}},
	[3]={reward_gold=1000,reward_exp=2000,
			units={"npc_line_boss_1",["npc_line_creep_4"]=2}},
}

function GameMode:InitGameMode()
	ListenToGameEvent('game_rules_state_change', Dynamic_Wrap(self, 'OnGameRulesStateChange'), self)
--	ListenToGameEvent("npc_spawned",Dynamic_Wrap( self, 'OnNPCSpawned' ), self )
	ListenToGameEvent('entity_killed', Dynamic_Wrap(self, 'OnEntityKilled'), self)
 
    GameRules:SetCustomGameTeamMaxPlayers(1, 2)
end

function GameMode:OnGameRulesStateChange()
	local newState = GameRules:State_Get()

	if newState == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		GameMode:LineBossSpawner()
	end
end


function GameMode:LineBossSpawner()
	 self.wave_number = self.wave_number + 1	
	local current_boss = self.wave_list[self.wave_number]

	if current_boss == nil then
		GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS)
		return
	end

	GameMode:SpawnLineUnits(self.wave_number) 
end

function GameMode:SpawnLineUnits(index)
	-- TODO: Fix
end

function GameMode:OnEntityKilled(keys)

	local unit = EntIndexToHScript(keys.entindex_killed)
	local unit_name = unit:GetUnitName()

	if unit_name == "npc_dota_badguys_tower4" or unit_name == "npc_dota_goodguys_tower3_top" or unit_name == "npc_dota_goodguys_tower3_bot" then 
		self:OnTowerKill(unit:GetName(), unit:GetTeamNumber())
	end

	if unit_name == "npc_goodguys_fort" then
		GameRules:SetGameWinner(DOTA_TEAM_BADGUYS)		
	end

	if unit.reward then
		local ent_index = unit:entindex()
		
		self.current_units[ent_index] = nil
		local units = 0
		for key,value in pairs(self.current_units) do
			units = units + 1
		end

		if units == 0 then
			local current_wave = self.wave_list[self.wave_number]
			local reward_gold = current_wave.reward_gold
			local reward_exp = current_wave.reward_exp

			GiveGoldPlayers( reward_gold )
			GiveExperiencePlayers( reward_exp )
			GameMode:LineBossSpawner()
		end
	end
end

function GameMode:OnTowerKill(name, teamnumber)
	local towers = {}

	if teamnumber == DOTA_TEAM_BADGUYS then 
		towers = Entities:FindAllByName("dota_badguys_tower4_bot") 
		table.insert(towers, Entities:FindByName(nil, "dota_badguys_tower4_top"))
	else 
		towers = Entities:FindAllByName("dota_goodguys_tower3_top")  
		table.insert(towers, Entities:FindByName(nil, "dota_goodguys_tower3_bot"))
	end
 
	local isAllDead = true
	for _,tower in ipairs(towers) do
		if tower:IsAlive() then isAllDead = false end
	end

	if isAllDead then 
		for i=1,2 do
			local spawner = Vector(0,0,0)
			local way = nil
			if teamnumber == DOTA_TEAM_BADGUYS then 
				spawner = Entities:FindByName(nil, i == 1 and "bottom_spawner" or "top_spawner"):GetAbsOrigin()
				way = Entities:FindByName(nil, i == 1 and "lane_bot_pathcorner_goodguys_1" or "lane_bot_pathcorner_goodguys_1_top")
			else 
				spawner = Entities:FindAllByName("Spawner_good_bot")[i]:GetAbsOrigin()
				way = Entities:FindByName(nil, i == 1 and "lane_top_pathcorner_badguys_3_top" or "lane_bot_pathcorner_badguys_3a")
			end
			local unit = CreateUnitByName("npc_gold_lama",  spawner, true, nil, nil, teamnumber)
			unit:SetInitialGoalEntity(way)
		end
 	end
end

 
GameMode:InitGameMode()