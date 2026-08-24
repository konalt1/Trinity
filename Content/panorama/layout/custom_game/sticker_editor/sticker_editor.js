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
const PREVIEW_FREEZE_DELAY = 0.4;
const config = GameUI.CustomUIConfig();

let pick = null;
let hideLocked = false;
let openingLootbox = false;
let localSlots = null;
let drag = null;

function LocalPlayerID() {
  return Players.GetLocalPlayer();
}

function StickerData() {
  return CustomNetTables.GetTableValue("trinity_stickers", String(LocalPlayerID())) || {};
}

function OwnedSet(data) {
  const owned = {};
  const source = data.owned || {};
  for (const key in source) {
    if (source[key]) owned[key] = true;
  }
  return owned;
}

function CurrentSlots(data) {
  if (localSlots) return localSlots.slice();
  const slots = [];
  for (let i = 0; i < SLOT_COUNT; i++) {
    slots.push(data["slot" + i] || "");
  }
  return slots;
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

function Commit(slots) {
  localSlots = slots.slice();
  const payload = {};
  for (let i = 0; i < SLOT_COUNT; i++) {
    payload["s" + i] = slots[i] || "";
  }
  GameEvents.SendCustomGameEventToServer("trinity_sticker_save_wheel", payload);
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
  if (!OwnedSet(data)[key]) return;

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
  ClearDragOver();

  if (finished.dropIndex !== null) {
    if (finished.from === null) {
      AssignFromCollection(finished.dropIndex, finished.key);
    } else {
      SwapSlots(finished.from, finished.dropIndex);
    }
    return;
  }

  if (finished.from !== null) {
    ClearSlot(finished.from);
    return;
  }

  pick = null;
  Render();
}

function ClearDragOver() {
  const wheel = $("#WheelSlots");
  if (!wheel) return;
  for (const slot of wheel.Children()) {
    slot.RemoveClass("DragOver");
  }
}

function MakeDragSource(panel, key, from) {
  panel.SetDraggable(true);

  $.RegisterEventHandler("DragStart", panel, function (_panelId, callbacks) {
    if (drag && drag.display && drag.display.IsValid()) {
      drag.display.DeleteAsync(0);
    }

    const display = $.CreatePanel("Panel", $.GetContextPanel(), "");
    display.AddClass("StickerDragDisplay");
    $.CreatePanel("Movie", display, "", {
      class: "StickerDragMovie",
      controls: "none",
      repeat: "true",
      autoplay: "onload",
      src: StickerVideo(key),
    });

    callbacks.displayPanel = display;
    callbacks.offsetX = 26;
    callbacks.offsetY = 26;
    pick = null;
    drag = { key: key, from: from, display: display, dropIndex: null };
    return true;
  });

  $.RegisterEventHandler("DragEnd", panel, function () {
    FinishDrag();
    return true;
  });
}

function CreatePreviewMovie(parent, key, movieClass, playOnHover, hoverPanel) {
  const movie = $.CreatePanel("Movie", parent, "", {
    class: movieClass,
    controls: "none",
    repeat: "true",
    autoplay: "onload",
    src: StickerVideo(key),
  });
  DisableHittest(movie);

  if (!playOnHover) return movie;

  let hovered = false;
  hoverPanel.SetPanelEvent("onmouseover", function () {
    hovered = true;
    if (movie.IsValid()) movie.Play();
  });
  hoverPanel.SetPanelEvent("onmouseout", function () {
    hovered = false;
    if (movie.IsValid()) movie.Stop();
  });
  $.Schedule(PREVIEW_FREEZE_DELAY, function () {
    if (!hovered && movie.IsValid()) movie.Stop();
  });

  return movie;
}

function CreateWheelSlot(parent, index, key) {
  const slot = $.CreatePanel("Button", parent, "WheelSlot" + index);
  slot.AddClass("WheelSlot");
  slot.AddClass("WheelSlot" + index);
  if (!key) slot.AddClass("Empty");
  if (pick && pick.from === index) slot.AddClass("Picked");

  const preview = $.CreatePanel("Panel", slot, "");
  preview.AddClass("WheelSlotPreview");
  DisableHittest(preview);
  if (key) CreatePreviewMovie(preview, key, "WheelSlotMovie", false, slot);

  const capsule = $.CreatePanel("Panel", slot, "");
  capsule.AddClass("WheelSlotCapsule");
  DisableHittest(capsule);

  const label = $.CreatePanel("Label", capsule, "");
  label.AddClass("WheelSlotLabel");
  label.text = StickerName(key);

  slot.SetPanelEvent("onactivate", function () {
    OnSlotClicked(index);
  });
  slot.SetPanelEvent("oncontextmenu", function () {
    ClearSlot(index);
  });

  $.RegisterEventHandler("DragEnter", slot, function () {
    slot.AddClass("DragOver");
    return true;
  });
  $.RegisterEventHandler("DragLeave", slot, function () {
    slot.RemoveClass("DragOver");
    return true;
  });
  $.RegisterEventHandler("DragDrop", slot, function () {
    slot.RemoveClass("DragOver");
    if (drag) drag.dropIndex = index;
    return true;
  });

  if (key) MakeDragSource(slot, key, index);
  return slot;
}

function CreateCollectionRow(parent, key, owned) {
  const row = $.CreatePanel("Button", parent, "Collection" + key);
  row.AddClass("CollectionRow");
  if (!owned) row.AddClass("Locked");
  if (pick && pick.from === null && pick.key === key) row.AddClass("Selected");

  const preview = $.CreatePanel("Panel", row, "");
  preview.AddClass("CollectionPreview");
  DisableHittest(preview);
  if (owned) CreatePreviewMovie(preview, key, "CollectionMovie", true, row);

  const name = $.CreatePanel("Label", row, "");
  name.AddClass("CollectionName");
  name.text = owned ? StickerName(key) : $.Localize("#sticker_editor_locked");
  DisableHittest(name);

  if (owned) {
    row.SetPanelEvent("onactivate", function () {
      OnCollectionClicked(key);
    });
    MakeDragSource(row, key, null);
  }

  return row;
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
  if (!OwnedSet(StickerData())[key]) return;
  if (pick && pick.from === null && pick.key === key) {
    pick = null;
  } else {
    pick = { key: key, from: null };
  }
  Render();
}

function Render() {
  const data = StickerData();
  const owned = OwnedSet(data);
  const slots = CurrentSlots(data);

  const lootboxRow = $("#LootboxRow");
  if (lootboxRow) {
    lootboxRow.SetHasClass("ShowLootbox", data.lootbox_pending == 1);
  }

  const box = $("#HideLockedBox");
  if (box) box.SetHasClass("Checked", hideLocked);

  const wheel = $("#WheelSlots");
  if (wheel) {
    wheel.RemoveAndDeleteChildren();
    for (let i = 0; i < SLOT_COUNT; i++) {
      CreateWheelSlot(wheel, i, slots[i]);
    }
  }

  if (pick && pick.from === null && slots.indexOf(pick.key) >= 0) {
    pick = null;
  }

  const list = $("#CollectionList");
  if (list) {
    list.RemoveAndDeleteChildren();
    for (const key of STICKER_CATALOG) {
      const isOwned = !!owned[key];
      if (!isOwned && hideLocked) continue;
      if (slots.indexOf(key) >= 0) continue;
      CreateCollectionRow(list, key, isOwned);
    }
  }
}

function Open() {
  const modal = $("#StickerModal");
  if (!modal || config.trinityWarmupActive !== true) return;
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
  pick = null;
  modal.RemoveClass("Visible");
  modal.hittest = false;
  modal.hittestchildren = false;
}

function OpenLootbox() {
  if (openingLootbox) return;
  const data = StickerData();
  if (data.lootbox_pending != 1) return;
  openingLootbox = true;
  GameEvents.SendCustomGameEventToServer("trinity_sticker_open", {});
}

function ShowReveal(sticker, duplicate) {
  const overlay = $("#RevealOverlay");
  const name = $("#RevealName");
  const duplicateLabel = $("#RevealDuplicate");
  if (!overlay || !sticker) return;

  const movie = $("#RevealMovie");
  if (movie) movie.src = StickerVideo(sticker);
  if (name) name.text = StickerName(sticker);
  if (duplicateLabel) duplicateLabel.SetHasClass("ShowDuplicate", duplicate == 1 || duplicate === true);
  overlay.AddClass("ShowReveal");
}

function CloseReveal() {
  const overlay = $("#RevealOverlay");
  if (overlay) overlay.RemoveClass("ShowReveal");
  openingLootbox = false;
  if (IsOpen()) Render();
}

function OnHideLockedToggled() {
  hideLocked = !hideLocked;
  Render();
}

(function () {
  const close = $("#StickerClose");
  const dim = $("#StickerDim");
  const lootbox = $("#OpenLootboxButton");
  const hideRow = $("#HideLockedRow");

  if (close) close.SetPanelEvent("onactivate", Close);
  if (dim) dim.SetPanelEvent("onactivate", Close);
  if (lootbox) lootbox.SetPanelEvent("onactivate", OpenLootbox);
  if (hideRow) hideRow.SetPanelEvent("onactivate", OnHideLockedToggled);

  $.RegisterKeyBind($.GetContextPanel(), "key_escape", function () {
    if (IsOpen()) Close();
  });

  config.TrinityOpenStickerEditor = Open;

  GameEvents.Subscribe("trinity_warmup_ended", function () {
    Close();
    CloseReveal();
  });
  GameEvents.Subscribe("trinity_sticker_opened", function (event) {
    openingLootbox = false;
    ShowReveal(event.sticker, event.duplicate);
    if (IsOpen()) Render();
  });
  CustomNetTables.SubscribeNetTableListener("trinity_stickers", function () {
    localSlots = null;
    if (IsOpen()) Render();
  });
})();
