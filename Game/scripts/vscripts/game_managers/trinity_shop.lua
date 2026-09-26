-- Trinity: серверная часть нового магазина по категориям (Content/panorama/.../trinity_shop).
-- Покупка по правому клику из интерфейса приходит событием trinity_shop_buy.

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

-- Покупка на сервере: приказ PURCHASE_ITEM из Lua движок не исполняет (у него нет игрока-инициатора).
-- Логика как у родного магазина: у лавки — в инвентарь, вдали от неё — в тайник.
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

	local cost = GetItemCost(itemName)
	if not cost or cost <= 0 then
		SendDebug("buy " .. itemName .. ": no cost")
		return
	end
	if PlayerResource:GetGold(playerID) < cost then
		Reply(playerID, { ok = 0, reason = "gold" })
		return
	end

	local nearShop = hero:IsAlive() and hero:IsInRangeOfShop(DOTA_SHOP_HOME, true)
	local freeInventory = FirstFreeSlot(hero, 0, INVENTORY_LAST)
	local freeStash = FirstFreeSlot(hero, STASH_FIRST, STASH_LAST)
	if not (nearShop and freeInventory) and not freeStash then
		Reply(playerID, { ok = 0, reason = "full" })
		return
	end

	local item = CreateItem(itemName, hero, hero)
	if not item then
		SendDebug("buy " .. itemName .. ": CreateItem failed")
		return
	end
	item:SetPurchaser(hero)
	item:SetPurchaseTime(GameRules:GetGameTime())
	PlayerResource:SpendGold(playerID, cost, DOTA_ModifyGold_PurchaseItem)

	if nearShop and freeInventory then
		hero:AddItem(item)
	else
		-- AddItem кладёт в первый свободный слот инвентаря; вдали от лавки переносим в тайник.
		hero:AddItem(item)
		local slot = item:GetItemSlot()
		if slot ~= nil and slot >= 0 and slot <= INVENTORY_LAST then
			hero:SwapItems(slot, freeStash)
		end
	end

	Reply(playerID, { ok = 1, item = itemName })
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

function TrinityShop:Init()
	if not self._attrListener then
		self._attrListener = true
		CustomGameEventManager:RegisterListener("trinity_shop_hero_attr_request", function(_, event)
			TrinityShop:OnHeroAttributeRequest(event)
		end)
	end
	if self._initialized then
		return
	end
	self._initialized = true
	CustomGameEventManager:RegisterListener("trinity_shop_buy", function(_, event)
		TrinityShop:OnBuy(event)
	end)
end
