// Trinity: улучшение предметов из инвентаря (плюсик над предметом у лавки и в таверне).
// Куда: Content/panorama/layout/custom_game/item_upgrade/item_upgrade.js
// Данные: TRINITY_SHOP_DATA из shop_data.js (подключён раньше этого файла в том же layout).
//
// Плюсики и окно с вариантами — панели этого layout поверх экрана; координаты берутся у родных
// слотов инвентаря HUD (inventory_slot_0…8). Покупку делает сервер: trinity_shop_upgrade
// (game_managers/trinity_shop.lua), ответ — общее событие магазина trinity_shop_result.

"use strict";

const CONTEXT = $.GetContextPanel();
const CONFIG = GameUI.CustomUIConfig();
const DATA = TRINITY_SHOP_DATA;

if (!CONFIG.trinityUpgrade) {
	CONFIG.trinityUpgrade = {};
}
const STATE = CONFIG.trinityUpgrade;
STATE.generation = (STATE.generation || 0) + 1;
const GENERATION = STATE.generation;
STATE.open = null;
STATE.popupKey = null;

const INVENTORY_LAST = 8; // 0–5 инвентарь, 6–8 рюкзак: над ними плюсики
const POOL_LAST = 14; // + тайник 9–14: у лавки его компоненты тоже идут в сборку
const MAX_DEPTH = 4;
const TICK = 0.05;
const PLUS = { height: 18, overlap: 5 }; // ширина — во всю ширину слота
const LINK = { gap: 10, caret: 12 }; // зазор окно → плюсик, в нём стрелка-хвостик окна
const CARD = { stride: 156, perRow: 5, chrome: 16 }; // карточка 150 + рамка 2 + поля 4; рамка и поля окна
const SHOP_HOME = typeof DOTA_SHOP_TYPE !== "undefined" ? DOTA_SHOP_TYPE.DOTA_SHOP_HOME : 0;
// Таверна (площадка разминки): там свой магазин, но его триггер создаётся из Lua и клиент его не видит.
// Пока герой в таверне, на нём висит этот скрытый модификатор (game_managers/draft_spawn.lua).
const TAVERN_MODIFIER = "modifier_trinity_warmup_zone";

const PLUS_LAYER = $("#PlusLayer");
const POPUP = $("#UpgradePopup");
const CARDS = $("#UpgradeCards");
const CARET = $("#PopupCaret");
const HIGHLIGHT = $("#SlotHighlight");

// ---------------------------------------------------------------- рецепты

// «Во что собирается»: обратный индекс по components (как в trinity_shop.js).
const BUILDS_INTO = (() => {
	const into = {};
	Object.keys(DATA.recipes).forEach((name) => {
		DATA.recipes[name].components.forEach((part) => {
			into[part] = into[part] || [];
			if (into[part].indexOf(name) === -1) {
				into[part].push(name);
			}
		});
	});
	return into;
})();

function Upgrades(name) {
	if (!name || name.indexOf("item_recipe_") === 0) return [];
	return BUILDS_INTO[name] || [];
}

function FullPrice(name) {
	if (DATA.recipes[name]) return DATA.recipes[name].price;
	if (DATA.items[name]) return DATA.items[name].price;
	return 0;
}

function TakeOwned(name, pool, used) {
	for (let i = 0; i < pool.length; i++) {
		const entry = pool[i];
		if (entry.name === name && !used[entry.item]) {
			used[entry.item] = true;
			return entry;
		}
	}
	return null;
}

// Сколько доплатить за name с учётом своих предметов. Тот же алгоритм, что на сервере:
// свой готовый предмет — 0, сборный — дешевле из «собрать из своих частей» и «купить целиком».
function ResolveCost(name, pool, used, depth) {
	const work = Object.assign({}, used);
	if (TakeOwned(name, pool, work)) {
		return { cost: 0, used: work };
	}
	let best = { cost: FullPrice(name), used: used };
	const recipe = depth < MAX_DEPTH ? DATA.recipes[name] : null;
	if (recipe && recipe.components.length > 0) {
		let cost = recipe.recipe || 0;
		let setUsed = Object.assign({}, used);
		recipe.components.forEach((part) => {
			const result = ResolveCost(part, pool, setUsed, depth + 1);
			cost += result.cost;
			setUsed = result.used;
		});
		if (cost < best.cost) {
			best = { cost: cost, used: setUsed };
		}
	}
	return best;
}

