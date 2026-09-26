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

const SKILL_COLORS = [
    "#6cb4ff", "#7dcea0", "#e6c07b", "#e07a7a", "#c792ea",
    "#82cfff", "#f0a36b", "#9ad0b1", "#f5d76e", "#8ea2c8",
];

const state = {
    heroes: [],
    selectedHero: null,
    heroData: null,
    selectedMatchId: null,
    matchSeries: null,
    hiddenSkills: new Set(),
    sort: "matches",
};

function heroShort(name) {
    return String(name || "").replace(/^npc_dota_hero_/, "");
}

function heroTitle(name) {
    if (HERO_TITLES[name]) {
        return HERO_TITLES[name];
    }
    return heroShort(name).replace(/_/g, " ").replace(/\b\w/g, (ch) => ch.toUpperCase());
}

function heroPortrait(name) {
    return `https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/heroes/${heroShort(name)}.png`;
}

function skillTitle(name) {
    return String(name)
        .replace(/_lua$/, "")
        .replace(/_custom$/, "")
        .replace(/_trinity$/, "")
        .replace(/_/g, " ");
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

function formatClock(seconds) {
    const total = Math.max(0, Number(seconds) || 0);
    const minutes = Math.floor(total / 60);
    const rest = total % 60;
    return `${minutes}:${String(rest).padStart(2, "0")}`;
}

function formatMinuteClock(minute) {
    const total = Math.max(0, Number(minute) || 0);
    const minutes = Math.floor(total);
    const seconds = Math.round((total - minutes) * 60);
    return `${minutes}:${String(seconds).padStart(2, "0")}`;
}

function formatHoverValue(value) {
    const number = Number(value) || 0;
    if (Number.isInteger(number) || Math.abs(number - Math.round(number)) < 0.05) {
        return Math.round(number).toLocaleString("ru-RU");
    }
    return number.toLocaleString("ru-RU", { maximumFractionDigits: 1 });
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

async function api(path) {
    const response = await fetch(path);
    const body = await response.json();
    if (!response.ok || !body || body.ok !== true) {
        throw new Error((body && body.error) || `HTTP ${response.status}`);
    }
    return body;
}

function canvasMouse(canvas, event) {
    const rect = canvas.getBoundingClientRect();
    const scaleX = canvas.width / Math.max(rect.width, 1);
    const scaleY = canvas.height / Math.max(rect.height, 1);
    return {
        x: (event.clientX - rect.left) * scaleX,
        y: (event.clientY - rect.top) * scaleY,
        scaleX,
        scaleY,
    };
}

function chartLayout(canvas, series) {
    const pad = { left: 58, right: 16, top: 14, bottom: 32 };
    const width = canvas.width;
    const height = canvas.height;
    const innerW = width - pad.left - pad.right;
    const innerH = height - pad.top - pad.bottom;
    const points = series.flatMap((item) => item.points || []);
    if (points.length === 0) {
        return null;
    }
    const minX = Math.min(...points.map((p) => p.x));
    const maxX = Math.max(...points.map((p) => p.x), minX + 1);
    const maxY = Math.max(...points.map((p) => p.y), 1);
    const minY = 0;
    return {
        pad,
        width,
        height,
        minX,
        maxX,
        minY,
        maxY,
        xOf: (x) => pad.left + ((x - minX) / (maxX - minX)) * innerW,
        yOf: (y) => pad.top + innerH - ((y - minY) / (maxY - minY)) * innerH,
    };
}

function findHoveredPoint(chart, mouse) {
    const layout = chart.layout;
    if (!layout) {
        return null;
    }
    let best = null;
    let bestDist = 14;
    chart.series.forEach((item, seriesIndex) => {
        (item.points || []).forEach((point, pointIndex) => {
            const x = layout.xOf(point.x);
            const y = layout.yOf(point.y);
            const dist = Math.hypot((mouse.x - x) / mouse.scaleX, (mouse.y - y) / mouse.scaleY);
            if (dist <= bestDist) {
                bestDist = dist;
                best = { seriesIndex, pointIndex, item, point, x, y };
            }
        });
    });
    return best;
}

function drawAxisBadge(ctx, text, x, y, align, color) {
    ctx.font = "11px Segoe UI, sans-serif";
    const width = ctx.measureText(text).width + 10;
    const height = 16;
    let left = x;
    if (align === "right") {
        left = x - width;
    } else if (align === "center") {
        left = x - width / 2;
    }
    left = Math.max(2, Math.min(left, ctx.canvas.width - width - 2));
    const top = Math.max(2, Math.min(y - height / 2, ctx.canvas.height - height - 2));
    ctx.beginPath();
    if (typeof ctx.roundRect === "function") {
        ctx.roundRect(left, top, width, height, 4);
    } else {
        ctx.rect(left, top, width, height);
    }
    ctx.fillStyle = "rgba(16, 20, 28, 0.94)";
    ctx.fill();
    ctx.strokeStyle = color;
    ctx.lineWidth = 1;
    ctx.stroke();
    ctx.fillStyle = "#e8eef7";
    ctx.fillText(text, left + 5, top + 12);
}

function paintChart(canvas, hover) {
    const chart = canvas._chart;
    if (!chart) {
        return;
    }
    const ctx = canvas.getContext("2d");
    const width = canvas.width;
    const height = canvas.height;
    ctx.clearRect(0, 0, width, height);

    const { series, options, layout } = chart;
    if (!layout) {
        ctx.fillStyle = "#8b97ab";
        ctx.font = "12px Segoe UI, sans-serif";
        ctx.textAlign = "center";
        ctx.fillText("Нет данных", width / 2, height / 2);
        ctx.textAlign = "left";
        return;
    }

    const { pad, xOf, yOf, minX, maxX, maxY } = layout;

    ctx.strokeStyle = "#2a3446";
    ctx.fillStyle = "#8b97ab";
    ctx.font = "11px Segoe UI, sans-serif";
    ctx.lineWidth = 1;
    for (let i = 0; i <= 4; i++) {
        const value = (maxY / 4) * i;
        const y = yOf(value);
        ctx.beginPath();
        ctx.moveTo(pad.left, y);
        ctx.lineTo(width - pad.right, y);
        ctx.stroke();
        ctx.fillText(formatNumber(value), 8, y + 4);
    }

    const tickStep = Math.max(1, Math.round((maxX - minX) / 8));
    for (let x = minX; x <= maxX; x += tickStep) {
        ctx.fillText(`${x}m`, xOf(x) - 8, height - 8);
    }

    series.forEach((item) => {
        if (!item.points.length) {
            return;
        }
        ctx.beginPath();
        ctx.strokeStyle = item.color;
        ctx.lineWidth = item.width || 2;
        ctx.setLineDash(item.dash || []);
        item.points.forEach((point, index) => {
            const x = xOf(point.x);
            const y = yOf(point.y);
            if (index === 0) {
                ctx.moveTo(x, y);
            } else {
                ctx.lineTo(x, y);
            }
        });
        ctx.stroke();
        ctx.setLineDash([]);
        item.points.forEach((point) => {
            ctx.beginPath();
            ctx.fillStyle = item.color;
            ctx.arc(xOf(point.x), yOf(point.y), item.dash ? 2 : 2.5, 0, Math.PI * 2);
            ctx.fill();
        });
    });

    if (options.subtitle) {
        ctx.fillStyle = "#8b97ab";
        ctx.fillText(options.subtitle, pad.left, 12);
    }

    if (!hover) {
        return;
    }

    ctx.save();
    ctx.strokeStyle = hover.item.color;
    ctx.globalAlpha = 0.85;
    ctx.lineWidth = 1;
    ctx.setLineDash([4, 3]);
    ctx.beginPath();
    ctx.moveTo(hover.x, pad.top);
    ctx.lineTo(hover.x, height - pad.bottom);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(pad.left, hover.y);
    ctx.lineTo(width - pad.right, hover.y);
    ctx.stroke();
    ctx.restore();

    ctx.beginPath();
    ctx.fillStyle = hover.item.color;
    ctx.arc(hover.x, hover.y, 5, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.strokeStyle = "#10141c";
    ctx.lineWidth = 2;
    ctx.arc(hover.x, hover.y, 5, 0, Math.PI * 2);
    ctx.stroke();

    drawAxisBadge(ctx, formatHoverValue(hover.point.y), pad.left - 6, hover.y, "right", hover.item.color);
    drawAxisBadge(ctx, formatMinuteClock(hover.point.x), hover.x, height - 10, "center", hover.item.color);
}

function bindChartHover(canvas) {
    if (canvas.dataset.hoverBound === "1") {
        return;
    }
    canvas.dataset.hoverBound = "1";
    canvas.addEventListener("mousemove", (event) => {
        const chart = canvas._chart;
        if (!chart) {
            return;
        }
        const hover = findHoveredPoint(chart, canvasMouse(canvas, event));
        const next = hover ? `${hover.seriesIndex}:${hover.pointIndex}` : "";
        canvas.style.cursor = hover ? "pointer" : "crosshair";
        if (canvas._hoverKey === next) {
            return;
        }
        canvas._hoverKey = next;
        paintChart(canvas, hover);
    });
    canvas.addEventListener("mouseleave", () => {
        canvas.style.cursor = "";
        if (!canvas._hoverKey) {
            return;
        }
        canvas._hoverKey = "";
        paintChart(canvas, null);
    });
}

function fitCanvas(canvas, height) {
    const parent = canvas.parentElement;
    const width = Math.max(360, Math.floor(parent.getBoundingClientRect().width));
    if (canvas.width !== width) {
        canvas.width = width;
    }
    if (canvas.height !== height) {
        canvas.height = height;
    }
}

function drawChart(canvas, series, options = {}) {
    fitCanvas(canvas, options.height || 280);
    canvas._chart = {
        series,
        options,
        layout: chartLayout(canvas, series),
    };
    canvas._hoverKey = "";
    canvas.style.cursor = canvas._chart.layout ? "crosshair" : "";
    bindChartHover(canvas);
    paintChart(canvas, null);
}

function pointsFrom(minutes, values) {
    return (minutes || []).map((minute, index) => ({
        x: minute,
        y: Number(values[index]) || 0,
    }));
}

function sortHeroes(heroes) {
    const byName = (a, b) => heroTitle(a.hero).localeCompare(heroTitle(b.hero), "ru");
    const desc = (key) => (a, b) => (Number(b[key]) || 0) - (Number(a[key]) || 0) || byName(a, b);
    if (state.sort === "name") {
        return heroes.slice().sort(byName);
    }
    if (state.sort === "pick") {
        return heroes.slice().sort(desc("pick_rate"));
    }
    if (state.sort === "win") {
        return heroes.slice().sort(desc("win_rate"));
    }
    return heroes.slice().sort(desc("matches"));
}

function renderHeroList() {
    const query = document.getElementById("hero-search").value.trim().toLowerCase();
    const root = document.getElementById("hero-list");
    const empty = document.getElementById("hero-empty");
    const count = document.getElementById("hero-count");
    root.innerHTML = "";
    const heroes = sortHeroes(state.heroes.filter((hero) => {
        const title = heroTitle(hero.hero).toLowerCase();
        return title.includes(query) || hero.hero.includes(query);
    }));
    empty.classList.toggle("hidden", state.heroes.length > 0);
    if (count) {
        count.textContent = heroes.length === state.heroes.length
            ? String(state.heroes.length)
            : `${heroes.length} из ${state.heroes.length}`;
    }
    heroes.forEach((hero) => {
        const matches = Number(hero.matches) || 0;
        const pickRate = hero.pick_rate;
        const winRate = hero.win_rate;
        const button = document.createElement("button");
        button.type = "button";
        button.className = "hero-btn"
            + (state.selectedHero === hero.hero ? " active" : "")
            + (matches === 0 ? " empty" : "");
        button.title = `${heroTitle(hero.hero)} · пик ${formatRate(pickRate)} · вин ${formatRate(winRate)} · ${matches} матч.`;

        const img = document.createElement("img");
        img.alt = heroTitle(hero.hero);
        img.src = heroPortrait(hero.hero);
        img.loading = "eager";
        img.addEventListener("error", () => {
            const fallback = document.createElement("div");
            fallback.className = "hero-portrait";
            fallback.textContent = heroTitle(hero.hero).slice(0, 2);
            img.replaceWith(fallback);
        });

        const name = document.createElement("span");
        name.className = "name";
        name.textContent = heroTitle(hero.hero);

        const rates = document.createElement("div");
        rates.className = "rates";
        const pick = document.createElement("span");
        pick.textContent = `Пик ${formatRate(pickRate)}`;
        const win = document.createElement("span");
        win.className = `rate-win ${winClass(winRate)}`.trim();
        win.textContent = `Вин ${formatRate(winRate)}`;
        rates.append(pick, win);

        button.append(img, name, rates);
        button.addEventListener("click", () => {
            selectHero(hero.hero).catch((error) => Trinity.toast(String(error.message || error), false));
        });
        root.appendChild(button);
    });
}

function renderHeader() {
    const root = document.getElementById("hero-head");
    const empty = document.getElementById("analytics-empty");
    if (!state.selectedHero || !state.heroData) {
        root.innerHTML = "";
        empty.classList.remove("hidden");
        return;
    }
    empty.classList.add("hidden");
    const pickRate = state.heroData.pick_rate;
    const winRate = state.heroData.win_rate;
    const matches = state.heroData.matches_count
        ?? (state.heroData.matches || []).length
        ?? 0;
    const wins = state.heroData.wins ?? 0;
    root.innerHTML = `
        <img class="portrait" alt="" src="${heroPortrait(state.selectedHero)}" onerror="this.style.display='none'">
        <div>
            <h1>${heroTitle(state.selectedHero)}</h1>
            <div class="pill-row">
                <span class="stat">Пикрейт <strong>${formatRate(pickRate)}</strong></span>
                <span class="stat ${winClass(winRate)}">Винрейт <strong>${formatRate(winRate)}</strong></span>
                <span class="stat">Матчи <strong>${matches}</strong>${matches > 0 ? ` (${wins} побед)` : ""}</span>
            </div>
        </div>
    `;
}

function renderCharts() {
    const charts = document.getElementById("charts");
    const matchesCard = document.getElementById("matches-card");
    if (!state.heroData) {
        charts.classList.add("hidden");
        matchesCard.classList.add("hidden");
        return;
    }
    charts.classList.remove("hidden");
    matchesCard.classList.remove("hidden");

    const average = state.heroData.average;
    const minutes = average.minutes || [];
    const overlay = state.matchSeries;

    drawChart(document.getElementById("chart-networth"), [
        { color: "#6cb4ff", points: pointsFrom(minutes, average.networth) },
        overlay ? { color: "#6cb4ff", dash: [6, 4], width: 2, points: pointsFrom(overlay.minutes, overlay.networth) } : null,
    ].filter(Boolean));

    drawChart(document.getElementById("chart-creeps"), [
        { color: "#e6c07b", points: pointsFrom(minutes, average.lane_creeps) },
        { color: "#7dcea0", points: pointsFrom(minutes, average.jungle_creeps) },
        overlay ? { color: "#e6c07b", dash: [6, 4], points: pointsFrom(overlay.minutes, overlay.lane_creeps) } : null,
        overlay ? { color: "#7dcea0", dash: [6, 4], points: pointsFrom(overlay.minutes, overlay.jungle_creeps) } : null,
    ].filter(Boolean), { subtitle: "жёлтый — лейн, зелёный — лес" });

    drawChart(document.getElementById("chart-damage"), [
        { color: "#e07a7a", points: pointsFrom(minutes, average.hero_damage) },
        overlay ? { color: "#e07a7a", dash: [6, 4], points: pointsFrom(overlay.minutes, overlay.hero_damage) } : null,
    ].filter(Boolean));

    const skillNames = Object.keys(average.skills || {});
    const legend = document.getElementById("skill-legend");
    legend.innerHTML = "";
    const skillSeries = [];
    skillNames.forEach((name, index) => {
        const color = SKILL_COLORS[index % SKILL_COLORS.length];
        const hidden = state.hiddenSkills.has(name);
        const button = document.createElement("button");
        button.className = hidden ? "off" : "";
        button.innerHTML = `<span class="swatch" style="background:${color}"></span>${skillTitle(name)}`;
        button.addEventListener("click", () => {
            if (hidden) {
                state.hiddenSkills.delete(name);
            } else {
                state.hiddenSkills.add(name);
            }
            renderCharts();
        });
        legend.appendChild(button);
        if (hidden) {
            return;
        }
        skillSeries.push({ color, points: pointsFrom(minutes, average.skills[name]) });
        if (overlay && overlay.skills[name]) {
            skillSeries.push({
                color,
                dash: [6, 4],
                points: pointsFrom(overlay.minutes, overlay.skills[name]),
            });
        }
    });
    const skillsCanvas = document.getElementById("chart-skills");
    const skillsEmpty = document.getElementById("chart-skills-empty");
    const hasSkillData = skillSeries.some((item) => item.points.length > 0);
    skillsCanvas.classList.toggle("hidden", !hasSkillData && skillNames.length === 0);
    skillsEmpty.classList.toggle("hidden", hasSkillData || skillNames.length > 0);
    if (!skillsCanvas.classList.contains("hidden")) {
        drawChart(skillsCanvas, skillSeries, { height: 320 });
    }

    const rows = document.getElementById("match-rows");
    rows.innerHTML = "";
    state.heroData.matches.forEach((match) => {
        const tr = document.createElement("tr");
        tr.className = "match-row" + (state.selectedMatchId === match.match_id ? " active" : "");
        tr.setAttribute("role", "button");
        tr.tabIndex = 0;
        tr.innerHTML = `
            <td>${formatDate(match.started_at)}</td>
            <td>${match.won === true ? "W" : match.won === false ? "L" : "—"}</td>
            <td>${formatClock(match.duration)}</td>
            <td>${formatNumber(match.networth)}</td>
            <td>${match.lane_creeps}</td>
            <td>${match.jungle_creeps}</td>
            <td>${formatNumber(match.hero_damage)}</td>
        `;
        tr.addEventListener("click", () => {
            toggleMatch(match.match_id).catch((error) => Trinity.toast(String(error.message || error), false));
        });
        rows.appendChild(tr);
    });
}

async function selectHero(hero) {
    state.selectedHero = hero;
    state.selectedMatchId = null;
    state.matchSeries = null;
    state.hiddenSkills = new Set();
    state.heroData = await api(`/v1/analytics/hero?hero=${encodeURIComponent(hero)}`);
    const params = new URLSearchParams(location.search);
    params.set("view", "analytics");
    params.set("hero", hero);
    history.replaceState(null, "", `/?${params.toString()}`);
    renderHeroList();
    renderHeader();
    renderCharts();
}

async function toggleMatch(matchId) {
    if (state.selectedMatchId === matchId) {
        state.selectedMatchId = null;
        state.matchSeries = null;
        renderCharts();
        return;
    }
    const payload = await api(`/v1/analytics/match?id=${encodeURIComponent(matchId)}`);
    const series = (payload.heroes || []).find((row) => row.hero === state.selectedHero) || null;
    state.selectedMatchId = matchId;
    state.matchSeries = series;
    renderCharts();
}

let resizeTimer = null;
window.addEventListener("resize", () => {
    if (!state.heroData) {
        return;
    }
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(renderCharts, 120);
});

document.getElementById("hero-search").addEventListener("input", renderHeroList);
document.getElementById("hero-sort").addEventListener("change", (event) => {
    state.sort = event.target.value;
    renderHeroList();
});

Trinity.skeleton(document.getElementById("hero-list"), "skel-hero", 9);

api("/v1/analytics/heroes")
    .then((payload) => {
        state.heroes = payload.heroes || [];
        renderHeroList();
        const wanted = new URLSearchParams(location.search).get("hero");
        const asked = state.heroes.find((hero) => hero.hero === wanted);
        const target = asked || state.heroes.find((hero) => (hero.matches || 0) > 0);
        if (target) {
            return selectHero(target.hero);
        }
        renderHeader();
    })
    .catch((error) => {
        document.getElementById("hero-list").innerHTML = "";
        renderHeader();
        Trinity.toast(`API недоступно: ${error.message}`, false);
    });
