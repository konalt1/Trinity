"use strict";

const MAX_PLAYERS_PER_TEAM = 3;
const HIDE_IDS = [
  "StatBranch",
  "StatBranchDrawer",
  "StatBranchButton",
  "StatBranchBackground",
  "level_stats_frame",
  "LevelStatsFrame",
  "InnateAbility",
  "InnateIcon",
  "innate",
  "innate_icon",
  "Facet",
  "FacetButton",
  "FacetIcon",
  "FacetContainer",
  "HeroFacet",
  "HeroFacetButton",
  "HeroFacetIcon",
];
const HIDE_TOPBAR_SLOT_IDS = [
  "TopBarRadiantPlayer4",
  "TopBarRadiantPlayer5",
  "TopBarDirePlayer4",
  "TopBarDirePlayer5",
  "RadiantPlayer3",
  "RadiantPlayer4",
  "RadiantPlayer5",
  "DirePlayer3",
  "DirePlayer4",
  "DirePlayer5",
  "DirePlayer8",
  "DirePlayer9",
  "TopBarPlayer3",
  "TopBarPlayer4",
  "TopBarPlayer5",
  "TopBarPlayer8",
  "TopBarPlayer9",
  "TopBarPlayer10",
];

function hidePanel(panel) {
  if (!panel) return;
  panel.visible = false;
  panel.style.visibility = "collapse";
  panel.style.opacity = "0";
  panel.enabled = false;
}

function hideSlot(panel) {
  if (!panel) return;
  panel.visible = false;
  panel.style.visibility = "collapse";
  panel.style.width = "0px";
  panel.style.height = "0px";
  panel.style.opacity = "0";
  panel.enabled = false;
}

function hideDefaultAbilityExtras() {
  HIDE_IDS.forEach((id) => hidePanel(FindDotaHudElement(id)));
  hideAbilityPanelLeftExtra();
}

function hideAbilityPanelLeftExtra() {
  const abilities = FindDotaHudElement("abilities");
  if (!abilities) return;

  const parent = abilities.GetParent();
  if (!parent) return;

  const siblings = parent.Children();
  const abilityIndex = siblings.indexOf(abilities);
  if (abilityIndex <= 0) return;

  hidePanel(siblings[abilityIndex - 1]);
}

function hideOverflowTopbarPlayers() {
  compactTopbarTeam("radiant");
  compactTopbarTeam("dire");
  HIDE_TOPBAR_SLOT_IDS.forEach((id) => hidePanel(FindDotaHudElement(id)));
}

function compactTopbarTeam(teamName) {
  const isRadiant = teamName === "radiant";
  const titleName = isRadiant ? "Radiant" : "Dire";
  const container =
    FindDotaHudElement(`TopBar${titleName}PlayersContainer`) ||
    FindDotaHudElement(`TopBar${titleName}Players`) ||
    FindDotaHudElement(`TopBar${titleName}Team`) ||
    FindDotaHudElement(`TopBar${titleName}TeamPlayers`) ||
    FindDotaHudElement(`${titleName}TeamPlayers`) ||
    FindDotaHudElement(`${titleName}Team`) ||
    FindDotaHudElement(`${titleName}Players`);

  if (!container) return;

  container.style.width = "186px";
  container.style.horizontalAlign = isRadiant ? "right" : "left";
  container.style.marginLeft = isRadiant ? "0px" : "20px";
  container.style.marginRight = isRadiant ? "20px" : "0px";

  const children = container.Children();
  children.forEach((child, index) => {
    if (index < MAX_PLAYERS_PER_TEAM) {
      child.visible = true;
      child.style.visibility = "visible";
      child.style.width = null;
      child.style.height = null;
      child.style.opacity = null;
      child.enabled = true;
    } else {
      hideSlot(child);
    }
  });
}

function hidePregamePlayerSlots() {
  const radiantContainer = FindDotaHudElement("RadiantTeamPlayers");
  if (radiantContainer) {
    const children = radiantContainer.Children();
    children.forEach((child, index) => {
      if (index >= MAX_PLAYERS_PER_TEAM) {
        hideSlot(child);
      } else {
        child.visible = true;
        child.style.visibility = "visible";
        child.style.width = null;
        child.style.height = null;
        child.style.opacity = null;
        child.enabled = true;
      }
    });
  }

  const direContainer = FindDotaHudElement("DireTeamPlayers");
  if (direContainer) {
    const children = direContainer.Children();
    children.forEach((child, index) => {
      if (index >= MAX_PLAYERS_PER_TEAM) {
        hideSlot(child);
      } else {
        child.visible = true;
        child.style.visibility = "visible";
        child.style.width = null;
        child.style.height = null;
        child.style.opacity = null;
        child.enabled = true;
      }
    });
  }
}

// -----------------------------------------------------------------------
// Spread skill icons to fill space freed by hidden innate / talent panels
// -----------------------------------------------------------------------

function spreadAbilities() {
  const abilities = FindDotaHudElement("abilities");
  if (!abilities) return;

  // Reset custom width styles to default to prevent any circular layout dependencies or jumping
  abilities.style.width = null;
  abilities.style.maxWidth = null;
  abilities.style.minWidth = null;

  // Clean up temporary debug label if it exists
  const debugLabel = FindDotaHudElement("TrinityDebugLabel");
  if (debugLabel) {
    debugLabel.DeleteAsync(0);
  }

  const children = abilities.Children();
  if (!children || children.length === 0) return;

  // Apply a fixed, clean spacing (12px on each side of every skill slot)
  const marginPerSide = 12;

  children.forEach((child) => {
    if (child.visible) {
      child.style.marginLeft = marginPerSide + "px";
      child.style.marginRight = marginPerSide + "px";
    } else {
      child.style.marginLeft = "0px";
      child.style.marginRight = "0px";
    }
  });
}

function adjustTopbarSpacings() {
  const radiantScore = FindDotaHudElement("RadiantScore");
  if (radiantScore) {
    radiantScore.style.marginRight = "20px";
  }
  const direScore = FindDotaHudElement("DireScore");
  if (direScore) {
    direScore.style.marginLeft = "20px";
  }

  const radiantTeam = FindDotaHudElement("TopBarRadiantTeam");
  if (radiantTeam) {
    radiantTeam.style.marginRight = "35px";
  }
  const direTeam = FindDotaHudElement("TopBarDireTeam");
  if (direTeam) {
    direTeam.style.marginLeft = "35px";
  }
}

function tickHudCleanup() {
  hideDefaultAbilityExtras();
  hideOverflowTopbarPlayers();
  hidePregamePlayerSlots();
  adjustTopbarSpacings();
  spreadAbilities();
  $.Schedule(0.25, tickHudCleanup);
}

tickHudCleanup();
