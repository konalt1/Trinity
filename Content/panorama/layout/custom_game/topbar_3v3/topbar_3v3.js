"use strict";

const TEAM_RADIANT = 2;
const TEAM_DIRE = 3;
const TOPBAR_SLOTS = 3;
const DEFAULT_HERO_IMAGE = "s2r://panorama/images/heroes/icons/npc_dota_hero_wisp_png.vtex";
const DEFAULT_TEAM_COLORS = {
  [TEAM_RADIANT]: "#5dba40",
  [TEAM_DIRE]: "#d96f37",
};
const DEFAULT_TOPBAR_IDS = [
  "topbar",
  "TopBar",
  "DotaTopBar",
  "HUDElementsTopBar",
  "TopBarContainer",
  "TopBarRadiantPlayers",
  "TopBarDirePlayers",
  "RadiantTeamPlayers",
  "DireTeamPlayers",
];

class TrinityTopBar {
  constructor() {
    this.context = $.GetContextPanel();
    this.radiantContainer = this.context.FindChildTraverse("RadiantSlots");
    this.direContainer = this.context.FindChildTraverse("DireSlots");
    this.timer = this.context.FindChildTraverse("GameTimer");
    this.radiantScore = this.context.FindChildTraverse("RadiantScore");
    this.direScore = this.context.FindChildTraverse("DireScore");
    this.slots = {
      [TEAM_RADIANT]: this.createTeamSlots(this.radiantContainer, TEAM_RADIANT),
      [TEAM_DIRE]: this.createTeamSlots(this.direContainer, TEAM_DIRE),
    };

    this.tick();
  }

  createTeamSlots(container, team) {
    const slots = [];
    for (let index = 0; index < TOPBAR_SLOTS; index++) {
      const slot = $.CreatePanel("Panel", container, `TrinityTopBar_${team}_${index}`, {
        class: "PlayerSlot EmptySlot",
      });

      slot.hero = $.CreatePanel("Image", slot, "HeroImage", { class: "HeroImage" });
      slot.respawn = $.CreatePanel("Label", slot, "RespawnLabel", {
        class: "RespawnLabel MonoNumbersFont",
        text: "",
      });
      slot.color = $.CreatePanel("Panel", slot, "PlayerColor", { class: "PlayerColor" });

      slots.push(slot);
    }

    return slots;
  }

  tick() {
    this.hideDefaultTopBar();
    this.updateTeam(TEAM_RADIANT);
    this.updateTeam(TEAM_DIRE);
    this.updateTimer();
    this.updateScores();

    $.Schedule(0.2, () => this.tick());
  }

  hideDefaultTopBar() {
    DEFAULT_TOPBAR_IDS.forEach((id) => {
      const panel = FindDotaHudElement(id);
      if (!panel) return;

      panel.visible = false;
      panel.style.visibility = "collapse";
      panel.style.opacity = "0";
      panel.enabled = false;
    });
  }

  updateTeam(team) {
    const playerIds = this.getPlayersForTeam(team).slice(0, TOPBAR_SLOTS);

    this.slots[team].forEach((slot, index) => {
      this.updateSlot(slot, playerIds[index], team);
    });
  }

  getPlayersForTeam(team) {
    const result = [];

    for (let playerId = 0; playerId < 24; playerId++) {
      if (!Players.IsValidPlayerID(playerId)) continue;

      const info = Game.GetPlayerInfo(playerId);
      if (!info || info.player_team_id !== team) continue;

      result.push(playerId);
    }

    result.sort((a, b) => {
      const aInfo = Game.GetPlayerInfo(a);
      const bInfo = Game.GetPlayerInfo(b);
      return (aInfo.player_team_slot || 0) - (bInfo.player_team_slot || 0);
    });

    return result;
  }

  updateSlot(slot, playerId, team) {
    const hasPlayer = playerId !== undefined && Players.IsValidPlayerID(playerId);
    slot.SetHasClass("EmptySlot", !hasPlayer);

    if (!hasPlayer) {
      slot.SetHasClass("Dead", false);
      slot.hero.SetImage(DEFAULT_HERO_IMAGE);
      slot.respawn.text = "";
      slot.color.style.backgroundColor = DEFAULT_TEAM_COLORS[team];
      return;
    }

    const info = Game.GetPlayerInfo(playerId);
    const heroName = info && info.player_selected_hero ? info.player_selected_hero : "";
    const heroEntity = info ? info.player_selected_hero_entity_index : -1;

    if (heroName) {
      slot.hero.SetImage(`file://{images}/heroes/${heroName}.png`);
    } else {
      slot.hero.SetImage(DEFAULT_HERO_IMAGE);
    }

    const isDead = heroEntity && heroEntity !== -1 && !Entities.IsAlive(heroEntity);
    slot.SetHasClass("Dead", isDead);
    slot.respawn.text = isDead ? String(Math.ceil(Entities.GetRespawnTime(heroEntity))) : "";
    slot.color.style.backgroundColor = GetPlayerColorHex(playerId);
  }

  updateTimer() {
    const dotaTime = Math.floor(Game.GetDOTATime(false, false));
    const sign = dotaTime < 0 ? "-" : "";
    const absTime = Math.abs(dotaTime);
    const minutes = Math.floor(absTime / 60);
    const seconds = absTime % 60;
    this.timer.text = `${sign}${minutes}:${seconds < 10 ? "0" : ""}${seconds}`;
  }

  updateScores() {
    this.radiantScore.text = String(this.getTeamScore(TEAM_RADIANT));
    this.direScore.text = String(this.getTeamScore(TEAM_DIRE));
  }

  getTeamScore(team) {
    const details = Game.GetTeamDetails ? Game.GetTeamDetails(team) : null;
    return details && details.team_score !== undefined ? details.team_score : 0;
  }
}

new TrinityTopBar();
