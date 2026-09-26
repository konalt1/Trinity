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

function formatCount(value) {
    if (value === null || value === undefined) {
        return "—";
    }
    const number = Number(value);
    if (!Number.isFinite(number)) {
        return "—";
    }
    return String(Math.round(number));
}

function formatDecimal(value, digits = 1) {
    if (value === null || value === undefined) {
        return "—";
    }
    const number = Number(value);
    if (!Number.isFinite(number)) {
        return "—";
    }
    if (Number.isInteger(number)) {
        return String(number);
    }
    return number.toFixed(digits);
}

function formatDuration(seconds) {
    if (seconds === null || seconds === undefined) {
        return "—";
    }
    const total = Math.round(Number(seconds));
    if (!Number.isFinite(total) || total < 0) {
        return "—";
    }
    const minutes = Math.floor(total / 60);
    const rest = total % 60;
    return `${minutes}:${String(rest).padStart(2, "0")}`;
}

function setText(id, value) {
    const node = document.getElementById(id);
    if (node) {
        node.textContent = value;
    }
}

function fillWinrate(prefix, period) {
    setText(`metric-${prefix}-radiant`, formatRate(period.radiant_win_rate));
    setText(`metric-${prefix}-dire`, formatRate(period.dire_win_rate));
    const decided = Number(period.decided) || 0;
    const note = document.getElementById(`metric-${prefix}-decided`);
    if (!note) {
        return;
    }
    if (decided < 1) {
        note.textContent = "Пока нет матчей с победителем";
        return;
    }
    note.textContent = `Radiant ${period.radiant_wins} · Dire ${period.dire_wins} · ${decided} матч.`;
}

function fillLifetime(stats) {
    setText("metric-all-matches", formatCount(stats.matches));
    setText("metric-all-kpm", formatDecimal(stats.kills_per_minute));
    setText("metric-all-gpm", formatCount(stats.median_gpm));
    setText("metric-all-xpm", formatCount(stats.median_xpm));
    setText("metric-all-bosses", formatDecimal(stats.avg_bosses));
    setText("metric-all-creeps-radiant", formatDecimal(stats.avg_creeps_radiant));
    setText("metric-all-creeps-dire", formatDecimal(stats.avg_creeps_dire));
    setText("metric-all-duration", formatDuration(stats.avg_duration));
    setText("metric-all-duration-radiant", formatDuration(stats.avg_duration_radiant_win));
    setText("metric-all-duration-dire", formatDuration(stats.avg_duration_dire_win));
    setText("metric-all-unfinished", formatRate(stats.unfinished_rate));

    const note = document.getElementById("metric-all-unfinished-note");
    if (!note) {
        return;
    }
    const six = Number(stats.six_player_matches) || 0;
    const completed = Number(stats.matches) || 0;
    if (six < 1) {
        note.textContent = "Пока нет матчей с 6 игроками";
        return;
    }
    note.textContent = `Не завершены ${six - completed} из ${six} матчей 3v3`;
}

async function loadOverview() {
    const response = await fetch("/v1/analytics/overview");
    const body = await response.json();
    if (!response.ok || !body || body.ok !== true) {
        throw new Error((body && body.error) || `HTTP ${response.status}`);
    }
    const week = body.week || {};
    const month = body.month || {};
    setText("metric-week-matches", String(Number(week.matches) || 0));
    setText("metric-week-players", String(Number(week.unique_players) || 0));
    setText("metric-month-players", String(Number(month.unique_players) || 0));
    fillWinrate("week", week);
    fillWinrate("month", month);
    fillLifetime(body.all || {});
}

Trinity.setLoading(true);
loadOverview()
    .catch((error) => {
        Trinity.toast(`API недоступно: ${error.message}`, false);
    })
    .finally(() => {
        Trinity.setLoading(false);
    });
