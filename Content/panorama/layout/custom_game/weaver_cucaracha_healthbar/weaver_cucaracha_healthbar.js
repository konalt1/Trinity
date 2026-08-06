(function () {
    "use strict";

    const ROOT = $.GetContextPanel();
    const PANELS = {};
    const UPDATE_INTERVAL = 1 / 30;

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value));
    }

    function getPanel(entityIndex) {
        if (PANELS[entityIndex]) return PANELS[entityIndex];

        const panel = $.CreatePanel("Panel", ROOT, "CucarachaHealthBar_" + entityIndex);
        panel.AddClass("CucarachaHealthBar");

        const health = $.CreatePanel("Panel", panel, "");
        health.AddClass("CucarachaHealth");
        const healthFill = $.CreatePanel("Panel", health, "");
        healthFill.AddClass("CucarachaHealthFill");

        const mana = $.CreatePanel("Panel", panel, "");
        mana.AddClass("CucarachaMana");
        const manaFill = $.CreatePanel("Panel", mana, "");
        manaFill.AddClass("CucarachaManaFill");

        PANELS[entityIndex] = {
            panel: panel,
            healthFill: healthFill,
            manaFill: manaFill,
        };
        return PANELS[entityIndex];
    }

    function canLocalPlayerSeeBar(entityIndex) {
        const localPlayerId = Game.GetLocalPlayerID();
        if (localPlayerId < 0) return true;
        return Entities.GetTeamNumber(entityIndex) === Players.GetTeam(localPlayerId);
    }

    function updateBar(entityIndex, state) {
        const elements = getPanel(entityIndex);
        const panel = elements.panel;

        if (!state || state.active !== 1 || !Entities.IsValidEntity(entityIndex)
            || !Entities.IsAlive(entityIndex) || !canLocalPlayerSeeBar(entityIndex)) {
            panel.style.visibility = "collapse";
            return;
        }

        const origin = Entities.GetAbsOrigin(entityIndex);
        if (!origin || origin.length < 3) {
            panel.style.visibility = "collapse";
            return;
        }

        const scale = clamp(Number(state.scale) || 1, 0.25, 1);
        const healthBarOffset = Math.max(40, Entities.GetHealthBarOffset(entityIndex) * scale);
        const screenX = Game.WorldToScreenX(origin[0], origin[1], origin[2] + healthBarOffset);
        const screenY = Game.WorldToScreenY(origin[0], origin[1], origin[2] + healthBarOffset);
        if (!isFinite(screenX) || !isFinite(screenY) || screenX < 0 || screenY < 0) {
            panel.style.visibility = "collapse";
            return;
        }

        const uiScaleX = panel.actualuiscale_x || 1;
        const uiScaleY = panel.actualuiscale_y || 1;
        panel.style.preTransformScale2d = String(scale);
        panel.style.transform = "translate3d(" + ((screenX - 52) / uiScaleX) + "px, "
            + ((screenY - 10) / uiScaleY) + "px, 0px)";

        const maxHealth = Math.max(1, Entities.GetMaxHealth(entityIndex));
        const maxMana = Math.max(1, Entities.GetMaxMana(entityIndex));
        elements.healthFill.style.width = (clamp(Entities.GetHealth(entityIndex) / maxHealth, 0, 1) * 100) + "%";
        elements.manaFill.style.width = (clamp(Entities.GetMana(entityIndex) / maxMana, 0, 1) * 100) + "%";
        panel.style.visibility = "visible";
    }

    function update() {
        const activeEntities = {};
        for (let playerId = 0; playerId < 8; playerId++) {
            const entityIndex = Players.GetPlayerHeroEntityIndex(playerId);
            if (entityIndex < 0 || activeEntities[entityIndex]) continue;

            activeEntities[entityIndex] = true;
            const state = CustomNetTables.GetTableValue("weaver_cucaracha", String(entityIndex));
            updateBar(entityIndex, state);
        }

        Object.keys(PANELS).forEach(function (entityIndex) {
            if (!activeEntities[entityIndex]) {
                PANELS[entityIndex].panel.style.visibility = "collapse";
            }
        });

        $.Schedule(UPDATE_INTERVAL, update);
    }

    update();
})();
