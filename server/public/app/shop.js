(function () {
    const T = window.Trinity;
    const els = {
        form: document.getElementById("shop-form"),
        title: document.getElementById("shop-title"),
        stats: document.getElementById("shop-stats"),
        board: document.getElementById("shop-board"),
        current: document.getElementById("shop-current"),
        search: document.getElementById("shop-search"),
        save: document.getElementById("shop-save"),
        clear: document.getElementById("shop-clear"),
        tooltip: document.getElementById("shop-tooltip"),
    };

    const state = {
        categories: [],
        items: [],
        byId: {},
        currentId: "",
        done: {},
        search: "",
        drag: null,
        unassigned: 0,
        over: 0,
    };

    function itemById(id) {
        return state.byId[id] || null;
    }

    function queue() {
        return state.items.filter((item) => !state.done[item.id]);
    }

    function currentItem() {
        if (state.currentId) {
            const picked = itemById(state.currentId);
            if (picked && !state.done[picked.id]) {
                return picked;
            }
        }
        return queue()[0] || null;
    }

    function recount() {
        const count = {};
        const labels = {};
        state.categories.forEach((cat) => {
            const names = new Set();
            cat.subcategories.forEach((sub) => {
                sub.items.forEach((id) => {
                    names.add(id);
                    count[id] = (count[id] || 0) + 1;
                    (labels[id] = labels[id] || []).push({
                        catId: cat.id,
                        subId: sub.id,
                        label: `${cat.name} / ${sub.name}`,
                    });
                });
            });
            cat.count = names.size;
        });
        let unassigned = 0;
        let over = 0;
        state.items.forEach((item) => {
            item.places = count[item.id] || 0;
            item.placeRows = labels[item.id] || [];
            item.placeLabels = item.placeRows.map((row) => row.label);
            item.unassigned = item.places === 0;
            item.over = item.places >= 3;
            if (item.unassigned) {
                unassigned++;
            }
            if (item.over) {
                over++;
            }
        });
        state.unassigned = unassigned;
        state.over = over;
        const remaining = queue().length;
        els.stats.textContent = `${unassigned} без категории · ${over} в 3+ · очередь ${state.items.length - remaining + 1} / ${state.items.length}`;
        if (remaining === 0) {
            els.stats.textContent = `${unassigned} без категории · ${over} в 3+ · очередь просмотрена`;
        }
    }

    function removeFrom(catId, subId, itemId) {
        const cat = state.categories.find((entry) => entry.id === catId);
        if (!cat) {
            return;
        }
        cat.subcategories.forEach((sub) => {
            if (sub.id !== subId) {
                return;
            }
            sub.items = sub.items.filter((id) => id !== itemId);
        });
    }

    function insertInto(catId, subId, itemId) {
        const cat = state.categories.find((entry) => entry.id === catId);
        if (!cat) {
            return;
        }
        cat.subcategories.forEach((sub) => {
            if (sub.id !== subId) {
                return;
            }
            if (!sub.items.includes(itemId)) {
                sub.items.push(itemId);
            }
        });
    }

    function markDirty() {
        T.setDirty(true);
        render();
    }

    function clearPlacements() {
        state.categories.forEach((cat) => {
            cat.subcategories.forEach((sub) => {
                sub.items = [];
            });
        });
        state.done = {};
        state.currentId = "";
        state.items.sort((a, b) => a.name.localeCompare(b.name, "ru"));
        T.setDirty(true);
        render();
    }

    function placements() {
        const out = {};
        state.categories.forEach((cat) => {
            out[cat.id] = {};
            cat.subcategories.forEach((sub) => {
                out[cat.id][sub.id] = sub.items.slice();
            });
        });
        return out;
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
        if (lower === "<b>" || lower === "</b>") {
            return lower;
        }
        if (lower === "<h1>" || lower === "</h1>") {
            return lower;
        }
        if (lower.startsWith("<font") || lower === "</font>") {
            const color = tag.match(/color\s*=\s*['"]([^'"]+)['"]/i);
            if (lower === "</font>") {
                return "</font>";
            }
            if (color) {
                return `<font color="${escapeHtml(color[1])}">`;
            }
        }
        return "";
    }

    function formatLevels(value) {
        const text = String(value ?? "").trim();
        return text === "" ? "—" : text.replace(/\s+/g, " ");
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
            const value = values[key] !== undefined ? values[key] : values[key.toLowerCase()];
            if (value === undefined) {
                return `%${key}%`;
            }
            return `\u0003${formatLevels(value)}\u0004`;
        });
        raw = escapeHtml(raw);
        raw = raw.replace(/\u0003(.*?)\u0004/g, '<span class="tt-val">$1</span>');
        raw = raw.replace(/\u0000(\d+)\u0001/g, (_, index) => tags[Number(index)] || "");
        raw = raw.replace(/\u0002/g, "%");
        raw = raw.replace(/\n+/g, "<br><br>");
        return raw;
    }

    function formatBonus(row) {
        const label = String(row.label || "");
        const percent = label.startsWith("%");
        const rest = label.replace(/^%?\+\s*/, "");
        const value = percent ? `${row.value}%` : row.value;
        return `+${escapeHtml(value)} ${escapeHtml(rest)}`;
    }

    function tooltipHtml(item) {
        const tip = item.tooltip || {};
        const values = tip.values || {};
        const bonuses = (tip.bonuses || []).map((row) => `<div class="dota-tt-bonus">${formatBonus(row)}</div>`).join("");
        const stats = (tip.stats || []).map((row) => {
            return `<div class="dota-tt-row"><span class="dota-tt-label">${escapeHtml(row.label)}</span><span class="dota-tt-nums">${escapeHtml(row.value)}</span></div>`;
        }).join("");
        const notes = (tip.notes || []).map((note) => `<div class="dota-tt-note">${richText(note, values)}</div>`).join("");
        const costs = [];
        if (tip.cooldown) {
            costs.push(`<span class="dota-tt-cd">⏱ ${escapeHtml(tip.cooldown)}</span>`);
        }
        if (tip.mana && String(tip.mana) !== "0") {
            costs.push(`<span class="dota-tt-mana">◆ ${escapeHtml(tip.mana)}</span>`);
        }
        return `
            <div class="dota-tt">
                <div class="dota-tt-head">
                    <img class="dota-tt-icon" alt="" src="${escapeHtml(item.icon)}">
                    <div>
                        <div class="dota-tt-name">${escapeHtml(tip.name || item.name)}</div>
                        <div class="dota-tt-gold">${escapeHtml(String(tip.price || item.price))} золота</div>
                    </div>
                </div>
                <div class="dota-tt-desc">${richText(tip.description, values) || "<span class='card-hint'>Нет описания</span>"}</div>
                ${bonuses ? `<div class="dota-tt-attrs">${bonuses}</div>` : ""}
                ${stats ? `<div class="dota-tt-attrs">${stats}</div>` : ""}
                ${notes}
                ${tip.lore ? `<div class="dota-tt-lore">${escapeHtml(tip.lore)}</div>` : ""}
                ${costs.length ? `<div class="dota-tt-costs">${costs.join("")}</div>` : ""}
            </div>
        `;
    }

    function showTooltip(item, event) {
        if (!item || state.drag) {
            return;
        }
        els.tooltip.innerHTML = tooltipHtml(item);
        els.tooltip.classList.remove("hidden");
        moveTooltip(event);
    }

    function moveTooltip(event) {
        if (state.drag || els.tooltip.classList.contains("hidden")) {
            return;
        }
        const pad = 14;
        const rect = els.tooltip.getBoundingClientRect();
        let x = event.clientX + pad;
        let y = event.clientY + pad;
        if (x + rect.width > window.innerWidth - 8) {
            x = event.clientX - rect.width - pad;
        }
        if (y + rect.height > window.innerHeight - 8) {
            y = window.innerHeight - rect.height - 8;
        }
        els.tooltip.style.left = Math.max(8, x) + "px";
        els.tooltip.style.top = Math.max(8, y) + "px";
    }

    function hideTooltip() {
        els.tooltip.classList.add("hidden");
    }

    function bindHover(node, item) {
        node.addEventListener("mouseenter", (event) => showTooltip(item, event));
        node.addEventListener("mousemove", moveTooltip);
        node.addEventListener("mouseleave", hideTooltip);
    }

    function itemIcon(item, className) {
        const img = document.createElement("img");
        img.alt = item.name;
        img.src = item.icon;
        img.loading = "lazy";
        img.referrerPolicy = "no-referrer";
        img.addEventListener("error", () => {
            if (!img.dataset.fallback) {
                img.dataset.fallback = "1";
                img.src = "https://cdn.dota2.com/apps/dota2/images/dota_react/items/" + item.id.replace(/^item_/, "") + ".png";
                return;
            }
            img.replaceWith(Object.assign(document.createElement("span"), {
                className: className,
                textContent: item.name.slice(0, 1),
            }));
        });
        return img;
    }

    function renderCurrent() {
        els.current.innerHTML = "";
        const item = currentItem();
        els.title.textContent = item ? item.name : "Магазин";
        if (!item) {
            const done = document.createElement("p");
            done.className = "card-hint";
            done.textContent = "Очередь просмотрена. Сохрани раскладку.";
            els.current.appendChild(done);
            return;
        }
        state.currentId = item.id;

        const hero = document.createElement("div");
        hero.className = "shop-hero";
        hero.draggable = true;
        hero.append(itemIcon(item, "shop-hero-fallback"));
        const name = document.createElement("div");
        name.className = "shop-hero-name";
        name.textContent = item.name;
        const price = document.createElement("div");
        price.className = "shop-hero-price";
        price.textContent = `${item.price} золота`;
        const meta = document.createElement("div");
        meta.className = "shop-hero-meta";
        if (item.places === 0) {
            meta.textContent = "Ещё нет категории";
        } else if (item.over) {
            meta.textContent = `${item.places} места — больше двух`;
        } else {
            meta.textContent = item.places === 1 ? "1 место" : `${item.places} места`;
        }
        hero.append(name, price, meta);
        hero.addEventListener("dragstart", (event) => {
            state.drag = { id: item.id };
            hero.classList.add("dragging");
            hideTooltip();
            event.dataTransfer.effectAllowed = "copy";
            event.dataTransfer.setData("text/plain", item.id);
        });
        hero.addEventListener("dragend", () => {
            hero.classList.remove("dragging");
            state.drag = null;
            hideTooltip();
            els.board.querySelectorAll(".drop-over").forEach((el) => el.classList.remove("drop-over"));
        });
        bindHover(hero, item);

        const places = document.createElement("div");
        places.className = "shop-places";
        item.placeRows.forEach((row) => {
            const chip = document.createElement("button");
            chip.type = "button";
            chip.className = "shop-place-chip" + (item.over ? " over" : "");
            chip.textContent = row.label;
            chip.addEventListener("click", () => {
                removeFrom(row.catId, row.subId, item.id);
                markDirty();
            });
            places.appendChild(chip);
        });

        const hint = document.createElement("p");
        hint.className = "card-hint";
        hint.textContent = "Перетащи в подкатегорию справа. Наведение — тултип как в игре.";

        const doneBtn = document.createElement("button");
        doneBtn.type = "button";
        doneBtn.className = "primary shop-done";
        doneBtn.textContent = "Готово";
        doneBtn.disabled = item.places < 1;
        doneBtn.addEventListener("click", () => {
            if (item.places < 1) {
                return;
            }
            state.done[item.id] = true;
            const next = queue()[0];
            state.currentId = next ? next.id : "";
            hideTooltip();
            render();
        });

        els.current.append(hero, places, hint, doneBtn);
    }

    function bindDrop(zone, catId, subId) {
        zone.addEventListener("dragover", (event) => {
            event.preventDefault();
            zone.classList.add("drop-over");
        });
        zone.addEventListener("dragleave", () => zone.classList.remove("drop-over"));
        zone.addEventListener("drop", (event) => {
            event.preventDefault();
            zone.classList.remove("drop-over");
            const item = currentItem();
            const id = (state.drag && state.drag.id) || (item && item.id);
            if (!id) {
                return;
            }
            insertInto(catId, subId, id);
            markDirty();
        });
    }

    function renderBoard() {
        els.board.innerHTML = "";
        const current = currentItem();
        state.categories.forEach((cat) => {
            const card = document.createElement("section");
            card.className = "shop-cat";
            card.style.setProperty("--cat-accent", cat.accent);
            const head = document.createElement("header");
            const title = document.createElement("h2");
            title.textContent = cat.name;
            const count = document.createElement("span");
            count.className = "shop-cat-count";
            count.textContent = String(cat.count);
            head.append(title, count);
            const subs = document.createElement("div");
            subs.className = "shop-subs";
            cat.subcategories.forEach((sub) => {
                const col = document.createElement("div");
                col.className = "shop-sub";
                col.style.setProperty("--sub-color", sub.color);
                const name = document.createElement("h3");
                name.textContent = `${sub.name} · ${sub.items.length}`;
                const body = document.createElement("div");
                body.className = "shop-sub-body";
                bindDrop(body, cat.id, sub.id);
                sub.items.forEach((id) => {
                    const item = itemById(id);
                    if (!item) {
                        return;
                    }
                    const btn = document.createElement("button");
                    btn.type = "button";
                    btn.className = "shop-mini" + (item.over ? " over" : "") + (current && current.id === id ? " current" : "");
                    btn.title = item.name;
                    btn.appendChild(itemIcon(item, "shop-mini-fallback"));
                    btn.addEventListener("click", () => {
                        if (current && current.id === id) {
                            removeFrom(cat.id, sub.id, id);
                            markDirty();
                            return;
                        }
                        state.currentId = id;
                        hideTooltip();
                        render();
                    });
                    bindHover(btn, item);
                    body.appendChild(btn);
                });
                if (sub.items.length === 0) {
                    const empty = document.createElement("p");
                    empty.className = "shop-empty";
                    empty.textContent = "Сюда";
                    body.appendChild(empty);
                }
                col.append(name, body);
                subs.appendChild(col);
            });
            card.append(head, subs);
            els.board.appendChild(card);
        });
    }

    function render() {
        recount();
        renderCurrent();
        renderBoard();
    }

    function applyCatalog(data) {
        state.categories = data.categories || [];
        state.items = data.items || [];
        state.byId = {};
        state.items.forEach((item) => {
            item.placeRows = [];
            state.byId[item.id] = item;
        });
        state.done = {};
        state.currentId = "";
        T.setDirty(false);
        if (state.search.trim()) {
            jumpSearch();
        }
        render();
        if (new URLSearchParams(location.search).get("clear") === "1") {
            clearPlacements();
        }
    }

    function jumpSearch() {
        const q = state.search.trim().toLowerCase();
        if (!q) {
            return;
        }
        let best = null;
        let bestScore = 9;
        state.items.forEach((item) => {
            const name = item.name.toLowerCase();
            const short = item.id.replace(/^item_/, "");
            let score = 9;
            if (name === q || short === q || item.id === q) {
                score = 0;
            } else if (name.startsWith(q) || short.startsWith(q)) {
                score = 1;
            } else if (name.includes(q) || short.includes(q)) {
                score = 2;
            }
            if (score < bestScore) {
                best = item;
                bestScore = score;
            }
        });
        if (best) {
            delete state.done[best.id];
            state.currentId = best.id;
        }
    }

    async function load() {
        T.setLoading(true);
        try {
            const response = await fetch("/v1/shop/catalog");
            const data = await response.json();
            if (!data.ok) {
                throw new Error(data.error || "catalog_failed");
            }
            applyCatalog(data);
        } catch (err) {
            T.toast(String(err.message || err), "err");
        } finally {
            T.setLoading(false);
        }
    }

    els.search.addEventListener("input", () => {
        state.search = els.search.value;
        jumpSearch();
        render();
    });
    els.form.addEventListener("click", (event) => {
        const btn = event.target.closest("#shop-clear");
        if (!btn) {
            return;
        }
        event.preventDefault();
        clearPlacements();
        T.toast("Категории очищены. Сохрани, чтобы записать в файл.", "ok");
    });
    els.form.addEventListener("submit", async (event) => {
        event.preventDefault();
        els.save.disabled = true;
        try {
            const response = await fetch("/v1/shop/save", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ placements: placements() }),
            });
            const data = await response.json();
            if (!data.ok) {
                throw new Error(data.error || "save_failed");
            }
            applyCatalog(data);
            T.toast("Раскладка сохранена", "ok");
        } catch (err) {
            T.toast(String(err.message || err), "err");
        } finally {
            els.save.disabled = false;
        }
    });

    load();
})();
