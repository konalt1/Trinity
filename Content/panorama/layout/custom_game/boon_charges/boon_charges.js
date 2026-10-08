// Trinity: выбор способности для бунов каравана с выбором («Два заряда», «Вампиризм», «Ускорение»).
// Куда: Content/panorama/layout/custom_game/boon_charges/boon_charges.js
// Сервер: items/caravan_boons.lua (CaravanBoons.OnChoicePick). Бун тратится при применении: у героя-цели висит
// видимый modifier_<бун>_pending, пока его игрок не выберет способность. Окно видит только этот игрок.
// Окно стоит над инвентарём справа и появляется свёрнутым в плашку (#BoonChargesTab).

"use strict";

const ANCHOR = $("#BoonChargesAnchor");
const ROOT = $("#BoonChargesRoot");
const TAB = $("#BoonChargesTab");
const TAB_TITLE = $("#BoonChargesTabTitle");
const TAB_ICON = $("#BoonChargesTabIcon");
const COLLAPSE = $("#BoonChargesCollapse");
const CONTEXT = $.GetContextPanel();
// Зазор над инвентарём: над слотами у лавки висят плюсики улучшения (item_upgrade, 18 − 5 px).
const INVENTORY_GAP = 24;
const LIST = $("#BoonChargesAbilities");
const TITLE = $("#BoonChargesTitle");
const HINT = $("#BoonChargesHint");
const ITEM_ICON = $("#BoonChargesItemIcon");
const CONFIG = GameUI.CustomUIConfig();

if (!CONFIG.trinityBoonCharges) {
	CONFIG.trinityBoonCharges = {};
}
const STATE = CONFIG.trinityBoonCharges;
STATE.generation = (STATE.generation || 0) + 1;
const GENERATION = STATE.generation;

// После перезагрузки скрипта старые подписки удаляем, иначе окно откроется дважды.
(STATE.listeners || []).forEach((id) => {
	try {
		GameEvents.Unsubscribe(id);
	} catch (e) {}
});
STATE.listeners = [];

let current = null; // { boon, target }

// Массивы из Lua приходят объектом { "1": …, "2": … }.
function ToArray(value) {
	if (!value) return [];
	if (Array.isArray(value)) return value;
	return Object.keys(value)
		.sort((a, b) => Number(a) - Number(b))
		.map((key) => value[key]);
}

function SetExpanded(expanded) {
	ANCHOR.SetHasClass("Expanded", expanded);
	ANCHOR.SetHasClass("Collapsed", !expanded);
	if (!expanded) {
		ROOT.RemoveClass("Failed");
	}
}

function Close() {
	current = null;
	ANCHOR.RemoveClass("Visible");
	ANCHOR.RemoveClass("Expanded");
	ANCHOR.RemoveClass("Collapsed");
	ROOT.RemoveClass("Busy");
	ROOT.RemoveClass("Failed");
	LIST.RemoveAndDeleteChildren();
}

function Pick(abilityIndex) {
	if (!current || ROOT.BHasClass("Busy")) return;
	ROOT.AddClass("Busy");
	ROOT.RemoveClass("Failed");
	GameEvents.SendCustomGameEventToServer("trinity_boon_charges_pick", {
		boon: current.boon,
		target: current.target,
		ability: abilityIndex,
	});
}

function AddAbility(abilityIndex, heroIndex) {
	const name = Abilities.GetAbilityName(abilityIndex);
	if (!name) return;

	const button = $.CreatePanel("Button", LIST, "");
	button.AddClass("BoonChargesAbility");

	const image = $.CreatePanel("DOTAAbilityImage", button, "");
	image.AddClass("BoonChargesAbilityImage");
	image.hittest = false;
	image.abilityname = name;
	image.contextEntityIndex = abilityIndex;

	const label = $.CreatePanel("Label", button, "");
	label.AddClass("BoonChargesAbilityName");
	label.hittest = false;
	label.text = $.Localize("#DOTA_Tooltip_ability_" + name);

	button.SetPanelEvent("onmouseover", () => {
		$.DispatchEvent("DOTAShowAbilityTooltipForEntityIndex", button, name, heroIndex);
	});
	button.SetPanelEvent("onmouseout", () => {
		$.DispatchEvent("DOTAHideAbilityTooltip", button);
	});
	button.SetPanelEvent("onactivate", () => {
		$.DispatchEvent("DOTAHideAbilityTooltip", button);
		Pick(abilityIndex);
	});
}

