if GameMode == nil then
	_G.GameMode = class({})
end

GameMode.current_units = {}
GameMode.line_interval = {}
GameMode.wave_number = 0
GameMode.towers = {} -- Таблица всех башен с информацией о них
GameMode.ancients = {} -- Таблица тронов
GameMode.lane_creeps_spawned = false -- Флаг спавна лейн крипов
GameMode.CHAT_WHEEL_COOLDOWN = 10

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
	ListenToGameEvent("npc_spawned",Dynamic_Wrap( self, 'OnNPCSpawned' ), self )
	ListenToGameEvent('entity_killed', Dynamic_Wrap(self, 'OnEntityKilled'), self)
	ListenToGameEvent('dota_inventory_item_added', Dynamic_Wrap(self, 'OnInventoryUpdate'), self)
	ListenToGameEvent('dota_player_drop_item', Dynamic_Wrap(self, 'OnChenInventoryChanged'), self)
	ListenToGameEvent('dota_item_picked_up', Dynamic_Wrap(self, 'OnChenInventoryChanged'), self)

	CustomGameEventManager:RegisterListener('chat_wheel_select', Dynamic_Wrap(self, 'OnChatWheelSelect'))	

	if KillfeedSystem and KillfeedSystem.Init then
		KillfeedSystem:Init()
	end
 

    GameRules:SetCustomGameTeamMaxPlayers(1, 2)
end

function GameMode:OnGameRulesStateChange()
	local newState = GameRules:State_Get()

	if newState == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		GameRules:SetTimeOfDay(0.25)

		-- Множитель времени респауна (0.2 ≈ в 5 раз быстрее таймер смерти). Нужен GetGameModeEntity() и ':' для Lua.
		GameRules:GetGameModeEntity():SetRespawnTimeScale(0.7)

		-- Сбрасываем флаг спавна крипов
		GameMode.lane_creeps_spawned = false
		
		-- Spawn neutral creeps with retries to ensure all spawners are ready
		Timers:CreateTimer(1.0, function()
			GameRules:SpawnNeutralCreeps()
		end)
		Timers:CreateTimer(3.0, function()
			GameRules:SpawnNeutralCreeps()
		end)
		GameMode:LineBossSpawner()
		
		-- Делаем все башни и троны неуязвимыми
		GameMode:MakeTowersInvulnerable()
		GameMode:MakeAncientsInvulnerable()
		
		-- Запускаем проверку спавна лейн крипов через таймер
		-- На случай если крипы заспавнятся до того как сработает OnNPCSpawned
		Timers:CreateTimer(1.0, function()
			if not GameMode.lane_creeps_spawned then
				-- Пробуем найти крипов
				local creep = Entities:FindByClassname(nil, "npc_dota_creep")
				
				if creep ~= nil then
					GameMode.lane_creeps_spawned = true
					GameMode:UnlockTier1Towers()
				else
					return 1.0 -- Проверяем снова через 1 секунду
				end
			end
		end)
	end
end

-- Функция спавна Guardian с привязкой к точке спавна
function GameMode:SpawnGuardianWithLeash(unit_name, position, team, leash_radius, owner_hero)
	-- Спавним юнита
	local guardian = CreateUnitByName(
		unit_name,
		position,
		true,
		owner_hero,
		owner_hero,
		team
	)
	
	if guardian ~= nil and IsValidEntity(guardian) then
		-- Применяем модификатор привязки к точке спавна
		guardian:AddNewModifier(guardian, nil, "modifier_leash_to_spawn", {
			radius = leash_radius or 1000
		})
		
		-- Если есть владелец, делаем юнита контролируемым
		if owner_hero and owner_hero:IsRealHero() then
			local playerID = owner_hero:GetPlayerOwnerID()
			guardian:SetControllableByPlayer(playerID, true)
			guardian:SetOwner(owner_hero)
		end
		
		print("[GameMode] ✓ " .. unit_name .. " заспавнен с привязкой " .. (leash_radius or 1000) .. " радиус")
		return guardian
	else
		print("[GameMode] ✗ Ошибка спавна " .. unit_name)
		return nil
	end
end