// Доплата за улучшение исходного предмета source в target; исходный предмет обязательно входит в сборку.
function UpgradeCost(target, source, pool) {
	const recipe = DATA.recipes[target];
	if (!recipe) return null;
	const rest = recipe.components.slice();
	const index = rest.indexOf(source.name);
	if (index === -1) return null;
	rest.splice(index, 1);
	let used = {};
	used[source.item] = true;
	let cost = recipe.recipe || 0;
	rest.forEach((part) => {
		const result = ResolveCost(part, pool, used, 1);
		cost += result.cost;
		used = result.used;
	});
	return cost;
}

// ---------------------------------------------------------------- герой и инвентарь

function LocalHero() {
	return Players.GetPlayerHeroEntityIndex(Players.GetLocalPlayer());
}

function LocalGold() {
	return Players.GetGold(Players.GetLocalPlayer());
}

// Свои предметы, которые годятся в сборку (как CollectOwnedItems на сервере).
function OwnedItems(hero) {
	const pool = [];
	for (let slot = 0; slot <= POOL_LAST; slot++) {
		const item = Entities.GetItemInSlot(hero, slot);
		if (item === -1 || item === undefined) continue;
		const purchaser = Items.GetPurchaser ? Items.GetPurchaser(item) : hero;
		if (purchaser !== -1 && purchaser !== hero) continue;
		if (Items.IsCombineLocked && Items.IsCombineLocked(item)) continue;
		pool.push({ item: item, name: Abilities.GetAbilityName(item), slot: slot });
	}
	return pool;
}

function HasModifier(unit, name) {
	const count = Entities.GetNumBuffs(unit);
	for (let i = 0; i < count; i++) {
		const buff = Entities.GetBuff(unit, i);
		if (buff !== -1 && Buffs.GetName(unit, buff) === name) return true;
	}
	return false;
}

function CanUpgradeHere(hero) {
	if (hero === -1 || !Entities.IsAlive(hero)) return false;
	if (Players.GetLocalPlayerPortraitUnit() !== hero) return false; // HUD показывает инвентарь другого юнита
	return Entities.IsInRangeOfShop(hero, SHOP_HOME, true) || HasModifier(hero, TAVERN_MODIFIER);
}

// ---------------------------------------------------------------- родные слоты HUD

function IsAlive(panel) {
	return !!panel && (!panel.IsValid || panel.IsValid());
}

function HudRoot() {
	return CONTEXT.FindAncestor ? CONTEXT.FindAncestor("DotaHud") : null;
}

// Кнопка предмета в слоте: inventory_list (0–5) и inventory_backpack_list (6–8), иначе поиск по всему HUD.
function SlotButton(slot) {
	STATE.slotPanels = STATE.slotPanels || {};
	const cached = STATE.slotPanels[slot];
	if (IsAlive(cached)) return cached;
	const hud = HudRoot();
	if (!hud) return null;
	const list = hud.FindChildTraverse(slot <= 5 ? "inventory_list" : "inventory_backpack_list");
	const slotPanel = (list && list.FindChildTraverse("inventory_slot_" + slot)) || hud.FindChildTraverse("inventory_slot_" + slot);
	if (!slotPanel) return null;
	const button = slotPanel.FindChildTraverse("AbilityButton") || slotPanel;
	STATE.slotPanels[slot] = button;
	return button;
}

// Прямоугольник панели в единицах вёрстки этого layout (экранные пиксели / масштаб).
function LayoutRect(panel) {
	if (!IsAlive(panel) || (panel.IsSizeValid && !panel.IsSizeValid())) return null;
	if (!panel.visible || panel.actuallayoutwidth < 4) return null;
	const scale = CONTEXT.actualuiscale_x || 1;
	const pos = panel.GetPositionWithinWindow();
	if (!pos || !isFinite(pos.x) || !isFinite(pos.y)) return null;
	return { x: pos.x / scale, y: pos.y / scale, w: panel.actuallayoutwidth / scale, h: panel.actuallayoutheight / scale };
}

