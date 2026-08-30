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
const STICKER_VIDEO_ROOT = "file://{resources}/videos/custom_game";
const SLOT_COUNT = 8;
const QUALITY_NORMAL = 1;
const QUALITY_ELITE = 2;
const SLOT_POS = [
  [0, -170],
  [150, -100],
  [196, 0],
  [150, 100],
  [0, 170],
  [-150, 100],
  [-196, 0],
  [-150, -100],
];
const config = GameUI.CustomUIConfig();

let pick = null;
let localSlots = null;
let drag = null;

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

function SlotsFromData(data) {
  const slots = [];
  for (let i = 0; i < SLOT_COUNT; i++) {
    slots.push(data["slot" + i] || "");
  }
  return slots;
}

function SlotsEqual(a, b) {
  if (!a || !b || a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) {
    if ((a[i] || "") !== (b[i] || "")) return false;
  }
  return true;
}

function CurrentSlots(data) {
  if (localSlots) return localSlots.slice();
  return SlotsFromData(data);
}

function StickerName(key) {
  if (!key) return $.Localize("#sticker_editor_empty");
  return $.Localize("#chat_wheel_donate_sound_" + key);
}

function StickerVideo(key) {
  return STICKER_VIDEO_ROOT + "/" + key + ".webm";
}

function DisableHittest(panel) {
  panel.hittest = false;
  panel.hittestchildren = false;
}

function IsOpen() {
  const modal = $("#StickerModal");
  return !!modal && modal.BHasClass("Visible");
}

function IsStickerUiAvailable() {
  return config.trinityWarmupActive === true || config.trinityStickerUiOverride === true;
}

function PanelWindowPos(panel) {
  if (!panel || !panel.GetPositionWithinWindow) return null;
  const pos = panel.GetPositionWithinWindow();
  if (!pos) return null;
  if (typeof pos.x === "number") return { x: pos.x, y: pos.y };
  if (typeof pos[0] === "number") return { x: pos[0], y: pos[1] };
  return null;
}

function WheelLocalCursor() {
  const area = $("#WheelArea");
  if (!area) return null;
  const cursor = GameUI.GetCursorPosition();
  const pos = PanelWindowPos(area);
  if (!cursor || !pos) return null;
  const scaleX = area.actualuiscale_x || 1;
  const scaleY = area.actualuiscale_y || 1;
  const w = (area.actuallayoutwidth || 0) / scaleX;
  const h = (area.actuallayoutheight || 0) / scaleY;
  if (w < 1 || h < 1) return null;
  return {
    x: (cursor[0] - pos.x) / scaleX,
    y: (cursor[1] - pos.y) / scaleY,
    w: w,
    h: h,
    cx: w * 0.5,
    cy: h * 0.5,
  };
}

function IsCursorOverWheel() {
  const local = WheelLocalCursor();
  if (!local) return false;
  const dx = local.x - local.cx;
  const dy = local.y - local.cy;
  const dist = Math.sqrt(dx * dx + dy * dy);
  return dist <= 280;
}

function SlotIndexAtCursor() {
  const local = WheelLocalCursor();
  if (!local) return null;
  const dx = local.x - local.cx;
  const dy = local.y - local.cy;
  const dist = Math.sqrt(dx * dx + dy * dy);
  if (dist < 48 || dist > 280) return null;

  let best = 0;
  let bestDist = 1e9;
  for (let i = 0; i < SLOT_COUNT; i++) {
    const ddx = dx - SLOT_POS[i][0];
    const ddy = dy - SLOT_POS[i][1];
    const d = ddx * ddx + ddy * ddy;
    if (d < bestDist) {
      bestDist = d;
      best = i;
    }
  }
  return best;
}

function HighlightSlot(index) {
  const wheel = $("#WheelSlots");
  if (!wheel) return;
  for (const slot of wheel.Children()) {
    const id = slot.id || "";
    const slotIndex = parseInt(id.replace("WheelSlot", ""), 10);
    slot.SetHasClass("DragOver", slotIndex === index);
  }
}

function TickDrag() {
  if (!drag) return;
  const index = SlotIndexAtCursor();
  drag.dropIndex = index;
  drag.overWheel = index !== null || IsCursorOverWheel();
  HighlightSlot(index);
  $.Schedule(0.03, TickDrag);
}

function SendSave(slots) {
  const payload = {
    PlayerID: LocalPlayerID(),
  };
  for (let i = 0; i < SLOT_COUNT; i++) {
    payload["s" + i] = slots[i] || "-";
  }
  GameEvents.SendCustomGameEventToServer("trinity_sticker_save_wheel", payload);
}

