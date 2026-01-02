if GameMode == nil then
	_G.GameMode = class({})
end

GameMode.current_units = {}
GameMode.line_interval = {}
GameMode.wave_number = 0
GameMode.towers = {} -- Таблица всех башен с информацией о них
GameMode.ancients = {} -- Таблица тронов
GameMode.lane_creeps_spawned = false -- Флаг спавна лейн крипов

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
 

    GameRules:SetCustomGameTeamMaxPlayers(1, 2)
end

function GameMode:OnGameRulesStateChange()
	local newState = GameRules:State_Get()

	if newState == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		print("=== ИГРА НАЧАЛАСЬ! Инициализация башен ===")
		
		-- Сбрасываем флаг спавна крипов
		GameMode.lane_creeps_spawned = false
		
		-- Spawn neutral creeps immediately
		GameRules:SpawnNeutralCreeps()
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
	print("=== Инициализация защиты башен ===")
	
	local towers_count = 0
	
	-- Находим все башни через класс npc_dota_tower
	local tower = Entities:FindByClassname(nil, "npc_dota_tower")
	while tower ~= nil do
		if tower and IsValidEntity(tower) then
			if self:RegisterTower(tower) then
				towers_count = towers_count + 1
			end
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
			towers_count = towers_count + 1
		end
		watch_tower = Entities:FindByClassname(watch_tower, "npc_dota_watch_tower")
	end
	
	print("=== Защищено башен: " .. towers_count .. " ===")
end