function CursorOver(panel) {
	if (!IsAlive(panel) || !panel.visible || panel.actuallayoutwidth < 4) return false;
	const cursor = GameUI.GetCursorPosition();
	const pos = panel.GetPositionWithinWindow();
	return cursor[0] >= pos.x && cursor[0] <= pos.x + panel.actuallayoutwidth && cursor[1] >= pos.y && cursor[1] <= pos.y + panel.actuallayoutheight;
}

// ---------------------------------------------------------------- плюсики

function PlusPanel(slot) {
	const id = "Plus_" + slot;
	let plus = PLUS_LAYER.FindChild(id);
	if (plus) return plus;
	plus = $.CreatePanel("Button", PLUS_LAYER, id);
	plus.AddClass("UpgradePlus");
	const label = $.CreatePanel("Label", plus, "");
	label.text = "+";
	label.hittest = false;
	plus.SetPanelEvent("onactivate", () => TogglePopup(slot));
	plus.SetPanelEvent("onmouseover", () => $.DispatchEvent("DOTAShowTextTooltip", plus, "Улучшить предмет"));
	plus.SetPanelEvent("onmouseout", () => $.DispatchEvent("DOTAHideTextTooltip", plus));
	return plus;
}

function HidePlus(slot) {
	const plus = PLUS_LAYER.FindChild("Plus_" + slot);
	if (plus) plus.SetHasClass("Shown", false);
}

function HideAll() {
	for (let slot = 0; slot <= INVENTORY_LAST; slot++) HidePlus(slot);
	ClosePopup();
}

// Варианты улучшения предмета в слоте: [{ name, cost }], cost — доплата. По возрастанию полной цены (её видит игрок).
// Только те, на которые хватает золота: нет ни одного — плюсик не показываем.
function SlotOptions(slot, pool, gold) {
	const source = pool.find((entry) => entry.slot === slot);
	if (!source) return [];
	const options = [];
	Upgrades(source.name).forEach((target) => {
		const cost = UpgradeCost(target, source, pool);
		if (cost !== null && cost <= gold) options.push({ name: target, cost: cost });
	});
	options.sort((a, b) => FullPrice(a.name) - FullPrice(b.name) || a.cost - b.cost);
	return options;
}

function Update() {
	const hero = LocalHero();
	if (!CanUpgradeHere(hero)) {
		HideAll();
		return;
	}
	const pool = OwnedItems(hero);
	const gold = LocalGold();

	for (let slot = 0; slot <= INVENTORY_LAST; slot++) {
		const options = SlotOptions(slot, pool, gold);
		const rect = options.length > 0 ? LayoutRect(SlotButton(slot)) : null;
		if (!rect) {
			HidePlus(slot);
			if (STATE.open && STATE.open.slot === slot) ClosePopup();
			continue;
		}
		const plus = PlusPanel(slot);
		plus.SetHasClass("Shown", true);
		plus.SetHasClass("CanAfford", true); // недоступные варианты отфильтрованы, плюсик всегда яркий
		plus.SetHasClass("Open", !!STATE.open && STATE.open.slot === slot);
		plus.style.width = rect.w.toFixed(1) + "px";
		plus.style.marginLeft = rect.x.toFixed(1) + "px";
		plus.style.marginTop = (rect.y - PLUS.height + PLUS.overlap).toFixed(1) + "px";

		if (STATE.open && STATE.open.slot === slot) {
			const item = Entities.GetItemInSlot(hero, slot);
			if (item !== STATE.open.item) {
				ClosePopup();
			} else {
				UpdatePopup(slot, options, gold, rect);
			}
		}
	}
}

// ---------------------------------------------------------------- окно вариантов

function TogglePopup(slot) {
	if (STATE.open && STATE.open.slot === slot) {
		ClosePopup();
		return;
	}
	const hero = LocalHero();
	STATE.open = { slot: slot, item: Entities.GetItemInSlot(hero, slot) };
	STATE.popupKey = null;
	Update();
}

