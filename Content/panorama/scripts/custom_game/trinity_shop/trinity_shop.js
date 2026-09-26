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

// Состояние переживает hot load. generation обрывает старый опрос поиска после перезагрузки скрипта.
if (!CONFIG.trinityShop) {
	CONFIG.trinityShop = { mode: "new", category: null, sub: null, attr: null, selected: null };
}
const STATE = CONFIG.trinityShop;
STATE.generation = (STATE.generation || 0) + 1;
const GENERATION = STATE.generation;

// Нативный магазин (id сняты в игре):
//   shop → Main → HeightLimiter → HeightLimiterContainer → GridMainShop
//     GridMainShop → SearchAndButtonsContainer (шапка с поиском, остаётся родной)
//                  → GridHeaderAndMainContent (вкладки и сетка: в новом режиме скрываем, на их место встаёт наша панель)
const NATIVE_SHOP_ID = "shop";
const NATIVE_HEADER_ID = "SearchAndButtonsContainer";
const NATIVE_CONTENT_ID = "GridHeaderAndMainContent";

function FindDotaHudPanel(panelId) {
	const hud = CONTEXT.FindAncestor ? CONTEXT.FindAncestor("DotaHud") : null;
	if (!hud || !hud.FindChildTraverse) {
		return null;
	}
	return hud.FindChildTraverse(panelId);
}

function GetNativeShop() {
	return FindDotaHudPanel(NATIVE_SHOP_ID);
}

function GetNativeHeader() {
	const shop = GetNativeShop();
	return shop ? shop.FindChildTraverse(NATIVE_HEADER_ID) : null;
}

function GetNativeContent() {
	const shop = GetNativeShop();
	return shop ? shop.FindChildTraverse(NATIVE_CONTENT_ID) : null;
}

function FindTextEntry(panel) {
	if (!panel || (panel.IsValid && !panel.IsValid())) {
		return null;
	}
	if (panel.paneltype === "TextEntry") {
		return panel;
	}
	const count = panel.GetChildCount ? panel.GetChildCount() : 0;
	for (let i = 0; i < count; i++) {
		const found = FindTextEntry(panel.GetChild(i));
		if (found) {
			return found;
		}
	}
	return null;
}

// Текст только из поля поиска в шапке магазина, а не из любого поля в магазине.
function SearchQuery() {
	const entry = FindTextEntry(GetNativeHeader());
	const text = entry && entry.text ? String(entry.text) : "";
	return text.replace(/^\s+|\s+$/g, "");
}

// Встроить панель в GridHeaderAndMainContent, переключатель вида — в шапку с поиском.
function AttachToNativeShop() {
	if (STATE.generation !== GENERATION) {
		return;
	}
	const content = GetNativeContent();
	const header = GetNativeHeader();
	if (!content || !header) {
		$.Schedule(0.5, AttachToNativeShop);
		return;
	}

	if (CONTEXT.GetParent() !== content) {
		CONTEXT.SetParent(content);
	}
	CONTEXT.style.width = "100%";

	// Переключатель вида: убрать копию от прошлой генерации скрипта, поставить свой.
	// После горячей перезагрузки в шапке остаётся переключатель прошлой генерации: удалить его и перенести новый.
	const toggle = CONTEXT.FindChildTraverse("ViewToggle");
	if (toggle) {
		header.Children().forEach((child) => {
			if (child.id === "ViewToggle" && child !== toggle) {
				child.DeleteAsync(0);
			}
		});
		toggle.SetParent(header);
	}

	AttachBuildTree();
	ApplyMode();
	$.Schedule(0.2, WatchNativeSearch);
}

// Закреплённые предметы скрыты: их дублируют сборки. Ищем все панели магазина с «Pinned» в id
// (сам ряд и его заголовок), кешируем и прячем каждый тик — родной магазин может вернуть видимость.
function HidePinnedItems() {
	const shop = GetNativeShop();
	if (!IsAlive(shop)) return;
	if (!STATE.pinnedPanels || STATE.pinnedPanels.length === 0 || STATE.pinnedPanels.some((p) => !IsAlive(p))) {
		// Предки окна сборки и родного дерева не прятать, даже если в их id есть «Pinned».
		const keep = [];
		[GetNativeCombines(), TREE_PANEL].forEach((panel) => {
			for (let p = panel; IsAlive(p) && p !== shop; p = p.GetParent()) keep.push(p);
		});
		const found = [];
		const walk = (panel, depth) => {
			if (!IsAlive(panel) || depth > 14 || panel === CONTEXT) return;
			if (panel.id && /pinned/i.test(panel.id) && keep.indexOf(panel) === -1) {
				found.push(panel);
				return;
			}
			const n = panel.GetChildCount ? panel.GetChildCount() : 0;
			for (let i = 0; i < n; i++) walk(panel.GetChild(i), depth + 1);
		};
		walk(shop, 0);
		STATE.pinnedPanels = found;
	}
	STATE.pinnedPanels.forEach((panel) => {
		if (panel.style.visibility !== "collapse") panel.style.visibility = "collapse";
	});
}

function GetNativeCombines() {
	const shop = GetNativeShop();
	return shop ? shop.FindChildTraverse("ItemCombines") : null;
}

// Окно сборки — сразу после нативного дерева (под рядом закреплённых предметов), нативное дерево в новом режиме скрыто.
function AttachBuildTree() {
	const combines = GetNativeCombines();
	if (!combines || !TREE_PANEL) {
		return;
	}
	const container = combines.GetParent();
	container.Children().forEach((child) => {
		if (child.id === "BuildTree" && child !== TREE_PANEL) {
			child.DeleteAsync(0);
		}
	});
	if (TREE_PANEL.GetParent() !== container) {
		TREE_PANEL.SetParent(container);
	}
	container.MoveChildAfter(TREE_PANEL, combines);
}

// В новом виде окно сборки видно всегда: без выбранного предмета оно пустое и занимает место родного дерева
// (в классическом виде родное дерево тоже стоит пустым блоком). Иначе магазин короче классического.
function UpdateTreeVisibility() {
	if (!TREE_PANEL) {
		return;
	}
	const showNative = ShowNative();
	TREE_PANEL.style.visibility = showNative ? "collapse" : "visible";
	const close = TreePart("BuildTreeClose");
	if (close) {
		close.style.visibility = STATE.selected ? "visible" : "collapse";
	}
	const combines = GetNativeCombines();
	if (combines) {
		combines.style.visibility = showNative ? "visible" : "collapse";
	}
}

