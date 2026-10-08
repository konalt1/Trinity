"use strict";

// Счётчик бунов в ванильном кружке над тайником (0/6 → поднято / всего).
// Ванильные подписи ищем по тексту, ссылки запоминаем и каждые REAPPLY сек. снова ставим свои числа:
// движок может перерисовать свой счётчик.

const NET_TABLE = "trinity_neutral_boons";
const NET_KEY = "counter";
const REAPPLY = 0.5;
const SEARCH_ROOTS = ["lower_hud", "HUDElements"];

const STATE = {
	picked: 0,
	total: 0,
	numerator: null,   // Label с числителем («0»)
	denominator: null, // Label со знаменателем («/6»)
	combined: null,    // если счётчик — одна подпись «0/6»
	logged: false,
};

const RE_DENOMINATOR = /^\s*\/\s*\d+\s*$/;
const RE_NUMBER = /^\s*\d+\s*$/;
const RE_COMBINED = /^\s*\d+\s*\/\s*\d+\s*$/;

function HudRoot() {
	let panel = $.GetContextPanel();
	while (panel && panel.id !== "DotaHud") {
		panel = panel.GetParent();
	}
	return panel;
}

function IsAlive(panel) {
	return panel && panel.IsValid && panel.IsValid();
}

function IsLabel(panel) {
	return panel && panel.paneltype === "Label" && typeof panel.text === "string";
}

function PathOf(panel) {
	const parts = [];
	while (panel && parts.length < 8) {
		parts.unshift(panel.id || panel.paneltype);
		panel = panel.GetParent();
	}
	return parts.join(" > ");
}

function CollectLabels(panel, out) {
	if (!panel) return;
	if (IsLabel(panel)) out.push(panel);
	const children = panel.Children();
	if (!children) return;
	for (let i = 0; i < children.length; i++) {
		CollectLabels(children[i], out);
	}
}

function FindCounter() {
	const hud = HudRoot();
	if (!hud) return false;
	let root = null;
	for (const id of SEARCH_ROOTS) {
		root = hud.FindChildTraverse(id);
		if (root) break;
	}
	const labels = [];
	CollectLabels(root || hud, labels);

	for (const label of labels) {
		if (!RE_DENOMINATOR.test(label.text)) continue;
		const siblings = label.GetParent() ? label.GetParent().Children() : [];
		for (let i = 0; i < siblings.length; i++) {
			if (siblings[i] !== label && IsLabel(siblings[i]) && RE_NUMBER.test(siblings[i].text)) {
				STATE.numerator = siblings[i];
				STATE.denominator = label;
				STATE.combined = null;
				LogFound();
				return true;
			}
		}
	}
	for (const label of labels) {
		if (RE_COMBINED.test(label.text)) {
			STATE.combined = label;
			STATE.numerator = null;
			STATE.denominator = null;
			LogFound();
			return true;
		}
	}
	return false;
}

function LogFound() {
	if (STATE.logged) return;
	STATE.logged = true;
	const panel = STATE.combined || STATE.denominator;
	$.Msg("[BoonCounter] counter found: " + PathOf(panel));
}

function HasCounter() {
	if (STATE.combined) return IsAlive(STATE.combined);
	return IsAlive(STATE.numerator) && IsAlive(STATE.denominator);
}

function Apply() {
	if (!HasCounter() && !FindCounter()) return;
	const picked = String(STATE.picked);
	const total = String(STATE.total);
	if (STATE.combined) {
		const text = picked + "/" + total;
		if (STATE.combined.text !== text) STATE.combined.text = text;
		return;
	}
	if (STATE.numerator.text !== picked) STATE.numerator.text = picked;
	const denominator = "/" + total;
	if (STATE.denominator.text !== denominator) STATE.denominator.text = denominator;
}

function OnCounter(data) {
	if (!data) return;
	STATE.picked = Number(data.picked) || 0;
	STATE.total = Number(data.total) || 0;
	Apply();
}

function Tick() {
	Apply();
	$.Schedule(REAPPLY, Tick);
}

CustomNetTables.SubscribeNetTableListener(NET_TABLE, (_, key, data) => {
	if (key === NET_KEY) OnCounter(data);
});
OnCounter(CustomNetTables.GetTableValue(NET_TABLE, NET_KEY) || { picked: 0, total: 0 });
Tick();
