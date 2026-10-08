-- Буны вместо нейтральных предметов.
--
-- Ванильные нейтральные предметы выключены (SetAllowNeutralItemDrops(false) в addon_game_mode.lua).
-- С 5:00 каждые 5 минут игра помечает по 3 лесных крипа в каждой половине карты (лес Света: x + y < 0,
-- лес Тьмы: x + y >= 0). Древние, крипы каравана и боссы не подходят; в одном лагере — не больше одного
-- помеченного (кандидат не ближе CAMP_SPACING к уже помеченному). Над помеченным крипом — синий знак,
-- как у Track Охотника за головами (modifier_neutral_boon_carrier, modifiers/modifier_neutral_boon_carrier.lua). Метка не снимается до смерти крипа: новые 3 добавляются к старым.
-- Тир — по номеру выбора: 5:00 → 1, 10:00 → 2, 15:00 → 3, 20:00 и позже → 4 (пулы CaravanLoot.BOONS).
-- При смерти помеченного крипа на землю выпадает случайный бун его тира.
--
-- Любой бун (и из каравана) поднимает только герой и только в пустой слот нейтрального предмета;
-- выложить, передать, переложить его нельзя — только применить (NeutralBoons:ExecuteOrderFilter).
-- Счётчик на HUD (кружок над тайником, вместо ванильного счётчика нейтралок; panorama boon_counter):
-- «поднято героями / (выпало + живые метки)», только буны лесных крипов, общий для всех игроков.
-- Нет-таблица trinity_neutral_boons, ключ counter = { picked, total }.
-- Отладка: neutral_boons_pick [тир] — выбрать крипов сейчас; neutral_boons_debug 0|1 — лог;
-- neutral_boons_list, neutral_boons_mark_me, neutral_boons_mark_effect — см. раздел «отладка» внизу.

require("map_modifications/Bosses/caravan/caravan_loot")

NeutralBoons = NeutralBoons or {}

NeutralBoons.FIRST_PICK_TIME = 300   -- 5:00
NeutralBoons.PICK_INTERVAL = 300     -- каждые 5 минут
NeutralBoons.PER_SIDE = 3
NeutralBoons.CAMP_SPACING = 500      -- «один крип на лагерь»
NeutralBoons.CARRIER_MODIFIER = "modifier_neutral_boon_carrier"
NeutralBoons.NEUTRAL_SLOT = DOTA_ITEM_NEUTRAL_SLOT or 16
NeutralBoons.debug = NeutralBoons.debug or false
NeutralBoons.NET_TABLE = "trinity_neutral_boons"
NeutralBoons.dropped = NeutralBoons.dropped or 0 -- буны, выпавшие из помеченных крипов
NeutralBoons.picked = NeutralBoons.picked or 0   -- из них подобраны героем (каждый предмет — один раз)

local ERROR_SLOT_FULL = "#dota_hud_error_boon_neutral_slot_full"
local ERROR_HERO_ONLY = "#dota_hud_error_boon_pickup_hero_only"
local ERROR_LOCKED = "#dota_hud_error_boon_locked"

-- Модификатор живёт в отдельном файле: файл, который сам что-то require-ит и возвращает таблицу,
-- движок не находит как модификатор («Attempted to create unknown modifier type»).
-- Виды метки: red — знак Track particles/map/boons/bounty_hunter_track_shield_mark.vpcf (по умолчанию), blue — свой синий, aegis — свечение Аегиса.
-- Переключение в игре: neutral_boons_mark_effect.
NeutralBoons.MARK_MODIFIERS = {
    blue = NeutralBoons.CARRIER_MODIFIER,
    red = "modifier_neutral_boon_carrier_red",
    aegis = "modifier_neutral_boon_carrier_aegis",
}
-- По умолчанию — свой знак Track (particles/map/boons/bounty_hunter_track_shield_mark.vpcf).
NeutralBoons.DEFAULT_MARK_EFFECT = "red"
NeutralBoons.markEffect = NeutralBoons.DEFAULT_MARK_EFFECT
for _, modifierName in pairs(NeutralBoons.MARK_MODIFIERS) do
    LinkLuaModifier(modifierName, "modifiers/modifier_neutral_boon_carrier", LUA_MODIFIER_MOTION_NONE)
end

-- ---------------------------------------------------------------- общее

local function Log(fmt, ...)
    if NeutralBoons.debug then
        print("[NeutralBoons] " .. string.format(fmt, ...))
    end
end

