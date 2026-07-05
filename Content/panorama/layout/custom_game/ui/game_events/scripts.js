const PANEL_TITLE = $("#GameEventTitle");
const HERO_KILL_GOLD_REWARD = 1;
const KILLFEED_PATCH_RETRY_DELAYS = [0.03, 0.08, 0.16, 0.32];
let cachedDotaHud = null;

function DebugMsg(message) {
}

DebugMsg("script loaded");

function NumberOr(value, fallback) {
    const number = Number(value);
    return isNaN(number) ? (fallback || 0) : number;
}

function SafeString(value) {
    if (value === null || value === undefined) return "";
    return String(value);
}

function NormalizeText(value) {
    return SafeString(value).toLowerCase().replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
}

function LocalizeUnitName(unitName) {
    unitName = SafeString(unitName);
    if (!unitName) return "";

    const token = unitName.indexOf("#") === 0 ? unitName : "#" + unitName;
    const localized = $.Localize(token);
    return localized && localized !== token ? localized : unitName;
}

function SafePlayerID(value) {
    return Math.floor(NumberOr(value, -1));
}

function GetPlayerInfo(playerID) {
    try {
        if (playerID >= 0 && typeof Game !== "undefined" && Game.GetPlayerInfo) {
            return Game.GetPlayerInfo(playerID);
        }
    } catch (error) {
    }

    return null;
}

function GetPlayerName(playerID) {
    try {
        if (playerID >= 0 && typeof Players !== "undefined" && Players.GetPlayerName) {
            const playerName = Players.GetPlayerName(playerID);
            if (playerName) return playerName;
        }
    } catch (error) {
    }

    const playerInfo = GetPlayerInfo(playerID);
    if (playerInfo && playerInfo.player_name) return playerInfo.player_name;

    return "";
}

function GetRootPanel() {
    return $.GetContextPanel();
}

function FindDotaHud() {
    if (cachedDotaHud && cachedDotaHud.IsValid && cachedDotaHud.IsValid()) {
        return cachedDotaHud;
    }

    let panel = GetRootPanel();
    while (panel) {
        if (panel.id === "DotaHud") {
            cachedDotaHud = panel;
            return panel;
        }
        panel = panel.GetParent ? panel.GetParent() : null;
    }
    return null;
}

function FindHudElement(id) {
    const hud = FindDotaHud();
    return hud && hud.FindChildTraverse ? hud.FindChildTraverse(id) : null;
}

function IsCombatEventRow(panel) {
    if (!panel || !panel.IsValid || !panel.IsValid()) return false;
    if (panel.paneltype === "DOTACombatEventRow") return true;
    if (panel.BHasClass && panel.BHasClass("ToastPanel") && panel.FindChildTraverse && panel.FindChildTraverse("EventLabel")) {
        return true;
    }

    return false;
}

function CollectCombatRows(panel, rows) {
    if (!panel || !panel.IsValid || !panel.IsValid()) return;

    if (IsCombatEventRow(panel)) {
        rows.push(panel);
    }

    if (!panel.GetChildCount || !panel.GetChild) return;

    for (let index = 0; index < panel.GetChildCount(); index++) {
        CollectCombatRows(panel.GetChild(index), rows);
    }
}

function GetCombatRows() {
    const rows = [];
    const roots = [
        FindHudElement("ToastManager"),
        FindHudElement("ToastLinesWrapper"),
        FindHudElement("combat_events"),
        FindHudElement("DOTACombatEvents")
    ];

    for (let index = 0; index < roots.length; index++) {
        CollectCombatRows(roots[index], rows);
    }

    const uniqueRows = [];
    for (let index = 0; index < rows.length; index++) {
        if (uniqueRows.indexOf(rows[index]) < 0) {
            uniqueRows.push(rows[index]);
        }
    }

    return uniqueRows;
}

function CollectPanelText(panel, parts) {
    if (!panel || !panel.IsValid || !panel.IsValid()) return;

    if (panel.text !== undefined && panel.text !== "") {
        parts.push(panel.text);
    }

    if (!panel.GetChildCount || !panel.GetChild) return;

    for (let index = 0; index < panel.GetChildCount(); index++) {
        CollectPanelText(panel.GetChild(index), parts);
    }
}

function RowText(row) {
    const parts = [];
    CollectPanelText(row, parts);
    return NormalizeText(parts.join(" "));
}

