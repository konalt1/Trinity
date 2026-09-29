# Ценовые тиры сборных предметов — черновик v2

5 тиров только для сборных предметов: **1200 / 2400 / 3600 / 4800 / 6000**. Базовые предметы (включая Blink, Shard, Ghost, Gem, Bottle, Javelin) остаются по ванили. Цена сборного = цена тира, разница уходит в рецепт: рецепт = тир − сумма компонентов.

Цены ванили — из `Game/scripts/npc/Items.txt` (копия KV, сверить с текущим патчем).

## Вне тиров (ванильная цена)

- Дешёвые сборки дешевле 1000: headdress 425, buckler 425, ring_of_basilius 425, magic_wand 460, bracer 505, wraith_band 505, null_talisman 505, soul_ring 805, urn_of_shadows 825, tranquil_boots 900. При тире 1200 они подорожали бы в 1,5–2,8 раза.
- Полуфабрикаты: power_treads 1400, pers 1400, phase_boots 1450, oblivion_staff 1625, soul_booster 3000. Если их затирить, цены поднимаются по цепочке: Perseverance 2400 тянет BFury, Linken, Lotus, Mage Slayer и Phylactery на тир выше; Oblivion Staff тянет Orchid и Bloodthorn; Soul Booster 3600 делает Angel's Demise невозможным (компоненты 7200 > 6000).

## Открытый вопрос

- **Bloodthorn**: Orchid 3600 + Oblivion Staff 1625 + Javelin 900 = 6125 > 6000. Варианты: убрать Oblivion Staff из рецепта (рецепт 1500) или поменять компонент.


## 1200 (5)

| Предмет | Ваниль | Δ | Рецепт | Компоненты |
|---|---|---|---|---|
| orb_of_corrosion | 1050 | +14% | 150 (было 0) | boots_of_elves 450 + orb_of_frost 300 + blight_stone 300 |
| falcon_blade | 1125 | +7% | 325 (было 250) | blades_of_attack 450 + fluffy_hat 250 + sobi_mask 175 |
| pavise | 1350 | -11% | 525 (было 675) | wizard_hat 250 + fluffy_hat 250 + ring_of_protection 175 |
| arcane_boots | 1500 | -20% | 25 (было 325) | boots 500 + ring_of_basilius 425 + wizard_hat 250 |
| ancient_janggo | 1625 | -26% | 100 (было 525) | headdress 425 + belt_of_strength 450 + wind_lace 225 |

## 2400 (30)

| Предмет | Ваниль | Δ | Рецепт | Компоненты |
|---|---|---|---|---|
| vanguard | 1700 | +41% | 700 (было 0) | vitality_booster 1000 + ring_of_health 700 |
| veil_of_discord | 1700 | +41% | 1050 (было 350) | voodoo_mask 650 + robe 450 + fluffy_hat 250 |
| mekansm | 1775 | +35% | 1475 (было 850) | headdress 425 + chainmail 500 |
| essence_distiller | 1775 | +35% | 825 (было 200) | urn_of_shadows 825 + chainmail 500 + wizard_hat 250 |
| mask_of_madness | 1900 | +26% | 500 (было 0) | broadsword 1000 + lifesteal 900 |
| dragon_lance | 1900 | +26% | 950 (было 450) | blade_of_alacrity 1000 + belt_of_strength 450 |
| lesser_crit | 2000 | +20% | 600 (было 200) | claymore 1350 + blades_of_attack 450 |
| yasha | 2100 | +14% | 950 (было 650) | blade_of_alacrity 1000 + boots_of_elves 450 |
| sange | 2100 | +14% | 950 (было 650) | ogre_axe 1000 + belt_of_strength 450 |
| kaya | 2100 | +14% | 950 (было 650) | staff_of_wizardry 1000 + robe 450 |
| glimmer_cape | 2150 | +12% | 1050 (было 800) | shadow_amulet 900 + shawl 450 |
| hand_of_midas | 2200 | +9% | 1950 (было 1750) | gloves 450 |
| force_staff | 2200 | +9% | 1150 (было 950) | staff_of_wizardry 1000 + fluffy_hat 250 |
| vladmir | 2200 | +9% | 200 (было 0) | buckler 425 + ring_of_basilius 425 + lifesteal 900 + blades_of_attack 450 |
| rod_of_atos | 2250 | +7% | 400 (было 250) | staff_of_wizardry 1000 + vitality_booster 1000 |
| holy_locket | 2250 | +7% | 1490 (было 1340) | magic_wand 460 + crown 450 |
| aether_lens | 2275 | +5% | 900 (было 775) | energy_booster 800 + void_stone 700 |
| blade_mail | 2400 | +0% | 450 (было 450) | broadsword 1000 + splintmail 950 |
| diffusal_blade | 2500 | -4% | 950 (было 1050) | blade_of_alacrity 1000 + robe 450 |
| armlet | 2500 | -4% | 525 (было 625) | helm_of_iron_will 975 + gloves 450 + blades_of_attack 450 |
| travel_boots | 2500 | -4% | 1900 (было 2000) | boots 500 |
| specialists_array | 2550 | -6% | 400 (было 550) | blade_of_alacrity 1000 + broadsword 1000 |
| helm_of_the_dominator | 2550 | -6% | 975 (было 1125) | helm_of_iron_will 975 + crown 450 |
| solar_crest | 2575 | -7% | 475 (было 500) | pavise 1200 + chainmail 500 + wind_lace 225 |
| consecrated_wraps | 2600 | -8% | 500 (было 700) | vitality_booster 1000 + shawl 450 + crown 450 |
| cyclone | 2600 | -8% | 475 (было 675) | staff_of_wizardry 1000 + void_stone 700 + wind_lace 225 |
| phylactery | 2600 | -8% | 0 (было 200) | pers 1400 + diadem 1000 |
| spirit_vessel | 2725 | -12% | 575 (было 900) | urn_of_shadows 825 + diadem 1000 |
| grove_bow | 2800 | -14% | 400 (было 800) | staff_of_wizardry 1000 + blade_of_alacrity 1000 |
| basher | 2875 | -17% | 350 (было 825) | mithril_hammer 1600 + belt_of_strength 450 |