--[[
	ПРИМЕР ИСПОЛЬЗОВАНИЯ GameMode.towers:
	
	-- Найти все башни T1 команды Radiant:
	for _, tower_info in pairs(GameMode.towers) do
		if tower_info.tier == 1 and tower_info.team == "radiant" then
			print("T1 башня Radiant: " .. tower_info.name)
		end
	end
	
	-- Найти все башни на top линии:
	for _, tower_info in pairs(GameMode.towers) do
		if tower_info.lane == "top" then
			print("Top башня: " .. tower_info.name .. " tier " .. tower_info.tier)
		end
	end
	
	-- Получить entity башни:
	local tower_entity = tower_info.entity
	tower_entity:RemoveModifierByName("modifier_invulnerable")
	
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
	print("=== Инициализация защиты тронов ===")
	
	local ancient_count = 0
	
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
			ancient_count = ancient_count + 1
		end
		ancient = Entities:FindByClassname(ancient, "npc_dota_fort")
	end
	
	print("=== Защищено тронов: " .. ancient_count .. " ===")
end

-- Снимаем неуязвимость с T1 башен
function GameMode:UnlockTier1Towers()
	print("========================================")
	print("=== СПАВН КРИПОВ: Снимаем защиту с T1 и T3 mid башен ===")
	
	local unlocked_count = 0
	
	for _, tower_info in pairs(GameMode.towers) do
		-- T1 башни всех линий
		if tower_info.tier == 1 and tower_info.entity and IsValidEntity(tower_info.entity) then
			tower_info.entity:RemoveModifierByName("modifier_invulnerable")
			unlocked_count = unlocked_count + 1
			print(string.format("    ✓ %s [T%d %s %s] уязвима", 
				tower_info.name, tower_info.tier, tower_info.team, tower_info.lane))
		-- T3 mid башни
		elseif tower_info.tier == 3 and tower_info.lane == "mid" and tower_info.entity and IsValidEntity(tower_info.entity) then
			tower_info.entity:RemoveModifierByName("modifier_invulnerable")
			unlocked_count = unlocked_count + 1
			print(string.format("    ✓ %s [T3 mid %s] уязвима", 
				tower_info.name, tower_info.team))
			-- Даем модификатор брони от T2 башен
			GameMode:UpdateT3MidArmor(tower_info)
		end
	end
	
	print("=== Разблокировано башен: " .. unlocked_count .. " ===")
	print("========================================")
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
			print(string.format("    ✓ РАЗБЛОКИРОВАНА: %s [T%d %s %s]", 
				tower_info.name, tower_info.tier, tower_info.team, tower_info.lane))
			return true
		end
	end
	
	return false
end

-- Обновляем броню T3 mid башни на основе количества живых T2 башен
function GameMode:UpdateT3MidArmor(t3_mid_tower_info)
	if not t3_mid_tower_info or not t3_mid_tower_info.entity or not IsValidEntity(t3_mid_tower_info.entity) then
		print("    >>> ERROR: T3 mid башня не валидна!")
		return
	end
	
	print(string.format("    >>> Обновляем броню для: %s [%s]", t3_mid_tower_info.name, t3_mid_tower_info.team))
	
	-- Подсчитываем живые T2 башни союзной команды
	local t2_count = 0
	for _, tower_info in pairs(GameMode.towers) do
		if tower_info.tier == 2 and tower_info.team == t3_mid_tower_info.team then
			print(string.format("        Проверка T2: %s [%s, %s]", 
				tower_info.name, tower_info.team, tower_info.lane))
			
			if tower_info.entity and IsValidEntity(tower_info.entity) then
				if tower_info.entity:IsAlive() then
					t2_count = t2_count + 1
					print("            -> Жива, считаем")
				else
					print("            -> Мертва, не считаем")
				end
			else
				print("            -> Entity не валидна")
			end
		end
	end
	
	print(string.format("        Всего живых T2 башен: %d", t2_count))
	
	-- Удаляем все старые модификаторы
	while t3_mid_tower_info.entity:HasModifier("modifier_tower_bonus_armor") do
		t3_mid_tower_info.entity:RemoveModifierByName("modifier_tower_bonus_armor")
	end
	
	-- Добавляем новый с нужным количеством стаков
	if t2_count > 0 then
		for i = 1, t2_count do
			t3_mid_tower_info.entity:AddNewModifier(t3_mid_tower_info.entity, nil, "modifier_tower_bonus_armor", {})
		end
		print(string.format("    >>> T3 mid башня %s получила +%d брони (T2 башен: %d)", 
			t3_mid_tower_info.name, t2_count * 5, t2_count))
	else
		print(string.format("    >>> T3 mid башня %s не имеет бонуса брони (нет T2 башен)", 
			t3_mid_tower_info.name))
	end
end

-- Обновляем броню всех T3 mid башен команды
function GameMode:UpdateAllT3MidArmor(team)
	print(string.format(">>> UpdateAllT3MidArmor вызвана для команды: %s", team))
	
	local found = false
	for _, tower_info in pairs(GameMode.towers) do
		if tower_info.tier == 3 and tower_info.lane == "mid" and tower_info.team == team then
			found = true
			print(string.format("    Найдена T3 mid башня: %s", tower_info.name))
			GameMode:UpdateT3MidArmor(tower_info)
		end
	end
	
	if not found then
		print("    ✗ T3 mid башня не найдена!")
	end
end

-- Снимаем неуязвимость с трона команды
function GameMode:UnlockAncient(team)
	for _, ancient_info in pairs(GameMode.ancients) do
		if ancient_info.team == team and 
		   ancient_info.entity and 
		   IsValidEntity(ancient_info.entity) then
			
			ancient_info.entity:RemoveModifierByName("modifier_invulnerable")
			print(string.format("    ✓ РАЗБЛОКИРОВАН ТРОН: %s [%s]", 
				ancient_info.name, ancient_info.team))
			return true
		end
	end
	
	return false
end


function GameMode:OnNPCSpawned(data)
 	local npc = EntIndexToHScript(data.entindex)
 	
 	if npc and npc:GetUnitName() then
 		-- Если это башня - регистрируем её (с проверкой на дубликаты внутри)
 		if npc:IsBuilding() and not npc:IsFort() and string.find(npc:GetUnitName(), "tower") then
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
   
   -- Отслеживаем спавн лейн крипов
   if npc:IsCreep() and not npc:IsNeutralUnitType() and not GameMode.lane_creeps_spawned then
       GameMode.lane_creeps_spawned = true
       GameMode:UnlockTier1Towers()
   end
end

function GameMode:OnInventoryUpdate(data)
	local item = EntIndexToHScript(data.item_entindex)

 	if item:GetItemSlot() == 16 and string.sub(item:GetName(), 0,9) ~= "item_tier" then 
 		local freeSlot 
 		for i=0,8 do
 			local freeSlotItem =  item:GetCaster():GetItemInSlot(i)

 			if not freeSlotItem then 
 				freeSlot = i
 				break
 			end
 		end

 		if freeSlot ~= nil then 
 			item:GetCaster():SwapItems(freeSlot, 16)
 		end
 	end
end

function GameMode:ModifyGoldFilter(data)
	if data.reason_const == DOTA_ModifyGold_HeroKill  then data.gold = data.gold * 2 end
	print(data.reason_const)
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

	local unit = EntIndexToHScript(keys.entindex_killed)
	local unit_name = unit:GetUnitName()

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
			print("========================================")
			print(string.format("=== УНИЧТОЖЕНА БАШНЯ: %s [T%d %s %s] ===", 
				killed_tower_info.name, killed_tower_info.tier, killed_tower_info.team, killed_tower_info.lane))
			
			-- Если это T1 или T2 - разблокируем следующий тир на линии
			if killed_tower_info.tier == 1 or killed_tower_info.tier == 2 then
				GameMode:UnlockNextTierTower(killed_tower_info.team, killed_tower_info.lane, killed_tower_info.tier)
				
				-- Если уничтожена T2 башня - обновляем броню T3 mid башни
				if killed_tower_info.tier == 2 then
					print(">>> T2 башня уничтожена, обновляем броню T3 mid команды: " .. killed_tower_info.team)
					GameMode:UpdateAllT3MidArmor(killed_tower_info.team)
				end
			-- Если это T3 или T4 - разблокируем трон
			elseif killed_tower_info.tier == 3 or killed_tower_info.tier == 4 then
				GameMode:UnlockAncient(killed_tower_info.team)
			end
			print("========================================")
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

 
GameMode:InitGameMode()