function RowMatchesKill(row, data) {
    const text = RowText(row);
    if (!text) return false;

    const killerPlayer = SafePlayerID(data.killer_player);
    const killedPlayer = SafePlayerID(data.killed_player);
    const candidates = [
        data.killer_name,
        data.killed_name,
        GetPlayerName(killerPlayer),
        GetPlayerName(killedPlayer),
        data.killer_hero,
        data.killed_hero,
        LocalizeUnitName(data.killer_hero),
        LocalizeUnitName(data.killed_hero)
    ].map(NormalizeText).filter(Boolean);

    let matches = 0;
    for (let index = 0; index < candidates.length; index++) {
        if (text.indexOf(candidates[index]) >= 0) matches++;
    }

    return matches >= 1;
}

function FindEventLabel(row) {
    return row && row.FindChildTraverse ? row.FindChildTraverse("EventLabel") : null;
}

function FindNameSpans(text, names) {
    const lowerText = SafeString(text).toLowerCase();
    const spans = [];

    for (let nameIndex = 0; nameIndex < names.length; nameIndex++) {
        const name = SafeString(names[nameIndex]).toLowerCase();
        if (!name) continue;

        let searchFrom = 0;
        while (searchFrom < lowerText.length) {
            const start = lowerText.indexOf(name, searchFrom);
            if (start < 0) break;

            spans.push({
                start: start,
                end: start + name.length
            });
            searchFrom = start + Math.max(1, name.length);
        }
    }

    return spans;
}

function NumberTouchesNameSpan(start, end, spans) {
    for (let index = 0; index < spans.length; index++) {
        const span = spans[index];
        if (start < span.end && end > span.start) return true;
    }

    return false;
}

function FindRewardNumberOutsideNames(text, names) {
    text = SafeString(text);
    const spans = FindNameSpans(text, names);
    const numberPattern = /[+-]?\d+/g;
    let match = null;

    while ((match = numberPattern.exec(text)) !== null) {
        const start = match.index;
        const end = start + match[0].length;
        if (!NumberTouchesNameSpan(start, end, spans)) {
            return {
                start: start,
                end: end,
                value: match[0]
            };
        }
    }

    return null;
}

function ReplaceRewardNumberOutsideNames(text, amount, names) {
    text = SafeString(text);
    const rewardMatch = FindRewardNumberOutsideNames(text, names);
    if (!rewardMatch) return text;

    const replacement = rewardMatch.value.indexOf("+") === 0
        ? "+" + String(amount)
        : String(amount);

    return text.substring(0, rewardMatch.start) + replacement + text.substring(rewardMatch.end);
}

function EscapeLabelText(value) {
    return SafeString(value)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;");
}

function EscapeAttribute(value) {
    return EscapeLabelText(value)
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");
}

function GetPlayerColorHex(playerID) {
    try {
        if (playerID >= 0 && typeof Players !== "undefined" && Players.GetPlayerColor) {
            let color = Players.GetPlayerColor(playerID).toString(16);
            while (color.length < 8) color = "0" + color;
            color = color.substring(6, 8) + color.substring(4, 6) + color.substring(2, 4) + color.substring(0, 2);
            return "#" + color;
        }
    } catch (error) {
    }

    return "";
}

function BuildColoredNameMarkup(name, playerID) {
    name = EscapeLabelText(name);
    const color = GetPlayerColorHex(playerID);
    if (!color) return name;

    return "<font color='" + color + "'>" + name + "</font>";
}

function GetPlayerNamesFromEvent(data) {
    const killerPlayer = SafePlayerID(data.killer_player);
    const killedPlayer = SafePlayerID(data.killed_player);

    return [
        data.killer_name,
        data.killed_name,
        GetPlayerName(killerPlayer),
        GetPlayerName(killedPlayer)
    ].filter(Boolean);
}

function GetPlayerNameForEvent(data, key) {
    const playerID = SafePlayerID(data[key + "_player"]);
    return SafeString(data[key + "_name"]) || GetPlayerName(playerID);
}

function ExtractNamesFromEventLabelText(text, rewardMatch) {
    text = SafeString(text);
    const beforeReward = rewardMatch ? text.substring(0, rewardMatch.start) : text;
    const parts = beforeReward.trim().split(/\s{2,}/).filter(Boolean);

    if (parts.length >= 2) {
        return {
            killer: parts[0],
            victim: parts[parts.length - 1]
        };
    }

    const words = beforeReward.trim().split(/\s+/).filter(Boolean);
    return {
        killer: words[0] || "",
        victim: words.length > 1 ? words[words.length - 1] : ""
    };
}

