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
  "RadiantPlayer4",
  "RadiantPlayer5",
  "DirePlayer4",
  "DirePlayer5",
  "TopBarPlayer4",
  "TopBarPlayer5",
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
    FindDotaHudElement(`TopBar${titleName}Players`) ||
    FindDotaHudElement(`TopBar${titleName}Team`) ||
    FindDotaHudElement(`TopBar${titleName}TeamPlayers`) ||
    FindDotaHudElement(`${titleName}TeamPlayers`) ||
    FindDotaHudElement(`${titleName}Team`) ||
    FindDotaHudElement(`${titleName}Players`);

  if (!container) return;

  container.style.width = "186px";
  container.style.horizontalAlign = isRadiant ? "right" : "left";
  container.style.marginLeft = isRadiant ? "0px" : "8px";
  container.style.marginRight = isRadiant ? "8px" : "0px";

  const children = container.Children();
  if (children.length < 5) return;

  children.forEach((child, index) => {
    child.visible = index < MAX_PLAYERS_PER_TEAM;
    child.style.visibility = index < MAX_PLAYERS_PER_TEAM ? "visible" : "collapse";
    child.enabled = index < MAX_PLAYERS_PER_TEAM;
  });
}

function tickHudCleanup() {
  hideDefaultAbilityExtras();
  hideOverflowTopbarPlayers();
  $.Schedule(0.25, tickHudCleanup);
}

tickHudCleanup();
