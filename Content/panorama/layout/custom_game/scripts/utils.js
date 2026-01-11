"use strict";
const dotaHud = (() => {
  let panel = $.GetContextPanel();
  while (panel) {
    if (panel.id === "DotaHud") return panel;
    panel = panel.GetParent();
  }
  return panel;
})();
const FindDotaHudElement = (id) => (dotaHud === null || dotaHud === void 0 ? void 0 : dotaHud.FindChildTraverse(id));

const FindFirstChildWithClass = (panel, className) => panel.FindChildrenWithClassTraverse(className)[0];
Players.GetPlayerColorHex = (iPlayerID) => {
  let color = Players.GetPlayerColor(iPlayerID).toString(16);
  color = color.substring(6, 8) + color.substring(4, 6) + color.substring(2, 4) + color.substring(0, 2);
  return `#${color}`;
};
Players.GetPortraitImage = (iPlayerID, sHeroName) => {
  const name = sHeroName;
  return `file://{images}/heroes/${name}.png`;
};
const _default_context = $.GetContextPanel();
if (!$.LocalizeEngine) {
  $.LocalizeEngine = $.Localize;
  $.Localize = (text, parent) => {
    const token = text.startsWith("#") ? text : "#" + text;
    const localized = $.LocalizeEngine(token, parent || _default_context);
    return localized === token ? text : localized;
  };
}
// Value utils
const RandomFloat = (min, max) => {
  return Math.round((Math.random() * (max - min) + min) * 10) / 10;
};
const RandomInt = (min, max) => {
  return Math.round(RandomFloat(min, max));
};
const CreateTooltipParameters = (parameters) => {
  const toString = (value) => {
    switch (typeof value) {
      case "string":
      case "boolean":
      case "number":
        return value.toString();
      case "object":
        if (Array.isArray(value)) return value.map((v) => toString(v)).join(",");
        else return "object";
      case "undefined":
        return "undefined";
      default:
        throw `Not implemented for '${typeof value}'`;
    }
  };
  return Object.entries(parameters)
    .map(([key, value]) => key + "=" + toString(value))
    .join("&");
};
const TypewriterEffect = (text, element, speed = 50) => {
  let index = 0;
  element.SetDialogVariable("description", "");
  const typeNextChar = () => {
    if (index < text.length) {
      // Проверяем на теги delay и sound
      const remainingText = text.substring(index);
      // Проверяем на тег delay
      const delayMatch = remainingText.match(/^<delay=(\d+)>/);
      if (delayMatch) {
        const delaySeconds = parseInt(delayMatch[1]);
        index += delayMatch[0].length; // Пропускаем тег
        $.Schedule(delaySeconds, typeNextChar);
        return;
      }
      // Проверяем на тег sound
      const soundMatch = remainingText.match(/^<sound="([^"]+)">/);
      if (soundMatch) {
        const soundName = soundMatch[1];
        Game.EmitSound(soundName);
        index += soundMatch[0].length; // Пропускаем тег
        $.Schedule(0.1, typeNextChar); // Небольшая пауза после звука
        return;
      }
      // Обычный символ
      const currentText = text.substring(0, index + 1);
      element.SetDialogVariable("description", currentText);
      index++;
      $.Schedule(speed / 1000, typeNextChar);
    }
  };
  typeNextChar();
};
String.prototype.replaceAll = function (searchValue, replaceValue) {
  const regexp = searchValue instanceof RegExp ? searchValue : new RegExp(searchValue.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "g");
  return this.replace(regexp, replaceValue);
};
// Object.fromEntries = (array) =>
//   array.reduce((obj, [key, value]) => {
//     obj[key.toString()] = value;
//     return obj;
//   }, {});
Array.prototype.flatMap = function (callback, thisArg) {
  return this.reduce((acc, item, index) => acc.concat(callback.call(thisArg, item, index, this)), []);
};
Array.prototype.removeDuplicates = function () {
  return Array.from(new Set(this));
};
Number.prototype.toRounded = function (fractionDigits = 0) {
  const fraction = 10 ** fractionDigits;
  return Math.round(this.valueOf() * fraction) / fraction;
};
const secondsToMinsSecs = (seconds) => {
  var mins = Math.floor(seconds / 60);
  var secs = Math.floor(seconds % 60);
  if (mins < 10) {
    mins = mins;
  }
  if (secs < 10) {
    secs = `0${secs}`;
  }
  return mins + ":" + secs;
};