local function IsAlive(unit)
    return unit ~= nil and not unit:IsNull() and unit:IsAlive()
end

function NeutralBoons:IsBoonName(name)
    return type(name) == "string" and string.sub(name, 1, 10) == "item_boon_"
end

function NeutralBoons:TierForPick(pickIndex)
    local tiers = CaravanLoot and CaravanLoot.BOONS and #CaravanLoot.BOONS or 4
    return math.max(1, math.min(pickIndex, tiers))
end

function NeutralBoons:SendError(playerID, message)
    local player = playerID ~= nil and playerID >= 0 and PlayerResource:GetPlayer(playerID) or nil
    if player then
        CustomGameEventManager:Send_ServerToPlayer(player, "dota_hud_error_message", {
            splitscreenplayer = 0,
            reason = 80,
            message = message,
        })
    end
end

-- ---------------------------------------------------------------- счётчик для HUD

function NeutralBoons:PublishCounter()
    local picked = self.picked
    local total = self.dropped + #self:MarkedCreeps()
    if self.sentPicked == picked and self.sentTotal == total then
        return
    end
    self.sentPicked = picked
    self.sentTotal = total
    CustomNetTables:SetTableValue(self.NET_TABLE, "counter", { picked = picked, total = total })
end

-- ---------------------------------------------------------------- выбор крипов

local function IsCandidate(unit)
    if not IsAlive(unit) or unit:GetTeamNumber() ~= DOTA_TEAM_NEUTRALS then
        return false
    end
    if unit.caravanId or unit.trinityBoonTier then
        return false
    end
    if unit.IsAncient and unit:IsAncient() then
        return false
    end
    if unit.IsBoss and unit:IsBoss() then
        return false
    end
    if unit.GetPlayerOwnerID and unit:GetPlayerOwnerID() >= 0 then
        return false
    end
    return true
end

local function IsRadiantSide(origin)
    return origin.x + origin.y < 0
end

function NeutralBoons:MarkedCreeps()
    local list = {}
    for _, unit in ipairs(Entities:FindAllByClassname("npc_dota_creep_neutral") or {}) do
        if IsAlive(unit) and unit.trinityBoonTier then
            table.insert(list, unit)
        end
    end
    return list
end

local function FarFromAll(origin, units, spacing)
    for _, other in ipairs(units) do
        if (other:GetAbsOrigin() - origin):Length2D() < spacing then
            return false
        end
    end
    return true
end

-- Вешает метку текущего вида (markEffect), снимая остальные. nil — модификатор не создался.
function NeutralBoons:ApplyMark(unit)
    for _, modifierName in pairs(self.MARK_MODIFIERS) do
        unit:RemoveModifierByName(modifierName)
    end
    local modifierName = self.MARK_MODIFIERS[self.markEffect] or self.CARRIER_MODIFIER
    local modifier = unit:AddNewModifier(unit, nil, modifierName, {})
    if not modifier then
        print("[NeutralBoons] failed to add " .. modifierName .. " to " .. unit:GetUnitName() .. "#" .. unit:entindex())
    end
    return modifier
end

function NeutralBoons:MarkName(unit)
    for effect, modifierName in pairs(self.MARK_MODIFIERS) do
        if unit:HasModifier(modifierName) then
            return effect
        end
    end
    return nil
end

