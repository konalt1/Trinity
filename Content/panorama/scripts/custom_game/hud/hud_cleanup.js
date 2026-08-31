"use strict";

const MIN_ABILITIES_WIDTH = 220;

const HIDE_IDS = [
  "StatBranch",
  "StatBranchDrawer",
  "StatBranchButton",
  "StatBranchBackground",
  "StatBranchGraphics",
  "StatBranchBG",
  "StatBranchGraphicsContainer",
  "talent_icon",
  "InnateAbility",
  "InnateIcon",
  "innate",
  "innate_icon",
  "InnateAbilityContainer",
  "InnateAbilityBG",
  "InnateAbilityGraphics",
  "Facet",
  "FacetButton",
  "FacetIcon",
  "FacetContainer",
  "HeroFacet",
  "HeroFacetButton",
  "HeroFacetIcon",
];
const HIDE_CLASSES = [
  "ShowStatBranch",
  "RootInnateDisplay",
  "FacetInnateDisplay",
  "HasInnate",
  "InnateFrame",
  "FacetHolder",
];
function hidePanel(panel) {
  if (!panel) return;
  panel.visible = false;
  panel.style.visibility = "collapse";
  panel.style.width = "0px";
  panel.style.height = "0px";
  panel.style.opacity = "0";
  panel.enabled = false;
}

function restorePanel(panel) {
  if (!panel) return;
  panel.visible = true;
  panel.style.visibility = "visible";
  panel.style.width = null;
  panel.style.height = null;
  panel.style.opacity = null;
  panel.enabled = true;
}

function hidePanelsByClass(className) {
  if (!dotaHud || !dotaHud.FindChildrenWithClassTraverse) return;

  if (dotaHud.BHasClass && dotaHud.BHasClass(className)) {
    hidePanel(dotaHud);
  }

  const panels = dotaHud.FindChildrenWithClassTraverse(className);
  if (!panels) return;

  panels.forEach((panel) => hidePanel(panel));
}

function hideDefaultAbilityExtras() {
  HIDE_IDS.forEach((id) => hidePanel(FindDotaHudElement(id)));
  HIDE_CLASSES.forEach((className) => hidePanelsByClass(className));
  cleanLevelStatsFrame();
}

// Hide ALL children of LevelStatsFrame except the "abilities" panel
// This removes any metal arcs, borders, backgrounds, innate/talent graphics
function cleanLevelStatsFrame() {
  const lsf = FindDotaHudElement("LevelStatsFrame") || FindDotaHudElement("level_stats_frame");
  if (!lsf) return;

  // Make sure LevelStatsFrame itself is visible
  lsf.visible = true;
  lsf.style.visibility = "visible";

  const children = lsf.Children();
  if (!children) return;

  for (let i = 0; i < children.length; i++) {
    const child = children[i];
    if (!child) continue;

    // Keep the abilities panel visible, hide everything else
    if (child.id === "abilities") {
      child.visible = true;
      child.style.visibility = "visible";
    } else {
      hidePanel(child);
    }
  }
}

// -----------------------------------------------------------------------
// Spread skill icons to fill space freed by hidden innate / talent panels
// -----------------------------------------------------------------------

function spreadAbilities() {
  const abilities = FindDotaHudElement("abilities");
  if (!abilities) return;

  // Keep enough room for large health/mana values below the ability slots.
  abilities.style.width = null;
  abilities.style.maxWidth = null;
  abilities.style.minWidth = MIN_ABILITIES_WIDTH + "px";

  // Clean up temporary debug label if it exists
  const debugLabel = FindDotaHudElement("TrinityDebugLabel");
  if (debugLabel) {
    debugLabel.DeleteAsync(0);
  }

  const children = abilities.Children();
  if (!children || children.length === 0) return;

  // Filter visible ability panels
  const visibleAbilities = [];
  children.forEach((child) => {
    if (child.visible) {
      visibleAbilities.push(child);
    } else {
      child.style.marginLeft = "0px";
      child.style.marginRight = "0px";
      const separator = child.FindChild("SeparatorLine");
      if (separator) {
        separator.DeleteAsync(0);
      }
    }
  });

  for (let i = 0; i < visibleAbilities.length; i++) {
    const child = visibleAbilities[i];

    child.style.marginTop = "0px";
    child.style.marginBottom = "0px";
    child.style.marginLeft = "0px";
    child.style.marginRight = "3px";
    child.style.overflow = "noclip";

    const separator = child.FindChild("SeparatorLine");
    if (separator) {
      separator.DeleteAsync(0);
    }
  }
}

function adjustAbilitiesAndStatBranch() {
  const panel = FindDotaHudElement("AbilitiesAndStatBranch");
  if (!panel) return;

  panel.style.minWidth = MIN_ABILITIES_WIDTH + "px";
}