// Высота окна сборки: не ниже родного дерева в классическом виде, чтобы магазин не менял размер.
function TreeReserveHeight() {
	const heights = ClassicHeights();
	return heights.combines > 20 ? Math.round(heights.combines) : 0;
}

function SetTreeHeight(needed) {
	if (!TREE_PANEL) return;
	const height = Math.max(needed || 0, TreeReserveHeight());
	TREE_PANEL.style.height = height > 0 ? height + "px" : null;
}

function WatchNativeSearch() {
	if (STATE.generation !== GENERATION) {
		return;
	}
	try {
		WatchNativeSelection();
	} catch (e) {
		STATE.lastError = "selection: " + e;
	}
	try {
		HidePinnedItems();
	} catch (e) {
		STATE.lastError = "pinned: " + e;
	}
	try {
		WatchShopOpen();
	} catch (e) {
		STATE.lastError = "open: " + e;
	}
	try {
		HeroAttribute(); // запросить заранее, чтобы к открытию категории атрибут уже был известен
		WatchGold();
	} catch (e) {
		STATE.lastError = "gold: " + e;
	}
	const searching = STATE.mode === "new" && SearchQuery() !== "";
	if (CONTEXT.BHasClass("SearchActive") !== searching) {
		CONTEXT.SetHasClass("SearchActive", searching);
		ApplyMode();
	} else {
		UpdateHeight();
	}
	$.Schedule(0.2, WatchNativeSearch);
}

// ---------------------------------------------------------------- открытие магазина: всегда с плашек категорий
// Родной HUD вешает класс ShopOpen на корень HUD (и/или на сам магазин), пока магазин открыт.
// Запасной признак — магазин виден и стоит в пределах экрана (закрытый уезжает за правый край).
function IsShopOpen() {
	const shop = GetNativeShop();
	if (!IsAlive(shop)) return false;
	const hud = CONTEXT.FindAncestor ? CONTEXT.FindAncestor("DotaHud") : null;
	if ((hud && hud.BHasClass("ShopOpen")) || shop.BHasClass("ShopOpen")) return true;
	if (!shop.visible || shop.actuallayoutwidth < 10) return false;
	const pos = shop.GetPositionWithinWindow();
	return pos.x < Game.GetScreenWidth() - 20;
}

function WatchShopOpen() {
	const open = IsShopOpen();
	if (open && STATE.shopOpen === false) {
		// Магазин только что открыли: вернуться на главную панель, выбор предмета сбросить.
		STATE.category = null;
		STATE.sub = null;
		STATE.selected = null;
		RenderCategory();
		RenderBuildTree();
	}
	STATE.shopOpen = open;
}

// ---------------------------------------------------------------- режимы

function SetShopMode(mode) {
	STATE.mode = mode;
	ApplyMode();
}

function ApplyMode() {
	const isOld = STATE.mode === "old";
	const showNative = ShowNative();
	CONTEXT.SetHasClass("ModeOld", isOld);
	if (showNative) {
		// Классический вид и поиск показывают родную сетку — иконки должны быть на своих местах.
		ReturnBorrowed();
	} else if (STATE.category && BorrowRegistry().length === 0) {
		const category = FindCategory(STATE.category);
		if (category) RenderItems(category);
	}

	const newButton = $("#ViewNewButton");
	const oldButton = $("#ViewOldButton");
	if (newButton) newButton.SetHasClass("Active", !isOld);
	if (oldButton) oldButton.SetHasClass("Active", isOld);

	// Нативные вкладки и сетка видны только в классическом режиме и при поиске.
	const content = GetNativeContent();
	if (content) {
		content.Children().forEach((child) => {
			if (child !== CONTEXT) {
				child.style.visibility = showNative ? "visible" : "collapse";
			}
		});
	}
	CONTEXT.style.visibility = showNative ? "collapse" : "visible";
	UpdateTreeVisibility();
	UpdateHeight();
}

// Родная сетка видна: классический вид, поиск или разовый замер высоты классического магазина.
function ShowNative() {
	return STATE.mode === "old" || CONTEXT.BHasClass("SearchActive") || !!STATE.measuring;
}

// ---------------------------------------------------------------- высота как у классического магазина
// Новый вид стоит на месте родных вкладок и сетки (GridHeaderAndMainContent), а окно сборки — на месте родного
// дерева (ItemCombines). Поэтому в классическом виде запоминаем высоту этих двух панелей и в новом виде задаём
// ровно такие же: магазин целиком получается того же размера, без подгонки по кадрам.
// Если классический вид ещё не открывали — один раз на кадр показываем родную сетку и меряем.

function PanelHeight(panel) {
	return panel.actuallayoutheight / (panel.actualuiscale_y || 1);
}

function ClassicHeights() {
	// Смена разрешения — старые замеры не годятся. Ключ classicSize: у прежнего формата (Main/HeightLimiter) другие поля.
	const screen = Game.GetScreenHeight();
	if (!STATE.classicSize || STATE.classicSize.screen !== screen) {
		STATE.classicSize = { screen: screen, heights: {} };
	}
	return STATE.classicSize.heights;
}

// В классическом виде запоминаем максимум (вкладки родной сетки бывают разной высоты).
function RememberClassicHeight() {
	const heights = ClassicHeights();
	const content = GetNativeContent();
	if (IsAlive(content)) {
		const h = PanelHeight(content);
		if (h > 100 && h > (heights.content || 0)) heights.content = h;
	}
	const combines = GetNativeCombines();
	if (IsAlive(combines) && combines.visible) {
		const h = PanelHeight(combines);
		if (h > 20 && h > (heights.combines || 0)) heights.combines = h;
	}
}

function MeasureClassicHeight() {
	if (STATE.measuring || STATE.mode !== "new") return;
	const shop = GetNativeShop();
	if (!IsAlive(shop) || PanelHeight(shop) < 50) return; // магазин ещё не разложен
	STATE.measuring = true;
	ApplyMode();
	$.Schedule(0.1, () => {
		if (STATE.generation !== GENERATION) return;
		RememberClassicHeight();
		STATE.measuring = false;
		STATE.measured = !!ClassicHeights().content;
		ApplyMode();
	});
}

function UpdateHeight() {
	if (ShowNative()) {
		if (STATE.mode === "old" && !CONTEXT.BHasClass("SearchActive")) RememberClassicHeight();
		return;
	}

	const heights = ClassicHeights();
	if (!heights.content) {
		if (!STATE.measured) MeasureClassicHeight();
		// Пока замера нет — всё место под шапкой в HeightLimiter.
		const shop = GetNativeShop();
		const limiter = shop ? shop.FindChildTraverse("HeightLimiter") : null;
		const header = GetNativeHeader();
		const start = limiter && header ? Math.floor(PanelHeight(limiter) - PanelHeight(header)) : 0;
		CONTEXT.style.height = (start > 50 ? start : 600) + "px";
		return;
	}
	const height = Math.round(heights.content) + "px";
	if (CONTEXT.style.height !== height) CONTEXT.style.height = height;
	if (!STATE.selected) SetTreeHeight(0);
}

