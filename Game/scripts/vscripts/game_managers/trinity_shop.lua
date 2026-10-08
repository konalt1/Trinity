-- Trinity: серверная часть нового магазина по категориям (Content/panorama/.../trinity_shop).
-- Покупка по правому клику из интерфейса приходит событием trinity_shop_buy (TrinityShop:OnBuy).

if TrinityShop == nil then
	TrinityShop = {}
end

local function SendDebug(text)
	print("[TrinityShop] " .. text)
end

local INVENTORY_LAST = 8 -- 0–5 инвентарь, 6–8 рюкзак
local STASH_FIRST = DOTA_STASH_SLOT_1 or 9
local STASH_LAST = DOTA_STASH_SLOT_6 or 14

local function FirstFreeSlot(hero, first, last)
	for slot = first, last do
		if not hero:GetItemInSlot(slot) then
			return slot
		end
	end
	return nil
end

local function Reply(playerID, payload)
	local player = PlayerResource:GetPlayer(playerID)
	if player then
		CustomGameEventManager:Send_ServerToPlayer(player, "trinity_shop_result", payload)
	end
end

-- ---------------------------------------------------------------- улучшение предмета из инвентаря
-- Плюсик над предметом в инвентаре (layout item_upgrade) → trinity_shop_upgrade { slot, item, cost }.
-- Сервер сам собирает предмет: берёт исходный предмет и остальные свои компоненты из инвентаря,
-- рюкзака и тайника, докупает недостающее (включая рецепт) и кладёт результат в слот исходного предмета.
-- Рецепты — из KV движка (item_recipe_<имя>, с переопределениями аддона), не из shop_data.js.

local UPGRADE_POOL_LAST = STASH_LAST -- инвентарь, рюкзак и тайник: у лавки тайник доступен
local UPGRADE_MAX_DEPTH = 4

local function ItemKeyValues(itemName)
	TrinityShop._kvCache = TrinityShop._kvCache or {}
	local cached = TrinityShop._kvCache[itemName]
	if cached ~= nil then
		return cached or nil
	end
	local kv = false
	local item = CreateItem(itemName, nil, nil)
	if item then
		kv = item.GetAbilityKeyValues and item:GetAbilityKeyValues() or false
		UTIL_Remove(item)
	end
	TrinityShop._kvCache[itemName] = kv
	return kv or nil
end

local function SortedKeys(tbl)
	local keys = {}
	for key in pairs(tbl) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