function FlushSave() {
  SendSave(CurrentSlots(StickerData()));
}

function Commit(slots) {
  const unique = [];
  const used = {};
  for (let i = 0; i < SLOT_COUNT; i++) {
    const key = slots[i] || "";
    if (key && used[key]) {
      unique.push("");
    } else {
      if (key) used[key] = true;
      unique.push(key);
    }
  }
  localSlots = unique;
  SendSave(unique);
  Render();
}

function ClearSlot(index) {
  const slots = CurrentSlots(StickerData());
  if (!slots[index]) return;
  slots[index] = "";
  pick = null;
  Commit(slots);
}

function AssignFromCollection(index, key) {
  const data = StickerData();
  if (!OwnedMap(data)[key]) return;

  const slots = CurrentSlots(data);
  const equippedAt = slots.indexOf(key);
  const replaced = slots[index];
  slots[index] = key;
  if (equippedAt >= 0 && equippedAt !== index) {
    slots[equippedAt] = replaced;
  }
  pick = null;
  Commit(slots);
}

function SwapSlots(from, to) {
  if (from === to) {
    pick = null;
    Render();
    return;
  }
  const slots = CurrentSlots(StickerData());
  const moved = slots[from];
  slots[from] = slots[to];
  slots[to] = moved;
  pick = null;
  Commit(slots);
}

function FinishDrag() {
  if (!drag) return;

  const finished = drag;
  drag = null;
  if (finished.display && finished.display.IsValid()) {
    finished.display.DeleteAsync(0);
  }

  const dropIndex = SlotIndexAtCursor();
  const overWheel = dropIndex !== null || IsCursorOverWheel();
  HighlightSlot(null);

  if (dropIndex !== null) {
    if (finished.from === null) {
      AssignFromCollection(dropIndex, finished.key);
    } else {
      SwapSlots(finished.from, dropIndex);
    }
    return;
  }

  if (finished.from !== null && !overWheel) {
    ClearSlot(finished.from);
    return;
  }

  pick = null;
  Render();
}

function MakeDragSource(panel, from) {
  $.RegisterEventHandler("DragStart", panel, function (_panelId, callbacks) {
    const key = panel.GetAttributeString("stickerKey", "");
    if (!key) return false;

    if (drag && drag.display && drag.display.IsValid()) {
      drag.display.DeleteAsync(0);
    }

    const display = $.CreatePanel("Panel", $.GetContextPanel(), "");
    display.AddClass("StickerDragDisplay");
    DisableHittest(display);
    const movie = $.CreatePanel("Movie", display, "", {
      class: "StickerDragMovie",
      controls: "none",
      repeat: "true",
      autoplay: "onload",
      src: StickerVideo(key),
    });
    DisableHittest(movie);

    callbacks.displayPanel = display;
    callbacks.offsetX = 26;
    callbacks.offsetY = 26;
    pick = null;
    drag = { key: key, from: from, display: display, dropIndex: null, overWheel: false };
    TickDrag();
    return true;
  });

  $.RegisterEventHandler("DragEnd", panel, function () {
    FinishDrag();
    return true;
  });
}

function FindMovie(parent) {
  if (!parent || parent.GetChildCount() < 1) return null;
  return parent.GetChild(0);
}

function SetMoviePlaying(movie, playing) {
  if (!movie || !movie.IsValid()) return;
  if (playing) movie.Play();
  else movie.Stop();
}

function CreatePreviewMovie(parent, key, movieClass, playOnHover, hoverPanel) {
  const options = {
    class: movieClass,
    controls: "none",
    repeat: "true",
    src: StickerVideo(key),
  };
  if (!playOnHover) options.autoplay = "onload";

  const movie = $.CreatePanel("Movie", parent, "", options);
  DisableHittest(movie);

  if (!playOnHover) return movie;

  hoverPanel.SetPanelEvent("onmouseover", function () {
    if (movie.IsValid()) movie.Play();
  });
  hoverPanel.SetPanelEvent("onmouseout", function () {
    if (movie.IsValid()) movie.Stop();
  });
  $.Schedule(0, function () {
    if (movie.IsValid()) movie.Stop();
  });

  return movie;
}

