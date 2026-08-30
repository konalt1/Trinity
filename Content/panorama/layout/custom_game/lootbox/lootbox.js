"use strict";

const STICKER_CATALOG = [
  "Gura",
  "NeuroHug",
  "Watson",
  "Anime",
  "Neurodance",
  "Choso",
  "StickerOne",
  "StickerTwo",
];
const STICKER_SOUNDS = {
  Gura: "high_five.impact",
  NeuroHug: "Hero_Chen.HolyPersuasion",
  Watson: "General.Buy",
  Anime: "Hero_Juggernaut.OmniSlash",
  Neurodance: "Hero_Weaver.Shukuchi",
  Choso: "Wheel.Choso",
  StickerOne: "high_five.impact",
  StickerTwo: "General.Buy",
};
const STICKER_ROLL_POOL = [
  { key: "Gura", quality: 1, weight: 100 },
  { key: "Gura", quality: 2, weight: 10 },
  { key: "NeuroHug", quality: 1, weight: 100 },
  { key: "NeuroHug", quality: 2, weight: 10 },
  { key: "Watson", quality: 1, weight: 100 },
  { key: "Watson", quality: 2, weight: 10 },
  { key: "Anime", quality: 1, weight: 100 },
  { key: "Anime", quality: 2, weight: 10 },
  { key: "Neurodance", quality: 1, weight: 30 },
  { key: "Neurodance", quality: 2, weight: 3 },
  { key: "Choso", quality: 1, weight: 100 },
  { key: "Choso", quality: 2, weight: 10 },
  { key: "StickerOne", quality: 1, weight: 30 },
  { key: "StickerOne", quality: 2, weight: 3 },
  { key: "StickerTwo", quality: 1, weight: 30 },
  { key: "StickerTwo", quality: 2, weight: 3 },
];
const STICKER_VIDEO_ROOT = "file://{resources}/videos/custom_game";
const QUALITY_NORMAL = 1;
const QUALITY_ELITE = 2;
const PREVIEW_FREEZE_DELAY = 0.4;
const ROULETTE_COUNT = 64;
const ROULETTE_WINNER_MIN = 54;
const ROULETTE_WINNER_MAX = 58;
const ROULETTE_SLOT_W = 200;
const ROULETTE_DURATION = 9;
const ROULETTE_DECEL_DURATION = 4;
const ROULETTE_CRUISE_SPEED = 1.45;
const ROULETTE_LAND_HOLD = 0.45;
const ROULETTE_SKIP_LOCK = 0.5;
const ROULETTE_TICK_SOUND = "General.ButtonClick";
const ROULETTE_LAND_SOUND = "ui.treasure_01";
// Единственная ручка размера стикера внутри круга. CSS на Movie не работает — менять здесь.
const MOVIE_SCALE = 0.5;
const config = GameUI.CustomUIConfig();

let openingLootbox = false;
let hoverSoundGuid = 0;
let pendingReveal = null;
let rouletteWinnerIndex = -1;
let rouletteSkipReady = 0;

config.lootboxRouletteGen = (config.lootboxRouletteGen || 0) + 1;

function LocalPlayerID() {
  return Players.GetLocalPlayer();
}

function StickerData() {
  return CustomNetTables.GetTableValue("trinity_stickers", String(LocalPlayerID())) || {};
}

function OwnedMap(data) {
  const owned = {};
  const source = data.owned || {};
  for (const key in source) {
    const value = source[key];
    if (value && typeof value === "object") {
      const quality = Number(value.quality || 0);
      if (quality >= QUALITY_NORMAL) {
        owned[key] = {
          quality: quality >= QUALITY_ELITE ? QUALITY_ELITE : QUALITY_NORMAL,
          copies: Number(value.copies || 0),
        };
      }
    } else if (value) {
      owned[key] = { quality: Number(value) >= QUALITY_ELITE ? QUALITY_ELITE : QUALITY_NORMAL, copies: 1 };
    }
  }
  return owned;
}

function IsElite(info) {
  return !!info && info.quality === QUALITY_ELITE;
}

function StickerName(key) {
  if (!key) return "";
  return $.Localize("#chat_wheel_donate_sound_" + key);
}

function StickerVideo(key) {
  return STICKER_VIDEO_ROOT + "/" + key + ".webm";
}

function FormatToken(token, value) {
  return $.Localize(token).replace("%s", String(value));
}

function DisableHittest(panel) {
  panel.hittest = false;
  panel.hittestchildren = false;
}

