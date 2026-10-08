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
// Признаков несколько, ни один не сверен в игре, поэтому:
//  1) родные события открытия/закрытия магазина (если движок их шлёт — им верим в первую очередь);
//  2) классы открытого магазина на HUD / магазине / Main — верим, только если хоть раз видели такой класс;
//  3) геометрия: магазин скрыт, нулевой ширины, прозрачен или за краем экрана.
// Каждая смена состояния пишется в консоль со всеми признаками ([TrinityShop] shop open/closed).
const SHOP_OPEN_CLASSES = ["ShopOpen", "ShopOpened", "ShopActive", "ShopVisible"];

function HasOpenClass(panel) {
	return IsAlive(panel) && SHOP_OPEN_CLASSES.some((name) => panel.BHasClass(name));
}

function ShopSignals() {
	const shop = GetNativeShop();
	if (!IsAlive(shop)) return null;
	const hud = CONTEXT.FindAncestor ? CONTEXT.FindAncestor("DotaHud") : null;
	const main = shop.FindChildTraverse("Main");
	const pos = shop.GetPositionWithinWindow();
	const transparent = shop.BIsTransparent ? !!shop.BIsTransparent() : false;
	return {
		event: STATE.shopEventOpen,
		cls: HasOpenClass(hud) || HasOpenClass(shop) || HasOpenClass(main),
		visible: !!shop.visible && shop.actuallayoutwidth >= 10 && !transparent,
		onScreen: pos.x < Game.GetScreenWidth() - 20 && pos.x + shop.actuallayoutwidth > 20,
	};
}

function IsShopOpen(s) {
	if (!s) return false;
	if (STATE.shopEvents && STATE.shopEvents.open && STATE.shopEvents.closed) return !!s.event;
	if (s.cls) STATE.shopClassSeen = true;
	if (STATE.shopClassSeen) return s.cls;
	return s.visible && s.onScreen;
}

function ResetShopView() {
	// Подсветка наведения могла остаться, если магазин закрыли с курсором на плашке.
	DATA.categories.forEach((category) => {
		const tile = $("#Category_" + category.id);
		if (tile) tile.RemoveClass("Hover");
	});
	STATE.category = null;
	STATE.sub = null;
	STATE.selected = null;
	RenderCategory();
	RenderBuildTree();
}

function WatchShopOpen() {
	const signals = ShopSignals();
	const open = IsShopOpen(signals);
	if (STATE.shopOpen !== undefined && open !== STATE.shopOpen) {
		$.Msg("[TrinityShop] shop " + (open ? "open" : "closed") + " " + JSON.stringify(signals));
		// Сброс и при закрытии, и при открытии: какой бы признак ни сработал, магазин откроется без выбранной категории.
		if (STATE.mode === "new") ResetShopView();
	}
	STATE.shopOpen = open;
}

