"use strict";
var favourites = new Array();
var nowrings = 9;
var selected_sound_current = undefined;
var nowselect = 0;
var current_button;
let tableHero;
let isWorkWheel = false;
var rings = [[Array(8).fill(""), Array(8).fill(true)]];
const initTableHero = () => {
  // Имя должно совпадать с видео и аудио, цифра это позиция в колесе чатов от 0 - до 7
  tableHero = { ["0"]: { sound: "pudge", maxTime: 5 }, ["3"]: { sound: "tuntunsahur", maxTime: 4 } };
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

      if (soundName != undefined && maxTime != undefined) {
        GameEvents.SendCustomGameEventToServer("chat_wheel_select", {
          select: soundName,
          maxTime,
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
  Game.CreateCustomKeyBind(GetGameKeybind(DOTAKeybindCommand_t.DOTA_KEYBIND_CHAT_WHEEL), "+" + name_bind);
  current_button = GetGameKeybind(DOTAKeybindCommand_t.DOTA_KEYBIND_CHAT_WHEEL);
  SetBindInterval();
  $("#Wheel").visible = false;
  $("#Bubble").visible = false;
  $("#PhrasesContainer").visible = false;
})();
function GetGameKeybind(command) {
  return Game.GetKeybindForCommand(command);
}
function SetBindInterval() {
  if (GetGameKeybind(DOTAKeybindCommand_t.DOTA_KEYBIND_HERO_CHAT_WHEEL) != current_button) {
    const name_bind = "WheelHeroButton" + Math.floor(Math.random() * 99999999);
    Game.AddCommand("+" + name_bind, StartWheel, "", 0);
    Game.AddCommand("-" + name_bind, StopWheel, "", 0);
    Game.CreateCustomKeyBind(GetGameKeybind(DOTAKeybindCommand_t.DOTA_KEYBIND_HERO_CHAT_WHEEL), "+" + name_bind);
    current_button = GetGameKeybind(DOTAKeybindCommand_t.DOTA_KEYBIND_HERO_CHAT_WHEEL);
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

const CreateVideoHeadMessage = (data) => {
  const hudRoot = dotaHud.FindChildTraverse("HeroRelicProgress");
  hudRoot.hittestchildren = true;

  //  hudRoot.GetChild(0)?.DeleteAsync(0);

  const newPanel = $.CreatePanel("Movie", hudRoot, "", {
    selectionpos: "auto",
    style: "width: 120px; height: 120px;  border-radius: 50%;",
    controls: "none",
    repeat: "true",
    disableaudio: "false",
    autoplay: "onload",
    src: `file://{images}/custom_game/${data.sound}.webm`,
  });

  const hero = data.hero;

  if (!hero) return;

  const maxTime = data.maxTime;
  let time = 0;
  const UpdateVideoPanels = () => {
    if (time >= maxTime) {
      newPanel.DeleteAsync(0);
      return;
    }
    const origin = Entities.GetAbsOrigin(hero);

    // Быстрая проверка валидности origin
    if (!origin || origin.length < 3) return;

    // Кэшируем вычисления координат
    const posX = Game.WorldToScreenX(origin[0], origin[1], origin[2]);
    const posY = Game.WorldToScreenY(origin[0], origin[1], origin[2]);

    // Быстрая проверка валидности координат
    if (isNaN(posX) || isNaN(posY)) return;

    const next = () => {
      const frameTime = Game.GetGameFrameTime();
      time += frameTime;

      $.Schedule(Game.GetGameFrameTime(), () => {
        UpdateVideoPanels();
      });
    };

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
    if (isNaN(panelX) || isNaN(panelY)) {
      return;
    }

    // Позиционируем панель
    const panelTransform = `translate3d(${(panelX - newPanel.actuallayoutwidth / 2) / newPanel.actualuiscale_x}px,${
      (panelY - newPanel.actuallayoutheight) / newPanel.actualuiscale_y
    }px,0)`;

    // Обновляем transform только если он изменился
    if (newPanel.style.transform !== panelTransform) {
      newPanel.style.transform = panelTransform;
    }

    next();
  };

  UpdateVideoPanels();
};

GameEvents.Subscribe("chat_wheel_send_sound", (event) => CreateVideoHeadMessage(event));