function NeutralBoons:PickCarriers(tier)
    local marked = self:MarkedCreeps()
    local sides = { radiant = {}, dire = {} }
    for _, unit in ipairs(Entities:FindAllByClassname("npc_dota_creep_neutral") or {}) do
        if IsCandidate(unit) then
            local origin = unit:GetAbsOrigin()
            table.insert(IsRadiantSide(origin) and sides.radiant or sides.dire, unit)
        end
    end

    local total = 0
    for side, pool in pairs(sides) do
        local picked = 0
        while picked < self.PER_SIDE and #pool > 0 do
            local index = RandomInt(1, #pool)
            local unit = table.remove(pool, index)
            if FarFromAll(unit:GetAbsOrigin(), marked, self.CAMP_SPACING) then
                unit.trinityBoonTier = tier
                self:ApplyMark(unit)
                table.insert(marked, unit)
                picked = picked + 1
                Log("tier %d carrier %s#%d on %s side", tier, unit:GetUnitName(), unit:entindex(), side)
            end
        end
        total = total + picked
        if picked < self.PER_SIDE then
            Log("only %d carriers on %s side (not enough free camps)", picked, side)
        end
    end
    return total
end

-- ---------------------------------------------------------------- дроп

function NeutralBoons:RandomBoon(tier)
    local pool = CaravanLoot.BOONS[tier] or CaravanLoot.BOONS[#CaravanLoot.BOONS] or {}
    if #pool == 0 then
        return nil
    end
    return pool[RandomInt(1, #pool)]
end

function NeutralBoons:DropBoon(itemName, origin)
    local item = CreateItem(itemName, nil, nil)
    if not item then
        print("[NeutralBoons] Failed to create " .. tostring(itemName))
        return
    end
    item:SetPurchaseTime(0)
    item.trinityNeutralBoon = true -- для счётчика: бун из лесного крипа, а не из каравана
    if item.SetSellable then
        item:SetSellable(false)
    end
    CreateItemOnPositionForLaunch(origin, item)
    item:LaunchLootInitialHeight(false, 0, 150, 0.5, origin + RandomVector(RandomFloat(50, 110)))
end

function NeutralBoons:OnEntityKilled(keys)
    local unit = keys and keys.entindex_killed and EntIndexToHScript(keys.entindex_killed) or nil
    if not unit or unit:IsNull() or not unit.trinityBoonTier then
        return
    end
    local tier = unit.trinityBoonTier
    unit.trinityBoonTier = nil
    local itemName = self:RandomBoon(tier)
    if itemName then
        Log("carrier %s died, drops %s (tier %d)", unit:GetUnitName(), itemName, tier)
        self:DropBoon(itemName, unit:GetAbsOrigin())
        self.dropped = self.dropped + 1
    end
    self:PublishCounter()
end

-- ---------------------------------------------------------------- таймер

function NeutralBoons:Think()
    -- Каждую секунду: метка могла пропасть и без смерти крипа.
    self:PublishCounter()
    if GameRules:State_Get() ~= DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
        return 1
    end
    local now = GameRules:GetDOTATime(false, false)
    if now < self.FIRST_PICK_TIME then
        return 1
    end
    local pickIndex = math.floor((now - self.FIRST_PICK_TIME) / self.PICK_INTERVAL) + 1
    while (self.lastPick or 0) < pickIndex do
        self.lastPick = (self.lastPick or 0) + 1
        local tier = self:TierForPick(self.lastPick)
        local count = self:PickCarriers(tier)
        Log("pick #%d at %.0fs: tier %d, %d carriers", self.lastPick, now, tier, count)
        self:PublishCounter()
    end
    return 1
end

-- ---------------------------------------------------------------- слот нейтрального предмета

local LOCKED_ORDERS = {}
for _, name in ipairs({
    "DOTA_UNIT_ORDER_DROP_ITEM",
    "DOTA_UNIT_ORDER_GIVE_ITEM",
    "DOTA_UNIT_ORDER_MOVE_ITEM",
    "DOTA_UNIT_ORDER_SELL_ITEM",
    "DOTA_UNIT_ORDER_DISASSEMBLE_ITEM",
    "DOTA_UNIT_ORDER_DROP_ITEM_AT_FOUNTAIN",
    "DOTA_UNIT_ORDER_MOVE_ITEM_TO_STASH",
}) do
    if _G[name] ~= nil then
        LOCKED_ORDERS[_G[name]] = true
    end
end

local function OrderUnit(data)
    local units = data and data.units
    local index = units and (units["0"] or units[0] or units[1])
    return index and EntIndexToHScript(index) or nil
end

-- false — приказ отменён. Вызывается из GameMode:ExecuteOrderFilter.
function NeutralBoons:ExecuteOrderFilter(data)
    local orderType = data.order_type
    local unit = OrderUnit(data)
    local playerID = data.issuer_player_id_const

    if orderType == DOTA_UNIT_ORDER_PICKUP_ITEM then
        local physical = data.entindex_target and EntIndexToHScript(data.entindex_target) or nil
        local item = physical and physical.GetContainedItem and physical:GetContainedItem() or nil
        if not item or item:IsNull() or not self:IsBoonName(item:GetAbilityName()) then
            return true
        end
        if not unit or unit:IsNull() or not unit:IsRealHero() then
            self:SendError(playerID, ERROR_HERO_ONLY)
            return false
        end
        if unit:GetItemInSlot(self.NEUTRAL_SLOT) then
            self:SendError(playerID, ERROR_SLOT_FULL)
            return false
        end
        return true
    end

    if LOCKED_ORDERS[orderType] then
        local item = data.entindex_ability and EntIndexToHScript(data.entindex_ability) or nil
        if item and not item:IsNull() and item.GetAbilityName and self:IsBoonName(item:GetAbilityName()) then
            self:SendError(playerID, ERROR_LOCKED)
            return false
        end
    end
    return true
end

-- Поднятый бун — в слот нейтрального предмета. Если слот занят (успели положить что-то другое), бун падает обратно.
function NeutralBoons:OnItemPickedUp(keys)
    local item = keys and keys.ItemEntityIndex and EntIndexToHScript(keys.ItemEntityIndex) or nil
    if not item or item:IsNull() or not self:IsBoonName(item:GetAbilityName()) then
        return
    end
    local unitIndex = keys.HeroEntityIndex or keys.UnitEntityIndex
    local hero = unitIndex and EntIndexToHScript(unitIndex) or nil
    if not hero or hero:IsNull() then
        return
    end
    if item.trinityNeutralBoon and not item.trinityBoonCounted and hero.IsRealHero and hero:IsRealHero() then
        item.trinityBoonCounted = true
        self.picked = self.picked + 1
        self:PublishCounter()
    end

    -- Предмет кладётся в инвентарь в этом же кадре; перекладываем на следующем.
    Timers:CreateTimer(0, function()
        if item:IsNull() or hero:IsNull() then
            return
        end
        local slot = nil
        for i = 0, 16 do
            if hero:GetItemInSlot(i) == item then
                slot = i
                break
            end
        end
        if slot == nil or slot == self.NEUTRAL_SLOT then
            return
        end
        if hero:GetItemInSlot(self.NEUTRAL_SLOT) then
            -- Слот занят другим предметом: бун возвращается на землю.
            Log("%s: neutral slot busy, dropping %s", hero:GetUnitName(), item:GetAbilityName())
            hero:DropItemAtPositionImmediate(item, hero:GetAbsOrigin() + RandomVector(80))
            self:SendError(hero:GetPlayerOwnerID(), ERROR_SLOT_FULL)
            if item.trinityBoonCounted then
                -- Бун вернулся на землю: снова считается неподобранным.
                item.trinityBoonCounted = nil
                self.picked = math.max(0, self.picked - 1)
                self:PublishCounter()
            end
            return
        end
        hero:SwapItems(slot, self.NEUTRAL_SLOT)
        if hero:GetItemInSlot(self.NEUTRAL_SLOT) ~= item then
            -- Движок не пустил предмет в слот: бун остаётся в инвентаре и всё равно применяется.
            print("[NeutralBoons] engine kept " .. item:GetAbilityName() .. " in slot " .. slot .. " (neutral slot rejected)")
        end
    end)
end

-- ---------------------------------------------------------------- init

function NeutralBoons:Init()
    if self.initialized then
        return
    end
    self.initialized = true

    ListenToGameEvent("entity_killed", function(keys)
        NeutralBoons:OnEntityKilled(keys)
    end, nil)
    ListenToGameEvent("dota_item_picked_up", function(keys)
        NeutralBoons:OnItemPickedUp(keys)
    end, nil)

    self:PublishCounter()
    Timers:CreateTimer("trinity_neutral_boons_think", {
        endTime = 1,
        callback = function()
            return NeutralBoons:Think()
        end,
    })

    Convars:RegisterCommand("neutral_boons_pick", function(_, tier)
        local value = NeutralBoons:TierForPick(tonumber(tier) or 1)
        local count = NeutralBoons:PickCarriers(value)
        print("[NeutralBoons] manual pick: tier " .. value .. ", " .. count .. " carriers")
    end, "Mark boon carriers now: neutral_boons_pick [tier]", 0)

    Convars:RegisterCommand("neutral_boons_debug", function(_, value)
        NeutralBoons.debug = value == "1" or value == "true" or value == "on"
        print("[NeutralBoons] debug " .. tostring(NeutralBoons.debug))
    end, "Toggle neutral boons log: neutral_boons_debug 0|1", 0)
end

-- ---------------------------------------------------------------- отладка
-- neutral_boons_list — носители в консоль + пинг на миникарте + круг и подпись над крипом (10 сек.;
--   круги и подписи видны только в инструментах).
-- neutral_boons_mark_me [0|1] — метка текущего вида на своём герое (без числа — переключить).
-- neutral_boons_mark_effect blue|red|aegis — вид метки (без аргумента — показать текущий);
--   уже помеченные крипы и герой из mark_me перевешиваются сразу.

local DEBUG_DRAW_TIME = 10

local function CommandHero()
    local player = Convars:GetCommandClient()
    local hero = player and player.GetAssignedHero and player:GetAssignedHero() or nil
    if not hero and PlayerResource then
        hero = PlayerResource:GetSelectedHeroEntity(0)
    end
    return hero
end

function NeutralBoons:DebugList()
    local hero = CommandHero()
    local team = hero and hero:GetTeamNumber() or DOTA_TEAM_GOODGUYS
    local list = self:MarkedCreeps()
    print(string.format("[NeutralBoons] %d carriers, mark effect %s, time %.0f", #list, self.markEffect,
        GameRules:GetDOTATime(false, false)))
    for i, unit in ipairs(list) do
        local origin = unit:GetAbsOrigin()
        local mark = self:MarkName(unit)
        print(string.format("[NeutralBoons]  %d. %s#%d tier %d at (%.0f, %.0f, %.0f) mark %s, visible to your team %s",
            i, unit:GetUnitName(), unit:entindex(), unit.trinityBoonTier or 0,
            origin.x, origin.y, origin.z, tostring(mark or "NONE"),
            tostring(hero ~= nil and hero:CanEntityBeSeenByMyTeam(unit))))
        pcall(MinimapEvent, team, unit, origin.x, origin.y, DOTA_MINIMAP_EVENT_HINT_LOCATION, 5)
        pcall(DebugDrawCircle, origin, Vector(60, 140, 255), 40, 120, false, DEBUG_DRAW_TIME)
        pcall(DebugDrawText, origin + Vector(0, 0, 220),
            string.format("boon tier %d | %s", unit.trinityBoonTier or 0, tostring(mark or "NO MARK")), false, DEBUG_DRAW_TIME)
    end
    if #list == 0 then
        print("[NeutralBoons]  none: run neutral_boons_pick 1 (after 5:00 picks happen by themselves)")
    end
end

function NeutralBoons:DebugMarkMe(value)
    local hero = CommandHero()
    if not hero then
        print("[NeutralBoons] mark_me: no hero")
        return
    end
    local on
    if value == nil or value == "" then
        on = self:MarkName(hero) == nil
    else
        on = value == "1" or value == "true" or value == "on"
    end
    if on then
        local modifier = self:ApplyMark(hero)
        self.debugMarkedHero = hero
        print("[NeutralBoons] mark_me on " .. hero:GetUnitName() .. ": " .. self.markEffect
            .. (modifier and " (modifier ok)" or " (modifier FAILED)"))
    else
        for _, modifierName in pairs(self.MARK_MODIFIERS) do
            hero:RemoveModifierByName(modifierName)
        end
        self.debugMarkedHero = nil
        print("[NeutralBoons] mark_me off")
    end
end

function NeutralBoons:DebugMarkEffect(value)
    if value == nil or value == "" then
        print("[NeutralBoons] mark effect " .. self.markEffect .. " (blue | red | aegis)")
        return
    end
    if not self.MARK_MODIFIERS[value] then
        print("[NeutralBoons] unknown mark effect " .. tostring(value) .. " (blue | red | aegis)")
        return
    end
    self.markEffect = value
    local count = 0
    for _, unit in ipairs(self:MarkedCreeps()) do
        self:ApplyMark(unit)
        count = count + 1
    end
    local hero = self.debugMarkedHero
    if hero and not hero:IsNull() and self:MarkName(hero) then
        self:ApplyMark(hero)
    end
    print("[NeutralBoons] mark effect " .. value .. ", re-marked " .. count .. " carriers")
end

-- Регистрируется и при script_reload (Init повторно не выполняется).
if IsServer() and not _G.NEUTRAL_BOONS_DEBUG_COMMANDS then
    _G.NEUTRAL_BOONS_DEBUG_COMMANDS = true
    Convars:RegisterCommand("neutral_boons_list", function()
        NeutralBoons:DebugList()
    end, "List boon carriers, ping them on the minimap", 0)
    Convars:RegisterCommand("neutral_boons_mark_me", function(_, value)
        NeutralBoons:DebugMarkMe(value)
    end, "Put the carrier mark on your hero: neutral_boons_mark_me [0|1]", 0)
    Convars:RegisterCommand("neutral_boons_mark_effect", function(_, value)
        NeutralBoons:DebugMarkEffect(value)
    end, "Carrier mark look: neutral_boons_mark_effect blue|red|aegis", 0)
end

return NeutralBoons