function GetChildImageSource(panel) {
    if (!panel) return "";

    try {
        if (panel.GetAttributeString) {
            const src = panel.GetAttributeString("src", "");
            if (src) return src;

            const defaultSrc = panel.GetAttributeString("defaultsrc", "");
            if (defaultSrc) return defaultSrc;
        }
    } catch (error) {
    }

    try {
        if (panel.src) return panel.src;
    } catch (error) {
    }

    return "";
}

function BuildHeroIconSource(heroName) {
    heroName = SafeString(heroName);
    if (!heroName) return "";

    return "file://{images}/heroes/icons/" + heroName + ".png";
}

function GetKnownChildClasses(child) {
    const knownClasses = [
        "InlineImage",
        "CombatEventHeroIcon",
        "InlinePanel",
        "CombatEventKillIcon",
        "CombatEventGoldIcon",
        "CombatEventAssistIcon",
        "CombatEventAbilityIcon",
        "CombatEventItemIcon"
    ];
    const result = [];

    for (let index = 0; index < knownClasses.length; index++) {
        const className = knownClasses[index];
        if (child.BHasClass && child.BHasClass(className)) {
            result.push(className);
        }
    }

    return result.join(" ");
}

function GetChildClasses(child) {
    try {
        if (child.GetClasses) {
            const classes = child.GetClasses();
            if (classes) return classes;
        }
    } catch (error) {
    }

    return GetKnownChildClasses(child);
}

function PanelHasClassName(child, classes, className) {
    try {
        if (child.BHasClass && child.BHasClass(className)) return true;
    } catch (error) {
    }

    return (" " + SafeString(classes) + " ").indexOf(" " + className + " ") >= 0;
}

function BuildInlineChildMarkup(child, classes, fallbackSrc) {
    if (!child || !child.IsValid || !child.IsValid()) return "";

    const classAttribute = classes ? " class='" + EscapeAttribute(classes) + "'" : "";

    if (child.paneltype === "Image" || PanelHasClassName(child, classes, "InlineImage")) {
        const src = GetChildImageSource(child) || SafeString(fallbackSrc);
        const srcAttribute = src ? " src='" + EscapeAttribute(src) + "'" : "";
        return "<img" + classAttribute + srcAttribute + "/>";
    }

    return "<panel" + classAttribute + "/>";
}

function CollectInlineChildMarkups(eventLabel, data) {
    const markups = [];
    let heroIconIndex = 0;

    if (eventLabel && eventLabel.GetChildCount && eventLabel.GetChild) {
        for (let index = 0; index < eventLabel.GetChildCount(); index++) {
            const child = eventLabel.GetChild(index);
            if (!child || !child.IsValid || !child.IsValid()) continue;

            const classes = GetChildClasses(child);
            const isHero = PanelHasClassName(child, classes, "CombatEventHeroIcon");
            const isGold = PanelHasClassName(child, classes, "CombatEventGoldIcon");
            const fallbackSrc = isHero
                ? BuildHeroIconSource(heroIconIndex++ === 0 ? data.killer_hero : data.killed_hero)
                : "";

            markups.push({
                markup: BuildInlineChildMarkup(child, classes, fallbackSrc),
                isGold: isGold,
                isHero: isHero,
                isKill: PanelHasClassName(child, classes, "CombatEventKillIcon")
            });
        }
    }

    return markups;
}

function RemoveFirstTextOccurrence(text, needle) {
    text = SafeString(text);
    needle = SafeString(needle);
    if (!needle) return text;

    const index = text.toLowerCase().indexOf(needle.toLowerCase());
    if (index < 0) return text;

    return text.substring(0, index) + text.substring(index + needle.length);
}

function ExtractExtraTextBeforeReward(oldText, rewardMatch, killerName, victimName) {
    let text = rewardMatch ? SafeString(oldText).substring(0, rewardMatch.start) : SafeString(oldText);
    text = RemoveFirstTextOccurrence(text, killerName);
    text = RemoveFirstTextOccurrence(text, victimName);
    return text.replace(/\s+/g, " ").trim();
}

function ExtractTextAfterReward(oldText, rewardMatch) {
    if (!rewardMatch) return "";

    return SafeString(oldText)
        .substring(rewardMatch.end)
        .replace(/\s+/g, " ")
        .trim();
}