// ---------------------------------------------------------------- плашки категорий

function FindCategory(id) {
	return DATA.categories.find((c) => c.id === id) || null;
}

function BuildCategoryGrid() {
	const grid = $("#CategoryGrid");
	grid.RemoveAndDeleteChildren();

	// 3 ряда по 2 плашки: ряды делят высоту поровну, плашки — ширину ряда (проценты в Panorama не учитывают отступы).
	let row = null;
	DATA.categories.forEach((category, index) => {
		if (index % 2 === 0) {
			row = $.CreatePanel("Panel", grid, "");
			row.AddClass("CategoryRow");
		}
		const tile = $.CreatePanel("Button", row, "Category_" + category.id);
		tile.BLoadLayoutSnippet("CategoryTile");
		tile.FindChildTraverse("CategoryArt").SetImage(category.art);
		tile.FindChildTraverse("CategoryName").text = $.Localize(category.token);
		tile.style.backgroundColor = TileGradient(category.accent);
		tile.SetPanelEvent("onactivate", () => OpenCategory(category.id));
	});
}

// Тёмный градиент в тоне категории (в макете: top ≈ accent на 30 %, bottom почти чёрный).
function TileGradient(accent) {
	return "gradient( linear, 0% 0%, 0% 100%, from( " + accent + "40 ), to( #0d0f12 ) )";
}

// ---------------------------------------------------------------- экран категории

function OpenCategory(id) {
	STATE.category = id;
	STATE.sub = null;
	// Порядок по умолчанию задаёт вес предмета для героя (hero_item_weights.js), поэтому атрибут героя
	// сам не включается: иначе предметы со статом встали бы выше самых востребованных. Статы всё равно запрашиваем.
	HeroAttribute();
	STATE.attr = null;
	STATE.attrTouched = true;
	STATE.selected = null;
	RenderCategory();
}

// ---------------------------------------------------------------- основной атрибут героя
// В Panorama API нет основного атрибута героя: спрашиваем сервер (game_managers/trinity_shop.lua).

function LocalHero() {
	return Players.GetPlayerHeroEntityIndex(Players.GetLocalPlayer());
}

// Атрибут текущего героя ("str" | "agi" | "int" | "multi") или null, пока сервер не ответил.
// Тем же запросом сервер присылает статы предметов магазина из KV (для сортировки по стату).
function HeroAttribute() {
	const hero = LocalHero();
	if (hero === -1) return null;
	const known = STATE.heroAttr && STATE.heroAttr.hero === hero ? STATE.heroAttr.attr : null;
	if (known && STATE.itemStats) return known;
	// Повторный запрос не чаще раза в 2 с (ответ мог потеряться, герой мог смениться).
	const now = Game.GetGameTime();
	if (!STATE.heroAttrAsked || STATE.heroAttrAsked.hero !== hero || now - STATE.heroAttrAsked.time > 2) {
		STATE.heroAttrAsked = { hero: hero, time: now };
		GameEvents.SendCustomGameEventToServer("trinity_shop_hero_attr_request", {
			items: STATE.itemStats ? "" : Object.keys(DATA.items).join(","),
		});
	}
	return known;
}

function OnHeroAttribute(event) {
	if (STATE.generation !== GENERATION) return;
	let resort = false;
	if (event.stats && !STATE.itemStats) {
		const stats = {};
		Object.keys(event.stats).forEach((name) => {
			const s = event.stats[name];
			stats[name] = { str: Number(s.str) || 0, agi: Number(s.agi) || 0, int: Number(s.int) || 0, all: Number(s.all) || 0 };
		});
		STATE.itemStats = stats;
		resort = true;
	}
	const hero = Number(event.hero);
	if (hero === LocalHero() && event.attr) {
		const changed = !STATE.heroAttr || STATE.heroAttr.hero !== hero || STATE.heroAttr.attr !== event.attr;
		STATE.heroAttr = { hero: hero, attr: event.attr };
		// Игрок сам не трогал сортировку — применить атрибут героя к открытой категории.
		if (changed && STATE.category && !STATE.attrTouched && STATE.attr !== event.attr) {
			STATE.attr = event.attr;
			resort = true;
		}
	}
	if (resort && STATE.category) RenderCategory();
}

// ---------------------------------------------------------------- золото: доступные предметы сверху

function LocalGold() {
	return Players.GetGold(Players.GetLocalPlayer());
}

// Какие из видимых предметов сейчас по карману. Меняется — список пересобирается (доступные уходят наверх).
function AffordKey(names, gold) {
	return names.filter((name) => DATA.items[name].price <= gold).join(",");
}

function WatchGold() {
	const category = FindCategory(STATE.category);
	const showNative = ShowNative();
	// Во время перетаскивания карточку не пересоздаём — иначе бросок потеряется.
	if (!category || showNative || STATE.dragging || STATE.measuring) return;
	if (AffordKey(GetVisibleItems(category), LocalGold()) !== STATE.affordKey) {
		RenderItems(category);
	}
}

function CloseCategory() {
	STATE.category = null;
	STATE.selected = null;
	RenderCategory();
}

function RenderCategory() {
	const category = FindCategory(STATE.category);
	CONTEXT.SetHasClass("CategoryOpen", !!category);
	if (!category) {
		ReturnBorrowed();
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
	// 3 подкатегории — три узкие кнопки в ряд (CSS .ThreeSubs), 2 — как раньше, по половине.
	row.SetHasClass("ThreeSubs", category.subcategories.length === 3);

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
			STATE.attrTouched = true;
			STATE.selected = null;
			RenderCategory();
		});
	});
}

// Сколько выбранного стата даёт предмет. Числа — из KV игры (присылает сервер, STATE.itemStats);
// пока их нет — только признак из shop_data.js (1 = «даёт», 0 = «не даёт»).
// multi: предмет с 2+ статами, величина — их сумма.
function ItemStatAmount(name, attrId) {
	// Сервер присылает только предметы со статами: отсутствующий в ответе = статов нет.
	const stats = STATE.itemStats ? STATE.itemStats[name] || {} : null;
	if (stats) {
		const all = stats.all || 0;
		const str = (stats.str || 0) + all;
		const agi = (stats.agi || 0) + all;
		const int = (stats.int || 0) + all;
		if (attrId === "multi") {
			const count = (str > 0 ? 1 : 0) + (agi > 0 ? 1 : 0) + (int > 0 ? 1 : 0);
			return count >= 2 ? str + agi + int : 0;
		}
		return attrId === "str" ? str : attrId === "agi" ? agi : attrId === "int" ? int : 0;
	}
	const attributes = DATA.items[name].attributes;
	if (attrId === "multi") return attributes.length >= 2 ? 1 : 0;
	return attributes.indexOf(attrId) !== -1 ? 1 : 0;
}