-- { recipe = имя рецепта, cost = цена рецепта, sets = { { компоненты }, ... } } или nil, если предмет не собирается.
local function RecipeInfo(target)
	TrinityShop._recipeCache = TrinityShop._recipeCache or {}
	local cached = TrinityShop._recipeCache[target]
	if cached ~= nil then
		return cached or nil
	end
	local info = false
	local recipeName = "item_recipe_" .. string.sub(target, 6)
	local kv = string.sub(target, 1, 12) ~= "item_recipe_" and ItemKeyValues(recipeName) or nil
	if kv and kv.ItemResult == target and type(kv.ItemRequirements) == "table" then
		local sets = {}
		local reqs = kv.ItemRequirements
		for _, key in ipairs(SortedKeys(reqs)) do
			local set = {}
			for raw in string.gmatch(tostring(reqs[key]), "[^;]+") do
				-- «item_blink*» в KV — компонент с вариантами; для сборки берём базовое имя.
				local part = string.gsub(raw, "[%s%*]", "")
				if part ~= "" then
					set[#set + 1] = part
				end
			end
			if #set > 0 then
				sets[#sets + 1] = set
			end
		end
		if #sets > 0 then
			info = { recipe = recipeName, cost = GetItemCost(recipeName) or 0, sets = sets }
		end
	end
	TrinityShop._recipeCache[target] = info
	return info or nil
end

local function CopyUsed(used)
	local copy = {}
	for key, value in pairs(used) do
		copy[key] = value
	end
	return copy
end

-- Предметы героя, которые можно пустить на сборку: свои (купленные этим героем), не заблокированные.
local function CollectOwnedItems(hero)
	local pool = {}
	for slot = 0, UPGRADE_POOL_LAST do
		local item = hero:GetItemInSlot(slot)
		if item and not item:IsNull() then
			local purchaser = item:GetPurchaser()
			local locked = item.IsCombineLocked and item:IsCombineLocked()
			if (purchaser == nil or purchaser == hero) and not locked then
				pool[#pool + 1] = { item = item, name = item:GetAbilityName(), slot = slot }
			end
		end
	end
	return pool
end

local function TakeOwned(name, pool, used)
	for _, entry in ipairs(pool) do
		if entry.name == name and not used[entry.item] then
			used[entry.item] = true
			return entry
		end
	end
	return nil
end

-- Сколько доплатить за предмет name с учётом своих компонентов. Возвращает цену, таблицу used
-- (использованные свои предметы) и список bought (что докупить: целые предметы и платные рецепты).
-- Свой готовый предмет — 0; сборный — дешевле из «собрать» и «купить целиком».
local function ResolveCost(name, pool, used, depth)
	local work = CopyUsed(used)
	if TakeOwned(name, pool, work) then
		return 0, work, {}
	end
	local bestCost = GetItemCost(name) or 0
	local bestUsed = used
	local bestBought = { name }
	local info = depth < UPGRADE_MAX_DEPTH and RecipeInfo(name) or nil
	if info then
		for _, set in ipairs(info.sets) do
			local cost = info.cost
			local setUsed = CopyUsed(used)
			local setBought = {}
			if info.cost > 0 then
				setBought[1] = info.recipe
			end
			for _, part in ipairs(set) do
				local partCost, partUsed, partBought = ResolveCost(part, pool, setUsed, depth + 1)
				cost = cost + partCost
				setUsed = partUsed
				for _, bought in ipairs(partBought) do
					setBought[#setBought + 1] = bought
				end
			end
			if cost < bestCost then
				bestCost = cost
				bestUsed = setUsed
				bestBought = setBought
			end
		end
	end
	return bestCost, bestUsed, bestBought
end

-- План улучшения source → target: исходный предмет обязан войти в сборку.
local function PlanUpgrade(target, sourceEntry, pool)
	local info = RecipeInfo(target)
	if not info then
		return nil
	end
	local best = nil
	for _, set in ipairs(info.sets) do
		local rest = {}
		local found = false
		for _, part in ipairs(set) do
			if not found and part == sourceEntry.name then
				found = true
			else
				rest[#rest + 1] = part
			end
		end
		if found then
			local used = { [sourceEntry.item] = true }
			local cost = info.cost
			for _, part in ipairs(rest) do
				local partCost, partUsed = ResolveCost(part, pool, used, 1)
				cost = cost + partCost
				used = partUsed
			end
			if not best or cost < best.cost then
				best = { cost = cost, used = used }
			end
		end
	end
	return best
end

-- ---------------------------------------------------------------- покупка из магазина
-- ПКМ по карточке/узлу (trinity_shop.js) → trinity_shop_buy { item }.
-- Приказ PURCHASE_ITEM из Lua движок не исполняет (у него нет игрока-инициатора), поэтому покупаем сами.
-- Как в родном магазине: у лавки — в инвентарь, вдали от неё — в тайник; сборный предмет учитывает
-- свои компоненты (инвентарь, рюкзак, тайник) и докупает только недостающее.

-- Предмет с запасом (варды, смоук, граната) — по KV, а не по таймеру пополнения:
-- при полном запасе таймер равен 0, и запас раньше не уменьшался.
local function HasStock(itemName)
	local kv = ItemKeyValues(itemName)
	if not kv then
		return false
	end
	return (tonumber(kv.ItemStockMax) or 0) > 0 or (tonumber(kv.ItemStockTime) or 0) > 0
end

-- Бесплатные предметы (Observer Ward, ItemCost 0) тоже покупаются, если KV не запрещает покупку.
local function IsPurchasable(itemName, cost)
	if cost > 0 then
		return true
	end
	local kv = ItemKeyValues(itemName)
	return kv ~= nil and tonumber(kv.ItemPurchasable or 1) ~= 0 and tonumber(kv.ItemRecipe or 0) ~= 1
end

-- План покупки target: целиком или из своих компонентов + докупка недостающего (что дешевле).
-- Свою копию самого target не засчитываем: покупка второго предмета — это новый предмет.
local function PlanPurchase(target, pool)
	local best = { cost = GetItemCost(target) or 0, used = {}, bought = { target } }
	local info = RecipeInfo(target)
	if not info then
		return best
	end
	for _, set in ipairs(info.sets) do
		local cost = info.cost
		local used = {}
		local bought = {}
		if info.cost > 0 then
			bought[1] = info.recipe
		end
		for _, part in ipairs(set) do
			local partCost, partUsed, partBought = ResolveCost(part, pool, used, 1)
			cost = cost + partCost
			used = partUsed
			for _, name in ipairs(partBought) do
				bought[#bought + 1] = name
			end
		end
		if cost < best.cost then
			best = { cost = cost, used = used, bought = bought }
		end
	end
	return best
end

local function NewPurchasedItem(itemName, hero)
	local item = CreateItem(itemName, hero, hero)
	if not item then
		SendDebug("buy " .. itemName .. ": CreateItem failed")
		return nil
	end
	item:SetPurchaser(hero)
	item:SetPurchaseTime(GameRules:GetGameTime())
	return item
end

-- Положить предмет: у лавки — в инвентарь (если есть место), иначе — в тайник.
-- AddItem кладёт в первый свободный слот инвентаря; вдали от лавки переносим в тайник.
local function PlacePurchasedItem(hero, item, toInventory)
	hero:AddItem(item)
	if toInventory or item:IsNull() then
		return
	end
	local slot = item:GetItemSlot()
	local freeStash = FirstFreeSlot(hero, STASH_FIRST, STASH_LAST)
	if slot ~= nil and slot >= 0 and slot <= INVENTORY_LAST and freeStash then
		hero:SwapItems(slot, freeStash)
	end
end

local function CountFreeSlots(hero, first, last)
	local count = 0
	for slot = first, last do
		if not hero:GetItemInSlot(slot) then
			count = count + 1
		end
	end
	return count
end

function TrinityShop:OnBuy(event)
	local playerID = event.PlayerID
	local itemName = event.item
	if type(itemName) ~= "string" or not string.match(itemName, "^item_[%w_]+$") then
		return
	end
	local hero = PlayerResource:GetSelectedHeroEntity(playerID)
	if not hero then
		return
	end

	local wholeCost = GetItemCost(itemName)
	if wholeCost == nil or not IsPurchasable(itemName, wholeCost) then
		SendDebug("buy " .. itemName .. ": not purchasable (cost " .. tostring(wholeCost) .. ")")
		return
	end

	local nearShop = hero:IsAlive() and hero:IsInRangeOfShop(DOTA_SHOP_HOME, true)
	local pool = CollectOwnedItems(hero)
	local plan = PlanPurchase(itemName, pool)
	local assemble = next(plan.used) ~= nil

	if PlayerResource:GetGold(playerID) < plan.cost then
		Reply(playerID, { ok = 0, reason = "gold" })
		return
	end

	-- Запас: команда общая (playerID -1), как в DraftSpawn:RestoreWardShopStock.
	local team = hero:GetTeamNumber()
	local stocked = not assemble and HasStock(itemName)
	if stocked then
		local count = GameRules:GetItemStockCount(team, itemName, -1) or 0
		if count <= 0 then
			Reply(playerID, { ok = 0, reason = "stock" })
			return
		end
	end

	if not assemble then
		local freeInventory = FirstFreeSlot(hero, 0, INVENTORY_LAST)
		local freeStash = FirstFreeSlot(hero, STASH_FIRST, STASH_LAST)
		if not (nearShop and freeInventory) and not freeStash then
			Reply(playerID, { ok = 0, reason = "full" })
			return
		end
		local item = NewPurchasedItem(itemName, hero)
		if not item then
			return
		end
		if plan.cost > 0 then
			PlayerResource:SpendGold(playerID, plan.cost, DOTA_ModifyGold_PurchaseItem)
		end
		PlacePurchasedItem(hero, item, nearShop and freeInventory ~= nil)
		if stocked then
			-- DecreaseItemStock в API нет: запас уменьшает IncreaseItemStock с отрицательным count.
			local ok, err = pcall(function()
				GameRules:IncreaseItemStock(team, itemName, -1, -1)
			end)
			SendDebug("buy " .. itemName .. ": stock left " .. tostring(GameRules:GetItemStockCount(team, itemName, -1)) .. (ok and "" or (" (error: " .. tostring(err) .. ")")))
		end
		Reply(playerID, { ok = 1, item = itemName })
		return
	end

	-- Сборка из своих компонентов. У лавки или когда все свои компоненты лежат в тайнике — собираем сразу.
	local allInStash = true
	for _, entry in ipairs(pool) do
		if plan.used[entry.item] and entry.slot < STASH_FIRST then
			allInStash = false
		end
	end

	if nearShop or allInStash then
		local result = NewPurchasedItem(itemName, hero)
		if not result then
			return
		end
		if plan.cost > 0 then
			PlayerResource:SpendGold(playerID, plan.cost, DOTA_ModifyGold_PurchaseItem)
		end
		for _, entry in ipairs(pool) do
			if plan.used[entry.item] and not entry.item:IsNull() then
				hero:RemoveItem(entry.item)
			end
		end
		local toInventory = nearShop and FirstFreeSlot(hero, 0, INVENTORY_LAST) ~= nil
		PlacePurchasedItem(hero, result, toInventory)
		Reply(playerID, { ok = 1, item = itemName })
		return
	end

	-- Вдали от лавки, а свои компоненты у героя: докупаем только недостающее в тайник,
	-- собирается оно, когда курьер донесёт части до инвентаря (как в родном магазине).
	if CountFreeSlots(hero, STASH_FIRST, STASH_LAST) < #plan.bought then
		Reply(playerID, { ok = 0, reason = "full" })
		return
	end
	if plan.cost > 0 then
		PlayerResource:SpendGold(playerID, plan.cost, DOTA_ModifyGold_PurchaseItem)
	end
	for _, partName in ipairs(plan.bought) do
		local part = NewPurchasedItem(partName, hero)
		if part then
			PlacePurchasedItem(hero, part, false)
		end
	end
	Reply(playerID, { ok = 1, item = itemName })
end

function TrinityShop:OnUpgrade(event)
	local playerID = event.PlayerID
	local target = event.item
	local sourceSlot = tonumber(event.slot)
	if type(target) ~= "string" or not string.match(target, "^item_[%w_]+$") then
		return
	end
	if not sourceSlot or sourceSlot < 0 or sourceSlot > INVENTORY_LAST then
		return
	end
	local hero = PlayerResource:GetSelectedHeroEntity(playerID)
	if not hero then
		return
	end
	-- Таверна (разминка): её магазин — триггер из Lua, на всякий случай доверяем и модификатору площадки.
	local inTavern = hero:HasModifier("modifier_trinity_warmup_zone")
	if not hero:IsAlive() or not (hero:IsInRangeOfShop(DOTA_SHOP_HOME, true) or inTavern) then
		Reply(playerID, { ok = 0, reason = "shop" })
		return
	end

	local source = hero:GetItemInSlot(sourceSlot)
	if not source or source:IsNull() then
		return
	end
	local pool = CollectOwnedItems(hero)
	local sourceEntry = nil
	for _, entry in ipairs(pool) do
		if entry.item == source then
			sourceEntry = entry
		end
	end
	if not sourceEntry then
		Reply(playerID, { ok = 0, reason = "recipe" })
		return
	end

	local plan = PlanUpgrade(target, sourceEntry, pool)
	if not plan then
		SendDebug("upgrade " .. sourceEntry.name .. " -> " .. target .. ": no recipe")
		Reply(playerID, { ok = 0, reason = "recipe" })
		return
	end
	local expected = tonumber(event.cost)
	if expected and expected ~= plan.cost then
		-- Цена в плюсике считается по shop_data.js: расхождение с KV — повод обновить данные магазина.
		SendDebug("upgrade " .. sourceEntry.name .. " -> " .. target .. ": UI cost " .. expected .. ", server cost " .. plan.cost)
	end
	if PlayerResource:GetGold(playerID) < plan.cost then
		Reply(playerID, { ok = 0, reason = "gold" })
		return
	end

	local result = CreateItem(target, hero, hero)
	if not result then
		SendDebug("upgrade " .. target .. ": CreateItem failed")
		return
	end
	result:SetPurchaser(hero)
	result:SetPurchaseTime(GameRules:GetGameTime())

	if plan.cost > 0 then
		PlayerResource:SpendGold(playerID, plan.cost, DOTA_ModifyGold_PurchaseItem)
	end
	for _, entry in ipairs(pool) do
		if plan.used[entry.item] and not entry.item:IsNull() then
			hero:RemoveItem(entry.item)
		end
	end

	-- Слот исходного предмета освободился: AddItem кладёт в первый свободный, переносим на место исходного.
	hero:AddItem(result)
	if not result:IsNull() then
		local slot = result:GetItemSlot()
		if slot ~= nil and slot >= 0 and slot ~= sourceSlot and not hero:GetItemInSlot(sourceSlot) then
			hero:SwapItems(slot, sourceSlot)
		end
	end

	Reply(playerID, { ok = 1, item = target, upgrade = 1 })
end

-- Основной атрибут героя для фильтра магазина по умолчанию (в Panorama API его нет).
local PRIMARY_ATTRIBUTE_IDS = {
	[DOTA_ATTRIBUTE_STRENGTH or 0] = "str",
	[DOTA_ATTRIBUTE_AGILITY or 1] = "agi",
	[DOTA_ATTRIBUTE_INTELLECT or 2] = "int",
	[DOTA_ATTRIBUTE_ALL or 3] = "multi",
}

-- Статы предмета из KV (с учётом переопределений аддона): временный предмет, значения 1-го уровня.
local STAT_KEYS = {
	str = { "bonus_strength", "bonus_str" },
	agi = { "bonus_agility", "bonus_agi" },
	int = { "bonus_intellect", "bonus_intelligence", "bonus_int" },
	all = { "bonus_all_stats", "bonus_stats" },
}

local function ReadItemStats(itemName)
	TrinityShop._statsCache = TrinityShop._statsCache or {}
	local cached = TrinityShop._statsCache[itemName]
	if cached then
		return cached
	end
	local stats = { str = 0, agi = 0, int = 0, all = 0 }
	local item = CreateItem(itemName, nil, nil)
	if item then
		for stat, keys in pairs(STAT_KEYS) do
			for _, key in ipairs(keys) do
				local value = item:GetSpecialValueFor(key) or 0
				if value > stats[stat] then
					stats[stat] = value
				end
			end
		end
		UTIL_Remove(item)
	end
	TrinityShop._statsCache[itemName] = stats
	return stats
end

function TrinityShop:OnHeroAttributeRequest(event)
	local playerID = event.PlayerID
	local player = PlayerResource:GetPlayer(playerID)
	if not player then
		return
	end
	local payload = {}
	local hero = PlayerResource:GetSelectedHeroEntity(playerID)
	if hero then
		payload.hero = hero:entindex()
		payload.attr = PRIMARY_ATTRIBUTE_IDS[hero:GetPrimaryAttribute()]
	end
	if type(event.items) == "string" and event.items ~= "" then
		payload.stats = {}
		for itemName in string.gmatch(event.items, "item_[%w_]+") do
			-- Только предметы со статами: ответ меньше, клиент считает остальные нулевыми.
			local stats = ReadItemStats(itemName)
			if stats.str + stats.agi + stats.int + stats.all > 0 then
				payload.stats[itemName] = stats
			end
		end
	end
	CustomGameEventManager:Send_ServerToPlayer(player, "trinity_shop_hero_attr", payload)
end

-- ---------------------------------------------------------------- запас предметов для интерфейса
-- Сколько вардов (и прочих предметов с запасом) осталось в магазине у команды. В Panorama этого нет,
-- поэтому сервер раз в 0,25 с пишет счётчики в nettable trinity_shop, ключ stock_<команда>, только при изменении.
-- Читает ряд расходников в окне сборки (trinity_shop.js, RenderConsumables).

local STOCK_ITEMS = { "item_ward_observer", "item_ward_sentry", "item_smoke_of_deceit", "item_blood_grenade" }
local STOCK_INTERVAL = 0.25

function TrinityShop:UpdateStockTable()
	self._stockSent = self._stockSent or {}
	for _, team in ipairs({ DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS }) do
		local counts = {}
		local key = ""
		for _, itemName in ipairs(STOCK_ITEMS) do
			if HasStock(itemName) then
				local count = tonumber(GameRules:GetItemStockCount(team, itemName, -1)) or 0
				counts[itemName] = math.max(0, math.floor(count))
				key = key .. itemName .. "=" .. counts[itemName] .. ";"
			end
		end
		if self._stockSent[team] ~= key then
			self._stockSent[team] = key
			CustomNetTables:SetTableValue("trinity_shop", "stock_" .. team, counts)
		end
	end
end

function TrinityShop:Init()
	if not self._attrListener then
		self._attrListener = true
		CustomGameEventManager:RegisterListener("trinity_shop_hero_attr_request", function(_, event)
			TrinityShop:OnHeroAttributeRequest(event)
		end)
	end
	if not self._upgradeListener then
		self._upgradeListener = true
		CustomGameEventManager:RegisterListener("trinity_shop_upgrade", function(_, event)
			TrinityShop:OnUpgrade(event)
		end)
	end
	-- Таймер с именем: при перезагрузке скриптов заменяется, а не дублируется. Ошибка не должна его останавливать.
	Timers:CreateTimer("trinity_shop_stock", {
		useGameTime = false,
		callback = function()
			local ok, err = pcall(function()
				TrinityShop:UpdateStockTable()
			end)
			if not ok then
				SendDebug("stock: " .. tostring(err))
			end
			return STOCK_INTERVAL
		end,
	})
	if self._initialized then
		return
	end
	self._initialized = true
	-- Ошибка в покупке не должна проходить молча: пишем в консоль с трассировкой.
	CustomGameEventManager:RegisterListener("trinity_shop_buy", function(_, event)
		local ok, err = xpcall(function()
			TrinityShop:OnBuy(event)
		end, debug.traceback)
		if not ok then
			SendDebug("buy " .. tostring(event and event.item) .. " failed: " .. tostring(err))
		end
	end)
end
