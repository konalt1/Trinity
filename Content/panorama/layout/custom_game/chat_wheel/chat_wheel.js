"use strict";
var favourites = new Array();
var nowrings = 9;
var selected_sound_current = undefined;
var nowselect = 0;
var current_button;
let tableHero;
let isWorkWheel = false;
const CHAT_WHEEL_BIND_COMMAND = DOTAKeybindCommand_t.DOTA_KEYBIND_CHAT_WHEEL;
const CHAT_STICKER_VIDEO_ROOT = "file://{resources}/videos/custom_game";
const CHAT_STICKER_SIZE = 120;
const CHAT_STICKER_MESSAGE_OFFSET_X = 205;
const CHAT_STICKER_SOUNDS = {
  Gura: "high_five.impact",
  NeuroHug: "Hero_Chen.HolyPersuasion",
  Watson: "General.Buy",
  Anime: "Hero_Juggernaut.OmniSlash",
  Neurodance: "Hero_Weaver.Shukuchi",
  Choso: "Wheel.Choso",
  StickerOne: "high_five.impact",
  StickerTwo: "General.Buy",
};
const STICKER_MAX_TIME = {
  Gura: 1,
  NeuroHug: 1.5,
  Watson: 1.5,
  Anime: 1.5,
  Neurodance: 1.5,
  Choso: 0.7,
  StickerOne: 1.5,
  StickerTwo: 1,
};
var rings = [[Array(8).fill(""), Array(8).fill(true)]];
const loadTableHeroFromNet = () => {
  const playerID = Players.GetLocalPlayer();
  const data = CustomNetTables.GetTableValue("trinity_stickers", String(playerID)) || {};
  tableHero = {};
  for (let i = 0; i < 8; i++) {
    const sound = data["slot" + i] || "";
    tableHero[String(i)] = {
      sound: sound,
      maxTime: sound ? STICKER_MAX_TIME[sound] || 1.5 : 0,
    };
  }
};
const initTableHero = () => {
  loadTableHeroFromNet();
};
const initChatWheel = () => {
  var _a;
  for (var i = 0; i < 8; i++) {
    $.CreatePanel(`Button`, $("#PhrasesContainer"), `Phrase${i}`, {
      class: `MyPhrases`,
    });
    $("#Phrase" + i).BLoadLayoutSnippet("Phrase");
    $("#Phrase" + i)
      .GetChild(0)
      .GetChild(0).visible = Boolean(rings[0][1][i]);
    let name = "";

    if (!tableHero) {
      initTableHero();
    }
    if (tableHero) {
      name = tableHero[i]?.sound || "";
    }
    const hasSound = name !== "";
    const PhraseLabel = $("#Phrase" + i)
      .GetChild(0)
      .GetChild(0)
      .GetChild(0);
    PhraseLabel.text = $.Localize(hasSound ? "#chat_wheel_donate_sound_" + name : "#chat_wheel_donate_sound_empty");
    const phrase = $("#Phrase" + i)
      .GetChild(0)
      .GetChild(0)
      .GetChild(0);
    phrase.style.opacity = hasSound ? "1" : "0.3";
    $("#Phrase" + i)
      .GetChild(0)
      .GetChild(0)
      .GetChild(1).style.backgroundSize = "100%";
    $("#Bubble").style.backgroundImage = `url('s2r://panorama/images/chat_wheel/center_cursor_png.vtex')`;
  }
};
function StartWheel() {
  selected_sound_current = undefined;
  isWorkWheel = true;
  $("#Wheel").visible = true;
  $("#Bubble").visible = true;
  $("#PhrasesContainer").visible = true;
  $("#PhrasesContainer").RemoveAndDeleteChildren();
  initTableHero();
  initChatWheel();
  checkMousePosition();
}
function StopWheel() {
  $("#Wheel").visible = false;
  $("#Bubble").visible = false;
  $("#PhrasesContainer").visible = false;
  const cooldown = CustomNetTables.GetTableValue("cooldown_info", `${Players.GetLocalPlayer()}`)?.cooldown_chat || 0;

  if (cooldown == 0) {
    if (selected_sound_current || selected_sound_current === 0) {
      const soundName = tableHero[selected_sound_current.toString()] ? tableHero[selected_sound_current.toString()].sound : undefined;
      const maxTime = tableHero[selected_sound_current.toString()] ? tableHero[selected_sound_current.toString()].maxTime : undefined;

      if (soundName) {
        GameEvents.SendCustomGameEventToServer("chat_wheel_select", {
          select: soundName,
          maxTime: maxTime || STICKER_MAX_TIME[soundName] || 1.5,
        });
      }
    }
  } else {
    GameEvents.SendEventClientSide("dota_hud_error_message", {
      message: $.Localize("#dota_error_cooldown_chat_wheel"),
      reason: 80,
      sequenceNumber: 0,
    });
  }
  if (nowselect != 0) {
    $("#PhrasesContainer").RemoveAndDeleteChildren();
    initChatWheel();
  }
  isWorkWheel = false;
  selected_sound_current = undefined;
}
function OnMouseOver(num) {
  $("#WheelPointer").RemoveClass("Hidden");
  $("#Arrow").RemoveClass("Hidden");
  for (var i = 0; i < 8; i++) {
    if ($("#Wheel").BHasClass("ForWheel" + i)) $("#Wheel").RemoveClass("ForWheel" + i);
  }
  $("#Wheel").AddClass("ForWheel" + num);
}
(function () {
  GameUI.CustomUIConfig().chatWheelLoaded = true;
  const name_bind = "WheelHeroButton" + Math.floor(Math.random() * 99999999);
  Game.AddCommand("+" + name_bind, StartWheel, "", 0);
  Game.AddCommand("-" + name_bind, StopWheel, "", 0);
  Game.CreateCustomKeyBind(GetGameKeybind(CHAT_WHEEL_BIND_COMMAND), "+" + name_bind);
  current_button = GetGameKeybind(CHAT_WHEEL_BIND_COMMAND);
  SetBindInterval();
  $("#Wheel").visible = false;
  $("#Bubble").visible = false;
  $("#PhrasesContainer").visible = false;
  CustomNetTables.SubscribeNetTableListener("trinity_stickers", () => {
    loadTableHeroFromNet();
  });
})();
function GetGameKeybind(command) {
  return Game.GetKeybindForCommand(command);
}
function SetBindInterval() {
  if (GetGameKeybind(CHAT_WHEEL_BIND_COMMAND) != current_button) {
    const name_bind = "WheelHeroButton" + Math.floor(Math.random() * 99999999);
    Game.AddCommand("+" + name_bind, StartWheel, "", 0);
    Game.AddCommand("-" + name_bind, StopWheel, "", 0);
    Game.CreateCustomKeyBind(GetGameKeybind(CHAT_WHEEL_BIND_COMMAND), "+" + name_bind);
    current_button = GetGameKeybind(CHAT_WHEEL_BIND_COMMAND);
  }
  $.Schedule(0.2, SetBindInterval);
}
const windowWidth = Game.GetScreenWidth();
const heightWidth = Game.GetScreenHeight();
const center = [windowWidth / 2, heightWidth / 2];
const checkMousePosition = () => {
  if (!$("#Bubble") || !isWorkWheel) return null;
  const bubble = $("#Bubble");
  const cursorPosition = GameUI.GetCursorPosition();
  const maxDistanceBuble = 20;
  let dx = cursorPosition[0] - center[0];
  let dy = cursorPosition[1] - center[1];
  const distance = Math.sqrt(dx * dx + dy * dy);
  if (distance > maxDistanceBuble) {
    const scale = maxDistanceBuble / distance;
    dx *= scale;
    dy *= scale;
  }
  bubble.style.transform = `translatex(${dx}px) translatey(${dy}px)`;
  const numBlocks = 8;
  const mouseX = cursorPosition[0];
  const mouseY = cursorPosition[1];
  let angle = Math.atan2(mouseY - center[1], mouseX - center[0]);
  if (angle < 0) angle += 2 * Math.PI;
  angle += Math.PI / 2;
  if (angle < 0) angle += 2 * Math.PI;
  const sectorSize = (2 * Math.PI) / numBlocks;
  const halfZone = sectorSize / 2;
  let phraseNumber = undefined;
  for (let i = 0; i < numBlocks; i++) {
    const sectorCenter = i * sectorSize;
    let diff = angle - sectorCenter;
    if (diff > Math.PI) diff -= 2 * Math.PI;
    if (diff < -Math.PI) diff += 2 * Math.PI;
    if (Math.abs(diff) <= halfZone) {
      phraseNumber = i;
      break;
    }
  }
  const phraseNumbers = [0, 1, 2, 3, 4, 5, 6, 7];
  if (phraseNumber !== undefined) {
    phraseNumber = phraseNumbers[phraseNumber];
  }
  if (Math.abs(dx) < 10 && Math.abs(dy) < 10) {
    phraseNumber = undefined;
    $("#WheelPointer").AddClass("Hidden");
    $("#Arrow").AddClass("Hidden");
    if (selected_sound_current !== undefined) {
      $("#Wheel").RemoveClass("ForWheel" + selected_sound_current);
    }
  }
  const lines = [$("#Phrase0"), $("#Phrase1"), $("#Phrase2"), $("#Phrase3"), $("#Phrase4"), $("#Phrase5"), $("#Phrase6"), $("#Phrase7")];
  lines.forEach((element) => {
    if (!element) return;
    if (element.id === `Phrase${phraseNumber}`) {
      let phrase = element.FindChildrenWithClassTraverse("Phrase")[0];
      OnMouseOver(phraseNumber);
      phrase.style.preTransformScale2d = "1.15";
    } else {
      let phrase = element.FindChildrenWithClassTraverse("Phrase")[0];
      phrase.style.preTransformScale2d = "1";
    }
  });
  selected_sound_current = phraseNumber;
  $.Schedule(0.03, checkMousePosition);
};

