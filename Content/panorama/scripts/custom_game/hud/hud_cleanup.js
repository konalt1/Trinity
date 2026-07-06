"use strict";

const MAX_PLAYERS_PER_TEAM = 3;
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

  container.style.width = "183px";
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

  // Apply a fixed, clean spacing (16px on each side of every skill slot)
  const marginPerSide = 16;

  for (let i = 0; i < visibleAbilities.length; i++) {
    const child = visibleAbilities[i];
    child.style.marginLeft = marginPerSide + "px";
    child.style.marginRight = marginPerSide + "px";
    child.style.overflow = "noclip";

    // Manage separator line
    let separator = child.FindChild("SeparatorLine");
    if (i < visibleAbilities.length - 1) {
      if (!separator) {
        separator = $.CreatePanel("Panel", child, "SeparatorLine");
        separator.style.width = "2px";
        separator.style.height = "42px";
        separator.style.verticalAlign = "center";
        separator.style.horizontalAlign = "right";
        separator.style.marginRight = "-17px";
        separator.style.background = "gradient( linear, 0% 0%, 0% 100%, from( rgba(255,255,255,0) ), color-stop( 0.2, rgba(255,255,255,0.7) ), color-stop( 0.8, rgba(255,255,255,0.7) ), to( rgba(255,255,255,0) ) )";
        separator.style.zIndex = "10";
      }
    } else {
      if (separator) {
        separator.DeleteAsync(0);
      }
    }
  }
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
