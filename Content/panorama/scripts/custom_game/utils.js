"use strict";
const FindDotaHudElement = (id) => dotaHud.FindChildTraverse(id);
const dotaHud = (() => {
    let panel = $.GetContextPanel();
    while (panel) {
        if (panel.id === "DotaHud")
            return panel;
        panel = panel.GetParent();
    }
    return panel;
})();
const RandomInt = (min, max) => {
    return Math.floor(Math.random() * (max - min) + min);
};
const GetPlayerColorHex = (playerID) => {
    let color = Players.GetPlayerColor(playerID).toString(16);
    color = color.substring(6, 8) + color.substring(4, 6) + color.substring(2, 4) + color.substring(0, 2);
    return `#${color}`;
};
const escapeRegExp = (string) => {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
};
const replaceAll = (data, from, to) => {
    return data.replace(new RegExp(escapeRegExp(from), 'g'), to);
};
const GetPortraitImage = (player_id, hero_name) => {
    return `file://{images}/heroes/${hero_name}.png`;
};
const _default_context = $.GetContextPanel();
const Localize = (text, panel) => {
    const token = text.startsWith("#") ? text : "#" + text;
    const localized = $.Localize(token, panel || _default_context);
    return localized == token ? text : localized;
};

const GetTeamPlayer = (playerId) => {
    if (!Players.IsValidPlayerID(playerId)) return 0
    const playerInfo = Game.GetPlayerInfo(playerId)
    let teamPlayer = playerInfo.player_team_id

    if (playerInfo.player_connection_state !== 2) {
        const netTable = CustomNetTables.GetTableValue("players_disconnect_team", playerId.toString())
        if (netTable && netTable.team) teamPlayer = netTable.team
    }

    return teamPlayer
}  