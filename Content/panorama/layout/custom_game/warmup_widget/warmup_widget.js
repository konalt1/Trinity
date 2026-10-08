"use strict";

const CONTEXT = $.GetContextPanel();
const config = GameUI.CustomUIConfig();
const MAX_HERO_LEVEL = 30;
const TICK_GEN_KEY = "_trinityWarmupWidgetTickGen";
config[TICK_GEN_KEY] = (config[TICK_GEN_KEY] || 0) + 1;
const tickGen = config[TICK_GEN_KEY];

function IsLocalPlayerOnMatchTeam() {
    const playerID = Players.GetLocalPlayer();
    if (playerID < 0) {
        return false;
    }

    const team = Players.GetTeam(playerID);
    return team === 2 || team === 3;
}

function HasLocalHero() {
    const playerID = Players.GetLocalPlayer();
    if (playerID < 0) {
        return false;
    }

    return Players.GetPlayerHeroEntityIndex(playerID) !== -1;
}

function IsWarmupActive() {
    return config.trinityWarmupActive === true;
}

// Лутбоксы работают только через бэкенд; пока он выключен (TrinityStickers.USE_BACKEND = false), кнопку не показываем.
const LOOTBOXES_ENABLED = false;

function IsStickerUiAvailable() {
    return IsWarmupActive() || config.trinityStickerUiOverride === true;
}

function GetLocalHeroLevel() {
    const playerID = Players.GetLocalPlayer();
    if (playerID < 0) {
        return 0;
    }

    return Players.GetLevel(playerID) || 0;
}

function RememberWarmupEndTime(remaining) {
    remaining = Number(remaining);
    if (isNaN(remaining)) {
        return;
    }

    config.trinityWarmupRemaining = remaining;
    config.trinityWarmupEndTime = Game.Time() + Math.max(0, remaining);
}

function GetRemainingWarmupSeconds() {
    const endTime = Number(config.trinityWarmupEndTime);
    if (!isNaN(endTime) && endTime > 0) {
        return Math.max(0, endTime - Game.Time());
    }

    return Math.max(0, Number(config.trinityWarmupRemaining) || 0);
}

function FormatWarmupTime(seconds) {
    seconds = Math.max(0, Math.ceil(seconds));
    const minutes = Math.floor(seconds / 60);
    const rest = seconds % 60;
    return minutes + ":" + (rest < 10 ? "0" : "") + rest;
}

function UpdateVisibility() {
    const column = $("#WarmupColumn");
    if (!column) {
        return;
    }

    const canUseWidget = IsLocalPlayerOnMatchTeam() && HasLocalHero();
    const warmupVisible = canUseWidget && IsWarmupActive();
    const stickerUiVisible = canUseWidget && IsStickerUiAvailable();
    const columnVisible = warmupVisible || stickerUiVisible;
    const stickers = $("#WarmupStickers");
    const lootboxes = $("#WarmupLootboxes");
    const warmup = $("#WarmupWidget");

    column.SetHasClass("Hidden", !columnVisible);
    column.hittest = columnVisible;
    column.hittestchildren = columnVisible;
    if (stickers) {
        stickers.SetHasClass("Hidden", !stickerUiVisible);
    }
    if (lootboxes) {
        lootboxes.SetHasClass("Hidden", !stickerUiVisible || !LOOTBOXES_ENABLED);
    }
    if (warmup) {
        warmup.SetHasClass("Hidden", !warmupVisible);
    }
}

function UpdateLevelButtons() {
    const atMax = GetLocalHeroLevel() >= MAX_HERO_LEVEL;
    const canLevel = IsWarmupActive() && !atMax;
    const levelUp = $("#WarmupLevelUp");
    const maxLevel = $("#WarmupMaxLevel");

    if (levelUp) {
        levelUp.enabled = canLevel;
    }
    if (maxLevel) {
        maxLevel.enabled = canLevel;
    }
}

function UpdateTimer() {
    const timer = $("#WarmupTimer");
    if (!timer) {
        return;
    }

    timer.text = FormatWarmupTime(GetRemainingWarmupSeconds());
}

function SendWarmupCommand(eventName) {
    if (!IsWarmupActive() || !IsLocalPlayerOnMatchTeam()) {
        return;
    }

    GameEvents.SendCustomGameEventToServer(eventName, {});
}

function OnLevelUp() {
    SendWarmupCommand("trinity_warmup_level_up");
}

function OnMaxLevel() {
    SendWarmupCommand("trinity_warmup_max_level");
}

function OnRefresh() {
    SendWarmupCommand("trinity_warmup_refresh");
}