function ClosePopup() {
	if (!STATE.open && !POPUP.BHasClass("Visible")) return;
	STATE.open = null;
	STATE.popupKey = null;
	POPUP.SetHasClass("Visible", false);
	CARET.SetHasClass("Visible", false);
	HIGHLIGHT.SetHasClass("Visible", false);
	CARDS.RemoveAndDeleteChildren();
	for (let slot = 0; slot <= INVENTORY_LAST; slot++) {
		const plus = PLUS_LAYER.FindChild("Plus_" + slot);
		if (plus) plus.SetHasClass("Open", false);
	}
}

// Как в родном магазине: без разделителя разрядов (моноширинный шрифт делает пробел слишком широким).
function FormatGold(value) {
	return String(value);
}

function ItemDisplayName(itemName) {
	return $.Localize("#DOTA_Tooltip_Ability_" + itemName);
}

function ItemDescription(itemName) {
	const item = DATA.items[itemName];
	if (!item || !item.descToken) return "";
	const text = $.Localize(item.descToken);
	return text && text !== item.descToken && text.charAt(0) !== "#" ? text : "";
}

// Хватает золота — заказ на сервер и окно закрывается (результат виден в слоте).
// Не хватает — родная красная ошибка, окно остаётся: можно выбрать другой вариант.
function RequestUpgrade(slot, target, cost) {
	if (cost > LocalGold()) {
		GameEvents.SendEventClientSide("dota_hud_error_message", { splitscreenplayer: 0, reason: 80, message: "Недостаточно золота" });
		return;
	}
	GameEvents.SendCustomGameEventToServer("trinity_shop_upgrade", { slot: slot, item: target, cost: cost });
	ClosePopup();
}

// Карточки перестраиваются только при смене вариантов, цен или золота; позиция — каждый тик.
function UpdatePopup(slot, options, gold, rect) {
	const key = slot + "|" + options.map((o) => o.name + ":" + o.cost + ":" + (o.cost <= gold ? 1 : 0)).join(",");
	if (key !== STATE.popupKey) {
		STATE.popupKey = key;
		RenderCards(slot, options, gold);
	}
	const cols = Columns(options.length);
	const width = cols * CARD.stride + CARD.chrome;
	const screenW = CONTEXT.actuallayoutwidth / (CONTEXT.actualuiscale_x || 1);
	const screenH = CONTEXT.actuallayoutheight / (CONTEXT.actualuiscale_y || 1);
	const left = Math.max(8, Math.min(rect.x + rect.w / 2 - width / 2, screenW - width - 8));
	const bottom = rect.y - PLUS.height + PLUS.overlap - LINK.gap;
	CARDS.style.width = cols * CARD.stride + "px";
	POPUP.style.marginLeft = left.toFixed(1) + "px";
	POPUP.style.marginBottom = Math.max(0, screenH - bottom).toFixed(1) + "px";
	POPUP.SetHasClass("Visible", true);

	// Связь с плюсиком: хвостик окна смотрит в центр плюсика, слот предмета обведён тем же золотом.
	CARET.style.marginLeft = (rect.x + rect.w / 2 - LINK.caret / 2).toFixed(1) + "px";
	CARET.style.marginTop = (bottom - LINK.caret / 2 - 1).toFixed(1) + "px";
	CARET.SetHasClass("Visible", true);
	HIGHLIGHT.style.marginLeft = (rect.x - 2).toFixed(1) + "px";
	HIGHLIGHT.style.marginTop = (rect.y - 2).toFixed(1) + "px";
	HIGHLIGHT.style.width = (rect.w + 4).toFixed(1) + "px";
	HIGHLIGHT.style.height = (rect.h + 4).toFixed(1) + "px";
	HIGHLIGHT.SetHasClass("Visible", true);
}

// Ряды поровну, без пустоты справа: 7 вариантов → 4 + 3, а не 5 + 2. Окно по ширине самого длинного ряда.
function Columns(count) {
	const rows = Math.max(1, Math.ceil(count / CARD.perRow));
	return Math.max(1, Math.ceil(count / rows));
}