-- Функция спавна тестового Guardian (для консольных команд)
function GameMode:SpawnTestGuardian()
	print("========================================")
	print("[GameMode] СПАВН npc_guardian_good")
	print("========================================")
	
	local spawn_pos = Vector(0, 0, 256)
	
	-- Находим первого игрока для привязки юнита
	local playerID = 0
	local hero = PlayerResource:GetSelectedHeroEntity(playerID)
	
	-- Спавним с привязкой к точке спавна
	local guardian = GameMode:SpawnGuardianWithLeash(
		"npc_guardian_good",
		spawn_pos,
		DOTA_TEAM_GOODGUYS,
		1000,  -- Радиус привязки 1000 юнитов
		hero
	)
	
	if guardian then
		print("[GameMode] Позиция: " .. tostring(guardian:GetAbsOrigin()))
		print("[GameMode] entindex: " .. tostring(guardian:entindex()))
		print("[GameMode] Здоровье: " .. tostring(guardian:GetHealth()))
		print("[GameMode] ✓ Юнит привязан к точке спавна (радиус 1000)")
	end
	
	print("========================================")
end

-- Регистрируем одну башню в таблице
function GameMode:RegisterTower(tower)
	if not tower or not IsValidEntity(tower) then
		return false
	end
	
	local tower_entindex = tower:entindex()
	
	-- ПРОВЕРКА НА ДУБЛИКАТЫ: Если башня уже в таблице - не добавляем
	for _, existing_tower in pairs(GameMode.towers) do
		if existing_tower.entindex == tower_entindex then
			return false -- Башня уже зарегистрирована
		end
	end
	
	local unit_name = tower:GetUnitName()
	local tier = self:GetTowerTier(unit_name)
	local lane = self:GetTowerLane(unit_name)
	local team = self:GetTowerTeam(unit_name)
	
	-- Сохраняем информацию о башне
	local tower_info = {
		entity = tower,
		name = unit_name,
		tier = tier,
		lane = lane,
		team = team,
		entindex = tower_entindex
	}
	
	-- Добавляем в таблицу башен
	table.insert(GameMode.towers, tower_info)
	
	-- Добавляем неуязвимость всем башням (T1 потеряют при спавне крипов)
	tower:AddNewModifier(tower, nil, "modifier_invulnerable", {})
	
	return true
end

function GameMode:GetTowerTier(tower_name)
	-- Определяем тир башни из её имени
	if string.find(tower_name, "tower1") then
		return 1
	elseif string.find(tower_name, "tower2") then
		return 2
	elseif string.find(tower_name, "tower3") then
		return 3
	elseif string.find(tower_name, "tower4") then
		return 4
	else
		return 0 -- Для watch towers и других
	end
end

function GameMode:GetTowerLane(tower_name)
	-- Определяем линию башни
	if string.find(tower_name, "top") then
		return "top"
	elseif string.find(tower_name, "mid") then
		return "mid"
	elseif string.find(tower_name, "bot") then
		return "bot"
	else
		return "unknown"
	end
end

function GameMode:GetTowerTeam(tower_name)
	-- Определяем команду башни
	if string.find(tower_name, "goodguys") then
		return "radiant"
	elseif string.find(tower_name, "badguys") then
		return "dire"
	else
		return "neutral"
	end
end

--[[
	СИСТЕМА ЗАЩИТЫ БАШЕН И ТРОНОВ:
	
	При старте игры:
	- Все башни получают неуязвимость
	- Все троны получают неуязвимость
	
	Логика разблокировки:
	1. T1 башни теряют неуязвимость при спавне лейн крипов
	2. T3 MID башни теряют неуязвимость при спавне лейн крипов
	   - T3 mid получает +5 брони за каждую живую союзную T2 башню
	   - При уничтожении T2 башни броня обновляется
	3. T2 башня теряет неуязвимость когда уничтожена T1 той же команды на той же линии
	4. T3 top/bot башня теряет неуязвимость когда уничтожена T2 той же команды на той же линии
	5. Трон теряет неуязвимость когда уничтожена любая T3 башня этой команды
	
	Вся информация о башнях хранится в GameMode.towers
	Вся информация о тронах хранится в GameMode.ancients
]]

function GameMode:MakeTowersInvulnerable()
	-- Находим все башни через класс npc_dota_tower
	local tower = Entities:FindByClassname(nil, "npc_dota_tower")
	while tower ~= nil do
		if tower and IsValidEntity(tower) then
			self:RegisterTower(tower)
		end
		tower = Entities:FindByClassname(tower, "npc_dota_tower")
	end
	
	-- Также проверяем watch towers если они есть
	local watch_tower = Entities:FindByClassname(nil, "npc_dota_watch_tower")
	while watch_tower ~= nil do
		if watch_tower and IsValidEntity(watch_tower) then
			-- Для watch towers создаем специальную запись
			local tower_info = {
				entity = watch_tower,
				name = watch_tower:GetUnitName(),
				tier = 0,
				lane = "watch",
				team = "neutral",
				entindex = watch_tower:entindex()
			}
			table.insert(GameMode.towers, tower_info)
			watch_tower:AddNewModifier(watch_tower, nil, "modifier_invulnerable", {})
		end
		watch_tower = Entities:FindByClassname(watch_tower, "npc_dota_watch_tower")
	end
