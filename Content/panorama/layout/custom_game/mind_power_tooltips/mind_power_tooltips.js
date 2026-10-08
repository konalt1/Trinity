"use strict";

// Mind Power display in ability tooltips.
// Adapted from Cykada's spell mastery tooltips (tooltips.js), which in turn is based on
// https://github.com/JoyfulShush/dota-reimagined (content/panorama/scripts/custom_game/tooltips.ts).
//
// For abilities listed in MIND_POWER_RULES (game_managers/custom_ability_tooltips.lua) the
// native description and attribute list are replaced with our own block:
//   * every Mind Power scaled value gets "(+100% <icon>)";
//   * while Alt is held the value shows without Mind Power and the flat bonus is shown instead;
//   * the current ability level is highlighted, scaled damage/heal is coloured.
// Numbers come from the engine (client override in abilities/mind_power.lua), rules and raw
// AbilityValues from the "mind_power_tooltips" net table. Any other ability keeps the native tooltip.

(function () {
    const NET_TABLE = "mind_power_tooltips";
    const MIND_POWER_TABLE = "mind_power";
    const BLOCK_ID = "TrinityMindPowerTooltip";
    const BLOCK_LAYOUT = "file://{resources}/layout/custom_game/mind_power_tooltips/mind_power_tooltip_block.xml";
    const ICON = "file://{images}/custom_game/icons/mind_power_tooltip.png";
    const TOKEN_PREFIX = "DOTA_Tooltip_ability_";
    const POLL_INTERVAL = 0.03;
    const MAX_NOTES = 6;
    const NO_UNIT = -1;
    const PORTRAIT_UNIT = -2;
    const DEFAULT_WIDTH = 330;

    const config = GameUI.CustomUIConfig();
    const generation = (config.trinityMindPowerTooltipGeneration || 0) + 1;
    config.trinityMindPowerTooltipGeneration = generation;

    const state = {
        shown: false,
        abilityName: "",
        unit: -1,
        signature: "",
        ownsNative: false,
        width: 0,
        lastError: "",
    };

    // ------------------------------------------------------------------
    // Panels
    // ------------------------------------------------------------------

    function rootPanel() {
        let panel = $.GetContextPanel();
        while (panel && panel.GetParent()) {
            panel = panel.GetParent();
        }
        return panel;
    }

    function findDescriptionOuter() {
        const root = rootPanel();
        if (!root) return null;
        const tooltips = root.FindChildTraverse("Tooltips");
        if (!tooltips) return null;
        const tooltip = tooltips.FindChildTraverse("DOTAAbilityTooltip");
        if (!tooltip) return null;
        return tooltip.FindChildTraverse("AbilityDescriptionOuterContainer");
    }

    function nativeParts(outer) {
        const parent = outer.GetParent();
        return {
            description: outer.FindChildTraverse("AbilityDescriptionContainer"),
            attributes: parent ? parent.FindChildTraverse("AbilityExtraAttributes") : null,
        };
    }

    function setShown(panel, shown) {
        if (!panel) return;
        panel.visible = shown;
        panel.enabled = shown;
    }

    function findBlock(outer) {
        return outer.FindChild(BLOCK_ID);
    }

    function restoreNative(outer) {
        if (!outer) return;
        const block = findBlock(outer);
        if (block) {
            block.RemoveAndDeleteChildren();
            block.visible = false;
        }
        if (state.ownsNative) {
            const parts = nativeParts(outer);
            setShown(parts.description, true);
            setShown(parts.attributes, true);
            state.ownsNative = false;
        }
        state.signature = "";
    }

    function layoutWidth(panel) {
        if (!panel || !panel.visible) return 0;
        const scale = panel.actualuiscale_x || 1;
        const width = panel.actuallayoutwidth || 0;
        return width > 0 ? Math.round(width / scale) : 0;
    }

    // The tooltip sizes itself by content, so a 100% wide block collapses to zero.
    // Take the width of the native description (or its container) while it is still visible.
    function blockWidth(outer, parts) {
        const measured = layoutWidth(parts.description) || layoutWidth(parts.attributes) || layoutWidth(outer);
        if (measured > 50) state.width = measured;
        return state.width || DEFAULT_WIDTH;
    }

    function prepareBlock(outer, parts, keepNativeDescription) {
        const width = blockWidth(outer, parts);
        let block = findBlock(outer);
        if (!block) {
            block = $.CreatePanel("Panel", outer, BLOCK_ID);
            block.BLoadLayout(BLOCK_LAYOUT, false, false);
        }
        block.AddClass("MindPowerTooltip");
        block.RemoveAndDeleteChildren();
        block.style.width = width + "px";
        block.visible = true;

        // Keep our block where the native description is, above Scepter/Shard blocks.
        const anchor = parts.description;
        if (anchor && anchor.GetParent() === outer) {
            if (keepNativeDescription) outer.MoveChildAfter(block, anchor);
            else outer.MoveChildBefore(block, anchor);
        }
        return block;
    }

    function hideNative(parts, keepNativeDescription) {
        setShown(parts.description, keepNativeDescription);
        setShown(parts.attributes, false);
        state.ownsNative = true;
    }

    // ------------------------------------------------------------------
    // Values
    // ------------------------------------------------------------------

    function localize(token) {
        const localized = $.Localize("#" + token);
        if (!localized || localized === "#" + token || localized === token) return null;
        return localized;
    }

    // Mind Power is fractional (intellect), so scaled values get long tails like 50.26.
    // Keep precision where it matters: 92 / 50.3 / 5.36 / 0.25.
    function formatNumber(value) {
        const number = Number(value);
        if (!isFinite(number)) return String(value);
        const magnitude = Math.abs(number);
        const factor = magnitude >= 100 ? 1 : magnitude >= 10 ? 10 : 100;
        const rounded = Math.round(number * factor) / factor;
        return String(rounded);
    }

    function levelStrings(raw) {
        if (raw === undefined || raw === null) return [];
        return String(raw).trim().split(/\s+/).filter((part) => part.length > 0);
    }

    function entryRaw(entry) {
        if (entry !== null && typeof entry === "object") return entry.value;
        return entry;
    }

    function entryHasTalent(entry) {
        if (entry === null || typeof entry !== "object") return false;
        return Object.keys(entry).some((key) => key.indexOf("special_bonus") === 0);
    }

    function entryRequires(entry, key) {
        if (entry === null || typeof entry !== "object") return false;
        return Number(entry[key]) === 1;
    }

    function unitHasBuff(unit, name) {
        if (unit === undefined || unit < 0) return false;
        const count = Entities.GetNumBuffs(unit);
        for (let i = 0; i < count; i++) {
            const buff = Entities.GetBuff(unit, i);
            if (buff !== -1 && Buffs.GetName(unit, buff) === name) return true;
        }
        return false;
    }

    function mindPowerFor(unit) {
        if (unit === undefined || unit < 0) return 0;

        let hero = unit;
        if (!Entities.IsRealHero(unit)) {
            // Chen's hunters and other summons scale from the owner's Mind Power.
            const playerId = Entities.GetPlayerOwnerID(unit);
            if (playerId !== undefined && playerId >= 0) {
                const heroIndex = Players.GetPlayerHeroEntityIndex(playerId);
                if (heroIndex !== undefined && heroIndex >= 0) hero = heroIndex;
            }
        }

        const row = CustomNetTables.GetTableValue(MIND_POWER_TABLE, String(hero));
        return row ? Number(row.value) || 0 : 0;
    }

    function damageSuffix(damageType) {
        const text = String(damageType || "");
        if (text.indexOf("PHYSICAL") !== -1) return "Phy";
        if (text.indexOf("MAGICAL") !== -1) return "Mag";
        if (text.indexOf("PURE") !== -1) return "Pure";
        return "";
    }

    function abilityDamageSuffix(ctx) {
        if (ctx.inGame) {
            switch (Abilities.GetAbilityDamageType(ctx.ability)) {
                case DAMAGE_TYPES.DAMAGE_TYPE_PHYSICAL: return "Phy";
                case DAMAGE_TYPES.DAMAGE_TYPE_MAGICAL: return "Mag";
                case DAMAGE_TYPES.DAMAGE_TYPE_PURE: return "Pure";
            }
        }
        return damageSuffix(ctx.data.damage_type);
    }

    function colourFor(ctx, key) {
        if (!ctx.rules[key]) return "";
        if (/heal/i.test(key)) return "Heal";
        if (/damage|dmg/i.test(key)) return ctx.damageSuffix;
        return "";
    }

    function buildContext(abilityName, unit, data) {
        const ability = unit >= 0 ? Entities.GetAbilityByName(unit, abilityName) : -1;
        const inGame = ability !== undefined && ability !== -1;

        const rules = {};
        const multiplierKeys = {};
        const rawRules = data.rules || {};
        Object.keys(rawRules).forEach((key) => {
            const rule = rawRules[key];
            rules[key] = rule;
            if (typeof rule === "string") multiplierKeys[rule] = true;
        });

        const ctx = {
            name: abilityName,
            data: data,
            values: data.values || {},
            rules: rules,
            multiplierKeys: multiplierKeys,
            unit: unit,
            ability: inGame ? ability : -1,
            inGame: inGame,
            level: inGame ? Abilities.GetLevel(ability) : 0,
            maxLevel: inGame ? Abilities.GetMaxLevel(ability) : 0,
            mindPower: inGame ? mindPowerFor(unit) : 0,
            alt: inGame && GameUI.IsAltDown(),
            hasShard: inGame && unitHasBuff(unit, "modifier_item_aghanims_shard"),
            hasScepter: inGame && Entities.HasScepter(unit),
        };
        ctx.damageSuffix = abilityDamageSuffix(ctx);
        return ctx;
    }

    function multiplierLevels(ctx, key) {
        const rule = ctx.rules[key];
        if (rule === undefined) return 0;
        if (typeof rule === "number") return 1;
        return levelStrings(entryRaw(ctx.values[rule])).length;
    }

    function multiplierAt(ctx, key, levelIndex) {
        const rule = ctx.rules[key];
        if (rule === undefined) return 0;
        if (typeof rule === "number") return rule;
        if (ctx.inGame) return Abilities.GetLevelSpecialValueFor(ctx.ability, rule, levelIndex);

        const levels = levelStrings(entryRaw(ctx.values[rule]));
        if (levels.length === 0) return 0;
        return Number(levels[Math.min(levelIndex, levels.length - 1)]) || 0;
    }

    function currentIndex(ctx) {
        return Math.max(ctx.level - 1, 0);
    }

    // Values of one key, one entry per level (or a single entry for flat keys).
    // withMindPower=false strips the Mind Power part so only the ability's own value is left.
    function keyValues(ctx, key, withMindPower) {
        const entry = ctx.values[key];
        const levels = levelStrings(entryRaw(entry));
        const multi = levels.length > 1 || multiplierLevels(ctx, key) > 1;
        const scaled = ctx.rules[key] !== undefined;
        const result = [];

        if (ctx.inGame) {
            const count = multi ? Math.max(ctx.maxLevel, levels.length, 1) : 1;
            for (let i = 0; i < count; i++) {
                const levelIndex = multi ? i : currentIndex(ctx);
                let value = Abilities.GetLevelSpecialValueFor(ctx.ability, key, levelIndex);
                if (scaled && !withMindPower) {
                    value -= ctx.mindPower * multiplierAt(ctx, key, levelIndex);
                }
                result.push(value);
            }
        } else if (levels.length > 0) {
            levels.forEach((level) => result.push(Number(level)));
        } else {
            result.push(0);
        }

        // A flat KV value stays one number even when only its Mind Power scaling grows by level
        // (Alt view of "800" with side bonus "5 6 7" must not read "800 / 800 / 800").
        if (levels.length <= 1 && result.length > 1 && result.every((value) => value === result[0])) {
            result.length = 1;
        }

        return { values: result, multi: result.length > 1 };
    }

    function valueSpan(value, colour, highlight) {
        const cls = "MPVal" + colour + (highlight ? "Lvl" : "");
        return `<span class='${cls}'>${value}</span>`;
    }

    function formatValueList(ctx, list, colour, decorate) {
        const current = ctx.inGame && ctx.level > 0 ? ctx.level - 1 : -1;
        return list.values
            .map((value, index) => {
                const highlight = !list.multi || index === current;
                return valueSpan(decorate(formatNumber(value)), colour, highlight);
            })
            .join(" / ");
    }

    function iconHtml() {
        return `<img class='MPIcon' src='${ICON}' />`;
    }

    function signed(value) {
        const number = Number(value);
        return (number < 0 ? "-" : "+") + formatNumber(Math.abs(number));
    }

    function mindPowerSuffix(ctx, key, list) {
        const current = ctx.inGame && ctx.level > 0 ? ctx.level - 1 : -1;
        // Scaling that grows with ability level is listed per level even when the value itself is flat.
        const perLevel = multiplierLevels(ctx, key) > 1;
        const levelCount = ctx.inGame ? Math.max(ctx.maxLevel, 1) : multiplierLevels(ctx, key);
        const count = perLevel ? (list.multi ? list.values.length : levelCount) : 1;

        if (ctx.alt) {
            // Flat bonus from the hero's current Mind Power.
            const parts = [];
            for (let i = 0; i < count; i++) {
                const levelIndex = perLevel ? i : currentIndex(ctx);
                const bonus = ctx.mindPower * multiplierAt(ctx, key, levelIndex);
                const highlight = !perLevel || i === current;
                parts.push(`<span class='${highlight ? "MPBonusLvl" : "MPBonus"}'>${signed(bonus)}</span>`);
            }
            return ` (${parts.join(" / ")}${iconHtml()})`;
        }

        const percents = [];
        for (let i = 0; i < count; i++) {
            percents.push(signed(multiplierAt(ctx, key, i) * 100));
        }
        return ` (${percents.join(" / ")}%${iconHtml()})`;
    }

    // ------------------------------------------------------------------
    // Attribute lines
    // ------------------------------------------------------------------

    function parseHeader(text) {
        let header = text;
        const flags = { percent: false, plus: false, minus: false };
        let changed = true;
        while (changed && header.length > 0) {
            changed = false;
            const first = header.charAt(0);
            if (first === "%") { flags.percent = true; header = header.substring(1); changed = true; }
            else if (first === "+") { flags.plus = true; header = header.substring(1); changed = true; }
            else if (first === "-") { flags.minus = true; header = header.substring(1); changed = true; }
        }
        flags.text = header.trim();
        return flags;
    }

    function shouldListKey(ctx, key) {
        if (ctx.multiplierKeys[key]) return false;
        const entry = ctx.values[key];
        if (entryRequires(entry, "RequiresShard") && !ctx.hasShard) return false;
        if (entryRequires(entry, "RequiresScepter") && !ctx.hasScepter) return false;
        return localize(`${TOKEN_PREFIX}${ctx.name}_${key}`) !== null;
    }

    function isHiddenTalentValue(ctx, key, list) {
        const entry = ctx.values[key];
        if (!entryHasTalent(entry)) return false;
        const raw = levelStrings(entryRaw(entry));
        const baseIsEmpty = raw.length === 0 || raw.every((value) => Number(value) === 0);
        if (!baseIsEmpty) return false;
        return list.values.every((value) => Number(value) === 0);
    }

    function orderKeys(ctx, keys, nativeText, descriptionText) {
        const position = {};
        keys.forEach((key) => {
            const header = localize(`${TOKEN_PREFIX}${ctx.name}_${key}`);
            let index = -1;
            if (header && nativeText) {
                const clean = parseHeader(header).text;
                if (clean.length > 0) index = nativeText.indexOf(clean);
            }
            if (index === -1 && descriptionText) {
                const inDescription = descriptionText.indexOf(`%${key}%`);
                if (inDescription !== -1) index = 100000 + inDescription;
            }
            position[key] = index === -1 ? 200000 : index;
        });
        return keys.slice().sort((a, b) => position[a] - position[b] || (a < b ? -1 : a > b ? 1 : 0));
    }

    function attributeLines(ctx, nativeText, descriptionText) {
        const keys = orderKeys(
            ctx,
            Object.keys(ctx.values).filter((key) => shouldListKey(ctx, key)),
            nativeText,
            descriptionText
        );

        const lines = [];
        keys.forEach((key) => {
            const header = parseHeader(localize(`${TOKEN_PREFIX}${ctx.name}_${key}`));
            const scaled = ctx.rules[key] !== undefined;
            const list = keyValues(ctx, key, !(scaled && ctx.alt));
            if (isHiddenTalentValue(ctx, key, list)) return;

            const decorate = (text) => {
                let value = text;
                if (header.plus && Number(text) >= 0) value = "+" + value;
                else if (header.minus && Number(text) > 0) value = "-" + value;
                if (header.percent) value += "%";
                return value;
            };

            let line = `${header.text} ${formatValueList(ctx, list, colourFor(ctx, key), decorate)}`;
            if (scaled) line += mindPowerSuffix(ctx, key, list);
            lines.push(line);
        });
        return lines;
    }

    // ------------------------------------------------------------------
    // Description
    // ------------------------------------------------------------------

    function usesUnsupportedTemplates(text) {
        return /\{[sdf]:/.test(text);
    }

    function renderDescription(ctx, text) {
        let html = text.replace(/%([A-Za-z0-9_]+)%/g, (match, key) => {
            if (!(key in ctx.values)) return match;
            // The description text states "value + Mind Power × multiplier" itself,
            // so scaled keys show the ability's own value here.
            const list = keyValues(ctx, key, false);
            return formatValueList(ctx, list, colourFor(ctx, key), (value) => value);
        });
        html = html.replace(/%%/g, "%");
        html = html.replace(/\r?\n[ \t]*/g, "<br>");
        return html;
    }

    function notes(ctx) {
        const result = [];
        for (let i = 0; i < MAX_NOTES; i++) {
            const note = localize(`${TOKEN_PREFIX}${ctx.name}_Note${i}`);
            if (note === null) break;
            result.push(renderDescription(ctx, note));
        }
        return result;
    }

    function addLabel(parent, className, html) {
        const label = $.CreatePanel("Label", parent, "");
        label.html = true;
        label.AddClass(className);
        label.text = html;
        return label;
    }

    // ------------------------------------------------------------------
    // Render
    // ------------------------------------------------------------------

    function signatureOf(ctx) {
        return [
            ctx.name, ctx.unit, ctx.ability, ctx.level, formatNumber(ctx.mindPower),
            ctx.alt ? 1 : 0, ctx.hasShard ? 1 : 0, ctx.hasScepter ? 1 : 0,
        ].join("|");
    }

    function render(force) {
        try {
            return renderUnsafe(force);
        } catch (error) {
            const message = String(error && error.stack ? error.stack : error);
            if (message !== state.lastError) {
                state.lastError = message;
                $.Msg("[MindPowerTooltip] render failed for " + state.abilityName + ": " + message);
            }
            restoreNative(findDescriptionOuter());
            state.signature = "error";
            return true;
        }
    }

    function renderUnsafe(force) {
        const outer = findDescriptionOuter();
        if (!outer) return false;
        // After an error keep the native tooltip until the next hover instead of retrying every frame.
        if (!force && state.signature === "error") return true;

        const data = state.abilityName ? CustomNetTables.GetTableValue(NET_TABLE, state.abilityName) : null;
        if (!data || !data.values || !data.rules) {
            restoreNative(outer);
            return true;
        }

        const ctx = buildContext(state.abilityName, state.unit, data);
        const signature = signatureOf(ctx);
        const block = findBlock(outer);
        if (!force && signature === state.signature && (!state.ownsNative || (block && block.visible))) return true;

        const parts = nativeParts(outer);
        const nativeText = parts.attributes && parts.attributes.text ? String(parts.attributes.text) : "";
        const descriptionText = localize(`${TOKEN_PREFIX}${ctx.name}_Description`) || "";
        const keepNativeDescription = descriptionText.length === 0 || usesUnsupportedTemplates(descriptionText);

        const target = prepareBlock(outer, parts, keepNativeDescription);

        if (!keepNativeDescription) {
            addLabel(target, "MPDescription", renderDescription(ctx, descriptionText));
            notes(ctx).forEach((note) => addLabel(target, "MPNote", note));
        }

        const lines = attributeLines(ctx, nativeText, descriptionText);
        if (lines.length > 0) {
            addLabel(target, "MPAttributes", lines.join("<br>"));
        }

        if (ctx.inGame && Object.keys(ctx.rules).length > 0) {
            const hint = localize(ctx.alt ? "trinity_mind_power_tooltip_alt_active" : "trinity_mind_power_tooltip_alt_hint");
            if (hint) addLabel(target, "MPHint", `${iconHtml()} ${hint}`);
        }

        // Hide the native text only once our block really has content.
        if (target.GetChildCount() === 0) {
            restoreNative(outer);
            state.signature = signature;
            return true;
        }
        hideNative(parts, keepNativeDescription);

        state.signature = signature;
        return true;
    }

    // unit: entity index, PORTRAIT_UNIT (take the selected unit) or NO_UNIT (hero pick, raw KV values).
    function show(abilityName, unit) {
        state.shown = true;
        state.abilityName = abilityName || "";
        if (unit === PORTRAIT_UNIT) state.unit = Players.GetLocalPlayerPortraitUnit();
        else state.unit = unit !== undefined && unit >= 0 ? unit : NO_UNIT;
        state.signature = "";

        // Dota fills the tooltip around the same event; render now and once more next frame.
        render(true);
        $.Schedule(0, () => {
            if (generation !== config.trinityMindPowerTooltipGeneration) return;
            if (state.shown && state.abilityName === abilityName) render(true);
        });
    }

    function showItem() {
        state.shown = true;
        state.abilityName = "";
        restoreNative(findDescriptionOuter());
    }

    function hide() {
        state.shown = false;
    }

    function poll() {
        if (generation !== config.trinityMindPowerTooltipGeneration) return;

        if (state.shown && state.abilityName) {
            const outer = findDescriptionOuter();
            if (outer && state.ownsNative) {
                // Dota may bring its own attribute list back while the tooltip refreshes.
                const parts = nativeParts(outer);
                if (parts.attributes && parts.attributes.visible) state.signature = "";
            }
            render(false);
        }

        $.Schedule(POLL_INTERVAL, poll);
    }

    // ------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------

    $.RegisterForUnhandledEvent("DOTAShowAbilityTooltipForEntityIndex", (panel, abilityName, entityIndex) => show(abilityName, entityIndex >= 0 ? entityIndex : PORTRAIT_UNIT));
    $.RegisterForUnhandledEvent("DOTAShowAbilityTooltip", (panel, abilityName) => {
        if (String(abilityName).indexOf("item_") === 0) showItem();
        else show(abilityName, PORTRAIT_UNIT);
    });
    $.RegisterForUnhandledEvent("DOTAShowAbilityTooltipForHero", (panel, abilityName) => show(abilityName, NO_UNIT));
    $.RegisterForUnhandledEvent("DOTAShowAbilityTooltipForLevel", (panel, abilityName) => show(abilityName, NO_UNIT));
    $.RegisterForUnhandledEvent("DOTAShowAbilityShopItemTooltip", showItem);
    $.RegisterForUnhandledEvent("DOTAShowAbilityInventoryItemTooltip", showItem);
    $.RegisterForUnhandledEvent("DOTAHideAbilityTooltip", hide);

    GameEvents.Subscribe("dota_player_learned_ability", () => { state.signature = ""; });

    poll();
})();