// Родные события магазина. Неизвестное имя просто не сработает.
// Признаку из событий верим, только когда пришли оба события — открытия и закрытия.
function OnShopEvent(open) {
	STATE.shopEvents = STATE.shopEvents || {};
	STATE.shopEvents[open ? "open" : "closed"] = true;
	STATE.shopEventOpen = open;
}
$.RegisterForUnhandledEvent("DOTAHUDShopOpened", () => OnShopEvent(true));
$.RegisterForUnhandledEvent("DOTAHUDShopClosed", () => OnShopEvent(false));

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
	} else if (BorrowRegistry().length === 0) {
		RenderItems(FindCategory(STATE.category));
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

// Родная сетка видна: классический вид или поиск.
function ShowNative() {
	return STATE.mode === "old" || CONTEXT.BHasClass("SearchActive");
}

// ---------------------------------------------------------------- высота как у классического магазина
// Новый вид стоит на месте родных вкладок и сетки (GridHeaderAndMainContent), а окно сборки — на месте родного
// дерева (ItemCombines). Высоты этих панелей в классическом виде постоянные, в условных пикселях Panorama
// (экран высотой 1080, от разрешения не зависят). Сняты в игре 2026-10-04 на 2560x1440 (масштаб 1.333):
// GridHeaderAndMainContent 808px → 606, ItemCombines 131px → 98.
// Если Valve поменяет родной магазин — переснять эти два числа в отладчике Panorama.
const CLASSIC_CONTENT_HEIGHT = 606;
const CLASSIC_COMBINES_HEIGHT = 98;

function ClassicHeights() {
	return { content: CLASSIC_CONTENT_HEIGHT, combines: CLASSIC_COMBINES_HEIGHT };
}

function UpdateHeight() {
	if (ShowNative()) return;
	const height = CLASSIC_CONTENT_HEIGHT + "px";
	if (CONTEXT.style.height !== height) CONTEXT.style.height = height;
	if (!STATE.selected) {
		SetTreeHeight(0);
		// Ряд расходников центрируется по высоте окна сборки: перерисовать, если она поменялась.
		const reserve = TreeReserveHeight();
		if (STATE.consumablesReserve !== reserve) {
			STATE.consumablesReserve = reserve;
			RenderBuildTree();
		}
	}
}

// ---------------------------------------------------------------- плашки категорий

function FindCategory(id) {
	return DATA.categories.find((c) => c.id === id) || null;
}

function BuildCategoryRow() {
	const row = $("#CategoryRow");
	row.RemoveAndDeleteChildren();

	// 6 плашек в одну строку, только арт; название — во всплывающей подсказке.
	DATA.categories.forEach((category, index) => {
		const tile = $.CreatePanel("Button", row, "Category_" + category.id);
		tile.BLoadLayoutSnippet("CategoryTile");
		tile.SetHasClass("First", index === 0);
		tile.FindChildTraverse("CategoryArt").SetImage(category.art);
		tile.FindChildTraverse("CategoryBar").style.backgroundColor = category.accent;
		tile.SetPanelEvent("onactivate", () => ToggleCategory(category.id));
		tile.SetPanelEvent("onmouseover", () => {
			tile.AddClass("Hover");
			PaintCategoryTile(tile, category);
			$.DispatchEvent("DOTAShowTextTooltip", tile, $.Localize(category.token));
		});
		tile.SetPanelEvent("onmouseout", () => {
			tile.RemoveClass("Hover");
			PaintCategoryTile(tile, category);
			$.DispatchEvent("DOTAHideTextTooltip");
		});
	});
	PaintCategoryTiles();
}

// Цвета плашки — как у подкатегорий: выбрана — 77→2a % и рамка 2px, наведение — 38→10 % и рамка 1px,
// иначе серая (как полоса атрибутов). Наведение красим из JS: в CSS цвет категории не передать.
function PaintCategoryTile(tile, category) {
	const active = STATE.category === category.id;
	const hover = tile.BHasClass("Hover");
	tile.SetHasClass("Active", active);
	if (active || hover) {
		tile.style.backgroundColor = "gradient( linear, 0% 0%, 0% 100%, from( " + category.accent + (active ? "77" : "38") + " ), to( " + category.accent + (active ? "2a" : "10") + " ) )";
		tile.style.border = active ? "2px solid " + category.accent : "1px solid " + category.accent + "80";
	} else {
		tile.style.backgroundColor = "gradient( linear, 0% 0%, 0% 100%, from( #2a2f35 ), to( #1a1d21 ) )";
		tile.style.border = "1px solid #000000";
	}
}

function PaintCategoryTiles() {
	DATA.categories.forEach((category) => {
		const tile = $("#Category_" + category.id);
		if (tile) PaintCategoryTile(tile, category);
	});
}

// ---------------------------------------------------------------- экран категории

// Снять выбор предмета и очистить окно сборки (иначе внизу остаётся рецепт прошлого предмета).
function ClearSelection() {
	STATE.selected = null;
	RenderBuildTree();
}

// Клик по категории выбирает её, повторный — снимает выбор (тогда в списке все предметы).
// Подкатегория сбрасывается, сортировка по атрибуту сохраняется.
function ToggleCategory(id) {
	STATE.category = STATE.category === id ? null : id;
	STATE.sub = null;
	ClearSelection();
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
		if (changed && !STATE.attrTouched && STATE.attr !== event.attr) {
			STATE.attr = event.attr;
			resort = true;
		}
	}
	if (resort) RenderCategory();
}

// ---------------------------------------------------------------- золото: доступные предметы сверху