const TOPBAR_VISIBLE_SLOTS = 3;
const TOPBAR_CONTAINER_IDS = [
  "TopBarRadiantPlayers",
  "TopBarDirePlayers",
  "TopBarRadiantPlayersContainer",
  "TopBarDirePlayersContainer",
  "RadiantTeamPlayers",
  "DireTeamPlayers",
  "TopBarRadiantTeam",
  "TopBarDireTeam",
  "RadiantPlayersContainer",
  "DirePlayersContainer",
];
const TOPBAR_PLAYER_ID_PREFIXES = [
  "RadiantPlayer",
  "DirePlayer",
  "TopBarRadiantPlayer",
  "TopBarDirePlayer",
  "RadiantTeamPlayer",
  "DireTeamPlayer",
];

function topBarSlotNumber(id) {
  if (!id) return -1;
  const match = id.match(/(?:Radiant|Dire).*Player(\d+)$/i);
  return match ? parseInt(match[1], 10) : -1;
}

function isTopBarHeroSlot(panel) {
  if (!panel) return false;

  if (topBarSlotNumber(panel.id) >= 0) return true;

  const type = panel.paneltype || "";
  if (/Team/i.test(type)) return false;
  if (/HUDTopBarPlayer$/i.test(type) || /TopBarPlayer$/i.test(type)) return true;

  if (panel.BHasClass) {
    if (panel.BHasClass("TopBarPlayerSlot")) return true;
    if (panel.BHasClass("HUDTopBarPlayer")) return true;
  }

  return false;
}

function isNestedTopBarHeroSlot(panel) {
  let parent = panel.GetParent ? panel.GetParent() : null;
  while (parent) {
    if (isTopBarHeroSlot(parent)) return true;
    parent = parent.GetParent ? parent.GetParent() : null;
  }
  return false;
}

function walkPanels(panel, visit) {
  if (!panel) return;
  visit(panel);
  if (!panel.Children) return;

  const children = panel.Children();
  if (!children) return;

  for (let i = 0; i < children.length; i++) {
    walkPanels(children[i], visit);
  }
}

function hideExtraSlotsInContainer(container) {
  if (!container || !container.Children) return;

  const children = container.Children();
  if (!children || children.length < 4) return;

  const slots = [];
  for (let i = 0; i < children.length; i++) {
    if (isTopBarHeroSlot(children[i])) {
      slots.push(children[i]);
    }
  }

  const toHide = slots.length >= 4 ? slots : children.length === 5 ? children : [];
  for (let i = 0; i < TOPBAR_VISIBLE_SLOTS && i < toHide.length; i++) {
    restorePanel(toHide[i]);
  }
  for (let i = TOPBAR_VISIBLE_SLOTS; i < toHide.length; i++) {
    hidePanel(toHide[i]);
  }
}

function hideExtraSlotsGrouped(panels) {
  const groups = [];

  for (let i = 0; i < panels.length; i++) {
    const panel = panels[i];
    const parent = panel.GetParent ? panel.GetParent() : null;
    let group = null;
    for (let g = 0; g < groups.length; g++) {
      if (groups[g].parent === parent) {
        group = groups[g];
        break;
      }
    }
    if (!group) {
      group = { parent: parent, slots: [] };
      groups.push(group);
    }
    group.slots.push(panel);
  }

  groups.forEach((group) => {
    if (group.slots.length < 4) return;
    for (let i = 0; i < TOPBAR_VISIBLE_SLOTS && i < group.slots.length; i++) {
      restorePanel(group.slots[i]);
    }
    for (let i = TOPBAR_VISIBLE_SLOTS; i < group.slots.length; i++) {
      hidePanel(group.slots[i]);
    }
  });
}

function hideNumberedTopBarSlots(prefix) {
  const zeroBased = !!FindDotaHudElement(prefix + "0");
  const first = zeroBased ? 0 : 1;
  const hideFrom = first + TOPBAR_VISIBLE_SLOTS;
  for (let slot = first; slot < hideFrom; slot++) {
    restorePanel(FindDotaHudElement(prefix + slot));
  }
  for (let slot = hideFrom; slot < 10; slot++) {
    hidePanel(FindDotaHudElement(prefix + slot));
  }
}

function hideExtraTopBarHeroSlots() {
  TOPBAR_PLAYER_ID_PREFIXES.forEach(hideNumberedTopBarSlots);
  TOPBAR_CONTAINER_IDS.forEach((id) => hideExtraSlotsInContainer(FindDotaHudElement(id)));

  const topBar =
    FindDotaHudElement("TopBar") ||
    FindDotaHudElement("topbar") ||
    FindDotaHudElement("HUDTopBar");
  if (!topBar) return;

  const found = [];
  walkPanels(topBar, (panel) => {
    if (!isTopBarHeroSlot(panel) || isNestedTopBarHeroSlot(panel)) return;
    found.push(panel);
  });
  hideExtraSlotsGrouped(found);
}

function tickHudCleanup() {
  hideDefaultAbilityExtras();
  hideExtraTopBarHeroSlots();
  adjustAbilitiesAndStatBranch();
  spreadAbilities();
  $.Schedule(0.25, tickHudCleanup);
}

tickHudCleanup();