function BuildRewardMarkup(amount, assistAmount, goldIcon, afterRewardText) {
    afterRewardText = SafeString(afterRewardText).replace(/\s+/g, " ").trim();

    const assistRewardMatch = afterRewardText.match(/^(\+\s*\d+)(.*)$/);
    if (assistRewardMatch) {
        const assistGold = assistAmount !== null
            ? "+" + String(assistAmount)
            : assistRewardMatch[1].replace(/\s+/g, " ").trim();
        const assistTail = assistRewardMatch[2].replace(/\s+/g, " ").trim();

        return String(amount)
            + " "
            + goldIcon
            + " "
            + EscapeLabelText(assistGold)
            + " "
            + goldIcon
            + (assistTail ? " " + EscapeLabelText(assistTail) : "");
    }

    if (assistAmount !== null) {
        return String(amount)
            + " "
            + goldIcon
            + " +"
            + String(assistAmount)
            + " "
            + goldIcon
            + (afterRewardText ? " " + EscapeLabelText(afterRewardText) : "");
    }

    return String(amount)
        + " "
        + goldIcon
        + (afterRewardText ? " " + EscapeLabelText(afterRewardText) : "");
}

function BuildCombatEventLabelMarkup(oldText, amount, data, rewardMatch, eventLabel) {
    const fallbackNames = ExtractNamesFromEventLabelText(oldText, rewardMatch);
    const killerName = GetPlayerNameForEvent(data, "killer") || fallbackNames.killer;
    const victimName = GetPlayerNameForEvent(data, "killed") || fallbackNames.victim;
    const killerPlayerID = SafePlayerID(data && data.killer_player);
    const victimPlayerID = SafePlayerID(data && data.killed_player);
    const assistCount = NumberOr(data && data.assist_count, 0);
    const assistAmount = assistCount > 0 && data && data.assist_gold !== undefined
        ? NumberOr(data.assist_gold, 0)
        : null;
    const extraText = ExtractExtraTextBeforeReward(oldText, rewardMatch, killerName, victimName);
    const afterRewardText = ExtractTextAfterReward(oldText, rewardMatch);
    const inlineChildren = CollectInlineChildMarkups(eventLabel, data || {});
    let goldIndex = -1;

    for (let index = inlineChildren.length - 1; index >= 0; index--) {
        if (inlineChildren[index].isGold || inlineChildren[index].markup.indexOf("CombatEventGoldIcon") >= 0) {
            goldIndex = index;
            break;
        }
    }

    const eventIcons = inlineChildren
        .filter(function (child) { return !child.isGold && child.markup.indexOf("CombatEventGoldIcon") < 0; })
        .map(function (child) { return child.markup; })
        .filter(Boolean)
        .join(" ");
    const goldIcon = goldIndex >= 0
        ? inlineChildren[goldIndex].markup
        : "<panel class='CombatEventGoldIcon'/>";

    return " "
        + BuildColoredNameMarkup(killerName, killerPlayerID)
        + " "
        + eventIcons
        + " "
        + BuildColoredNameMarkup(victimName, victimPlayerID)
        + (extraText ? " " + EscapeLabelText(extraText) : "")
        + " "
        + BuildRewardMarkup(amount, assistAmount, goldIcon, afterRewardText)
        + " ";
}

function TryDialogVariablePatch(row, eventLabel, amount) {
    const variableNames = [
        "gold",
        "gold_amount",
        "bounty",
        "amount",
        "value",
        "reward",
        "event_value"
    ];
    const targets = [row, eventLabel].filter(Boolean);

    for (let targetIndex = 0; targetIndex < targets.length; targetIndex++) {
        const target = targets[targetIndex];
        for (let nameIndex = 0; nameIndex < variableNames.length; nameIndex++) {
            const name = variableNames[nameIndex];

            if (target.SetDialogVariableInt) {
                target.SetDialogVariableInt(name, amount);
            }
            if (target.SetDialogVariable) {
                target.SetDialogVariable(name, String(amount));
            }
        }
    }
}