function LocalGold() {
	return Players.GetGold(Players.GetLocalPlayer());
}

// Снимок списка: состав, порядок и что по карману. Меняется — список пересобирается
// (купленный предмет пропадает, раз в минуту меняется вес от времени матча, карточка блекнет без золота).
function ListKey(names, gold) {
	return names.map((name) => name + (DATA.items[name].price <= gold ? "+" : "-")).join(",");
}

function WatchGold() {
	const category = FindCategory(STATE.category);
	const showNative = ShowNative();
	// Во время перетаскивания карточку не пересоздаём — иначе бросок потеряется.
	if (showNative || STATE.dragging) return;
	if (ListKey(GetVisibleItems(category), LocalGold()) !== STATE.listKey) {
		RenderItems(category);
	}
}

function RenderCategory() {
	const category = FindCategory(STATE.category);
	CONTEXT.SetHasClass("CategoryOpen", !!category);
	// Порядок по умолчанию задаёт вес предмета для героя, атрибут сам не включается.
	// Запрос нужен ради статов предметов из KV (сортировка по атрибуту); повторяется не чаще раза в 2 с.
	HeroAttribute();

	PaintCategoryTiles();
	RenderSubcategories(category);
	RenderAttributes();
	RenderItems(category);
}

function RenderSubcategories(category) {
	const row = $("#SubcategoryRow");
	row.RemoveAndDeleteChildren();
	if (!category) return;
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
			ClearSelection();
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
			ClearSelection();
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

// ---------------------------------------------------------------- купленные предметы скрыты
// Последний слот героя: 0–5 инвентарь, 6–8 рюкзак, 9–14 тайник, 15 ТП, 16 нейтральный.
const HERO_LAST_SLOT = 16;
const COURIER_LAST_SLOT = 8;

// Предметы, которые у героя уже есть: инвентарь, рюкзак, тайник и курьер (только купленные этим героем —
// пока курьер несёт покупку, она не должна возвращаться в список). Продал или собрал в другой предмет — снова в списке.
// Значение — сколько штук (нужно для доли собранного предмета, ItemAssemblyShare).
function OwnedItemNames() {
	const owned = {};
	const hero = LocalHero();
	if (hero === -1) return owned;
	const collect = (unit, lastSlot, onlyMine) => {
		for (let slot = 0; slot <= lastSlot; slot++) {
			const item = Entities.GetItemInSlot(unit, slot);
			if (item === -1 || item === undefined) continue;
			if (onlyMine && Items.GetPurchaser && Items.GetPurchaser(item) !== hero) continue;
			const name = Abilities.GetAbilityName(item);
			owned[name] = (owned[name] || 0) + 1;
		}
	};
	collect(hero, HERO_LAST_SLOT, false);
	// VERIFY: Entities.GetAllEntitiesByClassname для курьеров в Panorama. Нет API — курьер просто не учитывается.
	try {
		const team = Entities.GetTeamNumber(hero);
		(Entities.GetAllEntitiesByClassname("npc_dota_courier") || []).forEach((courier) => {
			if (Entities.GetTeamNumber(courier) === team) collect(courier, COURIER_LAST_SLOT, true);
		});
	} catch (e) {
		STATE.lastError = "courier: " + e;
	}
	return owned;
}

// ---------------------------------------------------------------- вес предмета от минуты матча
// Каждый предмет выходит на максимум веса к своей минуте (пик), которая зависит от цены:
//   дешевле CHEAP_PRICE — максимум сразу с горна и до 3-й минуты;
//   500 → 3 мин, 1000 → 7 мин (между ними — линейно), дальше +5 минут за каждую 1000 (2000 → 12, 3000 → 17, 5000 → 27).
// До пика множитель растёт от ×1/MAX_MULT (на 0:00) до ×MAX_MULT, после пика падает обратно в FALL_SLOWDOWN раз медленнее.
// Множитель применяется к сжатому весу (вес^WEIGHT_POWER): у Dotabuff первый предмет героя весит в 3–8 раз больше
// десятого, и без сжатия время не может поднять ранние предметы над дорогими.
// Минуты считаются целыми от горна (до горна — 0), поэтому порядок меняется раз в минуту, а не на глазах.
// Quelling Blade отдельной логики не имеет — обычный дешёвый предмет.
const TIME_WEIGHT = {
	WEIGHT_POWER: 0.5,
	MAX_MULT: 3,
	CHEAP_PRICE: 500,
	CHEAP_PEAK: 3,
	MID_PRICE: 1000,
	MID_PEAK: 7,
	MINUTES_PER_1000: 5,
	FALL_SLOWDOWN: 2,
};

function MatchMinute() {
	return Math.floor(Math.max(0, Game.GetDOTATime(false, false)) / 60);
}

function ItemCost(name) {
	const item = DATA.items[name];
	if (item && item.price > 0) return item.price;
	const recipe = DATA.recipes[name];
	return recipe && recipe.price > 0 ? recipe.price : 0;
}

// Минута, к которой предмет выходит на максимальный вес.
function ItemPeakMinute(price) {
	const t = TIME_WEIGHT;
	if (price <= t.CHEAP_PRICE) return t.CHEAP_PEAK;
	if (price <= t.MID_PRICE) {
		return t.CHEAP_PEAK + ((price - t.CHEAP_PRICE) / (t.MID_PRICE - t.CHEAP_PRICE)) * (t.MID_PEAK - t.CHEAP_PEAK);
	}
	return t.MID_PEAK + ((price - t.MID_PRICE) / 1000) * t.MINUTES_PER_1000;
}

// Множитель веса от времени: от ×1/MAX_MULT до ×MAX_MULT. Цены нет — ×1.
function ItemTimeMultiplier(name, minute) {
	const t = TIME_WEIGHT;
	const price = ItemCost(name);
	if (price <= 0) return 1;
	const peak = ItemPeakMinute(price);
	let shape; // -1 … 1
	if (minute <= peak) {
		shape = price <= t.CHEAP_PRICE ? 1 : 1 - (2 * (peak - minute)) / peak;
	} else {
		shape = Math.max(-1, 1 - (2 * (minute - peak)) / (peak * t.FALL_SLOWDOWN));
	}
	return Math.pow(t.MAX_MULT, shape);
}

// ---------------------------------------------------------------- бонус за собранные части
// Доля собранного предмета: цена частей, которые уже есть у героя (OwnedItemNames), / полная цена предмета.
// Части внутри частей тоже считаются (Belt of Strength идёт в Abyssal Blade через Sange), свиток рецепта — тоже.
// Каждый экземпляр части засчитывается в предмет один раз; в разные предметы — независимо.
function OwnedPartsValue(name, pool) {
	const recipe = DATA.recipes[name];
	if (!recipe) return 0;
	let value = 0;
	recipe.components.forEach((part) => {
		if (pool[part] > 0) {
			pool[part]--;
			value += ItemCost(part);
		} else {
			value += OwnedPartsValue(part, pool);
		}
	});
	if (recipe.recipe > 0) {
		const scroll = recipe.recipeItem || "item_recipe_" + name.replace(/^item_/, "");
		if (pool[scroll] > 0) {
			pool[scroll]--;
			value += recipe.recipe;
		}
	}
	return value;
}

function ItemAssemblyShare(name, owned) {
	const total = ItemCost(name);
	if (total <= 0 || !DATA.recipes[name]) return 0;
	const pool = {};
	Object.keys(owned).forEach((key) => (pool[key] = owned[key]));
	return Math.min(1, OwnedPartsValue(name, pool) / total);
}

// Итоговый вес предметов для сортировки: (вес Dotabuff)^WEIGHT_POWER × множитель минуты,
// затем подтягивание к самому тяжёлому предмету на долю собранного: 50% собрано — половина пути наверх,
// почти собранный предмет — выше всех (ASSEMBLY_TOP_BONUS). Предметы без веса тоже поднимаются за собранные части.
const ASSEMBLY_TOP_BONUS = 1.05;

function ItemSortWeights(owned) {
	const weights = HeroWeights() || {};
	const minute = MatchMinute();
	const result = {};
	let top = 0;
	Object.keys(DATA.items).forEach((name) => {
		const base = weights[name] || 0;
		const value = base > 0 ? Math.pow(base, TIME_WEIGHT.WEIGHT_POWER) * ItemTimeMultiplier(name, minute) : 0;
		result[name] = value;
		if (DATA.items[name].categories.length > 0 && value > top) top = value;
	});
	const target = top * ASSEMBLY_TOP_BONUS;
	Object.keys(result).forEach((name) => {
		const share = ItemAssemblyShare(name, owned);
		if (share > 0 && target > result[name]) result[name] += (target - result[name]) * share;
	});
	return result;
}

// Порядок в категории (золото на порядок не влияет — только блеклость карточки):
//  1) если выбран атрибут — сначала предметы с этим статом;
//  2) по итоговому весу (ItemSortWeights: вес героя × минута матча + собранные части), от больших;
//  3) без веса (или у героя нет таблицы) — по цене от дешёвых, при равной цене больше выбранного стата выше; затем по имени.
// category = null — все предметы нового вида (у кого есть хоть одна категория).
// Предметы, которые у героя уже есть (OwnedItemNames), в список не попадают.
function GetVisibleItems(category) {
	const sub = category ? category.subcategories.find((s) => s.id === STATE.sub) || null : null;
	const attr = STATE.attr;
	const amount = (name) => (attr ? ItemStatAmount(name, attr) : 0);
	const owned = OwnedItemNames();
	const weights = ItemSortWeights(owned);
	const weight = (name) => weights[name] || 0;

	return Object.keys(DATA.items)
		.filter((name) => {
			if (owned[name]) return false;
			const categories = DATA.items[name].categories;
			if (category ? categories.indexOf(category.id) === -1 : categories.length === 0) return false;
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
	STATE.listKey = ListKey(names, gold);
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
		[card, card.FindChildTraverse("ItemIcon"), text, card.FindChildTraverse("ItemName"), card.FindChildTraverse("ItemDesc"), card.FindChildTraverse("ItemPriceLabel")].forEach((panel) => {
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
	// Сначала настоящая карточка родного магазина (DOTAShopItem); иначе любая панель с этим предметом.
	// У предметов, которых нет в родной сетке (бывшие нейтралки: Elven Tunic), панели может не быть или она
	// не принимает Activated — тогда не падаем, окно сборки уже показано выше.
	let nativeItem = shop ? FindNativeShopItem(shop, name) : null;
	if (!nativeItem && shop) {
		nativeItem = FindPanelByItemName(shop, name, CONTEXT);
	}
	if (nativeItem && IsAlive(nativeItem)) {
		try {
			$.DispatchEvent("Activated", nativeItem);
		} catch (e) {
			$.Msg("[TrinityShop] native Activated skipped for " + name + ": " + e);
		}
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
		// recipeItem — если рецепт предмета лежит под чужим именем (Grove Bow: item_recipe_iron_talon).
		parts.push(recipe.recipeItem || ("item_recipe_" + name.replace(/^item_/, "")));
	}
	return parts;
}

// Узел в точке (x, y) — центр иконки, в координатах холста. Слои TreeUpRow/TreeItemRow/TreeCompRow — на весь холст без потока.
function AddTreeNode(layer, x, y, itemName, small, clickable, buyable, size) {
	// Панели создаются вне нашего layout (окно перенесено в нативный магазин), CSS-классы на них не действуют — стили inline.
	const width = size ? size.w : small ? TREE.nodeW : TREE.itemW;
	const height = size ? size.h : small ? TREE.nodeH : TREE.itemH;

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
	return node;
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
		RenderConsumables(compRow, retry);
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

// ---------------------------------------------------------------- расходники в пустом окне сборки
// Пока предмет не выбран, на месте дерева сборки — ряд расходников. ПКМ — купить, Shift+ЛКМ — в быструю покупку,
// перетаскивание — как у карточек, наведение — родной тултип (там цена).
// У предметов с запасом (варды, смоук, граната) в углу иконки — сколько их осталось в магазине команды.
const CONSUMABLES = [
	"item_tpscroll",
	"item_ward_observer",
	"item_ward_sentry",
	"item_tango",
	"item_flask",
	"item_clarity",
	"item_enchanted_mango",
	"item_faerie_fire",
	"item_smoke_of_deceit",
	"item_dust",
	"item_blood_grenade",
];

function RenderConsumables(layer, retry) {
	const canvas = TreePart("BuildTreeCanvas");
	const width = TreeWidth();
	const count = CONSUMABLES.length;
	const step = 6;
	// Иконки в одну линию на всю ширину, но не крупнее узлов дерева; пропорции родной иконки (≈ 88×64).
	const w = Math.min(TREE.nodeW, Math.floor((width - (count - 1) * step) / count));
	const h = Math.round(w * 0.73);
	const reserve = TreeReserveHeight();
	const height = Math.max(h, reserve > TREE.padding ? reserve - TREE.padding : h);
	canvas.style.height = height + "px";
	const rowW = count * w + (count - 1) * step;
	const left = (width - rowW) / 2;
	STOCK_NODES = {};
	CONSUMABLES.forEach((itemName, i) => {
		const node = AddTreeNode(layer, left + i * (w + step) + w / 2, height / 2, itemName, true, false, true, { w: w, h: h });
		// Счётчик запаса в правом нижнем углу, как в родном магазине. Стили inline (панели вне нашего layout).
		const label = $.CreatePanel("Label", node, "");
		label.hittest = false;
		label.style.horizontalAlign = "right";
		label.style.verticalAlign = "bottom";
		label.style.marginRight = "2px";
		label.style.fontFamily = "monospaceNumbersFont";
		label.style.fontSize = "13px";
		label.style.fontWeight = "bold";
		label.style.color = "#ffffff";
		label.style.textShadow = "1px 1px 1px 3.0 #000000";
		label.visible = false;
		STOCK_NODES[itemName] = { node: node, label: label };
	});
	UpdateStockBadges();

	// Первая отрисовка до раскладки: перерисовать, когда станет известна ширина.
	const attempt = retry || 0;
	if (!((canvas.actuallayoutwidth || 0) > 50) && attempt < 10) {
		$.Schedule(0.05, () => {
			if (STATE.generation === GENERATION && !STATE.selected) RenderBuildTree(attempt + 1);
		});
	}
}

// Запас магазина пишет сервер (trinity_shop.lua, UpdateStockTable): nettable trinity_shop, ключ stock_<команда>.
// Нет предмета в таблице — запаса у него нет, счётчик скрыт. Запас 0 — иконка тусклая, как в родном магазине.
var STOCK_NODES = {};

function UpdateStockBadges() {
	const team = Players.GetTeam(Players.GetLocalPlayer());
	const stock = CustomNetTables.GetTableValue("trinity_shop", "stock_" + team) || {};
	Object.keys(STOCK_NODES).forEach((itemName) => {
		const entry = STOCK_NODES[itemName];
		if (!IsAlive(entry.label)) return;
		const count = stock[itemName];
		const known = count !== undefined && count !== null;
		entry.label.visible = known;
		if (known) entry.label.text = String(count);
		const empty = known && Number(count) <= 0;
		entry.node.style.opacity = empty ? "0.45" : "1.0";
		entry.node.style.saturation = empty ? "0.0" : "1.0";
		entry.label.style.color = empty ? "#d2503f" : "#ffffff";
	});
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
	const MESSAGES = {
		gold: "Недостаточно золота",
		full: "Нет места в инвентаре и тайнике",
		shop: "Улучшать предметы можно только у лавки",
		recipe: "Этот предмет так не улучшить",
		stock: "Нет в наличии",
	};
	const message = MESSAGES[event.reason] || MESSAGES.full;
	GameEvents.SendEventClientSide("dota_hud_error_message", { splitscreenplayer: 0, reason: 80, message: message });
});

GameEvents.Subscribe("trinity_shop_hero_attr", OnHeroAttribute);

// Запас магазина: подписка одна на все перезагрузки скрипта.
if (STATE.stockListener !== undefined) CustomNetTables.UnsubscribeNetTableListener(STATE.stockListener);
STATE.stockListener = CustomNetTables.SubscribeNetTableListener("trinity_shop", () => {
	if (STATE.generation === GENERATION) UpdateStockBadges();
});

try {
	STATE.dragging = false;
	ReturnBorrowed();
	// Атрибут героя сам не включается: порядок по умолчанию — вес предмета для героя.
	STATE.attrTouched = true;
	BuildCategoryRow();
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