function RenderCards(slot, options, gold) {
	CARDS.RemoveAndDeleteChildren();
	const cols = Columns(options.length);
	let row = null;
	options.forEach((option, index) => {
		if (index % cols === 0) {
			// Неполный последний ряд — по центру окна.
			row = $.CreatePanel("Panel", CARDS, "");
			row.AddClass("UpgradeRow");
		}
		const card = $.CreatePanel("Button", row, "");
		card.BLoadLayoutSnippet("UpgradeCard");
		card.SetHasClass("CantAfford", option.cost > gold);
		card.FindChildTraverse("UpgradeName").text = ItemDisplayName(option.name);
		card.FindChildTraverse("UpgradeIcon").itemname = option.name;
		card.FindChildTraverse("UpgradeDesc").text = ItemDescription(option.name);
		// В карточке полная цена предмета, как в магазине. Цвет — по доплате: хватает ли золота на улучшение.
		card.FindChildTraverse("UpgradePriceLabel").text = FormatGold(FullPrice(option.name));

		const buy = () => RequestUpgrade(slot, option.name, option.cost);
		card.SetPanelEvent("onactivate", buy);
		// Наведение на иконку — родной тултип предмета.
		const frame = card.FindChildTraverse("UpgradeIconFrame");
		frame.SetPanelEvent("onactivate", buy);
		frame.SetPanelEvent("onmouseover", () => $.DispatchEvent("DOTAShowAbilityTooltip", frame, option.name));
		frame.SetPanelEvent("onmouseout", () => $.DispatchEvent("DOTAHideAbilityTooltip", frame));
	});
}

// ---------------------------------------------------------------- инициализация (в конце файла)

// Клик мимо окна, его хвостика и его плюсика (левой или правой кнопкой, по миру или по любой панели HUD)
// закрывает окно. Клик по другому плюсику закрывает это окно и открывает окно того слота.
function IsInsidePopup() {
	const plus = STATE.open ? PLUS_LAYER.FindChild("Plus_" + STATE.open.slot) : null;
	return CursorOver(POPUP) || CursorOver(CARET) || CursorOver(plus);
}

function WatchOutsideClick() {
	const down = GameUI.IsMouseDown(0) || GameUI.IsMouseDown(1);
	if (down && !STATE.mouseWasDown && STATE.open && !IsInsidePopup()) {
		ClosePopup();
	}
	STATE.mouseWasDown = down;
}

function Tick() {
	if (STATE.generation !== GENERATION) return;
	try {
		WatchOutsideClick();
		Update();
	} catch (e) {
		$.Msg("[ItemUpgrade] " + e + " " + (e.stack || ""));
	}
	$.Schedule(TICK, Tick);
}

// Esc закрывает окно. Клавиатуру окно не забирает (иначе не работали бы горячие клавиши способностей):
// слушаем «Cancelled», которое HUD рассылает по Esc. Родное действие Esc (отмена прицела и т.п.) тоже выполнится.
if (STATE.escHandle !== undefined && $.UnregisterForUnhandledEvent) {
	$.UnregisterForUnhandledEvent("Cancelled", STATE.escHandle);
}
STATE.escHandle = $.RegisterForUnhandledEvent("Cancelled", () => {
	if (STATE.generation !== GENERATION || !STATE.open) return;
	ClosePopup();
});

// Клики по миру приходят и сюда — мгновенно, без ожидания тика. Клик не поглощается.
GameUI.SetMouseCallback((eventName, arg) => {
	if (STATE.generation !== GENERATION || !STATE.open) return false;
	if (eventName === "pressed" && !IsInsidePopup()) ClosePopup();
	return false;
});

// После горячей перезагрузки убрать плюсики прошлой генерации и сбросить кеш слотов.
PLUS_LAYER.RemoveAndDeleteChildren();
CARDS.RemoveAndDeleteChildren();
POPUP.SetHasClass("Visible", false);
CARET.SetHasClass("Visible", false);
HIGHLIGHT.SetHasClass("Visible", false);
STATE.slotPanels = {};
STATE.mouseWasDown = false;
Tick();