function PatchEventLabelReward(row, amount, data) {
    const eventLabel = FindEventLabel(row);
    if (!eventLabel || eventLabel.text === undefined) {
        DebugMsg("EventLabel not found on matched row");
        return false;
    }

    const oldText = SafeString(eventLabel.text);
    const names = GetPlayerNamesFromEvent(data || {});
    const rewardMatch = FindRewardNumberOutsideNames(oldText, names);
    const childCount = eventLabel.GetChildCount ? eventLabel.GetChildCount() : 0;

    TryDialogVariablePatch(row, eventLabel, amount);

    if (!rewardMatch) {
        DebugMsg("no reward number outside player names; EventLabel='" + oldText + "' children=" + childCount);
        return false;
    }

    if (NumberOr(rewardMatch.value, -1) === amount) {
        DebugMsg("EventLabel already has reward " + amount + ": '" + oldText + "' children=" + childCount);
        return true;
    }

    if (childCount > 0) {
        const newMarkup = BuildCombatEventLabelMarkup(oldText, amount, data || {}, rewardMatch, eventLabel);
        eventLabel.text = newMarkup;
        eventLabel.style.textOverflow = "shrink";
        DebugMsg("patched EventLabel with inline markup: '" + oldText + "' -> '" + newMarkup + "'");
        return true;
    }

    const newText = ReplaceRewardNumberOutsideNames(oldText, amount, names);
    if (newText === oldText) {
        DebugMsg("EventLabel text unchanged: " + oldText);
        return false;
    }

    eventLabel.text = newText;
    eventLabel.style.textOverflow = "shrink";
    DebugMsg("patched plain EventLabel: '" + oldText + "' -> '" + newText + "'");
    return true;
}

function TryPatchNativeKillfeed(data, allowFallback) {
    if (data && data.__trinityKillfeedPatched === true) return true;

    const rows = GetCombatRows();
    const amount = NumberOr(data && data.gold, HERO_KILL_GOLD_REWARD);
    DebugMsg("patch attempt rows=" + rows.length + " fallback=" + (allowFallback === true ? "true" : "false"));

    for (let index = rows.length - 1; index >= 0; index--) {
        const row = rows[index];
        if (!row || row.__trinityHeroKillGoldPatched === true) continue;
        if (!RowMatchesKill(row, data)) continue;

        DebugMsg("matched row by event data at index=" + index);
        row.__trinityHeroKillGoldPatched = PatchEventLabelReward(row, amount, data);
        if (row.__trinityHeroKillGoldPatched) data.__trinityKillfeedPatched = true;
        return row.__trinityHeroKillGoldPatched;
    }

    if (allowFallback !== true) {
        DebugMsg("no matching row yet");
        return false;
    }

    for (let index = rows.length - 1; index >= 0; index--) {
        const row = rows[index];
        if (!row || row.__trinityHeroKillGoldPatched === true) continue;

        DebugMsg("using fallback row at index=" + index);
        row.__trinityHeroKillGoldPatched = PatchEventLabelReward(row, amount, data);
        if (row.__trinityHeroKillGoldPatched) data.__trinityKillfeedPatched = true;
        return row.__trinityHeroKillGoldPatched;
    }

    DebugMsg("no unpatched combat rows found");
    return false;
}

function ScheduleNativeKillfeedPatch(data) {
    DebugMsg(
        "event received killer_id=" + SafeString(data && data.killer_player)
        + " killed_id=" + SafeString(data && data.killed_player)
        + " killer='" + SafeString(data && data.killer_name)
        + "' killed='" + SafeString(data && data.killed_name)
        + "' killer_hero='" + SafeString(data && data.killer_hero)
        + "' killed_hero='" + SafeString(data && data.killed_hero)
        + "' killed_level=" + SafeString(data && data.killed_level)
        + " assist_gold=" + SafeString(data && data.assist_gold)
        + " assist_count=" + SafeString(data && data.assist_count)
        + " gold=" + SafeString(data && data.gold)
    );

    for (let index = 0; index < KILLFEED_PATCH_RETRY_DELAYS.length; index++) {
        const delay = KILLFEED_PATCH_RETRY_DELAYS[index];
        const allowFallback = index >= 2;

        $.Schedule(delay, function () {
            TryPatchNativeKillfeed(data || {}, allowFallback);
        });
    }
}

GameEvents.Subscribe("draw_game_event", ({
    color = "white",
    duration = 3,
    sound_event = "_game_events.template_sound_event",
    text_token = "TEMPLATE TITLE TEXT",
}) => {
    PANEL_TITLE.AddClass("IsDraw");
    PANEL_TITLE.text = $.Localize(text_token);
    PANEL_TITLE.style.washColor = color;

    $.Schedule(duration, () => PANEL_TITLE.RemoveClass("IsDraw"));
    Game.EmitSound(sound_event);
});

GameEvents.Subscribe("trinity_kill_toast", ScheduleNativeKillfeedPatch);