function OnOpen(data) {
	if (STATE.generation !== GENERATION || !data) return;
	Close();
	const abilities = ToArray(data.abilities);
	if (abilities.length === 0) return;

	const boon = data.boon || "item_boon_twin_charges";
	current = { boon: boon, target: data.target };
	TITLE.text = $.Localize("#DOTA_Tooltip_Ability_" + boon);
	HINT.text = $.Localize("#trinity_boon_choice_hint_" + boon);
	ITEM_ICON.itemname = boon;
	TAB_ICON.itemname = boon;
	TAB_TITLE.text = TITLE.text;
	abilities.forEach((abilityIndex) => AddAbility(abilityIndex, data.target));
	ANCHOR.AddClass("Visible");
	SetExpanded(false);
	Place();
}

function OnResult(data) {
	if (STATE.generation !== GENERATION || !current) return;
	if (data && data.boon && data.boon !== current.boon) return;
	if (data && Number(data.ok) === 1) {
		Close();
		return;
	}
	ROOT.RemoveClass("Busy");
	ROOT.AddClass("Failed");
}

// ---------------------------------------------------------------- позиция над инвентарём

function IsAlive(panel) {
	return !!panel && (!panel.IsValid || panel.IsValid());
}

function InventoryPanel() {
	if (IsAlive(STATE.inventoryPanel)) return STATE.inventoryPanel;
	const hud = CONTEXT.FindAncestor ? CONTEXT.FindAncestor("DotaHud") : null;
	STATE.inventoryPanel = hud ? hud.FindChildTraverse("inventory_list") : null;
	return STATE.inventoryPanel;
}

// Правый край окна — по правому краю inventory_list, низ — над ним на INVENTORY_GAP.
// Нет инвентаря на экране (выбран другой юнит) — остаётся последняя позиция или запасная из CSS.
function Place() {
	const panel = InventoryPanel();
	if (!IsAlive(panel) || !panel.visible || panel.actuallayoutwidth < 4) return;
	const scaleX = CONTEXT.actualuiscale_x || 1;
	const scaleY = CONTEXT.actualuiscale_y || 1;
	const pos = panel.GetPositionWithinWindow();
	if (!pos || !isFinite(pos.x) || !isFinite(pos.y)) return;
	const screenW = CONTEXT.actuallayoutwidth / scaleX;
	const screenH = CONTEXT.actuallayoutheight / scaleY;
	const right = (pos.x + panel.actuallayoutwidth) / scaleX;
	const top = pos.y / scaleY;
	ANCHOR.style.marginRight = Math.max(8, screenW - right).toFixed(1) + "px";
	ANCHOR.style.marginBottom = Math.max(8, screenH - top + INVENTORY_GAP).toFixed(1) + "px";
}

// Есть ли у героя ожидающий модификатор буна (выбор ещё не сделан).
function HasPending(heroIndex, boon) {
	const name = "modifier_" + boon + "_pending";
	const count = Entities.GetNumBuffs(heroIndex);
	for (let i = 0; i < count; i++) {
		const buff = Entities.GetBuff(heroIndex, i);
		if (buff !== -1 && Buffs.GetName(heroIndex, buff) === name) return true;
	}
	return false;
}

// Ожидающий модификатор пропал (выбор сделан или героя нет) — окно больше не нужно.
function Watch() {
	if (STATE.generation !== GENERATION) return;
	// Модификатор может прийти на клиент позже события открытия: закрываем, только если его нет дольше секунды.
	if (current) {
		if (HasPending(current.target, current.boon)) {
			current.missingSince = null;
		} else if (current.missingSince == null) {
			current.missingSince = Game.GetGameTime();
		} else if (Game.GetGameTime() - current.missingSince > 1) {
			Close();
		}
	}
	if (current) {
		Place();
	}
	$.Schedule(0.25, Watch);
}

COLLAPSE.SetPanelEvent("onactivate", () => SetExpanded(false));
TAB.SetPanelEvent("onactivate", () => SetExpanded(true));
STATE.listeners.push(GameEvents.Subscribe("trinity_boon_charges_open", OnOpen));
STATE.listeners.push(GameEvents.Subscribe("trinity_boon_charges_result", OnResult));
Close();
Watch();
// После перезагрузки UI или переподключения сервер снова пришлёт невыбранный бун.
GameEvents.SendCustomGameEventToServer("trinity_boon_charges_request", {});