function LootboxWindow() {
  return $("#LootboxWindow");
}

function IsOpen() {
  const modal = $("#LootboxModal");
  return !!modal && modal.BHasClass("Visible");
}

function IsStickerUiAvailable() {
  return config.trinityWarmupActive === true || config.trinityStickerUiOverride === true;
}

function IsRevealing() {
  const window = LootboxWindow();
  return !!window && window.BHasClass("ShowingReveal");
}

function IsSpinning() {
  const window = LootboxWindow();
  return !!window && window.BHasClass("Spinning");
}

function CancelRoulette() {
  config.lootboxRouletteGen += 1;
  pendingReveal = null;
  rouletteWinnerIndex = -1;
  rouletteSkipReady = 0;
  const window = LootboxWindow();
  if (window) window.RemoveClass("Spinning");
  const strip = $("#RouletteStrip");
  if (strip) {
    strip.RemoveAndDeleteChildren();
    strip.style.x = "0px";
    strip.style.transform = "translatex(0px)";
  }
}

function StopHoverSound() {
  if (hoverSoundGuid) {
    Game.StopSound(hoverSoundGuid);
    hoverSoundGuid = 0;
  }
}

function PlayHoverSound(key) {
  StopHoverSound();
  const soundEvent = STICKER_SOUNDS[key];
  if (!soundEvent) return;
  hoverSoundGuid = Game.EmitSound(soundEvent) || 0;
}

function MovieSizeStyle(scale) {
  const pct = Math.round(scale * 100);
  return (
    "width: 100%; height: 100%; ui-scale: " +
    pct +
    "%; horizontal-align: center; vertical-align: center;"
  );
}

function CreatePreviewMovie(parent, key, hoverPanel) {
  const movie = $.CreatePanel("Movie", parent, "", {
    class: "LootboxMovie",
    style: MovieSizeStyle(MOVIE_SCALE),
    controls: "none",
    repeat: "true",
    autoplay: "onload",
    disableaudio: "true",
    src: StickerVideo(key),
  });
  DisableHittest(movie);

  let hovered = false;
  hoverPanel.SetPanelEvent("onmouseover", function () {
    hovered = true;
    if (movie.IsValid()) movie.Play();
    PlayHoverSound(key);
  });
  hoverPanel.SetPanelEvent("onmouseout", function () {
    hovered = false;
    if (movie.IsValid()) movie.Stop();
    StopHoverSound();
  });
  $.Schedule(PREVIEW_FREEZE_DELAY, function () {
    if (!hovered && movie.IsValid()) movie.Stop();
  });
}

function CreateStickerTile(parent, key, info) {
  const elite = IsElite(info);
  const tile = $.CreatePanel("Panel", parent, "LootboxSticker" + key);
  tile.AddClass("LootboxSticker");
  if (elite) tile.AddClass("Elite");

  const stage = $.CreatePanel("Panel", tile, "");
  stage.AddClass("LootboxStickerStage");
  DisableHittest(stage);

  const glow = $.CreatePanel("Panel", stage, "");
  glow.AddClass("LootboxStickerGlow");
  DisableHittest(glow);

  const preview = $.CreatePanel("Panel", stage, "");
  preview.AddClass("LootboxPreview");
  DisableHittest(preview);
  CreatePreviewMovie(preview, key, tile);

  const name = $.CreatePanel("Label", tile, "");
  name.AddClass("LootboxStickerName");
  name.text = StickerName(key);
  DisableHittest(name);

  const copies = $.CreatePanel("Label", tile, "");
  copies.AddClass("LootboxCopies");
  if (elite) {
    copies.text = $.Localize("#sticker_editor_elite");
  } else if (info) {
    copies.text = FormatToken("#sticker_editor_copies", info.copies || 1);
  } else {
    copies.text = $.Localize("#lootbox_copies_none");
  }
  DisableHittest(copies);

  return tile;
}

function Render() {
  const data = StickerData();
  const owned = OwnedMap(data);
  const lootboxes = Number(data.lootboxes) || 0;
  const canOpen = lootboxes > 0 && !IsRevealing() && !IsSpinning();

  const count = $("#TreasureCount");
  if (count) count.text = FormatToken("#lootbox_unopened", lootboxes);

  const openButton = $("#OpenLootboxButton");
  if (openButton) openButton.enabled = canOpen;
  const chest = $("#TreasureChestButton");
  if (chest) chest.enabled = canOpen;

  const list = $("#LootboxStickerList");
  if (list && !IsSpinning()) {
    if (!IsRevealing()) StopHoverSound();
    list.RemoveAndDeleteChildren();
    for (const key of STICKER_CATALOG) {
      CreateStickerTile(list, key, owned[key]);
    }
  }
}

