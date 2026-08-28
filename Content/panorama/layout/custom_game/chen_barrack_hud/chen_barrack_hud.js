(function () {
    "use strict";

    const NET_TABLE = "chen_barrack";
    const UPDATE_INTERVAL = 0.1;
    const DOUBLE_CLICK_WINDOW = 0.35;
    const QUEUE_SLOTS = 5;
    const QUICK_STATS_IDS = ["QuickStats", "quickstats", "QuickStatContainer", "stats"];
    const UNIT_SLOTS = [
        {
            key: "worker",
            ability: "chen_barrack_summon_worker",
        },
        {
            key: "hunter",
            ability: "chen_barrack_summon_hunter",
        },
        {
            key: "healer",
            ability: "chen_barrack_summon_healer",
        },
        {
            key: "brute",
            ability: "chen_barrack_summon_brute",
        },
    ];
    const UNIT_ABILITIES = UNIT_SLOTS.reduce(function (map, slot) {
        map[slot.key] = slot.ability;
        return map;
    }, {});

    const ROOT = $("#ChenBarrackHud");
    const PORTRAIT = $("#BarrackPortrait");
    const ICON = $("#BarrackIcon");
    const HEALTH_FILL = $("#BarrackHealthFill");
    const HEALTH_LABEL = $("#BarrackHealthLabel");
    const GOLD_LABEL = $("#BarrackGold");
    const STATUS_LABEL = $("#BarrackStatus");
    const UNITS_ROOT = $("#ChenBarrackUnits");
    const QUEUE_ROOT = $("#ChenBarrackQueue");

    const unitPanels = {};
    const queuePanels = [];
    let lastClickTime = 0;
    let lastState = null;

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value));
    }

    function formatTime(seconds) {
        const total = Math.max(0, Math.ceil(Number(seconds) || 0));
        const minutes = Math.floor(total / 60);
        const rest = total % 60;
        return minutes + ":" + (rest < 10 ? "0" : "") + rest;
    }

    function setAbilityIcon(panel, abilityName, entityIndex) {
        if (!panel) {
            return;
        }
        panel.abilityname = abilityName || "";
        if (entityIndex && entityIndex > 0) {
            panel.contextEntityIndex = entityIndex;
        }
    }

    function readQueue(state) {
        const count = Math.max(0, Math.min(QUEUE_SLOTS, Number(state.queue_count) || 0));
        const items = [];
        for (let i = 1; i <= count; i++) {
            items.push({
                unit: state["q" + i + "_unit"],
                remaining: Number(state["q" + i + "_remaining"]) || 0,
                total: Number(state["q" + i + "_total"]) || 0.1,
                active: Number(state["q" + i + "_active"]) === 1,
            });
        }
        return items;
    }

    function placeUnderQuickStats() {
        if (typeof FindDotaHudElement !== "function") {
            ROOT.style.marginTop = "88px";
            ROOT.style.marginLeft = "8px";
            return;
        }
        let stats = null;
        for (let i = 0; i < QUICK_STATS_IDS.length; i++) {
            stats = FindDotaHudElement(QUICK_STATS_IDS[i]);
            if (stats && stats.actuallayoutheight > 0) {
                break;
            }
            stats = null;
        }

        if (!stats) {
            ROOT.style.marginTop = "88px";
            ROOT.style.marginLeft = "8px";
            return;
        }

        ROOT.style.marginTop = (stats.actualyoffset + stats.actuallayoutheight + 4) + "px";
        ROOT.style.marginLeft = Math.max(6, stats.actualxoffset) + "px";
    }

    function createUnitSlots() {
        UNITS_ROOT.RemoveAndDeleteChildren();
        UNIT_SLOTS.forEach(function (slot) {
            const panel = $.CreatePanel("Panel", UNITS_ROOT, "ChenBarrackUnit_" + slot.key);
            panel.BLoadLayoutSnippet("ChenBarrackUnitSlot");
            setAbilityIcon(panel.FindChildTraverse("UnitIcon"), slot.ability);
            panel.SetPanelEvent("onactivate", function () {
                buyUnit(slot.key);
            });
            panel.SetPanelEvent("onmouseover", function () {
                const state = lastState;
                const entityIndex = state ? Number(state.barrack_entindex) || -1 : -1;
                if (entityIndex > 0) {
                    $.DispatchEvent("DOTAShowAbilityTooltipForEntityIndex", panel, slot.ability, entityIndex);
                    return;
                }
                $.DispatchEvent("DOTAShowAbilityTooltip", panel, slot.ability);
            });
            panel.SetPanelEvent("onmouseout", function () {
                $.DispatchEvent("DOTAHideAbilityTooltip", panel);
            });
            unitPanels[slot.key] = panel;
        });
    }

    function createQueueSlots() {
        QUEUE_ROOT.RemoveAndDeleteChildren();
        queuePanels.length = 0;
        for (let i = 0; i < QUEUE_SLOTS; i++) {
            const panel = $.CreatePanel("Panel", QUEUE_ROOT, "ChenBarrackQueue_" + i);
            panel.BLoadLayoutSnippet("ChenBarrackQueueSlot");
            queuePanels.push(panel);
        }
    }

    function getLocalState() {
        const playerId = Game.GetLocalPlayerID();
        if (playerId < 0) {
            return null;
        }
        return CustomNetTables.GetTableValue(NET_TABLE, String(playerId));
    }

    function queuedCount(state, unitKey) {
        return readQueue(state).reduce(function (total, item) {
            return total + (item && item.unit === unitKey ? 1 : 0);
        }, 0);
    }

    function buyUnit(unitKey) {
        const state = lastState;
        if (!state || state.active !== 1) {
            return;
        }
        GameEvents.SendCustomGameEventToServer("chen_barrack_queue_unit", {
            unit: unitKey,
        });
    }

    function selectBarrack(entityIndex) {
        if (!Entities.IsValidEntity(entityIndex)) {
            return;
        }
        GameUI.SelectUnit(entityIndex, false);
    }

    function focusBarrack(entityIndex) {
        if (!Entities.IsValidEntity(entityIndex)) {
            return;
        }
        selectBarrack(entityIndex);
        const origin = Entities.GetAbsOrigin(entityIndex);
        if (origin && GameUI.SetCameraTargetPosition) {
            GameUI.SetCameraTargetPosition(origin, 0.35);
        }
    }

    function onPortraitActivate() {
        const state = lastState;
        if (!state || state.active !== 1) {
            return;
        }

        const now = Game.Time();
        const entityIndex = Number(state.entindex) || -1;
        if (now - lastClickTime <= DOUBLE_CLICK_WINDOW) {
            focusBarrack(entityIndex);
            lastClickTime = 0;
            return;
        }

        lastClickTime = now;
        selectBarrack(entityIndex);
    }

    function updateUnitSlots(state) {
        const cap = Math.max(0, Number(state.cap) || 0);
        const gold = Math.max(0, Number(state.gold) || 0);
        const flying = state.flying === 1;
        const queueFull = readQueue(state).length >= QUEUE_SLOTS;

        UNIT_SLOTS.forEach(function (slot) {
            const panel = unitPanels[slot.key];
            if (!panel) {
                return;
            }

            const living = Math.max(0, Number(state[slot.key]) || 0);
            const cost = Math.max(0, Number(state[slot.key + "_cost"]) || 0);
            const atCap = cap > 0 && living + queuedCount(state, slot.key) >= cap;
            const noGold = gold < cost;
            panel.SetHasClass("AtCap", atCap);
            panel.SetHasClass("NoGold", noGold);
            panel.SetHasClass("Disabled", flying || atCap || noGold || queueFull);
            setAbilityIcon(panel.FindChildTraverse("UnitIcon"), slot.ability, Number(state.barrack_entindex) || -1);
            panel.FindChildTraverse("UnitCount").text = living + "/" + cap;
            panel.FindChildTraverse("UnitCost").text = String(cost);
        });
    }

    function updateQueue(state) {
        const items = readQueue(state);
        const entityIndex = Number(state.barrack_entindex) || -1;
        for (let i = 0; i < QUEUE_SLOTS; i++) {
            const panel = queuePanels[i];
            const item = items[i];
            if (!item || !item.unit) {
                panel.AddClass("Empty");
                panel.RemoveClass("Active");
                continue;
            }

            const remaining = Math.max(0, Number(item.remaining) || 0);
            const total = Math.max(0.1, Number(item.total) || 0.1);
            panel.RemoveClass("Empty");
            panel.SetHasClass("Active", item.active);
            setAbilityIcon(panel.FindChildTraverse("QueueIcon"), UNIT_ABILITIES[item.unit], entityIndex);
            panel.FindChildTraverse("QueueProgressFill").style.width =
                (clamp(1 - remaining / total, 0, 1) * 100) + "%";
            panel.FindChildTraverse("QueueTime").text = item.active ? String(Math.ceil(remaining)) : "";
        }
    }

    function updateHealth(entityIndex) {
        if (!Entities.IsValidEntity(entityIndex) || !Entities.IsAlive(entityIndex)) {
            HEALTH_FILL.style.width = "0%";
            HEALTH_LABEL.text = "";
            return;
        }

        const maxHealth = Math.max(1, Entities.GetMaxHealth(entityIndex));
        const health = clamp(Entities.GetHealth(entityIndex), 0, maxHealth);
        HEALTH_FILL.style.width = ((health / maxHealth) * 100) + "%";
        HEALTH_LABEL.text = String(health);
    }

    function updateStatus(state) {
        if (state.flying === 1) {
            STATUS_LABEL.text = $.Localize("#chen_barrack_hud_flying");
            return;
        }

        const cooldown = Number(state.takeoff_cd) || 0;
        if (cooldown > 0.05) {
            STATUS_LABEL.text = formatTime(cooldown);
            return;
        }

        STATUS_LABEL.text = "";
    }

    function update() {
        const state = getLocalState();
        lastState = state;
        if (!state || state.active !== 1) {
            ROOT.AddClass("Hidden");
            $.Schedule(UPDATE_INTERVAL, update);
            return;
        }

        ROOT.RemoveClass("Hidden");
        placeUnderQuickStats();
        GOLD_LABEL.text = String(Math.max(0, Number(state.gold) || 0));
        updateStatus(state);
        updateUnitSlots(state);
        updateQueue(state);
        updateHealth(Number(state.entindex) || -1);

        $.Schedule(UPDATE_INTERVAL, update);
    }

    ICON.abilityname = "chen_barrack";
    PORTRAIT.SetPanelEvent("onactivate", onPortraitActivate);
    createUnitSlots();
    createQueueSlots();
    CustomNetTables.SubscribeNetTableListener(NET_TABLE, function () {
        lastState = getLocalState();
    });
    update();
})();