end

--[[
	Структура tower_info:
	{
		entity = [handle башни],
		name = "npc_dota_goodguys_tower1_top",
		tier = 1,  -- 1, 2, 3, 4 (0 для watch towers)
		lane = "top", "mid", "bot", "watch", "unknown"
		team = "radiant", "dire", "neutral"
		entindex = [индекс энтити]
	}
]]

-- Делаем троны неуязвимыми
function GameMode:MakeAncientsInvulnerable()
	-- Находим древних (троны)
	local ancient = Entities:FindByClassname(nil, "npc_dota_fort")
	while ancient ~= nil do
		if ancient and IsValidEntity(ancient) then
			local unit_name = ancient:GetUnitName()
			local team = "neutral"
			
			if string.find(unit_name, "good") then
				team = "radiant"
			elseif string.find(unit_name, "bad") then
				team = "dire"
			end
			
			-- Сохраняем информацию о троне
			local ancient_info = {
				entity = ancient,
				name = unit_name,
				team = team,
				entindex = ancient:entindex()
			}
			
			table.insert(GameMode.ancients, ancient_info)
			ancient:AddNewModifier(ancient, nil, "modifier_invulnerable", {})
		end
		ancient = Entities:FindByClassname(ancient, "npc_dota_fort")
	end
end

-- Снимаем неуязвимость с T1 башен
function GameMode:UnlockTier1Towers()
	for _, tower_info in pairs(GameMode.towers) do
		-- T1 башни всех линий
		if tower_info.tier == 1 and tower_info.entity and IsValidEntity(tower_info.entity) then
			tower_info.entity:RemoveModifierByName("modifier_invulnerable")
		-- T2 mid башни
		elseif tower_info.tier == 2 and tower_info.lane == "mid" and tower_info.entity and IsValidEntity(tower_info.entity) then
			tower_info.entity:RemoveModifierByName("modifier_invulnerable")
			-- Даем модификатор брони от T1 башен
			GameMode:UpdateT2MidArmor(tower_info)
		end
	end
end

-- Снимаем неуязвимость со следующего тира башен на линии
function GameMode:UnlockNextTierTower(team, lane, current_tier)
	for _, tower_info in pairs(GameMode.towers) do
		if tower_info.tier == current_tier + 1 and 
		   tower_info.team == team and 
		   tower_info.lane == lane and 
		   tower_info.entity and 
		   IsValidEntity(tower_info.entity) then
			
			tower_info.entity:RemoveModifierByName("modifier_invulnerable")
			return true
		end
	end
	
	return false
end

-- Обновляем броню T2 mid башни на основе количества живых T1 башен
function GameMode:UpdateT2MidArmor(t2_mid_tower_info)
	if not t2_mid_tower_info or not t2_mid_tower_info.entity or not IsValidEntity(t2_mid_tower_info.entity) then
		return
	end
	
	-- Подсчитываем живые T1 башни союзной команды
	local t1_count = 0
	for _, tower_info in pairs(GameMode.towers) do
		if tower_info.tier == 1 and tower_info.team == t2_mid_tower_info.team then
			if tower_info.entity and IsValidEntity(tower_info.entity) and tower_info.entity:IsAlive() then
				t1_count = t1_count + 1
			end
		end
	end
	
	-- Удаляем все старые модификаторы
	while t2_mid_tower_info.entity:HasModifier("modifier_tower_bonus_armor") do
		t2_mid_tower_info.entity:RemoveModifierByName("modifier_tower_bonus_armor")
	end
	
	-- Добавляем новый с нужным количеством стаков
	if t1_count > 0 then
		for i = 1, t1_count do
			t2_mid_tower_info.entity:AddNewModifier(t2_mid_tower_info.entity, nil, "modifier_tower_bonus_armor", {})
		end
	end
end