function BindSlotDrop(slot, index) {
  $.RegisterEventHandler("DragEnter", slot, function () {
    slot.AddClass("DragOver");
    if (drag) {
      drag.dropIndex = index;
      drag.overWheel = true;
    }
    return true;
  });
  $.RegisterEventHandler("DragLeave", slot, function () {
    slot.RemoveClass("DragOver");
    if (drag && drag.dropIndex === index) drag.dropIndex = null;
    return true;
  });
  $.RegisterEventHandler("DragDrop", slot, function () {
    slot.RemoveClass("DragOver");
    if (drag) {
      drag.dropIndex = index;
      drag.overWheel = true;
    }
    return true;
  });
}

function CreateWheelSlot(parent, index) {
  const slot = $.CreatePanel("Button", parent, "WheelSlot" + index);
  slot.AddClass("WheelSlot");
  slot.AddClass("WheelSlot" + index);

  const preview = $.CreatePanel("Panel", slot, "Preview");
  preview.AddClass("WheelSlotPreview");
  DisableHittest(preview);

  const capsule = $.CreatePanel("Panel", slot, "Capsule");
  capsule.AddClass("WheelSlotCapsule");
  DisableHittest(capsule);

  const label = $.CreatePanel("Label", capsule, "Label");
  label.AddClass("WheelSlotLabel");

  slot.SetPanelEvent("onactivate", function () {
    OnSlotClicked(index);
  });
  slot.SetPanelEvent("oncontextmenu", function () {
    ClearSlot(index);
  });

  BindSlotDrop(slot, index);
  MakeDragSource(slot, index);
  return slot;
}

function UpdateWheelSlot(slot, index, key, elite) {
  const nextKey = key || "";
  const prev = slot.GetAttributeString("stickerKey", "");
  slot.SetAttributeString("stickerKey", nextKey);
  slot.SetHasClass("Empty", !nextKey);
  slot.SetHasClass("Elite", !!elite);
  slot.SetHasClass("Picked", !!(pick && pick.from === index));
  slot.SetDraggable(!!nextKey);

  const label = slot.FindChildTraverse("Label");
  if (label) {
    label.text = elite ? StickerName(nextKey) + " ★" : StickerName(nextKey);
  }

  const preview = slot.FindChild("Preview");
  if (!preview) return;

  if (nextKey === prev) {
    SetMoviePlaying(FindMovie(preview), IsOpen() && !!nextKey);
    return;
  }

  preview.RemoveAndDeleteChildren();
  if (nextKey) CreatePreviewMovie(preview, nextKey, "WheelSlotMovie", false, slot);
}

function CreateCollectionRow(parent, key, info) {
  const elite = IsElite(info);
  const row = $.CreatePanel("Button", parent, "Collection" + key);
  row.AddClass("CollectionRow");
  row.SetAttributeString("stickerKey", key);
  if (elite) row.AddClass("Elite");
  if (pick && pick.from === null && pick.key === key) row.AddClass("Selected");

  const preview = $.CreatePanel("Panel", row, "Preview");
  preview.AddClass("CollectionPreview");
  DisableHittest(preview);
  CreatePreviewMovie(preview, key, "CollectionMovie", true, row);

  const meta = $.CreatePanel("Panel", row, "");
  meta.AddClass("CollectionMeta");
  DisableHittest(meta);

  const name = $.CreatePanel("Label", meta, "Name");
  name.AddClass("CollectionName");
  name.text = StickerName(key);

  const copies = $.CreatePanel("Label", meta, "Copies");
  copies.AddClass("CollectionCopies");
  copies.text = elite
    ? $.Localize("#sticker_editor_elite")
    : String(info.copies || 1) + "/5";

  row.SetPanelEvent("onactivate", function () {
    OnCollectionClicked(key);
  });
  row.SetDraggable(true);
  MakeDragSource(row, null);
  return row;
}

function UpdateCollectionRow(row, key, info) {
  const elite = IsElite(info);
  row.SetAttributeString("stickerKey", key);
  row.SetHasClass("Elite", elite);
  row.SetHasClass("Selected", !!(pick && pick.from === null && pick.key === key));
  const copies = row.FindChildTraverse("Copies");
  if (copies) {
    copies.text = elite
      ? $.Localize("#sticker_editor_elite")
      : String(info.copies || 1) + "/5";
  }
}

function OnSlotClicked(index) {
  const slots = CurrentSlots(StickerData());

  if (pick) {
    if (pick.from === null) {
      AssignFromCollection(index, pick.key);
    } else {
      SwapSlots(pick.from, index);
    }
    return;
  }

  if (slots[index]) {
    pick = { key: slots[index], from: index };
    Render();
  }
}

