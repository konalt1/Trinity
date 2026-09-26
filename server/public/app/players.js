const HERO_TITLES = {
    npc_dota_hero_chen: "Чен",
    npc_dota_hero_dawnbreaker: "Донбрейкер",
    npc_dota_hero_doom_bringer: "Дум",
    npc_dota_hero_ember_spirit: "Эмбер",
    npc_dota_hero_juggernaut: "Джаггернаут",
    npc_dota_hero_largo: "Ларго",
    npc_dota_hero_lich: "Лич",
    npc_dota_hero_lion: "Лион",
    npc_dota_hero_nevermore: "Невермор",
    npc_dota_hero_ogre_magi: "Огр",
    npc_dota_hero_omniknight: "Омник",
    npc_dota_hero_phantom_assassin: "Фантомка",
    npc_dota_hero_pudge: "Пудж",
    npc_dota_hero_silencer: "Сайленсер",
    npc_dota_hero_techies: "Течис",
    npc_dota_hero_tinker: "Тинкер",
    npc_dota_hero_weaver: "Вивер",
};

const els = {
    grantForm: document.getElementById("grant-form"),
    grantSteam: document.getElementById("grant-steamid"),
    grantCount: document.getElementById("grant-count"),
    list: document.getElementById("players-list"),
    rows: document.getElementById("player-rows"),
    empty: document.getElementById("players-empty"),
    card: document.getElementById("player-card"),
    title: document.getElementById("player-title"),
    stats: document.getElementById("player-stats"),
    matches: document.getElementById("player-match-rows"),
    matchEmpty: document.getElementById("player-empty"),
};

function showSkeletonRows(body, columns, count) {
    body.innerHTML = "";
    for (let i = 0; i < count; i++) {
        const tr = document.createElement("tr");
        for (let c = 0; c < columns; c++) {
            const td = document.createElement("td");
            const bar = document.createElement("div");
            bar.className = "skel skel-line";
            td.appendChild(bar);
            tr.appendChild(td);
        }
        body.appendChild(tr);
    }
}

function parseSteamId(value) {
    const text = String(value || "").trim();
    return /^\d+$/.test(text) ? text : null;
}

function selectedSteamId() {
    return parseSteamId(new URLSearchParams(location.search).get("steamid"));
}

function heroTitle(name) {
    if (HERO_TITLES[name]) {
        return HERO_TITLES[name];
    }
    return String(name || "")
        .replace(/^npc_dota_hero_/, "")
        .replace(/_/g, " ")
        .replace(/\b\w/g, (ch) => ch.toUpperCase()) || "—";
}

function formatRate(value) {
    if (value === null || value === undefined) {
        return "—";
    }
    const number = Number(value);
    if (!Number.isFinite(number)) {
        return "—";
    }
    return `${Number.isInteger(number) ? String(number) : number.toFixed(1)}%`;
}

function winClass(value) {
    if (value === null || value === undefined) {
        return "";
    }
    return Number(value) >= 50 ? "up" : "down";
}

function formatNumber(value) {
    const number = Number(value) || 0;
    if (Math.abs(number) >= 10000) {
        return `${(number / 1000).toFixed(1)}k`;
    }
    if (Math.abs(number) >= 1000) {
        return Math.round(number).toLocaleString("ru-RU");
    }
    return Number.isInteger(number) ? String(number) : number.toFixed(1);
}

function formatClock(seconds) {
    const total = Math.max(0, Number(seconds) || 0);
    const minutes = Math.floor(total / 60);
    const rest = total % 60;
    return `${minutes}:${String(rest).padStart(2, "0")}`;
}

function formatDate(value) {
    if (!value) {
        return "—";
    }
    const date = new Date(String(value).replace(" ", "T"));
    if (Number.isNaN(date.getTime())) {
        return String(value);
    }
    return date.toLocaleString("ru-RU", {
        day: "2-digit",
        month: "2-digit",
        hour: "2-digit",
        minute: "2-digit",
    });
}

function teamLabel(team) {
    if (Number(team) === 2) {
        return "Radiant";
    }
    if (Number(team) === 3) {
        return "Dire";
    }
    return "—";
}

function teamClass(team) {
    if (Number(team) === 2) {
        return "team radiant";
    }
    if (Number(team) === 3) {
        return "team dire";
    }
    return "team";
}