// Вес предмета для героя игрока: винрейт × пикрейт по Dotabuff (hero_item_weights.js). Нет данных — 0.
function HeroWeights() {
	const table = typeof TRINITY_HERO_ITEM_WEIGHTS !== "undefined" ? TRINITY_HERO_ITEM_WEIGHTS : null;
	if (!table) return null;
	const heroName = Players.GetPlayerSelectedHero(Players.GetLocalPlayer());
	return table[heroName] || null;
}

// Порядок в категории (золото на порядок не влияет — только блеклость карточки):
//  1) если выбран атрибут — сначала предметы с этим статом;
//  2) по весу предмета для героя, от самых востребованных;
//  3) без веса (или у героя нет таблицы) — по цене от дешёвых, при равной цене больше выбранного стата выше; затем по имени.
function GetVisibleItems(category) {
	const sub = category.subcategories.find((s) => s.id === STATE.sub) || null;
	const attr = STATE.attr;
	const amount = (name) => (attr ? ItemStatAmount(name, attr) : 0);
	const weights = HeroWeights() || {};
	const weight = (name) => weights[name] || 0;

	return Object.keys(DATA.items)
		.filter((name) => {
			if (DATA.items[name].categories.indexOf(category.id) === -1) return false;
			if (sub && sub.items.indexOf(name) === -1) return false;
			return true;
		})
		.sort((a, b) => {
			const statA = amount(a);
			const statB = amount(b);
			if ((statA > 0) !== (statB > 0)) return statA > 0 ? -1 : 1;
			const weightDiff = weight(b) - weight(a);
			if (weightDiff !== 0) return weightDiff;
			const priceDiff = DATA.items[a].price - DATA.items[b].price;
			if (priceDiff !== 0) return priceDiff;
			return statB - statA || CompareText(ItemDisplayName(a), ItemDisplayName(b));
		});
}

// localeCompare в Panorama падает с ошибкой ICU — сравниваем строки напрямую.
function CompareText(a, b) {
	return a < b ? -1 : a > b ? 1 : 0;
}

// VERIFY: ключ локализации имени предмета (в ванили DOTA_Tooltip_Ability_item_*).
function ItemDisplayName(itemName) {
	return $.Localize("#DOTA_Tooltip_Ability_" + itemName);
}

function RenderItems(category) {
	const list = $("#ItemList");
	ReturnBorrowed();
	list.RemoveAndDeleteChildren();
	STATE.iconStats = { native: 0, own: 0 };

	const names = GetVisibleItems(category);
	const gold = LocalGold();
	STATE.affordKey = AffordKey(names, gold);
	CONTEXT.SetHasClass("NoItems", names.length === 0);

	names.forEach((name) => {
		const item = DATA.items[name];
		// Карточка — обычная панель: иконка (нативная DOTAShopItem) не должна лежать внутри кнопки,
		// иначе кнопка перехватывает перетаскивание. Кнопка — только текстовая часть (ItemText).
		const card = $.CreatePanel("Panel", list, "Item_" + name);
		card.BLoadLayoutSnippet("ItemCard");
		card.AddClass(TierClass(item));
		card.SetHasClass("Selected", STATE.selected === name);
		card.SetHasClass("CantAfford", item.price > gold);

		SetupItemIcon(card, name);
		card.FindChildTraverse("ItemName").text = ItemDisplayName(name);
		card.FindChildTraverse("ItemPriceLabel").text = FormatGold(item.price);
		card.FindChildTraverse("ItemDesc").text = $.Localize(item.descToken);

		// Текст: ЛКМ — выбрать (окно сборки), ПКМ — купить, наведение — нативный тултип.
		const text = card.FindChildTraverse("ItemText");
		text.SetPanelEvent("onactivate", () => OnItemActivate(name));
		// Перетаскивание с любой точки карточки: и с фона/иконки (card), и с текстовой кнопки.
		MakeDraggable(card, name);
		MakeDraggable(text, name);
		// Правый клик забирают дочерние элементы — вешаем покупку на все части текста.
		[text, card.FindChildTraverse("ItemName"), card.FindChildTraverse("ItemDesc"), card.FindChildTraverse("ItemPriceLabel")].forEach((panel) => {
			if (panel) {
				panel.hittest = true;
				panel.SetPanelEvent("oncontextmenu", () => BuyItem(name));
			}
		});
		text.SetPanelEvent("onmouseover", () => $.DispatchEvent("DOTAShowAbilityTooltip", text, name));
		text.SetPanelEvent("onmouseout", () => $.DispatchEvent("DOTAHideAbilityTooltip", text));
	});
}

// ---------------------------------------------------------------- родные иконки из нативной сетки
// Перетаскивание в быструю покупку/инвентарь/тайник, ПКМ и Shift-клик работают только у иконок, созданных
// родным магазином. Поэтому на время показа карточки переносим родную иконку из скрытой сетки в карточку,
// а перед перерисовкой возвращаем на прежнее место. Реестр — в CustomUIConfig, чтобы пережить hot load.

function BorrowRegistry() {
	if (!CONFIG.trinityShopBorrowed) {
		CONFIG.trinityShopBorrowed = [];
	}
	return CONFIG.trinityShopBorrowed;
}

function IsAlive(panel) {
	return !!panel && (!panel.IsValid || panel.IsValid());
}

function ChildIndex(parent, child) {
	if (parent.GetChildIndex) {
		return parent.GetChildIndex(child);
	}
	const children = parent.Children();
	for (let i = 0; i < children.length; i++) {
		if (children[i] === child) return i;
	}
	return -1;
}

// Вернуть одолженные иконки в обратном порядке — так индексы в родителях восстанавливаются точно.
// kind = "tree" возвращает только иконки окна сборки (они всегда одалживаются последними, после карточек).
function ReturnBorrowed(kind) {
	const registry = BorrowRegistry();
	while (registry.length > 0) {
		const entry = registry[registry.length - 1];
		if (kind && entry.kind !== kind) break;
		registry.pop();
		if (!IsAlive(entry.panel) || !IsAlive(entry.parent)) continue;
		entry.panel.SetParent(entry.parent);
		const sibling = entry.parent.GetChild(entry.index);
		if (sibling && sibling !== entry.panel) {
			entry.parent.MoveChildBefore(entry.panel, sibling);
		}
		entry.panel.style.width = null;
		entry.panel.style.height = null;
		entry.panel.style.horizontalAlign = null;
	}
}

