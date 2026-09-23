const state = {
    tab: document.documentElement.dataset.tab || "texts",
    catalog: null,
    report: null,
    issues: new Set(),
    locFilter: "all",
    onlyIssues: false,
    selectedOwner: null,
    selectedAbility: null,
    ability: null,
    locField: null,
};

function $(id) {
    return document.getElementById(id);
}

function notify(text, ok) {
    if (!text) {
        return;
    }
    Trinity.toast(text, ok);
}

function locRowFor(id) {
    return (state.report && state.report.rows || []).find((row) => row.id === id) || null;
}

function ownerFromLocRow(row) {
    return { type: row.owner_type, id: row.owner_id };
}

function currentAbilities() {
    if (!state.selectedOwner || !state.catalog) {
        return [];
    }
    if (state.selectedOwner.type === "hero") {
        const hero = state.catalog.heroes.find((item) => item.id === state.selectedOwner.id);
        return hero ? hero.abilities : [];
    }
    const group = state.catalog.groups.find((item) => item.id === state.selectedOwner.id);
    return group ? group.abilities : [];
}

function ownerTitle() {
    if (!state.selectedOwner || !state.catalog) {
        return "";
    }
    if (state.selectedOwner.type === "hero") {
        const hero = state.catalog.heroes.find((item) => item.id === state.selectedOwner.id);
        return hero ? hero.title : state.selectedOwner.id;
    }
    const group = state.catalog.groups.find((item) => item.id === state.selectedOwner.id);
    return group ? group.title : state.selectedOwner.id;
}

function hasIssue(abilityId) {
    return state.issues.has(abilityId);
}

function ownerHasIssue(abilities) {
    return abilities.some((skill) => hasIssue(skill.id));
}

function escapeHtml(value) {
    return String(value ?? "")
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
}

