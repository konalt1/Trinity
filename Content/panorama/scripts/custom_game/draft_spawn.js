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

  function ReadNumber(value) {
    const number = Number(value);
    return isNaN(number) ? null : number;
  }

  function ReadEventOrigin(event, prefix) {
    prefix = prefix || "";
    const x = ReadNumber(event && event[prefix + "x"]);
    const y = ReadNumber(event && event[prefix + "y"]);
    if (x == null || y == null) {
      return null;
    }
    return [x, y, ReadNumber(event && event[prefix + "z"]) || 0];
  }

  function GetCameraDestination(event) {
    const origin = ReadEventOrigin(event, "");
    if (origin) {
      return origin;
    }

    const playerID = Players.GetLocalPlayer();
    const hero = Players.GetPlayerHeroEntityIndex(playerID);
    if (hero === -1) {
      return null;
    }
    return Entities.GetAbsOrigin(hero);
  }

  function ReadCameraLerp(event) {
    const lerp = ReadNumber(event && event.lerp);
    if (lerp == null || lerp < 0) {
      return 0;
    }
    return lerp;
  }

  function StopWarmupCameraFly() {
    config._trinityWarmupCameraGen = (Number(config._trinityWarmupCameraGen) || 0) + 1;
  }

  function SetCameraOrigin(origin, lerp) {
    if (!origin) {
      return;
    }
    GameUI.SetCameraTarget(-1);
    GameUI.SetCameraTargetPosition(origin, lerp || 0);
  }

  function FlyCamera(from, to, duration) {
    StopWarmupCameraFly();
    const gen = config._trinityWarmupCameraGen;
    if (!from || duration <= 0) {
      SetCameraOrigin(to, 0);
      return;
    }

    const start = Game.Time();
    const tick = function () {
      if (config._trinityWarmupCameraGen !== gen) {
        return;
      }
      const elapsed = Game.Time() - start;
      const t = Math.min(1, elapsed / duration);
      const s = t * t * (3 - 2 * t);
      SetCameraOrigin(
        [
          from[0] + (to[0] - from[0]) * s,
          from[1] + (to[1] - from[1]) * s,
          from[2] + (to[2] - from[2]) * s,
        ],
        0
      );
      if (t < 1) {
        $.Schedule(0.03, tick);
      }
    };
    tick();
  }

  function FocusHeroCamera(event) {
    const playerID = Players.GetLocalPlayer();
    if (event && event.player_id != null && Number(event.player_id) !== playerID) {
      return;
    }

    const origin = GetCameraDestination(event);
    if (!origin) {
      return;
    }

    const lerp = ReadCameraLerp(event);
    if (lerp <= 0) {
      StopWarmupCameraFly();
      SetCameraOrigin(origin, 0);
      return;
    }

    FlyCamera(ReadEventOrigin(event, "from_") || origin, origin, lerp);
  }

  function QueueFocusHeroCamera(event) {
    const playerID = Players.GetLocalPlayer();
    if (event && event.player_id != null && Number(event.player_id) !== playerID) {
      return;
    }

    const lerp = ReadCameraLerp(event);
    if (lerp <= 0) {
      FocusHeroCamera(event);
      return;
    }

    const now = Game.Time();
    const last = Number(config._trinityWarmupCameraAt);
    if (!isNaN(last) && now - last < 0.25) {
      return;
    }
    config._trinityWarmupCameraAt = now;

    const payload = {
      player_id: event && event.player_id,
      x: event && event.x,
      y: event && event.y,
      z: event && event.z,
      from_x: event && event.from_x,
      from_y: event && event.from_y,
      from_z: event && event.from_z,
      lerp: lerp,
    };
    $.Schedule(0.05, function () {
      FocusHeroCamera(payload);
    });
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
    config.trinityCameraReady = true;
    const preGame = FindHudElement("PreGame");
    if (preGame) {
      HidePickOverlay(preGame);
    }
    QueueFocusHeroCamera(event);
  });

	GameEvents.Subscribe("trinity_warmup_started", function (event) {
    config.trinityWarmupActive = true;
    config.trinityWarmupGold = event && event.gold;
    const remaining = Number(event && event.remaining);
    config.trinityWarmupRemaining = isNaN(remaining) ? 0 : Math.max(0, remaining);
    config.trinityWarmupEndTime = Game.Time() + config.trinityWarmupRemaining;
    if (event && (event.x != null || ReadCameraLerp(event) > 0)) {
      config.trinityCameraReady = true;
      const preGame = FindHudElement("PreGame");
      if (preGame) {
        HidePickOverlay(preGame);
      }
    }
    QueueFocusHeroCamera(event);
  });

  function SelectLocalHero() {
    const playerID = Players.GetLocalPlayer();
    if (playerID < 0) {
      return -1;
    }
    const hero = Players.GetPlayerHeroEntityIndex(playerID);
    if (hero === -1) {
      return -1;
    }
    if (GameUI.SelectUnit) {
      GameUI.SelectUnit(hero, false);
    }
    return hero;
  }

  function RefreshAbilityHud() {
    return SelectLocalHero() !== -1;
  }

  function CountVisibleAbilityHudSlots() {
    const abilities = FindHudElement("abilities");
    if (!abilities || !abilities.Children) {
      return { visible: 0, total: 0 };
    }

    const children = abilities.Children() || [];
    let visible = 0;
    for (let i = 0; i < children.length; i++) {
      const child = children[i];
      if (child && child.visible) {
        visible++;
      }
    }
    return { visible: visible, total: children.length };
  }

  GameEvents.Subscribe("trinity_hud_test_request", function (event) {
    const hudRefreshDelays = [0, 0.05, 0.15, 0.35, 0.75];
    for (let i = 0; i < hudRefreshDelays.length; i++) {
      $.Schedule(hudRefreshDelays[i], RefreshAbilityHud);
    }

    $.Schedule(0.85, function () {
      const counts = CountVisibleAbilityHudSlots();
      GameEvents.SendCustomGameEventToServer("trinity_hud_test_report", {
        cycle: event && event.cycle,
        visible_slots: counts.visible,
        total_slots: counts.total,
      });
    });
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
    StopWarmupCameraFly();
    FocusHeroCamera();
    const hudRefreshDelays = [0, 0.05, 0.15, 0.35, 0.75];
    for (let i = 0; i < hudRefreshDelays.length; i++) {
      $.Schedule(hudRefreshDelays[i], RefreshAbilityHud);
    }
  });

  TickDraftSpawn();
})();
