// Trinity: новый магазин по категориям.
// Куда: Content/panorama/scripts/custom_game/trinity_shop/trinity_shop.js
// Данные: TRINITY_SHOP_DATA из shop_data.js (подключён раньше этого файла в том же layout).
//
// Схема: нативный магазин Доты остаётся (шапка, поиск, сборки, дерево сборки предмета, закреплённые,
// золото). Этот layout встраивается внутрь нативного магазина и в режиме «new» закрывает собой
// нативную сетку предметов. В режиме «old» сетка возвращается.
//
// Всё, что помечено VERIFY, — имена нативных панелей и API, которые надо сверить
// в Panorama debugger и Context7 перед тем, как считать этап готовым (см. README, раздел «Проверить»).

"use strict";

const CONTEXT = $.GetContextPanel();
const CONFIG = GameUI.CustomUIConfig();
const DATA = TRINITY_SHOP_DATA;

// Состояние переживает hot load.
if (!CONFIG.trinityShop) {
	CONFIG.trinityShop = { mode: "new", category: null, sub: null, attr: null, selected: null };
}
const STATE = CONFIG.trinityShop;

// VERIFY: id нативных панелей магазина.
const NATIVE_SHOP_ID = "shop";
const NATIVE_GRID_ID = "GridMainShop";

// ---------------------------------------------------------------- нативный HUD

function GetHudRoot() {
	let panel = CONTEXT;
	while (panel.GetParent()) {
		panel = panel.GetParent();
	}
	return panel;
}

function GetNativeGrid() {
	const shop = GetHudRoot().FindChildTraverse(NATIVE_SHOP_ID);
	return shop ? shop.FindChildTraverse(NATIVE_GRID_ID) : null;
}

// Встроить наш layout на место нативной сетки: тот же родитель, те же размеры.
function AttachToNativeShop() {
	const grid = GetNativeGrid();
	if (!grid) {
		// Магазин ещё не создан — повторить позже.
		$.Schedule(0.5, AttachToNativeShop);
		return;
	}
	const host = grid.GetParent();
	if (CONTEXT.GetParent() !== host) {
		CONTEXT.SetParent(host);
	}
	ApplyMode();
}

// ---------------------------------------------------------------- режимы

function SetShopMode(mode) {
	STATE.mode = mode;
	ApplyMode();
}

function ApplyMode() {
	const isOld = STATE.mode === "old";
	CONTEXT.SetHasClass("ModeOld", isOld);
	$("#ViewNewButton").SetHasClass("Active", !isOld);
	$("#ViewOldButton").SetHasClass("Active", isOld);

	const grid = GetNativeGrid();
	if (grid) {
		grid.style.visibility = isOld ? "visible" : "collapse";
	}
}

// ---------------------------------------------------------------- плашки категорий

function FindCategory(id) {
	return DATA.categories.find((c) => c.id === id) || null;
}

function BuildCategoryGrid() {
	const grid = $("#CategoryGrid");
	grid.RemoveAndDeleteChildren();

	DATA.categories.forEach((category) => {
		const tile = $.CreatePanel("Button", grid, "Category_" + category.id);
		tile.BLoadLayoutSnippet("CategoryTile");
		tile.FindChildTraverse("CategoryArt").SetImage(category.art);
		tile.FindChildTraverse("CategoryName").text = $.Localize(category.token);
		tile.style.backgroundColor = TileGradient(category.accent);
		tile.SetPanelEvent("onactivate", () => OpenCategory(category.id));
	});
}

// Тёмный градиент в тоне категории (в макете: top ≈ accent на 30 %, bottom почти чёрный).
function TileGradient(accent) {
	return "gradient( linear, 0% 0%, 0% 100%, from( " + accent + "55 ), to( #0d0f12 ) )";
}

// ---------------------------------------------------------------- экран категории

function OpenCategory(id) {
	STATE.category = id;
	STATE.sub = null;
	STATE.attr = null;
	STATE.selected = null;
	RenderCategory();
}

function CloseCategory() {
	STATE.category = null;
	RenderCategory();
}

function RenderCategory() {
	const category = FindCategory(STATE.category);
	CONTEXT.SetHasClass("CategoryOpen", !!category);
	if (!category) {
		return;
	}

	$("#CategoryHeaderArt").SetImage(category.art);
	$("#CategoryHeaderName").text = $.Localize(category.token);

	RenderSubcategories(category);
	RenderAttributes();
	RenderItems(category);
}

function RenderSubcategories(category) {
	const row = $("#SubcategoryRow");
	row.RemoveAndDeleteChildren();

	category.subcategories.forEach((sub) => {
		const active = STATE.sub === sub.id;
		const button = $.CreatePanel("Button", row, "Sub_" + sub.id);
		button.BLoadLayoutSnippet("SubcategoryButton");
		button.FindChildTraverse("SubIcon").itemname = sub.icon;
		button.FindChildTraverse("SubName").text = $.Localize(sub.token);

		// У каждой подкатегории свой цвет (макет: неактивна — 38→10 %, активна — 77→2a % и рамка 2px).
		button.style.backgroundColor = "gradient( linear, 0% 0%, 0% 100%, from( " + sub.color + (active ? "77" : "38") + " ), to( " + sub.color + (active ? "2a" : "10") + " ) )";
		button.style.border = active ? "2px solid " + sub.color : "1px solid " + sub.color + "80";

		button.SetPanelEvent("onactivate", () => {
			STATE.sub = active ? null : sub.id;
			STATE.selected = null;
			RenderCategory();
		});
	});
}