## 3600 (17)

| Предмет | Ваниль | Δ | Рецепт | Компоненты |
|---|---|---|---|---|
| echo_sabre | 2700 | +33% | 900 (было 0) | ogre_axe 1000 + broadsword 1000 + void_stone 700 |
| witch_blade | 2775 | +30% | 1125 (было 300) | oblivion_staff 1625 + chainmail 500 + orb_of_venom 350 |
| mage_slayer | 2800 | +29% | 500 (было 0) | pers 1400 + cloak 900 + blades_of_attack 450 + orb_of_venom 350 |
| meteor_hammer | 2850 | +26% | 750 (было 300) | crown 450 + kaya 2400 |
| maelstrom | 2950 | +22% | 650 (было 0) | mithril_hammer 1600 + javelin 900 + gloves 450 |
| aeon_disk | 3000 | +20% | 1800 (было 1200) | vitality_booster 1000 + energy_booster 800 |
| dagon | 3000 | +20% | 1700 (было 1100) | point_booster 1200 + crown 450 + wizard_hat 250 |
| invis_sword | 3250 | +11% | 350 (было 0) | claymore 1350 + blitz_knuckles 1000 + shadow_amulet 900 |
| orchid | 3275 | +10% | 625 (было 300) | oblivion_staff 1625 + claymore 1350 |
| revenants_brooch | 3300 | +9% | 550 (было 650) | lesser_crit 2400 + voodoo_mask 650 |
| heavens_halberd | 3400 | +6% | 650 (было 450) | talisman_of_evasion 1300 + splintmail 950 + ring_of_health 700 |
| desolator | 3500 | +3% | 100 (было 0) | mithril_hammer 1600 + mithril_hammer 1600 + blight_stone 300 |
| pipe | 3725 | -3% | 550 (было 675) | ring_of_tarrasque 1700 + cloak 900 + shawl 450 |
| crimson_guard | 3725 | -3% | 225 (было 1050) | vanguard 2400 + helm_of_iron_will 975 |
| lotus_orb | 3850 | -6% | 0 (было 250) | pers 1400 + platemail 1400 + energy_booster 800 |
| bfury | 3900 | -8% | 100 (было 400) | pers 1400 + broadsword 1000 + broadsword 1000 + quelling_blade 100 |
| black_king_bar | 4050 | -11% | 1000 (было 1450) | mithril_hammer 1600 + ogre_axe 1000 |

## 4800 (25)