function isHealthBarVisible(posX, posY, originZ) {
  return !(posX < 0 || posX > Game.GetScreenWidth() || posY < 0 || posY > Game.GetScreenHeight() || originZ < -500);
}

const isFiniteCoordinate = (value) => typeof value === "number" && isFinite(value);

const CreateVideoHeadMessage = (data) => {
  const hudRoot = dotaHud.FindChildTraverse("HeroRelicProgress");
  const hero = Number(data.hero);

  if (!hudRoot || !hero || !Entities.IsValidEntity(hero)) return false;

  const initialOrigin = Entities.GetAbsOrigin(hero);
  if (!initialOrigin || initialOrigin.length < 3) return false;

  const initialX = Game.WorldToScreenX(initialOrigin[0], initialOrigin[1], initialOrigin[2]);
  const initialY = Game.WorldToScreenY(initialOrigin[0], initialOrigin[1], initialOrigin[2]);
  if (!isFiniteCoordinate(initialX) || !isFiniteCoordinate(initialY)) return false;
  if (!isHealthBarVisible(initialX, initialY, initialOrigin[2])) return false;

  hudRoot.hittestchildren = true;

  //  hudRoot.GetChild(0)?.DeleteAsync(0);

  const newPanel = $.CreatePanel("Movie", hudRoot, "", {
    selectionpos: "auto",
    style: `width: ${CHAT_STICKER_SIZE}px; height: ${CHAT_STICKER_SIZE}px; border-radius: 50%; visibility: collapse;`,
    controls: "none",
    repeat: "true",
    disableaudio: "false",
    autoplay: "onload",
    src: `${CHAT_STICKER_VIDEO_ROOT}/${data.sound}.webm`,
  });

  const maxTime = data.maxTime;
  let time = 0;
  const UpdateVideoPanels = () => {
    if (time >= maxTime) {
      newPanel.DeleteAsync(0);
      return;
    }

   const next = () => {
      const frameTime = Game.GetGameFrameTime();
      time += frameTime;

      // В игре обновляем позицию каждый кадр. Во время паузы frameTime равен
      // нулю, поэтому оставляем небольшую задержку, чтобы не перегружать Panorama.
      const updateDelay = frameTime > 0 ? frameTime : 0.03;
      $.Schedule(updateDelay, UpdateVideoPanels);
    };

    const hideAndRetry = () => {
      newPanel.style.visibility = "collapse";
      next();
    };

    if (!Entities.IsValidEntity(hero)) {
      newPanel.DeleteAsync(0);
      return;
    }

    const origin = Entities.GetAbsOrigin(hero);

    // Быстрая проверка валидности origin
    if (!origin || origin.length < 3) {
      hideAndRetry();
      return;
    }

    // Кэшируем вычисления координат
    const posX = Game.WorldToScreenX(origin[0], origin[1], origin[2]);
    const posY = Game.WorldToScreenY(origin[0], origin[1], origin[2]);

    // Быстрая проверка валидности координат
    if (!isFiniteCoordinate(posX) || !isFiniteCoordinate(posY)) {
      hideAndRetry();
      return;
    }

    if (!isHealthBarVisible(posX, posY, origin[2])) {
      // Полностью скрываем панель если она за краем экрана
      if (newPanel.style.visibility !== "collapse") {
        newPanel.style.visibility = "collapse";
      }
      next();
      return;
    } else {
      // Показываем панель если она в видимой области
      if (newPanel.style.visibility !== "visible") {
        newPanel.style.visibility = "visible";
      }
    }

    // Вычисляем offset для позиционирования над юнитом
    let offSet = Entities.GetHealthBarOffset(hero) + 100;
    if (offSet < 200) {
      offSet = 200;
    }

    // Вычисляем координаты панели
    const panelX = Game.WorldToScreenX(origin[0], origin[1], origin[2] + offSet);
    const panelY = Game.WorldToScreenY(origin[0], origin[1], origin[2] + offSet);

    // Проверяем валидность координат
    if (!isFiniteCoordinate(panelX) || !isFiniteCoordinate(panelY)) {
      hideAndRetry();
      return;
    }

    const uiScaleX = newPanel.actualuiscale_x;
    const uiScaleY = newPanel.actualuiscale_y;
    if (!isFiniteCoordinate(uiScaleX) || !isFiniteCoordinate(uiScaleY) || uiScaleX <= 0 || uiScaleY <= 0) {
      hideAndRetry();
      return;
    }

    // Позиционируем панель
    const panelTransform = `translate3d(${(panelX - newPanel.actuallayoutwidth / 2) / uiScaleX}px,${
      (panelY - newPanel.actuallayoutheight) / uiScaleY
    }px,0)`;

    // Обновляем transform только если он изменился
    if (newPanel.style.transform !== panelTransform) {
      newPanel.style.transform = panelTransform;
    }

    next();
  };

  UpdateVideoPanels();
  return true;
};