function Open() {
  const modal = $("#LootboxModal");
  if (!modal || !IsStickerUiAvailable()) return;
  if (typeof config.TrinityCloseStickerEditor === "function") {
    config.TrinityCloseStickerEditor();
  }
  CloseReveal();
  modal.AddClass("Visible");
  modal.hittest = true;
  modal.hittestchildren = true;
  Render();
  modal.SetFocus();
}

function Close() {
  if (IsSpinning()) {
    SkipRoulette();
    return;
  }
  const modal = $("#LootboxModal");
  if (!modal) return;
  StopHoverSound();
  CloseReveal();
  modal.RemoveClass("Visible");
  modal.hittest = false;
  modal.hittestchildren = false;
  $.DispatchEvent("DropInputFocus");
}

function OpenLootbox() {
  if (openingLootbox || IsRevealing() || IsSpinning()) return;
  const data = StickerData();
  if ((Number(data.lootboxes) || 0) < 1) return;
  openingLootbox = true;
  GameEvents.SendCustomGameEventToServer("trinity_sticker_open", {});
  $.Schedule(8, function () {
    openingLootbox = false;
  });
}

function RollPoolTotal() {
  let total = 0;
  for (let i = 0; i < STICKER_ROLL_POOL.length; i++) {
    total += STICKER_ROLL_POOL[i].weight;
  }
  return total;
}

function PickWeightedRoll() {
  let roll = Math.floor(Math.random() * RollPoolTotal()) + 1;
  for (let i = 0; i < STICKER_ROLL_POOL.length; i++) {
    const item = STICKER_ROLL_POOL[i];
    roll -= item.weight;
    if (roll <= 0) {
      return { key: item.key, quality: item.quality };
    }
  }
  const fallback = STICKER_ROLL_POOL[0];
  return { key: fallback.key, quality: fallback.quality };
}

function RandomInt(min, max) {
  return min + Math.floor(Math.random() * (max - min + 1));
}

function RouletteProgress(elapsed) {
  const cruiseDuration = ROULETTE_DURATION - ROULETTE_DECEL_DURATION;
  const cruiseShare = cruiseDuration / (cruiseDuration + ROULETTE_DECEL_DURATION / 2);
  const cruiseEnd = cruiseDuration / ROULETTE_CRUISE_SPEED;
  if (elapsed <= cruiseEnd) {
    return cruiseShare * (elapsed / cruiseEnd);
  }

  const decelTime = Math.min(ROULETTE_DECEL_DURATION, elapsed - cruiseEnd);
  const t = decelTime / ROULETTE_DECEL_DURATION;
  return cruiseShare + (1 - cruiseShare) * (2 * t - t * t);
}

function CreateRouletteSlot(parent, item, index) {
  const elite = Number(item.quality) === QUALITY_ELITE;
  const slot = $.CreatePanel("Panel", parent, "RouletteSlot" + index);
  slot.AddClass("RouletteSlot");
  slot.SetAttributeString("sticker", item.key || "");
  if (elite) slot.AddClass("Elite");
  DisableHittest(slot);

  const preview = $.CreatePanel("Panel", slot, "");
  preview.AddClass("RoulettePreview");
  DisableHittest(preview);

  const movie = $.CreatePanel("Movie", preview, "", {
    class: "RouletteMovie",
    style: MovieSizeStyle(MOVIE_SCALE),
    controls: "none",
    repeat: "true",
    autoplay: "onload",
    disableaudio: "true",
    src: StickerVideo(item.key),
  });
  DisableHittest(movie);
  $.Schedule(PREVIEW_FREEZE_DELAY, function () {
    if (movie.IsValid()) movie.Stop();
  });

  const name = $.CreatePanel("Label", slot, "");
  name.AddClass("RouletteSlotName");
  name.text = StickerName(item.key);
  DisableHittest(name);
  return slot;
}