-- Обновляем броню всех T2 mid башен команды
function GameMode:UpdateAllT2MidArmor(team)
	for _, tower_info in pairs(GameMode.towers) do
		if tower_info.tier == 2 and tower_info.lane == "mid" and tower_info.team == team then
			GameMode:UpdateT2MidArmor(tower_info)
		end
	end
end

-- Снимаем неуязвимость с трона команды
function GameMode:UnlockAncient(team)
	for _, ancient_info in pairs(GameMode.ancients) do
		if ancient_info.team == team and 
		   ancient_info.entity and 
		   IsValidEntity(ancient_info.entity) then
			
			ancient_info.entity:RemoveModifierByName("modifier_invulnerable")
			return true
		end
	end
	
	return false
end


function GameMode:OnNPCSpawned(data)
 	local npc = EntIndexToHScript(data.entindex)

	if KillfeedSystem and KillfeedSystem.OnNPCSpawned then
		KillfeedSystem:OnNPCSpawned(npc)
	end
 	
 	if npc and npc:GetUnitName() then
		-- Если это башня - регистрируем её (с проверкой на дубликаты внутри)
 		local unitName = npc:GetUnitName() or ""
		if (unitName == "npc_guardian_good" or unitName == "npc_guardian_bad")
			and not npc:HasModifier("modifier_black_king_bar_immune") then
			npc:AddNewModifier(npc, nil, "modifier_black_king_bar_immune", {})
		end

 		if npc:IsBuilding() and not npc:IsFort() and string.find(unitName, "tower")
 			and not string.find(unitName, "npc_chen_building") then
 			GameMode:RegisterTower(npc)
 		end
 	end
 
    if npc:IsRealHero() and npc.FirstSpawned == nil then
       npc.FirstSpawned = true
       npc:AddAbility("high_five_custom")

       -- Выдаем способности mind_power и empty_ability
       local abilities_to_give = {
           "mind_power",
           "empty_ability"
       }
       
       for _, ability_name in pairs(abilities_to_give) do
           if not npc:HasAbility(ability_name) then
               npc:AddAbility(ability_name)
           end
       end
   end

   if npc:IsRealHero() and not npc:IsIllusion() and npc:GetUnitName() == "npc_dota_hero_chen" then
       if not npc:HasModifier("modifier_chen_holy_persuasion_mind_hp") then
           npc:AddNewModifier(npc, nil, "modifier_chen_holy_persuasion_mind_hp", {})
       end
       if ChenWorkerBuild and ChenWorkerBuild.SyncScepterForHero then
           Timers:CreateTimer(0, function()
               if npc and not npc:IsNull() then
                   ChenWorkerBuild.SyncScepterForHero(npc)
               end
               return nil
           end)
       end
   end
   
   -- Отслеживаем спавн лейн крипов
   if npc:IsCreep() and not npc:IsNeutralUnitType() and not GameMode.lane_creeps_spawned then
       GameMode.lane_creeps_spawned = true
       GameMode:UnlockTier1Towers()
   end
end

function GameMode:OnChenInventoryChanged(data)
	if not data then
		return
	end

	local hero = PlayerResource:GetSelectedHeroEntity(data.PlayerID or data.player_id)
	if hero and not hero:IsNull() and hero:IsRealHero() and hero:GetUnitName() == "npc_dota_hero_chen" then
		if ChenWorkerBuild and ChenWorkerBuild.SyncScepterForHero then
			ChenWorkerBuild.SyncScepterForHero(hero)
		end
	end
end

function GameMode:OnInventoryUpdate(data)
	local item = EntIndexToHScript(data.item_entindex)
	local hero = item and not item:IsNull() and item:GetCaster() or nil

	if hero and not hero:IsNull() and hero:IsRealHero() and hero:GetUnitName() == "npc_dota_hero_chen" then
		if ChenWorkerBuild and ChenWorkerBuild.SyncScepterForHero then
			ChenWorkerBuild.SyncScepterForHero(hero)
		end
	end
end

function GameMode:ModifyGoldFilter(data)
	if KillfeedSystem and KillfeedSystem.ModifyGoldFilter then
		local result = KillfeedSystem:ModifyGoldFilter(data)
		if result == false then
			return false
		end
	end

	if ChenBarrackGold and ChenBarrackGold.ModifyGoldFilter then
		local result = ChenBarrackGold.ModifyGoldFilter(data)
		if result == false then
			return false
		end
	end
	return true
end

