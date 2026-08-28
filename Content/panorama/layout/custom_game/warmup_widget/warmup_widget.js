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
        lootboxes.SetHasClass("Hidden", !stickerUiVisible);
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
    UpdateTimer();
    $.Schedule(0.1, Tick);
}

function Init() {
    const levelUp = $("#WarmupLevelUp");
    const maxLevel = $("#WarmupMaxLevel");
    const refresh = $("#WarmupRefresh");
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
        UpdateTimer();
    });

    GameEvents.Subscribe("trinity_warmup_ended", function () {
        config.trinityWarmupActive = false;
        config.trinityWarmupRemaining = 0;
        config.trinityWarmupEndTime = 0;
        UpdateVisibility();
        UpdateLevelButtons();
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
    UpdateTimer();
    Tick();
}

Init();