function BuildRouletteStrip(event) {
  const strip = $("#RouletteStrip");
  if (!strip) return -1;
  strip.RemoveAndDeleteChildren();
  strip.style.x = "0px";
  strip.style.transform = "translatex(0px)";
  strip.style.width = ROULETTE_COUNT * ROULETTE_SLOT_W + "px";

  const winnerIndex = RandomInt(ROULETTE_WINNER_MIN, ROULETTE_WINNER_MAX);
  const winnerKey = String(event.sticker || "");
  const winner = {
    key: winnerKey,
    quality: Number(event.quality) === QUALITY_ELITE ? QUALITY_ELITE : QUALITY_NORMAL,
  };
  for (let i = 0; i < ROULETTE_COUNT; i++) {
    let item = PickWeightedRoll();
    if (i === winnerIndex) {
      item = winner;
    } else if (item.key === winnerKey && Number(item.quality) === winner.quality) {
      item = PickWeightedRoll();
    }
    CreateRouletteSlot(strip, item, i);
  }
  return winnerIndex;
}

function SetStripX(strip, x) {
  strip.style.transform = "translatex(" + Math.round(x) + "px)";
}

function SlotUnderPointer(translateX, viewW, slotW) {
  if (slotW <= 0) return -1;
  return Math.floor((viewW / 2 - translateX) / slotW);
}

function WinnerCenterX() {
  return rouletteWinnerIndex * ROULETTE_SLOT_W + ROULETTE_SLOT_W / 2;
}

function FinishRoulette(event, gen, endX) {
  if (gen !== config.lootboxRouletteGen) return;
  const strip = $("#RouletteStrip");
  if (strip) {
    if (endX != null) SetStripX(strip, endX);
    const winner = strip.GetChild(rouletteWinnerIndex);
    if (winner) winner.AddClass("Winner");
  }
  Game.EmitSound(ROULETTE_LAND_SOUND);
  $.Schedule(ROULETTE_LAND_HOLD, function () {
    if (gen !== config.lootboxRouletteGen) return;
    ShowReveal(event);
  });
}

function AnimateRoulette(event, gen, startX, endX, viewW, slotW) {
  const strip = $("#RouletteStrip");
  if (!strip) {
    ShowReveal(event);
    return;
  }
  const started = Game.Time();
  let lastTickSlot = SlotUnderPointer(startX, viewW, slotW);

  function step() {
    if (gen !== config.lootboxRouletteGen) return;
    const elapsed = Game.Time() - started;
    const progress = RouletteProgress(elapsed);
    const x = startX + (endX - startX) * progress;
    SetStripX(strip, x);

    const slot = SlotUnderPointer(x, viewW, slotW);
    if (slot !== lastTickSlot && slot >= 0) {
      lastTickSlot = slot;
      Game.EmitSound(ROULETTE_TICK_SOUND);
    }

    if (elapsed < ROULETTE_DURATION) {
      $.Schedule(0.01, step);
    } else {
      FinishRoulette(event, gen, endX);
    }
  }

  SetStripX(strip, startX);
  $.Schedule(0.01, step);
}

function StartRouletteWhenReady(event, gen, attempt) {
  if (gen !== config.lootboxRouletteGen) return;
  const viewport = $("#RouletteViewport");
  const strip = $("#RouletteStrip");
  const uiScaleX = viewport ? viewport.actualuiscale_x || 1 : 1;
  const viewW = viewport ? viewport.actuallayoutwidth / uiScaleX : 0;
  if (!viewport || !strip || viewW < 32) {
    if (attempt < 40) {
      $.Schedule(0.03, function () {
        StartRouletteWhenReady(event, gen, attempt + 1);
      });
      return;
    }
  }

  const width = viewW >= 32 ? viewW : 1400;
  const endX = width / 2 - WinnerCenterX();
  AnimateRoulette(event, gen, 0, endX, width, ROULETTE_SLOT_W);
}

function StartRoulette(event) {
  const window = LootboxWindow();
  const sticker = event && String(event.sticker || "");
  if (!window || !sticker) return;

  CancelRoulette();
  pendingReveal = event;
  const gen = config.lootboxRouletteGen;
  window.RemoveClass("ShowingReveal");
  window.AddClass("Spinning");
  rouletteSkipReady = Game.Time() + ROULETTE_SKIP_LOCK;
  rouletteWinnerIndex = BuildRouletteStrip(event);
  if (rouletteWinnerIndex < 0) {
    ShowReveal(event);
    return;
  }
  $.Schedule(0.03, function () {
    StartRouletteWhenReady(event, gen, 0);
  });
}

function SkipRoulette() {
  if (!IsSpinning() || !pendingReveal) return;
  if (Game.Time() < rouletteSkipReady) return;
  const event = pendingReveal;
  config.lootboxRouletteGen += 1;
  ShowReveal(event);
}