function GameMode:ExecuteOrderFilter(data)
	if ChenBarrackWorkerHandleOrder then
		return ChenBarrackWorkerHandleOrder(data)
	end

	return true
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
	if CreepBountyComeback and CreepBountyComeback.OnEntityKilled then
		CreepBountyComeback.OnEntityKilled(keys)
	end

	local unit = EntIndexToHScript(keys.entindex_killed)
	if not unit or (unit.IsNull and unit:IsNull()) then
		return
	end

	local unit_name = unit:GetUnitName()
	if KillfeedSystem and KillfeedSystem.OnEntityKilled then
		KillfeedSystem:OnEntityKilled(keys, unit)
	end

	-- Обработка уничтожения башен
	if unit:IsBuilding() and not unit:IsFort() then
		-- Находим информацию о башне в нашей таблице
		local killed_tower_info = nil
		for _, tower_info in pairs(GameMode.towers) do
			if tower_info.entindex == unit:entindex() then
				killed_tower_info = tower_info
				break
			end
		end
		
		if killed_tower_info then
			-- Если это T1 - разблокируем T2 на линии и обновляем броню T2 mid
			if killed_tower_info.tier == 1 then
				GameMode:UnlockNextTierTower(killed_tower_info.team, killed_tower_info.lane, killed_tower_info.tier)
				GameMode:UpdateAllT2MidArmor(killed_tower_info.team)
			-- Если это T2 - разблокируем T3 на линии и разблокируем трон
			elseif killed_tower_info.tier == 2 then
				GameMode:UnlockNextTierTower(killed_tower_info.team, killed_tower_info.lane, killed_tower_info.tier)
				GameMode:UnlockAncient(killed_tower_info.team)
			-- Если это T3 - разблокируем T4 на линии
			elseif killed_tower_info.tier == 3 then
				GameMode:UnlockNextTierTower(killed_tower_info.team, killed_tower_info.lane, killed_tower_info.tier)
			end
		end
	end

	-- Старая логика
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
			if teamnumber == DOTA_TEAM_GOODGUYS then 
				spawner = Entities:FindByName(nil, i == 1 and "bottom_spawner" or "top_spawner"):GetAbsOrigin()
				way = Entities:FindByName(nil, i == 1 and "lane_bot_pathcorner_goodguys_1" or "lane_bot_pathcorner_goodguys_1_top")
			else 
				spawner = Entities:FindAllByName("Spawner_good_bot")[i]:GetAbsOrigin()
				way = Entities:FindByName(nil, i == 1 and "lane_top_pathcorner_badguys_3_top" or "lane_bot_pathcorner_badguys_3a")
			end
			local unit = CreateUnitByName("npc_gold_lama",  spawner, true, nil, nil, teamnumber == DOTA_TEAM_GOODGUYS and DOTA_TEAM_BADGUYS or DOTA_TEAM_GOODGUYS)
			unit:SetInitialGoalEntity(way)
		end
		EmitGlobalSound("MegaCreeps.Radiant")
 	end
end

function GameMode:OnChatWheelSelect(data) 
    local sound = data.select;
	local hero = PlayerResource:GetSelectedHeroEntity(data.PlayerID)
	local infoCooldown = CustomNetTables:GetTableValue("cooldown_info", tostring(data.PlayerID)) or {cooldown_chat = 0} ;
    if infoCooldown.cooldown_chat == 1 then return end
    if not sound then return end
    if not hero then return end
	 
	CustomNetTables:SetTableValue("cooldown_info", tostring(data.PlayerID), {cooldown_chat = 1});
    Timers:CreateTimer(GameMode.CHAT_WHEEL_COOLDOWN, function()
         CustomNetTables:SetTableValue("cooldown_info", tostring(data.PlayerID), { cooldown_chat = 0 });
	end);
	EmitSoundOn("Wheel." .. sound, hero) 

	CustomGameEventManager:Send_ServerToAllClients("chat_wheel_send_sound", {
      hero = hero:entindex(),
      sound = sound,
	  maxTime = data.maxTime
    });
end

-- Консольная команда для спавна Рошана
Convars:RegisterCommand("spawn_roshan", function()
	local hero = PlayerResource:GetSelectedHeroEntity(0)
	if hero then
		local pos = hero:GetAbsOrigin() + hero:GetForwardVector() * 300
		local roshan = CreateUnitByName("npc_dota_roshan_custom", pos, true, nil, nil, DOTA_TEAM_NEUTRALS)
		print("[Console] Рошан заспавнен на позиции: " .. tostring(pos))
	end
end, "Спавнит кастомного Рошана перед героем", 0)
 
GameMode:InitGameMode()
