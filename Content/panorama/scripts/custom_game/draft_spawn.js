"use strict";

(function () {
  const CONTEXT = $.GetContextPanel();
  const config = GameUI.CustomUIConfig();
  const tickKey = "_trinityDraftSpawn_" + ((CONTEXT && CONTEXT.id) || "unknown");
  if (config[tickKey]) {
    return;
  }
  config[tickKey] = true;

  const HERO_SELECTION = DOTA_GameState.DOTA_GAMERULES_STATE_HERO_SELECTION;
  const STRATEGY_TIME = DOTA_GameState.DOTA_GAMERULES_STATE_STRATEGY_TIME;

  function FindHudRoot() {
    let panel = $.GetContextPanel();
    while (panel) {
      if (panel.id === "DotaHud") {
        return panel;
      }
      panel = panel.GetParent();
    }
    return panel;
  }

  function FindHudElement(id) {
    const hud = FindHudRoot();
    return hud ? hud.FindChildTraverse(id) : null;
  }

  function LocalPlayerHasHero() {
    const playerID = Players.GetLocalPlayer();
    if (playerID < 0) {
      return false;
    }
    if (Players.GetSelectedHeroID(playerID) < 1) {
      return false;
    }
    return Players.GetPlayerHeroEntityIndex(playerID) !== -1;
  }

  function IsPickPhase(state) {
    return state === HERO_SELECTION || state === STRATEGY_TIME;
  }

  function HidePickOverlay(preGame) {
    if (!preGame || preGame._trinityHidden) {
      return;
    }
    preGame._trinityHidden = true;
    preGame._trinityPrevOpacity = preGame.style.opacity;
    preGame._trinityPrevVisibility = preGame.style.visibility;
    preGame.style.opacity = "0";
    preGame.style.visibility = "collapse";
    preGame.hittest = false;
    preGame.hittestchildren = false;
  }

  function RestorePickOverlay(preGame) {
    if (!preGame || !preGame._trinityHidden) {
      return;
    }
    preGame._trinityHidden = false;
    preGame.style.opacity = preGame._trinityPrevOpacity || "1";
    preGame.style.visibility = preGame._trinityPrevVisibility || "visible";
    preGame.hittest = true;
    preGame.hittestchildren = true;
  }

  function FocusHeroCamera(event) {
    const playerID = Players.GetLocalPlayer();
    if (event && event.player_id != null && Number(event.player_id) !== playerID) {
      return;
    }

    let origin = null;
    if (event && event.x != null && event.y != null) {
      origin = [Number(event.x), Number(event.y), Number(event.z) || 0];
    } else {
      const hero = Players.GetPlayerHeroEntityIndex(playerID);
      if (hero === -1) {
        return;
      }
      origin = Entities.GetAbsOrigin(hero);
    }

    if (origin) {
      GameUI.SetCameraTarget(-1);
      GameUI.SetCameraTargetPosition(origin, 0);
    }
  }

  function TickDraftSpawn() {
    if (!CONTEXT || !CONTEXT.IsValid()) {
      return;
    }

    const preGame = FindHudElement("PreGame");
    const state = Game.GetState();

    if (preGame) {
      if (config.trinityPickClosed || config.trinityCameraReady) {
        HidePickOverlay(preGame);
        const hudElements = FindHudElement("HUDElements");
        if (hudElements) {
          hudElements.style.opacity = "1";
          hudElements.style.visibility = "visible";
        }
      } else {
        RestorePickOverlay(preGame);
      }
    }

    if (config.trinityPickClosed && state < DOTA_GameState.DOTA_GAMERULES_STATE_GAME_IN_PROGRESS) {
      $.Schedule(0.1, TickDraftSpawn);
      return;
    }

    if (state >= DOTA_GameState.DOTA_GAMERULES_STATE_PRE_GAME) {
      return;
    }

    $.Schedule(0.1, TickDraftSpawn);
  }

  GameEvents.Subscribe("trinity_player_entered_map", function (event) {
    const playerID = Players.GetLocalPlayer();
    if (event && event.player_id != null && Number(event.player_id) !== playerID) {
      return;
    }
    FocusHeroCamera(event);
    config.trinityCameraReady = true;
    const preGame = FindHudElement("PreGame");
    if (preGame) {
      HidePickOverlay(preGame);
    }
  });

	GameEvents.Subscribe("trinity_warmup_started", function (event) {
    config.trinityWarmupActive = true;
    config.trinityWarmupGold = event && event.gold;
    const remaining = Number(event && event.remaining);
    config.trinityWarmupRemaining = isNaN(remaining) ? 0 : Math.max(0, remaining);
    config.trinityWarmupEndTime = Game.Time() + config.trinityWarmupRemaining;
    FocusHeroCamera(event);
    if (event && event.x != null) {
      config.trinityCameraReady = true;
    }
  });

  GameEvents.Subscribe("trinity_warmup_ended", function () {
    config.trinityWarmupActive = false;
    config.trinityWarmupGold = 0;
    config.trinityWarmupRemaining = 0;
    config.trinityWarmupEndTime = 0;
    config.trinityPickClosed = true;
    const preGame = FindHudElement("PreGame");
    if (preGame) {
      HidePickOverlay(preGame);
    }
    FocusHeroCamera();
  });

  TickDraftSpawn();
})();