function IsBorrowed(name) {
	return BorrowRegistry().some((entry) => entry.name === name);
}

// Перенести родную иконку предмета в target; null, если в сетке её нет или она уже занята.
function BorrowNative(name, target, before, kind) {
	if (IsBorrowed(name)) return null;
	const native = FindNativeShopItem(NativeGridRoot(), name);
	if (!native) return null;
	const parent = native.GetParent();
	BorrowRegistry().push({ panel: native, parent: parent, index: ChildIndex(parent, native), kind: kind, name: name });
	native.SetParent(target);
	if (before) target.MoveChildBefore(native, before);
	return native;
}

// У родной DOTAShopItem имя предмета не в ней самой, а во вложенной картинке DOTAItemImage.
function ShopItemName(panel) {
	if (panel.itemname) return panel.itemname;
	const count = panel.GetChildCount ? panel.GetChildCount() : 0;
	for (let i = 0; i < count; i++) {
		const child = panel.GetChild(i);
		if (!IsAlive(child)) continue;
		if (child.paneltype === "DOTAItemImage" && child.itemname) return child.itemname;
		const nested = ShopItemName(child);
		if (nested) return nested;
	}
	return "";
}

function FindNativeShopItem(panel, name) {
	if (!IsAlive(panel) || panel === CONTEXT) return null;
	if (panel.paneltype === "DOTAHUDShopSearchResults") return null; // результаты поиска не трогаем
	if (panel.paneltype === "DOTAShopItem") {
		return ShopItemName(panel) === name ? panel : null;
	}
	const count = panel.GetChildCount ? panel.GetChildCount() : 0;
	for (let i = 0; i < count; i++) {
		const found = FindNativeShopItem(panel.GetChild(i), name);
		if (found) return found;
	}
	return null;
}

// Искать только в нативной сетке (не в сборках, закреплённых и быстрой покупке).
function NativeGridRoot() {
	const content = GetNativeContent();
	return content ? content.FindChildTraverse("GridMainContent") : null;
}

function SetupItemIcon(card, name) {
	// Обычная картинка: одалживание родных иконок ломало классический магазин (родной магазин прячет их по своим правилам).
	card.FindChildTraverse("ItemIcon").itemname = name;
}

// ---------------------------------------------------------------- быстрая покупка и перетаскивание

// ---------------------------------------------------------------- быстрая покупка (родная)
// Событие dota_set_quick_buy из интерфейса игра не принимает, поэтому работаем через родные иконки скрытой сетки:
//  - Shift-клик: шлём родной иконке «нажатие» — игрок держит Shift, родной магазин сам добавляет предмет;
//  - бросок на родную быструю покупку: шлём ей родной «бросок» родной иконки.
function SetQuickBuy(name, dropPanel) {
	if (!name || name.indexOf("item_recipe_") === 0) return;
	const native = FindNativeShopItem(NativeGridRoot(), name);
	if (!native) {
		STATE.lastDrop = "quickbuy " + name + ": нет родной иконки";
		return;
	}
	if (dropPanel) {
		$.DispatchEvent("DragDrop", dropPanel, native);
		STATE.lastDrop = "quickbuy " + name + ": drop на #" + dropPanel.id;
	} else {
		$.DispatchEvent("Activated", native, "mouse");
		STATE.lastDrop = "quickbuy " + name + ": click shift=" + GameUI.IsShiftDown();
	}
}

// ---------------------------------------------------------------- бросок в сборку (GuideFlyout)
// Родная сборка принимает только родные иконки магазина: шлём самой глубокой панели сборки под курсором
// родной «бросок» родной иконки из скрытой сетки — как при перетаскивании в классическом магазине.
function GetGuideFlyout() {
	const shop = GetNativeShop();
	return shop ? shop.FindChildTraverse("GuideFlyout") : null;
}

function DeepestPanelAtCursor(root) {
	let best = CursorOver(root) ? root : null;
	const walk = (panel, depth) => {
		if (!IsAlive(panel) || depth > 16) return;
		const n = panel.GetChildCount ? panel.GetChildCount() : 0;
		for (let i = 0; i < n; i++) {
			const child = panel.GetChild(i);
			if (CursorOver(child)) {
				best = child;
				walk(child, depth + 1);
			}
		}
	};
	if (best) walk(root, 0);
	return best;
}

function AddToGuide(name, guide) {
	if (!name || name.indexOf("item_recipe_") === 0) return;
	const native = FindNativeShopItem(NativeGridRoot(), name);
	if (!native) {
		STATE.lastDrop = "guide " + name + ": нет родной иконки";
		return;
	}
	const target = DeepestPanelAtCursor(guide) || guide;
	// Родная сборка ждёт полный цикл перетаскивания: вход, бросок.
	$.DispatchEvent("DragEnter", target, native);
	$.DispatchEvent("DragDrop", target, native);
	STATE.lastDrop = "guide " + name + ": drop на #" + (target.id || target.paneltype);
}

// Панели HUD, на которые можно бросить предмет. Id ищем по шаблону один раз и кешируем.
const DROP_TARGETS = [
	{ kind: "quickbuy", pattern: /quick\s*buy/i },
	{ kind: "stash", pattern: /stash/i },
	{ kind: "inventory", pattern: /^inventory/i },
];

function CollectDropPanels() {
	const hud = CONTEXT.FindAncestor ? CONTEXT.FindAncestor("DotaHud") : null;
	const found = [];
	const walk = (panel, depth) => {
		if (!IsAlive(panel) || depth > 14 || panel === CONTEXT) return;
		const id = panel.id || "";
		DROP_TARGETS.forEach((target) => {
			if (id && target.pattern.test(id)) found.push({ kind: target.kind, panel: panel, id: id });
		});
		const n = panel.GetChildCount ? panel.GetChildCount() : 0;
		for (let i = 0; i < n; i++) walk(panel.GetChild(i), depth + 1);
	};
	if (hud) walk(hud, 0);
	return found;
}