function ParseFinishVotes(voted) {
    const set = {};
    if (voted == null || voted === "") {
        return set;
    }

    const parts = String(voted).split(",");
    for (let i = 0; i < parts.length; i++) {
        if (parts[i] !== "") {
            set[Number(parts[i])] = true;
        }
    }
    return set;
}

function UpdateFinishButton() {
    const button = $("#WarmupFinish");
    const count = $("#WarmupFinishCount");
    if (!button) {
        return;
    }

    const data = CustomNetTables.GetTableValue("trinity_warmup", "finish_vote") || {};
    const ready = Number(data.ready) || 0;
    const total = Number(data.total) || 0;
    const hasVoted = ParseFinishVotes(data.voted)[Players.GetLocalPlayer()] === true;

    if (count) {
        count.text = ready + "/" + total;
    }
    button.SetHasClass("Voted", hasVoted);
    button.enabled = IsWarmupActive() && !hasVoted;
}

function OnFinishWarmup() {
    const button = $("#WarmupFinish");
    if (!button || button.BHasClass("Voted") || !button.enabled) {
        return;
    }

    button.SetHasClass("Voted", true);
    button.enabled = false;
    SendWarmupCommand("trinity_warmup_finish");
}

function OnOpenStickers() {
    if (typeof config.TrinityOpenStickerEditor === "function") {
        config.TrinityOpenStickerEditor();
    }
}

function OnOpenLootbox() {
    if (typeof config.TrinityOpenLootbox === "function") {
        config.TrinityOpenLootbox();
    }
}

function Tick() {
    if (!CONTEXT || !CONTEXT.IsValid()) {
        return;
    }
    if (config[TICK_GEN_KEY] !== tickGen) {
        return;
    }

    UpdateVisibility();
    UpdateLevelButtons();
    UpdateFinishButton();
    UpdateTimer();
    $.Schedule(0.1, Tick);
}

function Init() {
    const levelUp = $("#WarmupLevelUp");
    const maxLevel = $("#WarmupMaxLevel");
    const refresh = $("#WarmupRefresh");
    const finish = $("#WarmupFinish");
    const stickers = $("#WarmupStickers");
    const lootboxes = $("#WarmupLootboxes");

    if (stickers) {
        stickers.SetPanelEvent("onactivate", OnOpenStickers);
    }
    if (lootboxes) {
        lootboxes.SetPanelEvent("onactivate", OnOpenLootbox);
    }
    if (levelUp) {
        levelUp.SetPanelEvent("onactivate", OnLevelUp);
    }
    if (maxLevel) {
        maxLevel.SetPanelEvent("onactivate", OnMaxLevel);
    }
    if (refresh) {
        refresh.SetPanelEvent("onactivate", OnRefresh);
    }
    if (finish) {
        finish.SetPanelEvent("onactivate", OnFinishWarmup);
    }

    CustomNetTables.SubscribeNetTableListener("trinity_warmup", function (_table, key) {
        if (key === "finish_vote") {
            UpdateFinishButton();
        }
    });

    GameEvents.Subscribe("trinity_warmup_started", function (event) {
        const playerID = Players.GetLocalPlayer();
        if (event && event.player_id != null && Number(event.player_id) !== playerID) {
            return;
        }
        config.trinityWarmupActive = true;
        if (event) {
            RememberWarmupEndTime(event.remaining);
        }
        UpdateVisibility();
        UpdateLevelButtons();
        UpdateFinishButton();
        UpdateTimer();
    });

    // Draft ended: warmup gets its full time again.
    GameEvents.Subscribe("trinity_warmup_timer", function (event) {
        if (!IsWarmupActive() || !event) {
            return;
        }
        RememberWarmupEndTime(event.remaining);
        UpdateTimer();
    });

    GameEvents.Subscribe("trinity_warmup_ended", function () {
        config.trinityWarmupActive = false;
        config.trinityWarmupRemaining = 0;
        config.trinityWarmupEndTime = 0;
        UpdateVisibility();
        UpdateLevelButtons();
        UpdateFinishButton();
        UpdateTimer();
    });

    GameEvents.Subscribe("trinity_sticker_ui_override", function (event) {
        config.trinityStickerUiOverride = !!event
            && (event.enabled === true || Number(event.enabled) === 1);
        if (!IsStickerUiAvailable()) {
            if (typeof config.TrinityCloseStickerEditor === "function") {
                config.TrinityCloseStickerEditor();
            }
            if (typeof config.TrinityCloseLootbox === "function") {
                config.TrinityCloseLootbox();
            }
        }
        UpdateVisibility();
    });

    UpdateVisibility();
    UpdateLevelButtons();
    UpdateFinishButton();
    UpdateTimer();
    Tick();
}

Init();