function sanitizeTag(tag) {
    const lower = tag.toLowerCase();
    if (lower === "<br>" || lower === "<br/>" || lower === "<br />") {
        return "<br>";
    }
    if (lower === "<b>" || lower === "</b>" || lower === "<h1>" || lower === "</h1>") {
        return lower;
    }
    const font = tag.match(/^<font\s+color\s*=\s*['"]?(#[0-9a-fA-F]{3,8}|[a-zA-Z]+)['"]?\s*>$/i);
    if (font) {
        return `<font color="${font[1]}">`;
    }
    if (lower === "</font>") {
        return "</font>";
    }
    return "";
}

function formatLevels(value) {
    const text = String(value ?? "").trim();
    if (text === "") {
        return "—";
    }
    return text.split(/\s+/).join(" / ");
}

function formatSpecial(value, label) {
    const parts = formatLevels(value).split(" / ");
    if (parts[0] === "—") {
        return "—";
    }
    if (!String(label || "").startsWith("%")) {
        return parts.join(" / ");
    }
    return parts.map((part) => (part.includes("%") ? part : part + "%")).join(" / ");
}

function displayLabel(label) {
    return String(label || "").replace(/^%/, "");
}

function locFromForm(lang) {
    const params = {};
    document.querySelectorAll(`#ability-params [data-label-${lang}]`).forEach((input) => {
        params[input.getAttribute("data-key")] = input.value;
    });
    return {
        name: $(`${lang}-name`).value,
        description: $(`${lang}-description`).value,
        shard: $(`${lang}-shard`).value,
        scepter: $(`${lang}-scepter`).value,
        params,
    };
}

function kvFromForm() {
    const values = [];
    document.querySelectorAll("#balance-params [data-value]").forEach((input) => {
        values.push({
            key: input.getAttribute("data-key"),
            value: input.value,
        });
    });
    return {
        cooldown: $("kv-cooldown").value,
        mana: $("kv-mana").value,
        cast_range: $("kv-range").value,
        damage: $("kv-damage").value,
        values,
    };
}

function valueMap(kv) {
    const map = {};
    (kv.values || []).forEach((row) => {
        map[row.key] = row.value;
    });
    if (kv.damage) {
        map.AbilityDamage = kv.damage;
        map.abilitydamage = kv.damage;
    }
    return map;
}

function richText(text, values) {
    let raw = String(text || "");
    const tags = [];
    raw = raw.replace(/<\/?(?:b|h1|br|font)(?:\s+[^>]*)?\/?>/gi, (tag) => {
        const safe = sanitizeTag(tag);
        if (safe === "") {
            return "";
        }
        const index = tags.length;
        tags.push(safe);
        return `\u0000${index}\u0001`;
    });
    raw = raw.replace(/%%/g, "\u0002");
    raw = raw.replace(/%([A-Za-z][A-Za-z0-9_]*)%/g, (_, key) => {
        if (!(key in values) && !(key.toLowerCase() in values)) {
            return `%${key}%`;
        }
        const value = values[key] !== undefined ? values[key] : values[key.toLowerCase()];
        return `\u0003${formatLevels(value)}\u0004`;
    });
    raw = escapeHtml(raw);
    raw = raw.replace(/\u0003(.*?)\u0004/g, '<span class="tt-val">$1</span>');
    raw = raw.replace(/\u0000(\d+)\u0001/g, (_, index) => tags[Number(index)] || "");
    raw = raw.replace(/\u0002/g, "%");
    raw = raw.replace(/\n+/g, "<br><br>");
    return raw;
}

function renderTooltip(target, loc, kv, icon, abilityId) {
    const values = valueMap(kv);
    const labels = loc.params || {};
    const rows = (kv.values || [])
        .filter((row) => labels[row.key])
        .map((row) => {
            return `<div class="dota-tt-row"><span class="dota-tt-label">${escapeHtml(displayLabel(labels[row.key]))}</span><span class="dota-tt-nums">${escapeHtml(formatSpecial(row.value, labels[row.key]))}</span></div>`;
        })
        .join("");
    const shard = loc.shard
        ? `<div class="dota-tt-extra"><b>Shard:</b> ${richText(loc.shard, values)}</div>`
        : "";
    const scepter = loc.scepter
        ? `<div class="dota-tt-extra"><b>Scepter:</b> ${richText(loc.scepter, values)}</div>`
        : "";
    const costs = [];
    if (kv.cooldown) {
        costs.push(`<span class="dota-tt-cd">⏱ ${escapeHtml(formatSpecial(kv.cooldown, ""))}</span>`);
    }
    if (kv.mana) {
        costs.push(`<span class="dota-tt-mana">◆ ${escapeHtml(formatSpecial(kv.mana, ""))}</span>`);
    }
    target.innerHTML = `
        <div class="dota-tt-head">
            <img class="dota-tt-icon" alt="" src="${escapeHtml(icon)}">
            <div>
                <div class="dota-tt-name">${escapeHtml(loc.name || abilityId)}</div>
                <div class="dota-tt-sub">${escapeHtml(abilityId)}</div>
            </div>
        </div>
        <div class="dota-tt-desc">${richText(loc.description, values) || "<span class='card-hint'>Нет описания</span>"}</div>
        ${shard}${scepter}
        ${rows ? `<div class="dota-tt-attrs">${rows}</div>` : ""}
        ${costs.length ? `<div class="dota-tt-costs">${costs.join("")}</div>` : ""}
    `;
}

function refreshPreview() {
    if (!state.ability) {
        return;
    }
    const kv = kvFromForm();
    const icon = state.ability.icon;
    renderTooltip($("tt-ru"), locFromForm("ru"), kv, icon, state.ability.id);
    renderTooltip($("tt-en"), locFromForm("en"), kv, icon, state.ability.id);
}

function locTextFields() {
    return ["ru-description", "ru-shard", "ru-scepter", "en-description", "en-shard", "en-scepter"]
        .map((id) => $(id))
        .filter(Boolean);
}

function insertLocKey(key) {
    const token = `%${key}%`;
    const allowed = new Set(locTextFields());
    const active = document.activeElement;
    const target = (active && allowed.has(active) ? active : null) || (allowed.has(state.locField) ? state.locField : null);
    if (!target) {
        notify("Сначала кликни в описание, Shard или Scepter", false);
        return;
    }
    state.locField = target;
    const start = target.selectionStart ?? target.value.length;
    const end = target.selectionEnd ?? start;
    target.value = target.value.slice(0, start) + token + target.value.slice(end);
    const cursor = start + token.length;
    target.focus();
    target.setSelectionRange(cursor, cursor);
    Trinity.setDirty(true);
    refreshPreview();
}

function renderLocKeyChips(keys) {
    const chips = $("loc-key-chips");
    if (!chips) {
        return;
    }
    chips.innerHTML = "";
    keys.forEach((key) => {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "key-chip";
        button.setAttribute("data-insert-key", key);
        button.textContent = key;
        chips.appendChild(button);
    });
}

function fillLocForm(ability) {
    $("ru-name").value = ability.loc.ru.name || "";
    $("ru-description").value = ability.loc.ru.description || "";
    $("ru-shard").value = ability.loc.ru.shard || "";
    $("ru-scepter").value = ability.loc.ru.scepter || "";
    $("en-name").value = ability.loc.en.name || "";
    $("en-description").value = ability.loc.en.description || "";
    $("en-shard").value = ability.loc.en.shard || "";
    $("en-scepter").value = ability.loc.en.scepter || "";

    const ruParams = ability.loc.ru.params || {};
    const enParams = ability.loc.en.params || {};
    const keys = new Set((ability.kv.values || []).map((row) => row.key));
    Object.keys(ruParams).forEach((key) => keys.add(key));
    Object.keys(enParams).forEach((key) => keys.add(key));
    const ordered = Array.from(keys);
    renderLocKeyChips(ordered);
    const body = $("ability-params");
    body.innerHTML = "";
    ordered.forEach((key) => {
        const tr = document.createElement("tr");
        tr.innerHTML = `
            <td><button type="button" class="key-chip" data-insert-key="${escapeHtml(key)}">${escapeHtml(key)}</button></td>
            <td><input data-label-ru data-key="${escapeHtml(key)}" type="text"></td>
            <td><input data-label-en data-key="${escapeHtml(key)}" type="text"></td>
        `;
        body.appendChild(tr);
        tr.querySelector("[data-label-ru]").value = ruParams[key] || "";
        tr.querySelector("[data-label-en]").value = enParams[key] || "";
    });
}

function fillKvForm(ability) {
    $("kv-cooldown").value = ability.kv.cooldown || "";
    $("kv-mana").value = ability.kv.mana || "";
    $("kv-range").value = ability.kv.cast_range || "";
    $("kv-damage").value = ability.kv.damage || "";
    const editable = ability.kv.editable === true;
    ["kv-cooldown", "kv-mana", "kv-range", "kv-damage"].forEach((id) => {
        $(id).disabled = !editable;
    });
    $("kv-readonly").classList.toggle("hidden", editable);
    $("balance-save").disabled = !editable;

    const body = $("balance-params");
    body.innerHTML = "";
    (ability.kv.values || []).forEach((row) => {
        const tr = document.createElement("tr");
        tr.innerHTML = `
            <td><code>${escapeHtml(row.key)}</code></td>
            <td><input data-value data-key="${escapeHtml(row.key)}" type="text" ${editable ? "" : "disabled"}></td>
        `;
        body.appendChild(tr);
        tr.querySelector("[data-value]").value = row.value || "";
    });
}

function setEditorsVisible(visible) {
    $("ability-form").classList.toggle("hidden", !visible);
    $("balance-form").classList.toggle("hidden", !visible);
    $("ability-preview").classList.toggle("hidden", !visible);
}

function renderSkillbar() {
    const bar = $("ability-skillbar");
    bar.innerHTML = "";
    currentAbilities().forEach((skill) => {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "skill-btn" + (state.selectedAbility === skill.id ? " active" : "");
        button.title = skill.id;
        const img = document.createElement("img");
        img.src = skill.icon;
        img.alt = skill.name;
        img.addEventListener("error", () => {
            img.style.visibility = "hidden";
        });
        const slot = document.createElement("span");
        slot.className = "slot";
        slot.textContent = skill.label || "";
        const name = document.createElement("span");
        name.className = "sname";
        name.textContent = skill.name;
        button.append(img, slot, name);
        if (hasIssue(skill.id)) {
            const flag = document.createElement("span");
            flag.className = "flag";
            flag.title = "EN расходится с RU";
            button.appendChild(flag);
        }
        button.addEventListener("click", () => {
            selectAbility(skill.id).catch((error) => notify(String(error.message || error), false));
        });
        bar.appendChild(button);
    });
}

function renderSidebar() {
    if (!state.catalog) {
        return;
    }
    const query = ($("ability-search").value || "").trim().toLowerCase();
    const list = $("ability-hero-list");
    list.innerHTML = "";
    state.catalog.heroes.filter((hero) => {
        if (state.onlyIssues && !ownerHasIssue(hero.abilities)) {
            return false;
        }
        if (!query) {
            return true;
        }
        const blob = [hero.title, hero.id, ...hero.abilities.map((skill) => `${skill.name} ${skill.id}`)].join(" ").toLowerCase();
        return blob.includes(query);
    }).forEach((hero) => {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "hero-btn" + (state.selectedOwner && state.selectedOwner.type === "hero" && state.selectedOwner.id === hero.id ? " active" : "");
        const img = document.createElement("img");
        img.src = hero.portrait;
        img.alt = hero.title;
        img.addEventListener("error", () => {
            const fallback = document.createElement("div");
            fallback.className = "hero-portrait";
            fallback.textContent = hero.title.slice(0, 2);
            img.replaceWith(fallback);
        });
        const name = document.createElement("span");
        name.className = "name";
        name.textContent = hero.title;
        button.append(img, name);
        if (ownerHasIssue(hero.abilities)) {
            const flag = document.createElement("span");
            flag.className = "flag";
            flag.title = "Есть расхождения RU и EN";
            button.appendChild(flag);
        }
        button.addEventListener("click", () => {
            selectOwner({ type: "hero", id: hero.id }).catch((error) => notify(String(error.message || error), false));
        });
        list.appendChild(button);
    });

    renderGroup("shared", $("ability-shared-list"), query);
    renderGroup("units", $("ability-units-list"), query);
}

function renderGroup(id, node, query) {
    const group = state.catalog.groups.find((item) => item.id === id);
    node.innerHTML = "";
    if (!group) {
        return;
    }
    group.abilities.filter((skill) => {
        if (state.onlyIssues && !hasIssue(skill.id)) {
            return false;
        }
        if (!query) {
            return true;
        }
        return `${skill.name} ${skill.id}`.toLowerCase().includes(query);
    }).forEach((skill) => {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "ability-group-btn" + (state.selectedAbility === skill.id && state.selectedOwner && state.selectedOwner.id === id ? " active" : "");
        const img = document.createElement("img");
        img.src = skill.icon;
        img.alt = skill.name;
        const name = document.createElement("span");
        name.textContent = skill.name;
        button.append(img, name);
        button.addEventListener("click", () => {
            selectOwner({ type: "group", id }, skill.id).catch((error) => notify(String(error.message || error), false));
        });
        node.appendChild(button);
    });
}

function renderIssueList() {
    const summary = $("loc-summary");
    const list = $("loc-issue-list");
    const badge = $("tab-check-count");
    if (!summary || !list) {
        return;
    }
    if (!state.report) {
        summary.textContent = "Отчёт сверки не загружен.";
        list.innerHTML = "";
        return;
    }
    const rows = state.report.rows || [];
    const missing = rows.filter((row) => row.tags.includes("missing")).length;
    summary.textContent = `Проверено ${state.report.checked}, сходится ${state.report.matched}. Проблем ${state.report.mismatched}, из них без английского текста ${missing}.`;
    if (badge) {
        badge.textContent = String(rows.length);
        badge.classList.toggle("hidden", rows.length === 0);
    }
    document.querySelectorAll("#loc-filters [data-filter]").forEach((button) => {
        button.setAttribute("aria-pressed", button.getAttribute("data-filter") === state.locFilter ? "true" : "false");
    });
    const query = (($("loc-search") && $("loc-search").value) || "").trim().toLowerCase();
    list.innerHTML = "";
    const visible = rows.filter((row) => {
        if (state.locFilter !== "all" && !row.tags.includes(state.locFilter)) {
            return false;
        }
        if (!query) {
            return true;
        }
        const blob = [row.id, row.ru_name, row.en_name, row.owner_title, row.en_preview, ...(row.issues || [])].join(" ").toLowerCase();
        return blob.includes(query);
    });
    if (visible.length === 0) {
        const empty = document.createElement("p");
        empty.className = "card-hint";
        empty.textContent = rows.length === 0
            ? "Расхождений нет: RU и EN совпадают по тексту, плейсхолдерам, абзацам и подписям."
            : "Под этот фильтр ничего не попало.";
        list.appendChild(empty);
        return;
    }
    visible.forEach((row) => {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "issue-btn" + (state.selectedAbility === row.id ? " active" : "");
        const img = document.createElement("img");
        img.src = row.icon;
        img.alt = row.en_name || row.ru_name || row.id;
        img.addEventListener("error", () => {
            img.style.visibility = "hidden";
        });
        const name = document.createElement("span");
        name.className = "name";
        name.textContent = row.en_name || row.ru_name || row.id;
        const meta = document.createElement("span");
        meta.className = "meta";
        meta.textContent = `${row.owner_title}${row.label ? " · " + row.label : ""} · ${row.issues.join(", ")}`;
        const preview = document.createElement("span");
        preview.className = "preview";
        preview.textContent = row.en_preview || "Нет английского описания";
        button.append(img, name, meta, preview);
        button.addEventListener("click", () => {
            selectOwner(ownerFromLocRow(row), row.id)
                .then(() => setTab("texts"))
                .catch((error) => notify(String(error.message || error), false));
        });
        list.appendChild(button);
    });
}

function renderIssueBanner(id) {
    const banner = $("loc-issue-banner");
    if (!banner) {
        return;
    }
    const row = locRowFor(id);
    if (!row || state.tab === "check") {
        banner.classList.add("hidden");
        banner.textContent = "";
        return;
    }
    const extra = [];
    if (row.placeholders_en_only && row.placeholders_en_only.length) {
        extra.push("EN %: " + row.placeholders_en_only.join(", "));
    }
    if (row.placeholders_ru_only && row.placeholders_ru_only.length) {
        extra.push("RU %: " + row.placeholders_ru_only.join(", "));
    }
    if (row.params_en_only && row.params_en_only.length) {
        extra.push("подписи только EN: " + row.params_en_only.join(", "));
    }
    if (row.params_ru_only && row.params_ru_only.length) {
        extra.push("подписи только RU: " + row.params_ru_only.join(", "));
    }
    banner.textContent = row.issues.join(", ") + (extra.length ? ". " + extra.join(". ") : "");
    banner.classList.remove("hidden");
}

function renderHead() {
    const head = $("ability-head");
    if (!state.selectedOwner) {
        head.innerHTML = `<div><h1>Способности</h1><p class="page-sub">Выбери героя слева, затем скилл.</p></div>`;
        return;
    }
    if (!state.ability) {
        head.innerHTML = `<div><h1>${escapeHtml(ownerTitle())}</h1><p class="page-sub">Выбери скилл.</p></div>`;
        return;
    }
    const skill = currentAbilities().find((item) => item.id === state.selectedAbility);
    const slot = skill && skill.label ? ` · ${skill.label}` : "";
    const vanilla = state.ability.custom ? "" : " · ванильный override";
    head.innerHTML = `<div><h1>${escapeHtml(ownerTitle())}${escapeHtml(slot)}</h1><p class="page-sub">${escapeHtml(state.ability.id)}${escapeHtml(vanilla)}</p></div>`;
}

function setTab(next) {
    state.tab = next;
    document.documentElement.dataset.tab = next;
    document.querySelectorAll("#ability-tabs .tab").forEach((button) => {
        button.setAttribute("aria-selected", button.getAttribute("data-tab") === next ? "true" : "false");
    });
    renderIssueBanner(state.selectedAbility);
    syncUrl({});
}

function syncUrl(extra) {
    const params = new URLSearchParams(location.search);
    params.set("view", "abilities");
    params.set("tab", state.tab);
    if (state.selectedOwner) {
        if (state.selectedOwner.type === "hero") {
            params.set("hero", state.selectedOwner.id);
            params.delete("group");
        } else {
            params.set("group", state.selectedOwner.id);
            params.delete("hero");
        }
    }
    Object.keys(extra || {}).forEach((key) => {
        if (extra[key] == null || extra[key] === "") {
            params.delete(key);
        } else {
            params.set(key, extra[key]);
        }
    });
    history.replaceState(null, "", `/?${params.toString()}`);
}

async function selectOwner(owner, abilityId) {
    state.selectedOwner = owner;
    state.ability = null;
    renderHead();
    renderSidebar();
    renderSkillbar();
    syncUrl({ ability: abilityId || null });
    const abilities = currentAbilities();
    const pick = abilityId || (abilities[0] ? abilities[0].id : null);
    if (pick) {
        await selectAbility(pick);
        return;
    }
    state.selectedAbility = null;
    setEditorsVisible(false);
}

async function selectAbility(id) {
    state.selectedAbility = id;
    renderSkillbar();
    renderSidebar();
    syncUrl({ ability: id });
    const response = await fetch(`/v1/abilities/ability?id=${encodeURIComponent(id)}`);
    const body = await response.json();
    if (!response.ok || !body || body.ok !== true) {
        setEditorsVisible(false);
        notify((body && body.error) || `HTTP ${response.status}`, false);
        return;
    }
    state.ability = body.ability;
    setEditorsVisible(true);
    renderHead();
    renderIssueBanner(id);
    fillLocForm(body.ability);
    fillKvForm(body.ability);
    Trinity.setDirty(false);
    refreshPreview();
}

async function loadReport() {
    const response = await fetch("/v1/localization/report");
    const body = await response.json();
    if (!response.ok || !body || body.ok !== true) {
        throw new Error((body && body.error) || `HTTP ${response.status}`);
    }
    state.report = body;
    state.issues = new Set((body.rows || []).map((row) => row.id));
}

function ownerForAbility(abilityId) {
    const row = locRowFor(abilityId);
    if (row) {
        return ownerFromLocRow(row);
    }
    if (!state.catalog) {
        return null;
    }
    const hero = state.catalog.heroes.find((item) => item.abilities.some((skill) => skill.id === abilityId));
    if (hero) {
        return { type: "hero", id: hero.id };
    }
    const group = state.catalog.groups.find((item) => item.abilities.some((skill) => skill.id === abilityId));
    if (group) {
        return { type: "group", id: group.id };
    }
    return null;
}

async function loadCatalog() {
    const response = await fetch("/v1/abilities/catalog");
    const body = await response.json();
    if (!response.ok || !body || body.ok !== true) {
        throw new Error((body && body.error) || `HTTP ${response.status}`);
    }
    state.catalog = body;
}

async function boot() {
    Trinity.skeleton($("ability-hero-list"), "skel-hero", 9);
    await loadCatalog();
    try {
        await loadReport();
    } catch (error) {
        notify(`Сверка локализации недоступна: ${error.message}`, false);
    }
    renderSidebar();
    renderIssueList();
    setTab(state.tab);

    const params = new URLSearchParams(location.search);
    const hero = params.get("hero");
    const group = params.get("group");
    const ability = params.get("ability");

    if (ability) {
        const owner = ownerForAbility(ability);
        if (owner) {
            await selectOwner(owner, ability);
            return;
        }
    }
    if (hero && state.catalog.heroes.some((item) => item.id === hero)) {
        await selectOwner({ type: "hero", id: hero });
        return;
    }
    if (group && state.catalog.groups.some((item) => item.id === group)) {
        await selectOwner({ type: "group", id: group });
        return;
    }
    if (state.report && state.report.rows && state.report.rows[0] && state.tab === "check") {
        renderHead();
        return;
    }
    if (state.catalog.heroes[0]) {
        await selectOwner({ type: "hero", id: state.catalog.heroes[0].id });
    }
}

$("ability-search").addEventListener("input", renderSidebar);

$("ability-only-issues").addEventListener("click", (event) => {
    state.onlyIssues = !state.onlyIssues;
    event.currentTarget.setAttribute("aria-pressed", state.onlyIssues ? "true" : "false");
    renderSidebar();
});

$("loc-search").addEventListener("input", renderIssueList);

document.querySelectorAll("#loc-filters [data-filter]").forEach((button) => {
    button.addEventListener("click", () => {
        state.locFilter = button.getAttribute("data-filter") || "all";
        renderIssueList();
    });
});

document.querySelectorAll("#ability-tabs .tab").forEach((button) => {
    button.addEventListener("click", () => setTab(button.getAttribute("data-tab")));
});

const locForm = $("ability-form");
locForm.addEventListener("pointerdown", (event) => {
    if (event.target && event.target.matches("textarea")) {
        state.locField = event.target;
    }
    const chip = event.target && event.target.closest("[data-insert-key]");
    if (chip && document.activeElement && document.activeElement.matches("#ability-form textarea")) {
        state.locField = document.activeElement;
    }
}, true);

locForm.addEventListener("focusin", (event) => {
    if (event.target && event.target.matches("textarea")) {
        state.locField = event.target;
    }
});

locForm.addEventListener("click", (event) => {
    const chip = event.target.closest("[data-insert-key]");
    if (!chip) {
        return;
    }
    event.preventDefault();
    insertLocKey(chip.getAttribute("data-insert-key"));
});

locForm.addEventListener("input", () => {
    Trinity.setDirty(true);
    refreshPreview();
});

locForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (!state.ability) {
        return;
    }
    const payload = {
        id: state.ability.id,
        loc: {
            ru: locFromForm("ru"),
            en: locFromForm("en"),
        },
    };
    $("ability-save").disabled = true;
    try {
        const response = await fetch("/v1/abilities/save", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload),
        });
        const body = await response.json();
        if (!response.ok || !body || body.ok !== true) {
            throw new Error((body && body.error) || `HTTP ${response.status}`);
        }
        notify("Сохранено в addon_russian.txt и addon_english.txt", true);
        try {
            await loadReport();
        } catch (_error) {
            notify("Тексты записаны, но отчёт сверки не обновился", false);
        }
        renderIssueList();
        await selectAbility(state.ability.id);
    } catch (error) {
        notify(String(error.message || error), false);
    } finally {
        $("ability-save").disabled = false;
    }
});

const kvForm = $("balance-form");
kvForm.addEventListener("input", () => {
    Trinity.setDirty(true);
    refreshPreview();
});

kvForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (!state.ability) {
        return;
    }
    const payload = {
        id: state.ability.id,
        kv: kvFromForm(),
    };
    $("balance-save").disabled = true;
    try {
        const response = await fetch("/v1/abilities/save", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload),
        });
        const body = await response.json();
        if (!response.ok || !body || body.ok !== true) {
            throw new Error((body && body.error) || `HTTP ${response.status}`);
        }
        notify(body.custom ? "Сохранено в KV героя" : "Числа ванильного скилла только для чтения", true);
        await selectAbility(state.ability.id);
    } catch (error) {
        notify(String(error.message || error), false);
        $("balance-save").disabled = false;
    }
});

setEditorsVisible(false);
boot().catch((error) => {
    $("ability-hero-list").innerHTML = "";
    notify(`API недоступно: ${error.message}`, false);
});