function CursorOver(panel) {
	if (!IsAlive(panel) || !panel.visible || panel.actuallayoutwidth < 4) return false;
	const cursor = GameUI.GetCursorPosition();
	const pos = panel.GetPositionWithinWindow();
	return cursor[0] >= pos.x && cursor[0] <= pos.x + panel.actuallayoutwidth && cursor[1] >= pos.y && cursor[1] <= pos.y + panel.actuallayoutheight;
}

function DropTargetAtCursor() {
	const cursor = GameUI.GetCursorPosition();
	if (!STATE.dropPanels || STATE.dropPanels.some((t) => !IsAlive(t.panel))) {
		STATE.dropPanels = CollectDropPanels();
	}
	// Самая маленькая панель под курсором — самая точная.
	let best = null;
	STATE.dropPanels.forEach((target) => {
		const panel = target.panel;
		if (!panel.visible || panel.actuallayoutwidth < 4) return;
		const pos = panel.GetPositionWithinWindow();
		const w = panel.actuallayoutwidth;
		const h = panel.actuallayoutheight;
		if (cursor[0] >= pos.x && cursor[0] <= pos.x + w && cursor[1] >= pos.y && cursor[1] <= pos.y + h) {
			if (!best || w * h < best.area) best = { kind: target.kind, id: target.id, panel: panel, area: w * h };
		}
	});
	return best;
}

// Перетаскивание с любой части карточки/узла: иконка едет за курсором; бросок на быструю покупку ставит её туда,
// на инвентарь или тайник — покупает.
function MakeDraggable(panel, name) {
	panel.SetDraggable(true);
	$.RegisterEventHandler("DragStart", panel, (panelId, settings) => {
		const image = $.CreatePanel("DOTAItemImage", CONTEXT, "");
		image.itemname = name;
		image.style.width = "55px";
		image.style.height = "40px";
		image.hittest = false;
		settings.displayPanel = image;
		settings.offsetX = 27;
		settings.offsetY = 20;
		settings.removePositionBeforeDrop = false;
		STATE.dragging = true;
		return true;
	});
	$.RegisterEventHandler("DragEnd", panel, (panelId, displayPanel) => {
		STATE.dragging = false;
		// Бросок на колонку сборок — правка сборки, а не покупка.
		const guide = GetGuideFlyout();
		if (CursorOver(guide)) {
			if (displayPanel && displayPanel.DeleteAsync) displayPanel.DeleteAsync(0);
			AddToGuide(name, guide);
			return true;
		}
		const target = DropTargetAtCursor();
		STATE.lastDrop = name + " → " + (target ? target.kind + " #" + target.id : "мимо");
		if (displayPanel && displayPanel.DeleteAsync) displayPanel.DeleteAsync(0);
		if (!target) return true;
		if (target.kind === "quickbuy") {
			SetQuickBuy(name, target.panel);
		} else {
			BuyItem(name);
		}
		return true;
	});
}

// Левый клик: с Shift — в быструю покупку, без — выбрать (окно сборки).
function OnItemActivate(name) {
	if (GameUI.IsShiftDown()) {
		SetQuickBuy(name);
		return;
	}
	SelectItem(name);
}