| Предмет | Ваниль | Δ | Рецепт | Компоненты |
|---|---|---|---|---|
| moon_shard | 4000 | +20% | 800 (было 0) | hyperstone 2000 + hyperstone 2000 |
| ultimate_scepter | 4200 | +14% | 600 (было 0) | point_booster 1200 + staff_of_wizardry 1000 + ogre_axe 1000 + blade_of_alacrity 1000 |
| sange_and_yasha | 4200 | +14% | 0 (было 0) | sange 2400 + yasha 2400 |
| yasha_and_kaya | 4200 | +14% | 0 (было 0) | kaya 2400 + yasha 2400 |
| kaya_and_sange | 4200 | +14% | 0 (было 0) | sange 2400 + kaya 2400 |
| boots_of_bearing | 4225 | +14% | 1000 (было 0) | tranquil_boots 900 + ancient_janggo 1200 + ring_of_tarrasque 1700 |
| nullifier | 4350 | +10% | 450 (было 0) | relic 3400 + splintmail 950 |
| hurricane_pike | 4450 | +8% | 0 (было 350) | force_staff 2400 + dragon_lance 2400 |
| guardian_greaves | 4450 | +8% | 1200 (было 1175) | arcane_boots 1200 + mekansm 2400 |
| shivas_guard | 4500 | +7% | 1650 (было 1350) | platemail 1400 + splintmail 950 + chasm_stone 800 |
| travel_boots_2 | 4500 | +7% | 400 (было 0) | travel_boots 2400 + recipe_travel_boots 2000 |
| manta | 4650 | +3% | 1400 (было 1550) | yasha 2400 + diadem 1000 |
| gungir | 4650 | +3% | 400 (было 400) | rod_of_atos 2400 + point_booster 1200 + chasm_stone 800 |
| radiance | 4700 | +2% | 100 (было 0) | relic 3400 + talisman_of_evasion 1300 |
| harpoon | 4700 | +2% | 200 (было 1000) | echo_sabre 3600 + diadem 1000 |
| sphere | 4800 | +0% | 600 (было 600) | pers 1400 + ultimate_orb 2800 |
| crellas_crozier | 4800 | +0% | 300 (было 300) | ghost 1500 + soul_booster 3000 |
| octarine_core | 4900 | -2% | 100 (было 200) | soul_booster 3000 + tiara_of_selemene 1700 |
| monkey_king_bar | 5000 | -4% | 700 (было 900) | demon_edge 2200 + blitz_knuckles 1000 + javelin 900 |
| refresher | 5000 | -4% | 1400 (было 1600) | ring_of_tarrasque 1700 + tiara_of_selemene 1700 |
| greater_crit | 5100 | -6% | 200 (было 900) | lesser_crit 2400 + demon_edge 2200 |
| assault | 5125 | -6% | 975 (было 1300) | buckler 425 + hyperstone 2000 + platemail 1400 |
| heart | 5200 | -8% | 300 (было 700) | reaver 2800 + ring_of_tarrasque 1700 |
| sheepstick | 5200 | -8% | 300 (было 700) | mystic_staff 2800 + tiara_of_selemene 1700 |
| ethereal_blade | 5200 | -8% | 500 (было 900) | ultimate_orb 2800 + ghost 1500 |

## 6000 (19)

| Предмет | Ваниль | Δ | Рецепт | Компоненты |
|---|---|---|---|---|
| bloodstone | 4700 | +28% | 600 (было 0) | veil_of_discord 2400 + soul_booster 3000 |
| satanic | 5050 | +19% | 950 (было 0) | reaver 2800 + claymore 1350 + lifesteal 900 |
| butterfly | 5450 | +10% | 550 (было 0) | eagle 2800 + claymore 1350 + talisman_of_evasion 1300 |
| mjollnir | 5500 | +9% | 400 (было 550) | maelstrom 3600 + hyperstone 2000 |
| rapier | 5600 | +7% | 400 (было 0) | relic 3400 + demon_edge 2200 |
| angels_demise | 5600 | +7% | 600 (было 0) | phylactery 2400 + soul_booster 3000 |
| helm_of_the_overlord | 5650 | +6% | 800 (было 300) | helm_of_the_dominator 2400 + ultimate_orb 2800 |
| silver_edge | 5700 | +5% | 200 (было 250) | invis_sword 3600 + demon_edge 2200 |
| ultimate_scepter_2 | 5800 | +3% | 1200 (было 1600) | ultimate_scepter 4800 |
| skadi | 5900 | +2% | 100 (было 0) | ultimate_orb 2800 + ultimate_orb 2800 + orb_of_frost 300 |
| hydras_breath | 5900 | +2% | 850 (было 1100) | specialists_array 2400 + dragon_lance 2400 + orb_of_venom 350 |
| devastator | 5975 | +0% | 0 (было 400) | witch_blade 3600 + grove_bow 2400 |
| disperser | 6100 | -2% | 800 (было 800) | diffusal_blade 2400 + eagle 2800 |
| abyssal_blade | 6250 | -4% | 1200 (было 1275) | basher 2400 + sange 2400 |
| bloodthorn | 6400 | -6% | **-125** (было 600) | orchid 3600 + oblivion_staff 1625 + javelin 900 |
| overwhelming_blink | 6800 | -12% | 950 (было 1750) | blink 2250 + reaver 2800 |
| swift_blink | 6800 | -12% | 950 (было 1750) | blink 2250 + eagle 2800 |
| arcane_blink | 6800 | -12% | 950 (было 1750) | blink 2250 + mystic_staff 2800 |
| wind_waker | 6800 | -12% | 800 (было 1400) | cyclone 2400 + mystic_staff 2800 |