async function api(path) {
    const response = await fetch(path);
    const body = await response.json();
    if (!response.ok || !body || body.ok !== true) {
        throw new Error((body && body.error) || `HTTP ${response.status}`);
    }
    return body;
}

function renderList(players) {
    els.rows.innerHTML = "";
    els.empty.classList.toggle("hidden", players.length > 0);
    players.forEach((player) => {
        const steamid = String(player.steamid);
        const tr = document.createElement("tr");
        tr.className = "player-row";
        tr.setAttribute("role", "button");
        tr.tabIndex = 0;
        tr.innerHTML = `
            <td><a class="player-link" href="/?view=players&steamid=${encodeURIComponent(steamid)}">${steamid}</a></td>
            <td>${player.matches}</td>
            <td>${player.wins}</td>
            <td>${formatRate(player.win_rate)}</td>
            <td>${formatDate(player.last_match_at)}</td>
        `;
        const open = () => {
            location.assign(`/?view=players&steamid=${encodeURIComponent(steamid)}`);
        };
        tr.addEventListener("click", (event) => {
            if (event.target.closest("a")) {
                return;
            }
            open();
        });
        tr.addEventListener("keydown", (event) => {
            if (event.key === "Enter" || event.key === " ") {
                event.preventDefault();
                open();
            }
        });
        els.rows.appendChild(tr);
    });
}

function renderPlayer(payload) {
    const steamid = String(payload.steamid);
    const matches = payload.matches || [];
    els.title.textContent = steamid;
    els.stats.innerHTML = `
        <span class="stat">Матчи <strong>${payload.matches_count ?? matches.length}</strong></span>
        <span class="stat ${winClass(payload.win_rate)}">Винрейт <strong>${formatRate(payload.win_rate)}</strong></span>
        <span class="stat">Победы <strong>${payload.wins ?? 0}</strong></span>
    `;
    els.matches.innerHTML = "";
    els.matchEmpty.classList.toggle("hidden", matches.length > 0);
    matches.forEach((match) => {
        const tr = document.createElement("tr");
        tr.innerHTML = `
            <td>${formatDate(match.started_at)}</td>
            <td>${heroTitle(match.hero)}</td>
            <td><span class="${teamClass(match.team)}">${teamLabel(match.team)}</span></td>
            <td>${match.won === true ? "W" : match.won === false ? "L" : "—"}</td>
            <td>${formatClock(match.duration)}</td>
            <td>${formatNumber(match.networth)}</td>
            <td>${formatNumber(match.hero_damage)}</td>
        `;
        els.matches.appendChild(tr);
    });
}

async function showList() {
    els.list.classList.remove("hidden");
    els.card.classList.add("hidden");
    showSkeletonRows(els.rows, 5, 5);
    const payload = await api("/v1/analytics/players");
    renderList(payload.players || []);
}

async function showPlayer(steamid) {
    els.list.classList.add("hidden");
    els.card.classList.remove("hidden");
    showSkeletonRows(els.matches, 7, 5);
    const payload = await api(`/v1/analytics/player?steamid=${encodeURIComponent(steamid)}`);
    renderPlayer(payload);
}

const steamid = selectedSteamId();
(steamid ? showPlayer(steamid) : showList()).catch((err) => {
    els.rows.innerHTML = "";
    els.matches.innerHTML = "";
    Trinity.toast(String(err.message || err), false);
});

if (els.grantForm && els.grantSteam && els.grantCount) {
    els.grantForm.addEventListener("submit", async (event) => {
        event.preventDefault();
        const grantId = parseSteamId(els.grantSteam.value);
        const count = Number(els.grantCount.value) || 0;
        if (!grantId) {
            Trinity.toast("Нужен числовой SteamID", false);
            return;
        }
        if (count < 1 || count > 99) {
            Trinity.toast("Число боксов: 1–99", false);
            return;
        }
        try {
            const response = await fetch("/v1/stickers/studio/grant-lootbox", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ steamid: grantId, count }),
            });
            const data = await response.json();
            if (!data.ok) {
                throw new Error(data.error || "grant_failed");
            }
            const boxes = data.player && data.player.lootboxes;
            Trinity.toast(`Выдано ${count}. Сейчас боксов: ${boxes}`, true);
        } catch (err) {
            Trinity.toast(String(err.message || err), false);
        }
    });
}