// Цвет угла карточки: ценовая категория из shop_data.js, а у предметов без неё (tier -1, ванильная цена) —
// по ближайшей ценовой полосе; дешёвые базовые предметы — нейтральный серый.
function TierClass(item) {
	if (item.tier >= 0) return "Tier" + item.tier;
	if (item.price < 1000) return "TierBase";
	const tiers = DATA.tiers;
	for (let i = 0; i < tiers.length; i++) {
		if (item.price <= tiers[i].price) return "Tier" + i;
	}
	return "Tier" + (tiers.length - 1);
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
function FindPanelByItemName(panel, itemName, skip) {
	if (!panel || panel === skip || (panel.IsValid && !panel.IsValid())) {
		return null;
	}
	if (panel.itemname === itemName) {
		return panel;
	}
	const count = panel.GetChildCount ? panel.GetChildCount() : 0;
	for (let i = 0; i < count; i++) {
		const found = FindPanelByItemName(panel.GetChild(i), itemName, skip);
		if (found) {
			return found;
		}
	}
	return null;
}

// Предмет, выбранный в родном магазине (клик в сборках, в поиске, в классическом виде): центральный предмет
// родного дерева сборки. Берём самую крупную иконку в нём; если размеры неизвестны (дерево скрыто) —
// тот предмет, для которого все остальные — его части или то, во что он собирается.
function NativeSelectedItem() {
	const combines = GetNativeCombines();
	if (!IsAlive(combines)) return null;
	const found = [];
	const walk = (panel, depth) => {
		if (!IsAlive(panel) || depth > 10) return;
		if (panel.paneltype === "DOTAItemImage" && panel.itemname) {
			found.push({ name: panel.itemname, area: panel.actuallayoutwidth * panel.actuallayoutheight });
		}
		const n = panel.GetChildCount ? panel.GetChildCount() : 0;
		for (let i = 0; i < n; i++) walk(panel.GetChild(i), depth + 1);
	};
	walk(combines, 0);
	if (found.length === 0) return null;

	const sorted = found.slice().sort((a, b) => b.area - a.area);
	if (sorted[0].area > 0 && (sorted.length === 1 || sorted[0].area > sorted[1].area)) {
		return sorted[0].name;
	}
	const names = found.map((f) => f.name).filter((n, i, all) => all.indexOf(n) === i);
	const center = names.find((candidate) => {
		const parts = TreeParts(candidate);
		const ups = BUILDS_INTO[candidate] || [];
		return names.every((other) => other === candidate || parts.indexOf(other) !== -1 || ups.indexOf(other) !== -1);
	});
	return center || null;
}

// Клик по родной иконке в сборках, поиске, закреплённых: вешаем свой обработчик рядом с родным (родной не заменяем).
const NATIVE_CLICK_SOURCES = ["GuideFlyout", "PinnedItems", "GridMainContent", "ItemCombines"];
function HookNativeItemClicks() {
	const shop = GetNativeShop();
	if (!IsAlive(shop)) return;
	const roots = NATIVE_CLICK_SOURCES.map((id) => shop.FindChildTraverse(id));
	const walkForSearch = (panel, depth) => {
		if (!IsAlive(panel) || depth > 12 || panel === CONTEXT) return;
		if (panel.paneltype === "DOTAHUDShopSearchResults") {
			roots.push(panel);
			return;
		}
		const n = panel.GetChildCount ? panel.GetChildCount() : 0;
		for (let i = 0; i < n; i++) walkForSearch(panel.GetChild(i), depth + 1);
	};
	walkForSearch(shop, 0);

	let hooked = 0;
	const hook = (panel, depth) => {
		if (!IsAlive(panel) || depth > 12) return;
		if (panel.paneltype === "DOTAShopItem") {
			if (panel.GetAttributeString("trinity_hooked", "") !== String(GENERATION)) {
				panel.SetAttributeString("trinity_hooked", String(GENERATION));
				$.RegisterEventHandler("Activated", panel, () => {
					if (STATE.generation !== GENERATION) return;
					const name = ShopItemName(panel);
					if (GameUI.IsShiftDown()) return; // родной Shift-клик сам кладёт предмет в быструю покупку
					STATE.nativeSelected = "click " + name;
					if (name && name !== STATE.selected) ShowInBuildTree(name);
				});
			}
			hooked++;
			return;
		}
		const n = panel.GetChildCount ? panel.GetChildCount() : 0;
		for (let i = 0; i < n; i++) hook(panel.GetChild(i), depth + 1);
	};
	roots.forEach((root) => hook(root, 0));
	STATE.hookedCount = hooked + " in " + roots.filter(IsAlive).length + " roots";
}

function WatchNativeSelection() {
	if (!STATE.hookTick || STATE.hookTick-- <= 0) {
		STATE.hookTick = 3;
		HookNativeItemClicks();
	}
	const name = NativeSelectedItem();
	if (name) STATE.nativeSelected = name;
	// Сразу после нашего выбора родное дерево ещё может показывать прежний предмет — пару тиков не реагируем.
	if (STATE.nativeMute > 0) {
		STATE.nativeMute--;
		STATE.lastNativeSelected = name;
		return;
	}
	if (!name || name === STATE.lastNativeSelected) return;
	STATE.lastNativeSelected = name;
	if (name !== STATE.selected) {
		ShowInBuildTree(name);
	}
}

// Показать предмет в окне сборки без переключения (повторный выбор не снимает его).
function ShowInBuildTree(name) {
	STATE.selected = name;
	$("#ItemList").Children().forEach((card) => {
		card.SetHasClass("Selected", card.id === "Item_" + name);
	});
	RenderBuildTree();
}

function SelectItem(name) {
	STATE.selected = name && STATE.selected !== name ? name : null;
	STATE.nativeMute = 3;
	// Список не перестраиваем: иначе родные иконки возвращаются в сетку и тут же одалживаются снова,
	// после такого двойного переноса движок оставляет иконку пустой. Только переключаем подсветку.
	$("#ItemList").Children().forEach((card) => {
		card.SetHasClass("Selected", card.id === "Item_" + STATE.selected);
	});
	RenderBuildTree();
	if (!name || STATE.selected !== name) {
		return;
	}
	const shop = GetNativeShop();
	const nativeItem = shop ? FindPanelByItemName(shop, name, CONTEXT) : null;
	if (nativeItem) {
		$.DispatchEvent("Activated", nativeItem);
	}
}

// ---------------------------------------------------------------- виджет сборки

// Окно сборки живёт под закреплёнными предметами (в нативном ItemCombinesAndBasicItemsContainer),
// поэтому ищем его панели через сохранённую ссылку, а не через $() контекста.
const TREE_PANEL = CONTEXT.FindChildTraverse("BuildTree");
function TreePart(id) {
	return TREE_PANEL ? TREE_PANEL.FindChildTraverse(id) : null;
}

// Сборка слева направо: компоненты и рецепт → предмет → во что собирается.
// Узлы групп — колонками у центра (не больше maxRows в колонке), gap — место под линии у центрального предмета.
const TREE = { itemW: 60, itemH: 44, nodeW: 48, nodeH: 35, step: 8, gap: 56, maxRows: 4, padding: 26, fallbackWidth: 495 };

// «Во что собирается»: обратный индекс по components, строится один раз.
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

function TreeParts(name) {
	const recipe = DATA.recipes[name];
	if (!recipe) {
		return [];
	}
	const parts = recipe.components.slice();
	if (recipe.recipe > 0) {
		parts.push("item_recipe_" + name.replace(/^item_/, ""));
	}
	return parts;
}

// Узел в точке (x, y) — центр иконки, в координатах холста. Слои TreeUpRow/TreeItemRow/TreeCompRow — на весь холст без потока.
function AddTreeNode(layer, x, y, itemName, small, clickable, buyable) {
	// Панели создаются вне нашего layout (окно перенесено в нативный магазин), CSS-классы на них не действуют — стили inline.
	const width = small ? TREE.nodeW : TREE.itemW;
	const height = small ? TREE.nodeH : TREE.itemH;

	const node = $.CreatePanel("Button", layer, "");
	node.style.width = width + "px";
	node.style.height = height + "px";
	node.style.marginLeft = (x - width / 2).toFixed(1) + "px";
	node.style.marginTop = (y - height / 2).toFixed(1) + "px";
	node.style.border = "1px solid #000000";
	node.style.backgroundColor = "#000000";
	const image = $.CreatePanel("DOTAItemImage", node, "");
	image.itemname = itemName;
	image.hittest = false;
	image.style.width = "100%";
	image.style.height = "100%";

	node.SetPanelEvent("onmouseover", () => $.DispatchEvent("DOTAShowAbilityTooltip", node, itemName));
	node.SetPanelEvent("onmouseout", () => $.DispatchEvent("DOTAHideAbilityTooltip", node));
	if (clickable) {
		node.SetPanelEvent("onactivate", () => OnItemActivate(itemName));
	} else {
		node.SetPanelEvent("onactivate", () => { if (GameUI.IsShiftDown()) SetQuickBuy(itemName); });
	}
	if (itemName.indexOf("item_recipe_") !== 0) {
		MakeDraggable(node, itemName);
	}
	if (buyable) {
		node.SetPanelEvent("oncontextmenu", () => BuyItem(itemName));
	}
}

// Раскладка группы сбоку от центра: side = -1 слева, +1 справа. Колонка 0 — ближняя к центру.
// Возвращает центры узлов { x, y } в порядке names.
function TreeGroupLayout(count, side, width, height) {
	if (count === 0) return [];
	const colStep = TREE.nodeW + TREE.step;
	const room = width / 2 - TREE.itemW / 2 - TREE.gap;
	const maxCols = Math.max(1, Math.floor((room + TREE.step) / colStep));
	const cols = Math.min(Math.ceil(count / TREE.maxRows), maxCols);
	const rows = Math.ceil(count / cols);
	const nearX = width / 2 + side * (TREE.itemW / 2 + TREE.gap + TREE.nodeW / 2);
	const points = [];
	for (let i = 0; i < count; i++) {
		const col = Math.floor(i / rows);
		const row = i % rows;
		const inCol = Math.min(rows, count - col * rows);
		const blockH = inCol * TREE.nodeH + (inCol - 1) * TREE.step;
		const top = (height - blockH) / 2;
		points.push({ x: nearX + side * col * colStep, y: top + row * (TREE.nodeH + TREE.step) + TREE.nodeH / 2 });
	}
	return points;
}

function TreeRowsNeeded(count, width) {
	if (count === 0) return 1;
	const colStep = TREE.nodeW + TREE.step;
	const room = width / 2 - TREE.itemW / 2 - TREE.gap;
	const maxCols = Math.max(1, Math.floor((room + TREE.step) / colStep));
	const cols = Math.min(Math.ceil(count / TREE.maxRows), maxCols);
	return Math.ceil(count / cols);
}

function AddTreeLine(layer, x1, y1, x2, y2) {
	const dx = x2 - x1;
	const dy = y2 - y1;
	const line = $.CreatePanel("Panel", layer, "");
	line.style.height = "2px";
	line.style.backgroundColor = "#7d878c";
	line.style.transformOrigin = "0% 50%";
	line.style.width = Math.sqrt(dx * dx + dy * dy).toFixed(1) + "px";
	line.style.marginLeft = x1.toFixed(1) + "px";
	line.style.marginTop = (y1 - 1).toFixed(1) + "px";
	line.style.transform = "rotateZ(" + (Math.atan2(dy, dx) * 180 / Math.PI).toFixed(2) + "deg)";
}

// Ширина холста в единицах вёрстки (1080p). До первой раскладки actuallayoutwidth = 0 — берём запасную.
function TreeWidth() {
	const canvas = TreePart("BuildTreeCanvas");
	const scale = canvas.actualuiscale_x || 1;
	const width = canvas.actuallayoutwidth / scale;
	return width > 50 ? width : TREE.fallbackWidth;
}

function RenderBuildTree(retry) {
	const name = STATE.selected;
	CONTEXT.SetHasClass("HasSelection", !!name);
	UpdateTreeVisibility();

	const lines = TreePart("TreeLines");
	const upRow = TreePart("TreeUpRow");
	const itemRow = TreePart("TreeItemRow");
	const compRow = TreePart("TreeCompRow");
	ReturnBorrowed("tree");
	[lines, upRow, itemRow, compRow].forEach((panel) => {
		panel.RemoveAndDeleteChildren();
		panel.hittest = false; // слои перекрывают друг друга на весь холст — клики должны доходить до узлов
	});
	if (!name) {
		SetTreeHeight(0);
		return;
	}

	const width = TreeWidth();
	const mid = width / 2;
	const ups = BUILDS_INTO[name] || [];
	const parts = TreeParts(name);

	// Высота холста — по самой высокой колонке, окно сборки подстраивается под неё.
	const rows = Math.max(TreeRowsNeeded(parts.length, width), TreeRowsNeeded(ups.length, width));
	const height = Math.max(TREE.itemH, rows * TREE.nodeH + (rows - 1) * TREE.step);
	TreePart("BuildTreeCanvas").style.height = height + "px";
	SetTreeHeight(height + TREE.padding);
	const midY = height / 2;

	// Слева компоненты и рецепт, линии от их правого края к левому краю предмета.
	TreeGroupLayout(parts.length, -1, width, height).forEach((point, i) => {
		const part = parts[i];
		const isRecipe = part.indexOf("item_recipe_") === 0;
		AddTreeNode(compRow, point.x, point.y, part, true, !isRecipe, true);
		AddTreeLine(lines, point.x + TREE.nodeW / 2, point.y, mid - TREE.itemW / 2, midY);
	});

	AddTreeNode(itemRow, mid, midY, name, false, false, true);

	// Справа — во что собирается, линии от правого края предмета.
	TreeGroupLayout(ups.length, 1, width, height).forEach((point, i) => {
		AddTreeNode(upRow, point.x, point.y, ups[i], true, true, true);
		AddTreeLine(lines, mid + TREE.itemW / 2, midY, point.x - TREE.nodeW / 2, point.y);
	});

	// Первая отрисовка идёт до раскладки: пересчитать линии, когда ширина станет известна.
	const attempt = retry || 0;
	if (!((TreePart("BuildTreeCanvas").actuallayoutwidth || 0) > 50) && attempt < 10) {
		$.Schedule(0.05, () => {
			if (STATE.generation === GENERATION && STATE.selected === name) {
				RenderBuildTree(attempt + 1);
			}
		});
	}
}

// VERIFY: формат приказа покупки в Panorama (поле с именем предмета) — сверить в Context7.
function BuyItem(name) {
	// Приказ покупки: предмет задаётся числовым ID в AbilityIndex (поля с именем предмета у приказа нет).
	const itemId = DATA.itemIds ? DATA.itemIds[name] : undefined;
	const hero = Players.GetPlayerHeroEntityIndex(Players.GetLocalPlayer());
	STATE.lastBuy = name + " id " + itemId + " hero " + hero + " t " + Game.GetGameTime().toFixed(1);
	if (hero === -1) {
		return;
	}
	// Покупка через сервер (game_managers/trinity_shop.lua): приказ из интерфейса движок не принимает.
	GameEvents.SendCustomGameEventToServer("trinity_shop_buy", { item: name, id: itemId || 0 });
}

// ---------------------------------------------------------------- инициализация (в конце файла)

// Ответ сервера на покупку: звук успеха или родная красная ошибка по центру экрана.
GameEvents.Subscribe("trinity_shop_result", (event) => {
	if (STATE.generation !== GENERATION) return;
	if (event.ok) {
		Game.EmitSound("General.Buy");
		return;
	}
	const message = event.reason === "gold" ? "Недостаточно золота" : "Нет места в инвентаре и тайнике";
	GameEvents.SendEventClientSide("dota_hud_error_message", { splitscreenplayer: 0, reason: 80, message: message });
});

GameEvents.Subscribe("trinity_shop_hero_attr", OnHeroAttribute);

try {
	STATE.dragging = false;
	ReturnBorrowed();
	BuildCategoryGrid();
	RenderCategory();
	RenderBuildTree();
	AttachToNativeShop();
} catch (e) {
	$.Msg("[TrinityShop] init error: " + e + " " + (e.stack || ""));
}
// Убрать отладочную надпись, оставшуюся от прошлых версий (при горячей перезагрузке).
(() => {
	const hud = CONTEXT.FindAncestor ? CONTEXT.FindAncestor("DotaHud") : null;
	const stale = hud ? hud.FindChildTraverse("TrinityShopDebug") : null;
	if (stale) stale.DeleteAsync(0);
})();