function FillRevealMovie(sticker) {
  const host = $("#RevealMovieHost");
  if (!host) return;
  host.RemoveAndDeleteChildren();
  const movie = $.CreatePanel("Movie", host, "RevealMovie", {
    class: "RevealMovie",
    style: MovieSizeStyle(MOVIE_SCALE),
    controls: "none",
    repeat: "true",
    autoplay: "onload",
    disableaudio: "true",
    src: StickerVideo(sticker),
  });
  DisableHittest(movie);
  movie.Play();
}

function ShowReveal(event) {
  const window = LootboxWindow();
  const name = $("#RevealName");
  const quality = $("#RevealQuality");
  const note = $("#RevealNote");
  const card = $("#TreasureReveal");
  const sticker = event && event.sticker;
  if (!window || !sticker) return;

  pendingReveal = null;
  rouletteWinnerIndex = -1;
  window.RemoveClass("Spinning");
  StopHoverSound();
  const elite = Number(event.quality) === QUALITY_ELITE;
  if (name) name.text = StickerName(sticker);
  if (card) card.SetHasClass("Elite", elite);
  if (quality) quality.text = $.Localize(elite ? "#sticker_editor_elite" : "#sticker_editor_normal");
  if (note) {
    let text = "";
    if (event.converted == 1 || event.converted === true) {
      text = $.Localize("#sticker_editor_converted");
    } else if (event.duplicate == 1 || event.duplicate === true) {
      text = $.Localize("#sticker_editor_duplicate");
    }
    note.text = text;
    note.SetHasClass("ShowNote", text !== "");
  }
  window.AddClass("ShowingReveal");
  const openButton = $("#OpenLootboxButton");
  if (openButton) openButton.enabled = false;
  const chest = $("#TreasureChestButton");
  if (chest) chest.enabled = false;
  $.Schedule(0.03, function () {
    FillRevealMovie(sticker);
    if (elite) PlayHoverSound(sticker);
  });
}

function CloseReveal() {
  CancelRoulette();
  const window = LootboxWindow();
  if (window) window.RemoveClass("ShowingReveal");
  openingLootbox = false;
  StopHoverSound();
  const host = $("#RevealMovieHost");
  if (host) host.RemoveAndDeleteChildren();
  if (IsOpen()) Render();
}

function OpenStickerEditor() {
  if (!IsRevealing()) return;
  if (typeof config.TrinityOpenStickerEditor === "function") {
    config.TrinityOpenStickerEditor();
  }
}

(function () {
  const close = $("#LootboxClose");
  const dim = $("#LootboxDim");
  const lootbox = $("#OpenLootboxButton");
  const chest = $("#TreasureChestButton");
  const continueBtn = $("#RevealContinue");
  const assignBtn = $("#RevealAssignSticker");
  const viewport = $("#RouletteViewport");

  if (close) close.SetPanelEvent("onactivate", Close);
  if (dim) dim.SetPanelEvent("onactivate", Close);
  if (lootbox) lootbox.SetPanelEvent("onactivate", OpenLootbox);
  if (chest) chest.SetPanelEvent("onactivate", OpenLootbox);
  if (continueBtn) continueBtn.SetPanelEvent("onactivate", CloseReveal);
  if (assignBtn) assignBtn.SetPanelEvent("onactivate", OpenStickerEditor);
  if (viewport) viewport.SetPanelEvent("onactivate", SkipRoulette);

  $.RegisterKeyBind($.GetContextPanel(), "key_escape", function () {
    if (IsOpen()) Close();
  });

  config.TrinityOpenLootbox = Open;
  config.TrinityCloseLootbox = Close;

  GameEvents.Subscribe("trinity_warmup_ended", function () {
    if (config.trinityStickerUiOverride === true) return;
    CloseReveal();
    const modal = $("#LootboxModal");
    if (!modal) return;
    StopHoverSound();
    modal.RemoveClass("Visible");
    modal.hittest = false;
    modal.hittestchildren = false;
    $.DispatchEvent("DropInputFocus");
  });
  GameEvents.Subscribe("trinity_sticker_opened", function (event) {
    openingLootbox = false;
    if (event && event.failed == 1) return;
    StartRoulette(event);
  });
  CustomNetTables.SubscribeNetTableListener("trinity_stickers", function () {
    if (IsOpen()) Render();
  });
})();