function RenderAttributes() {
	const strip = $("#AttributeStrip");
	strip.RemoveAndDeleteChildren();

	DATA.attributes.forEach((attr, index) => {
		const active = STATE.attr === attr.id;
		const segment = $.CreatePanel("Button", strip, "Attr_" + attr.id);
		segment.BLoadLayoutSnippet("AttributeSegment");
		segment.AddClass("Attr_" + attr.id);
		segment.SetHasClass("First", index === 0);
		segment.SetHasClass("Active", active);
		segment.FindChildTraverse("AttrIcon").SetImage(attr.icon);

		segment.SetPanelEvent("onmouseover", () => $.DispatchEvent("DOTAShowTextTooltip", segment, $.Localize(attr.token)));
		segment.SetPanelEvent("onmouseout", () => $.DispatchEvent("DOTAHideTextTooltip"));
		segment.SetPanelEvent("onactivate", () => {
			STATE.attr = active ? null : attr.id;
			STATE.selected = null;
			RenderCategory();
		});
	});
}

function ItemHasAttribute(item, attrId) {
	if (attrId === "multi") {
		return item.attributes.length >= 2;
	}
	return item.attributes.indexOf(attrId) !== -1;
}

function GetVisibleItems(category) {
	const sub = category.subcategories.find((s) => s.id === STATE.sub) || null;

	return Object.keys(DATA.items)
		.filter((name) => {
			const item = DATA.items[name];
			if (item.categories.indexOf(category.id) === -1) return false;
			if (sub && sub.items.indexOf(name) === -1) return false;
			if (STATE.attr && !ItemHasAttribute(item, STATE.attr)) return false;
			return true;
		})
		.sort((a, b) => DATA.items[a].price - DATA.items[b].price || ItemDisplayName(a).localeCompare(ItemDisplayName(b)));
}

// VERIFY: ключ локализации имени предмета (в ванили DOTA_Tooltip_Ability_item_*).
function ItemDisplayName(itemName) {
	return $.Localize("#DOTA_Tooltip_Ability_" + itemName);
}

function RenderItems(category) {
	const list = $("#ItemList");
	list.RemoveAndDeleteChildren();

	const names = GetVisibleItems(category);
	CONTEXT.SetHasClass("NoItems", names.length === 0);

	names.forEach((name) => {
		const item = DATA.items[name];
		const card = $.CreatePanel("Button", list, "Item_" + name);
		card.BLoadLayoutSnippet("ItemCard");
		card.AddClass("Tier" + item.tier);
		card.SetHasClass("Selected", STATE.selected === name);

		card.FindChildTraverse("ItemIcon").itemname = name;
		card.FindChildTraverse("ItemName").text = ItemDisplayName(name);
		card.FindChildTraverse("ItemPriceLabel").text = FormatGold(item.price);
		card.FindChildTraverse("ItemDesc").text = $.Localize(item.descToken);

		// ЛКМ — выбрать (показать дерево сборки), ПКМ — купить, наведение — нативный тултип предмета.
		card.SetPanelEvent("onactivate", () => SelectItem(name));
		card.SetPanelEvent("oncontextmenu", () => BuyItem(name));
		card.SetPanelEvent("onmouseover", () => $.DispatchEvent("DOTAShowAbilityTooltip", card, name));
		card.SetPanelEvent("onmouseout", () => $.DispatchEvent("DOTAHideAbilityTooltip", card));
	});
}

function FormatGold(value) {
	// 5500 → «5 500», как в макете.
	return String(value).replace(/\B(?=(\d{3})+(?!\d))/g, " ");
}

// ---------------------------------------------------------------- действия с предметом

// Выбор предмета должен открыть НАТИВНОЕ дерево сборки внизу магазина (как у родной сетки).
// VERIFY: как программно выбрать предмет в нативном магазине. Варианты, по порядку:
//   1) использовать для иконки карточки панель DOTAShopItem вместо DOTAItemImage — она сама
//      выбирает предмет, показывает дерево, тултип, покупку по ПКМ и перетаскивание;
//   2) найти событие выбора предмета в магазине через Panorama debugger / Context7;
//   3) если ничего не подходит — своё дерево по спецификации из README («Дерево сборки»).
function SelectItem(name) {
	STATE.selected = STATE.selected === name ? null : name;
	const category = FindCategory(STATE.category);
	if (category) {
		RenderItems(category);
	}
}

// VERIFY: формат приказа покупки в Panorama (поле с именем предмета) — сверить в Context7.
function BuyItem(name) {
	Game.PrepareUnitOrders({
		OrderType: dotaunitorder_t.DOTA_UNIT_ORDER_PURCHASE_ITEM,
		UnitIndex: Players.GetLocalPlayerPortraitUnit(),
		ShopItemName: name,
		Queue: false,
	});
}

// ---------------------------------------------------------------- инициализация (в конце файла)

BuildCategoryGrid();
RenderCategory();
AttachToNativeShop();
