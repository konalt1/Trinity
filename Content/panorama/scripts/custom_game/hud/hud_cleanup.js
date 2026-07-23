"use strict";

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

  panel.style.minWidth = "0px";
}

function tickHudCleanup() {
  hideDefaultAbilityExtras();
  adjustAbilitiesAndStatBranch();
  spreadAbilities();
  $.Schedule(0.25, tickHudCleanup);
}

tickHudCleanup();
