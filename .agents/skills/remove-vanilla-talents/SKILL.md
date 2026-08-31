---
name: remove-vanilla-talents
description: Убирать ванильные таланты героя Trinity и ставить ровно 8 заглушек special_bonus_unique_custom_* в слоты AbilityTalentStart. Использовать при новом герое, правке npc_heroes_custom.txt, override_hero, талантах, Ability10–22, SubAbilityNames, SwapAbilities, краше UpgradeName9 или dota_hud_stat_branch.xml.
---

# Убирание ванильных талантов

`override_hero` **мержит** ключи. Незаданный `AbilityN` остаётся ванильным. HUD дерева талантов умеет только 8 панелей. Девятый `special_bonus_*` ищет `UpgradeName9` в `dota_hud_stat_branch.xml` и роняет клиент.

Не копировать слепо `Ability10–17` с других героев Trinity.

## Когда читать

До правок слотов героя, если в задаче есть таланты, новый/кастомный герой, `npc_heroes_custom.txt`, лишние способности ульта или краш `UpgradeName9`.

## Порядок

1. Открыть ванильный блок героя в `C:\Users\1\Desktop\Кастомки\DotaScripts\scripts\npc\npc_heroes.txt`.
2. Выписать:
   - `AbilityTalentStart` → `T` (часто `10`, не всегда)
   - `Ability8` … последний слот с `special_bonus_*`
   - `SubAbilityNames` и скрытые песни/саб-абилки (`Ability7+`)
3. Восемь кастомных заглушек ставить в `Ability{T}` … `Ability{T+7}`.
4. Явно задать `"AbilityTalentStart" "{T}"`.
5. Затереть **каждый** ванильный `special_bonus_*`, даже за пределами `T+7`. Если ваниль кончалась позже Trinity-слотов — эти ключи тоже перезаписать (заглушкой из восьми или не оставлять лишний `special_bonus`).
6. Слоты песен и саб-абилок не занимать талантами. Пустые служебные слоты до `T` — `generic_hidden`, если так в ванили.
7. На герое после оверрайда должно остаться **ровно 8** способностей `special_bonus_*`.
8. Заглушки: `Game/scripts/npc/talents.txt`, имена `special_bonus_unique_custom_<hero>_1..8`, `BaseClass` `special_bonus_undefined`. Локализация «Заглушка» / `Placeholder`.

Не снимать таланты через `RemoveAbility` на спавне. Источник истины — KV слотов.

## Краш

```
FATAL ERROR: Unable to find child 'UpgradeName9' in layout file 'panorama\layout\hud\dota_hud_stat_branch.xml'
```

Искать: больше 8 `special_bonus_*`, талант в слоте песни/саб-абилки, `SwapAbilities` поверх такого слота.

## Пример: Largo

Ваниль: песни в `Ability8–10`, `AbilityTalentStart` `15`, таланты `Ability15–22`.

Нельзя: заглушки в `Ability10–17` — стирается третья песня, ваниль `Ability18–22` остаётся, на герое 13 талантов.

Нужно: песни оставить в `8–10`, заглушки в `15–22`, `AbilityTalentStart` `15`.

Другие `T ≠ 10` в ванили: Morphling `15`, Invoker `17`, Rubick `12`, Kez `12`, Keeper of the Light `11`.

## Файлы

| Что | Куда |
|-----|------|
| Слоты | `Game/scripts/npc/npc_heroes_custom.txt` |
| KV заглушек | `Game/scripts/npc/talents.txt` |
| Тексты | `Game/resource/addon_russian.txt`, `addon_english.txt` |
| Документация героя | раздел героя в `docs/AGENTS.md` |