const chatStickerMovies = [];
let chatStickerGuardStarted = false;
const CHAT_STICKER_MESSAGE_INDENT = "\u00A0&#160;&#160;\t&#160;\t&#160;&#160;\t&#160;\t&#160;\t&#160;\t&#160;&#160;\t\t\t";

const EscapeChatHtml = (text) => {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/'/g, "&apos;")
    .replace(/"/g, "&quot;");
};

const StartChatStickerGuard = () => {
  if (chatStickerGuardStarted) return;
  chatStickerGuardStarted = true;

  const UpdateChatStickerMovies = () => {
    const chatLinesContainer = FindDotaHudElement("ChatLinesContainer");
    const chatLinesPanel = FindDotaHudElement("ChatLinesPanel");
    const hudChat = FindDotaHudElement("HudChat");

    if (!chatLinesContainer || !chatLinesPanel || !hudChat) {
      $.Schedule(0.5, UpdateChatStickerMovies);
      return;
    }

    const viewHeight = 162;
    const messageHeight = CHAT_STICKER_SIZE + 28;
    const scrollY = chatLinesPanel.actuallayoutheight - viewHeight - chatLinesContainer.scrolloffset_y * -1;
    const chatActive = hudChat.BHasClass("Active");

    for (let i = chatStickerMovies.length - 1; i >= 0; i--) {
      const entry = chatStickerMovies[i];
      const message = entry.message;
      const movie = entry.movie;

      if (!message.IsValid() || !movie.IsValid()) {
        chatStickerMovies.splice(i, 1);
        continue;
      }

      const messageTop = message.actualyoffset - scrollY;
      const messageBottom = messageTop + messageHeight;
      const isVisible = messageBottom > 0 && messageTop < viewHeight;
      const isExpired = message.GetParent()?.BHasClass("Expired");

      if (!isExpired && isVisible) {
        movie.Play();
        continue;
      }

      if (!chatActive) {
        movie.Stop();
        continue;
      }

      if (isVisible) {
        movie.Play();
      } else {
        movie.Stop();
      }
    }

    $.Schedule(0.5, UpdateChatStickerMovies);
  };

  UpdateChatStickerMovies();
};

const CreateVideoChatMessage = (data) => {
  const chatLinesPanel = FindDotaHudElement("ChatLinesPanel");
  if (!chatLinesPanel || !data.sound) return;

  const playerID = Number(data.playerID);
  const hasValidPlayer = Players.IsValidPlayerID(playerID);
  const playerInfo = hasValidPlayer ? Game.GetPlayerInfo(playerID) : null;
  if (!playerInfo) return;

  const playerName = EscapeChatHtml(playerInfo.player_name);
  const playerColor = Players.GetPlayerColorHex(playerID);

  const message = $.CreatePanel("Panel", chatLinesPanel, "", {
    class: "ChatLine StickerChatMessage",
    selectionpos: "auto",
    hittest: "false",
    hittestchildren: "false",
  });
  message.style.flowChildren = "down";
  message.style.width = `${CHAT_STICKER_MESSAGE_OFFSET_X + CHAT_STICKER_SIZE}px`;
  message.style.height = `${CHAT_STICKER_SIZE + 28}px`;
  message.style.opacity = "1";

  const movie = $.CreatePanel("Movie", message, "", {
    selectionpos: "auto",
    style: `width: ${CHAT_STICKER_SIZE}px; height: ${CHAT_STICKER_SIZE}px; border-radius: 50%; horizontal-align: left; margin-left: ${CHAT_STICKER_MESSAGE_OFFSET_X}px;`,
    controls: "none",
    repeat: "true",
    disableaudio: "false",
    autoplay: "onload",
    src: `${CHAT_STICKER_VIDEO_ROOT}/${data.sound}.webm`,
  });

  const playerLine = $.CreatePanel("Label", message, "", {
    class: "ChatLine",
    html: "true",
    text: "undefined",
    selectionpos: "auto",
    hittest: "false",
    hittestchildren: "false",
  });
  playerLine.style.flowChildren = "right";
  playerLine.style.width = `${CHAT_STICKER_MESSAGE_OFFSET_X + CHAT_STICKER_SIZE}px`;
  playerLine.style.height = "28px";

  $.CreatePanel("Panel", playerLine, "", {
    class: "HeroBadge PlusHeroBadgeIconSmall NoTier",
    selectionpos: "auto",
  });
  $.CreatePanel("Image", playerLine, "", {
    class: "HeroIcon",
    selectionpos: "auto",
    src: Players.GetPortraitImage(playerID, playerInfo.player_selected_hero),
  });

  const stickerText = $.Localize(`chat_wheel_donate_sound_${data.sound}`, playerLine);
  playerLine.text = `${CHAT_STICKER_MESSAGE_INDENT}<font color='${playerColor}'>${playerName}</font> : `
    + "<img src='file://{images}/hud/reborn/icon_scoreboard_mute_sound.psd' class='ChatWheelIcon' />  "
    + stickerText;

  $.Schedule(7, () => {
    if (message.IsValid()) message.style.opacity = null;
  });

  chatStickerMovies.push({ message, movie });
  movie.Play();
  StartChatStickerGuard();
};

GameEvents.Subscribe("chat_wheel_send_sound", (event) => {
  const soundEvent = CHAT_STICKER_SOUNDS[event.sound];
  if (soundEvent) Game.EmitSound(soundEvent);

  const shownAboveHero = CreateVideoHeadMessage(event);
  if (!shownAboveHero) CreateVideoChatMessage(event);
});