function OnCollectionClicked(key) {
  if (!OwnedMap(StickerData())[key]) return;
  if (pick && pick.from === null && pick.key === key) {
    pick = null;
  } else {
    pick = { key: key, from: null };
  }
  Render();
}

function SyncWheel(slots, owned) {
  const wheel = $("#WheelSlots");
  if (!wheel) return;
  if (wheel.GetChildCount() !== SLOT_COUNT) {
    wheel.RemoveAndDeleteChildren();
  }
  for (let i = 0; i < SLOT_COUNT; i++) {
    let slot = wheel.FindChild("WheelSlot" + i);
    if (!slot) slot = CreateWheelSlot(wheel, i);
    UpdateWheelSlot(slot, i, slots[i], IsElite(owned[slots[i]]));
  }
}

function SyncCollection(owned, slots) {
  const list = $("#CollectionList");
  if (!list) return;

  const keep = {};
  for (const key of STICKER_CATALOG) {
    const info = owned[key];
    if (!info) continue;
    if (slots.indexOf(key) >= 0) continue;
    keep[key] = true;
    const row = list.FindChild("Collection" + key);
    if (row) UpdateCollectionRow(row, key, info);
    else CreateCollectionRow(list, key, info);
  }

  for (const row of list.Children()) {
    const key = row.GetAttributeString("stickerKey", "");
    if (!keep[key]) row.DeleteAsync(0);
  }
}

function StopWheelMovies() {
  const wheel = $("#WheelSlots");
  if (!wheel) return;
  for (const slot of wheel.Children()) {
    const preview = slot.FindChild("Preview");
    SetMoviePlaying(FindMovie(preview), false);
  }
}

function Render() {
  if (drag) return;

  const data = StickerData();
  const owned = OwnedMap(data);
  const slots = CurrentSlots(data);

  SyncWheel(slots, owned);

  if (pick && pick.from === null && slots.indexOf(pick.key) >= 0) {
    pick = null;
  }

  SyncCollection(owned, slots);
}

function Open() {
  const modal = $("#StickerModal");
  if (!modal || !IsStickerUiAvailable()) return;
  if (typeof config.TrinityCloseLootbox === "function") {
    config.TrinityCloseLootbox();
  }
  pick = null;
  modal.AddClass("Visible");
  modal.hittest = true;
  modal.hittestchildren = true;
  Render();
  modal.SetFocus();
}

function Close() {
  const modal = $("#StickerModal");
  if (!modal) return;
  FlushSave();
  pick = null;
  StopWheelMovies();
  modal.RemoveClass("Visible");
  modal.hittest = false;
  modal.hittestchildren = false;
}

function BindWheelInput(panel) {
  if (!panel) return;
  panel.SetPanelEvent("onactivate", function () {
    const index = SlotIndexAtCursor();
    if (index === null) return;
    OnSlotClicked(index);
  });
  panel.SetPanelEvent("oncontextmenu", function () {
    const index = SlotIndexAtCursor();
    if (index === null) return;
    ClearSlot(index);
  });
  $.RegisterEventHandler("DragEnter", panel, function () {
    if (drag) drag.overWheel = true;
    return true;
  });
  $.RegisterEventHandler("DragLeave", panel, function () {
    return true;
  });
  $.RegisterEventHandler("DragDrop", panel, function () {
    if (drag) drag.overWheel = true;
    return true;
  });
}

(function () {
  const close = $("#StickerClose");
  const dim = $("#StickerDim");

  if (close) close.SetPanelEvent("onactivate", Close);
  if (dim) dim.SetPanelEvent("onactivate", Close);

  BindWheelInput($("#WheelSlots"));

  $.RegisterKeyBind($.GetContextPanel(), "key_escape", function () {
    if (IsOpen()) Close();
  });

  config.TrinityOpenStickerEditor = Open;
  config.TrinityCloseStickerEditor = Close;

  GameEvents.Subscribe("trinity_warmup_ended", function () {
    if (config.trinityStickerUiOverride !== true) Close();
  });
  CustomNetTables.SubscribeNetTableListener("trinity_stickers", function (_table, key) {
    if (String(key) !== String(LocalPlayerID())) return;
    const incoming = SlotsFromData(StickerData());
    if (localSlots && SlotsEqual(localSlots, incoming)) {
      localSlots = null;
    }
    if (IsOpen() && !drag) Render();
  });
})();
