<?php

declare(strict_types=1);

final class AbilityStudio
{
    private const ABILITY_PATTERN = '/^[A-Za-z][A-Za-z0-9_]{0,63}$/';
    private const HERO_PATTERN = '/^npc_dota_hero_[a-z0-9_]+$/';

    private const HERO_TITLES = [
        'npc_dota_hero_chen' => 'Чен',
        'npc_dota_hero_dawnbreaker' => 'Донбрейкер',
        'npc_dota_hero_doom_bringer' => 'Дум',
        'npc_dota_hero_ember_spirit' => 'Эмбер',
        'npc_dota_hero_furion' => 'Фурион',
        'npc_dota_hero_juggernaut' => 'Джаггернаут',
        'npc_dota_hero_largo' => 'Ларго',
        'npc_dota_hero_lich' => 'Лич',
        'npc_dota_hero_lion' => 'Лион',
        'npc_dota_hero_lycan' => 'Ликан',
        'npc_dota_hero_nevermore' => 'Невермор',
        'npc_dota_hero_ogre_magi' => 'Огр',
        'npc_dota_hero_omniknight' => 'Омник',
        'npc_dota_hero_phantom_assassin' => 'Фантомка',
        'npc_dota_hero_pudge' => 'Пудж',
        'npc_dota_hero_silencer' => 'Сайленсер',
        'npc_dota_hero_techies' => 'Течис',
        'npc_dota_hero_tinker' => 'Тинкер',
        'npc_dota_hero_tusk' => 'Таск',
        'npc_dota_hero_weaver' => 'Вивер',
    ];

    private const VANILLA_SLOTS = [
        'npc_dota_hero_phantom_assassin' => [
            1 => 'phantom_assassin_stifling_dagger',
            2 => 'phantom_assassin_phantom_strike',
            3 => 'phantom_assassin_blur',
            4 => 'phantom_assassin_fan_of_knives',
            6 => 'phantom_assassin_coup_de_grace',
        ],
        'npc_dota_hero_techies' => [
            1 => 'techies_sticky_bomb',
            2 => 'techies_reactive_tazer',
            3 => 'techies_suicide',
            6 => 'techies_land_mines',
        ],
        'npc_dota_hero_juggernaut' => [
            1 => 'juggernaut_blade_fury',
            2 => 'juggernaut_healing_ward',
            3 => 'juggernaut_blade_dance',
            6 => 'juggernaut_omni_slash',
        ],
        'npc_dota_hero_lich' => [
            1 => 'lich_frost_nova',
            2 => 'lich_frost_shield',
            3 => 'lich_sinister_gaze',
            6 => 'lich_chain_frost',
        ],
        'npc_dota_hero_lion' => [
            1 => 'lion_impale',
            2 => 'lion_voodoo',
            3 => 'lion_mana_drain',
            6 => 'lion_finger_of_death',
        ],
        'npc_dota_hero_tinker' => [
            1 => 'tinker_laser',
            2 => 'tinker_march_of_the_machines',
            3 => 'tinker_defense_matrix',
            4 => 'tinker_heat_seeking_missile',
            6 => 'tinker_rearm',
        ],
        'npc_dota_hero_ogre_magi' => [
            1 => 'ogre_magi_fireblast',
            2 => 'ogre_magi_ignite',
            3 => 'ogre_magi_bloodlust',
            4 => 'ogre_magi_unrefined_fireblast',
            6 => 'ogre_magi_multicast',
        ],
        'npc_dota_hero_omniknight' => [
            1 => 'omniknight_purification',
            2 => 'omniknight_martyr',
            3 => 'omniknight_hammer_of_purity',
            6 => 'omniknight_guardian_angel',
        ],
        'npc_dota_hero_doom_bringer' => [
            1 => 'doom_bringer_devour',
            2 => 'doom_bringer_scorched_earth',
            3 => 'doom_bringer_infernal_blade',
            6 => 'doom_bringer_doom',
        ],
        'npc_dota_hero_weaver' => [
            1 => 'weaver_the_swarm',
            2 => 'weaver_shukuchi',
            3 => 'weaver_geminate_attack',
            6 => 'weaver_time_lapse',
        ],
        'npc_dota_hero_silencer' => [
            1 => 'silencer_curse_of_the_silent',
            2 => 'silencer_glaives_of_wisdom',
            3 => 'silencer_last_word',
            6 => 'silencer_global_silence',
        ],
        'npc_dota_hero_chen' => [
            1 => 'chen_penitence',
            2 => 'chen_holy_persuasion',
            3 => 'chen_divine_favor',
            6 => 'chen_hand_of_god',
        ],
        'npc_dota_hero_ember_spirit' => [
            1 => 'ember_spirit_searing_chains',
            2 => 'ember_spirit_sleight_of_fist',
            3 => 'ember_spirit_flame_guard',
            4 => 'ember_spirit_activate_fire_remnant',
            6 => 'ember_spirit_fire_remnant',
        ],
        'npc_dota_hero_pudge' => [
            1 => 'pudge_meat_hook',
            2 => 'pudge_rot',
            3 => 'pudge_flesh_heap',
            6 => 'pudge_dismember',
        ],
        'npc_dota_hero_dawnbreaker' => [
            1 => 'dawnbreaker_fire_wreath',
            2 => 'dawnbreaker_celestial_hammer',
            3 => 'dawnbreaker_luminosity',
            4 => 'dawnbreaker_converge',
            6 => 'dawnbreaker_solar_guardian',
        ],
        'npc_dota_hero_largo' => [
            1 => 'largo_catchy_lick',
            2 => 'largo_frogstomp',
            3 => 'largo_encore',
            6 => 'largo_amphibian_rhapsody',
        ],
        'npc_dota_hero_nevermore' => [
            1 => 'nevermore_shadowraze1',
            2 => 'nevermore_shadowraze2',
            3 => 'nevermore_shadowraze3',
            4 => 'nevermore_necromastery',
            6 => 'nevermore_requiem',
        ],
        'npc_dota_hero_furion' => [
            1 => 'furion_sprout',
            2 => 'furion_teleportation',
            3 => 'furion_force_of_nature',
            6 => 'furion_wrath_of_nature',
        ],
        'npc_dota_hero_tusk' => [
            1 => 'tusk_ice_shards',
            2 => 'tusk_snowball',
            3 => 'tusk_tag_team',
            6 => 'tusk_walrus_punch',
        ],
        'npc_dota_hero_lycan' => [
            1 => 'lycan_summon_wolves',
            2 => 'lycan_howl',
            3 => 'lycan_feral_impulse',
            6 => 'lycan_shapeshift',
        ],
    ];

    private const SLOT_LABELS = [
        1 => 'Q',
        2 => 'W',
        3 => 'E',
        4 => 'D',
        5 => 'F',
        6 => 'R',
    ];

    private const SKIP_VALUE_KEYS = [
        'CalculateSpellDamageTooltip' => true,
        'LinkedSpecialBonus' => true,
        'LinkedSpecialBonusField' => true,
        'LinkedSpecialBonusOperation' => true,
        'affected_by_aoe_increase' => true,
        'affected_by_mind_power' => true,
        'RequiresScepter' => true,
        'RequiresShard' => true,
        'special_bonus_scepter' => true,
        'special_bonus_shard' => true,
    ];

    /** @var array<string, array<string, mixed>>|null */
    private static ?array $abilityIndex = null;

    /** @var array<string, string>|null */
    private static ?array $locRu = null;

    /** @var array<string, string>|null */
    private static ?array $locEn = null;

    public static function catalog(): void
    {
        $index = self::abilityIndex();
        $heroes = [];
        foreach (self::activeHeroes() as $heroId) {
            $abilities = [];
            foreach (self::heroSlots($heroId) as $slot) {
                $abilities[] = self::listAbility($slot['id'], $index, $slot['slot'], $slot['label']);
            }
            $heroes[] = [
                'id' => $heroId,
                'title' => self::HERO_TITLES[$heroId] ?? self::heroTitle($heroId),
                'portrait' => self::heroPortrait($heroId),
                'abilities' => $abilities,
            ];
        }

        Http::json(200, [
            'ok' => true,
            'heroes' => $heroes,
            'groups' => [
                self::groupPayload('shared', 'Shared', 'shared.txt', $index),
                self::groupPayload('units', 'Units', 'units.txt', $index),
            ],
        ]);
    }

    public static function ability(): void
    {
        $id = self::abilityId($_GET['id'] ?? null);
        $index = self::abilityIndex();
        $entry = $index[$id] ?? null;
        $kv = is_array($entry['kv'] ?? null) ? $entry['kv'] : [];
        $custom = $entry !== null;

        Http::json(200, [
            'ok' => true,
            'ability' => [
                'id' => $id,
                'file' => $custom ? (string) $entry['file'] : null,
                'custom' => $custom,
                'texture' => self::textureName($kv, $id),
                'icon' => self::iconUrl(self::textureName($kv, $id), $id),
                'shard' => self::truthy($kv['IsGrantedByShard'] ?? null),
                'scepter' => self::truthy($kv['IsGrantedByScepter'] ?? null),
                'kv' => self::publicKv($kv, $custom),
                'loc' => [
                    'ru' => self::locFields($id, self::locMap('ru')),
                    'en' => self::locFields($id, self::locMap('en')),
                ],
            ],
        ]);
    }

    public static function save(): void
    {
        $body = Http::body();
        $id = self::abilityId($body['id'] ?? null);
        $index = self::abilityIndex();
        $entry = $index[$id] ?? null;

        $hasLoc = array_key_exists('loc', $body) && is_array($body['loc']);
        $hasKv = array_key_exists('kv', $body) && is_array($body['kv']);
        if (!$hasLoc && !$hasKv) {
            Http::json(400, ['ok' => false, 'error' => 'empty_save']);
        }

        if ($hasLoc) {
            $loc = $body['loc'];
            if (array_key_exists('ru', $loc) && is_array($loc['ru'])) {
                self::writeLocalization($id, 'ru', $loc['ru']);
            }
            if (array_key_exists('en', $loc) && is_array($loc['en'])) {
                self::writeLocalization($id, 'en', $loc['en']);
            }
        }

        if ($hasKv) {
            $kvBody = $body['kv'];
            if ($entry !== null) {
                self::writeKv($id, (string) $entry['file'], $kvBody);
                self::$abilityIndex = null;
            } else {
                $hasNumbers = false;
                foreach (['cooldown', 'mana', 'cast_range', 'damage'] as $field) {
                    if (trim((string) ($kvBody[$field] ?? '')) !== '') {
                        $hasNumbers = true;
                        break;
                    }
                }
                if ($hasNumbers || (is_array($kvBody['values'] ?? null) && $kvBody['values'] !== [])) {
                    Http::json(400, [
                        'ok' => false,
                        'error' => 'vanilla_kv_readonly',
                        'hint' => 'Числа ванильной способности правятся только после появления блока в KV Trinity',
                    ]);
                }
            }
        }

        Http::json(200, ['ok' => true, 'id' => $id, 'custom' => $entry !== null]);
    }

    public static function locReport(): void
    {
        $ruMap = self::locMap('ru');
        $enMap = self::locMap('en');
        $index = self::abilityIndex();
        $owners = self::abilityOwners();

        $ids = [];
        foreach (array_merge(self::locAbilityIds($ruMap), self::locAbilityIds($enMap), array_keys($index)) as $id) {
            if (self::includeListedAbility($id) && !str_starts_with($id, 'item_')) {
                $ids[$id] = true;
            }
        }
        ksort($ids);

        $rows = [];
        $ok = 0;
        $emptyBoth = 0;
        $issueCounts = [];

        foreach (array_keys($ids) as $id) {
            $ru = self::locFields($id, $ruMap);
            $en = self::locFields($id, $enMap);
            if ($ru['description'] === '' && $en['description'] === '' && $ru['name'] === '' && $en['name'] === '') {
                $emptyBoth++;
                continue;
            }

            $issues = [];
            $tags = [];
            if ($ru['description'] === '' && $en['description'] !== '') {
                $issues[] = 'нет RU Description';
                $tags['missing'] = true;
            }
            if ($en['description'] === '' && $ru['description'] !== '') {
                $issues[] = 'нет EN Description';
                $tags['missing'] = true;
            }
            if (($ru['name'] === '') !== ($en['name'] === '')) {
                $issues[] = $en['name'] === '' ? 'нет EN имени' : 'нет RU имени';
                $tags['missing'] = true;
            }

            $ruPh = self::locPlaceholders($ru['description']);
            $enPh = self::locPlaceholders($en['description']);
            $onlyRu = array_values(array_diff($ruPh, $enPh));
            $onlyEn = array_values(array_diff($enPh, $ruPh));
            if ($onlyRu !== [] || $onlyEn !== []) {
                $issues[] = 'плейсхолдеры';
                $tags['tokens'] = true;
            }

            $ruPar = self::locParagraphs($ru['description']);
            $enPar = self::locParagraphs($en['description']);
            if ($ru['description'] !== '' && $en['description'] !== '' && $ruPar !== $enPar) {
                $issues[] = 'абзацы ' . $ruPar . '/' . $enPar;
                $tags['paragraphs'] = true;
            }

            if (($ru['shard'] === '') !== ($en['shard'] === '')) {
                $issues[] = $en['shard'] === '' ? 'нет EN Shard' : 'нет RU Shard';
                $tags['missing'] = true;
            }
            if (($ru['scepter'] === '') !== ($en['scepter'] === '')) {
                $issues[] = $en['scepter'] === '' ? 'нет EN Scepter' : 'нет RU Scepter';
                $tags['missing'] = true;
            }

            $ruParams = array_keys($ru['params']);
            $enParams = array_keys($en['params']);
            sort($ruParams);
            sort($enParams);
            $paramOnlyRu = array_values(array_diff($ruParams, $enParams));
            $paramOnlyEn = array_values(array_diff($enParams, $ruParams));
            if ($paramOnlyRu !== [] || $paramOnlyEn !== []) {
                $issues[] = 'подписи параметров';
                $tags['params'] = true;
            }

            if ($issues === []) {
                $ok++;
                continue;
            }

            foreach ($issues as $issue) {
                $key = preg_replace('/^абзацы \d+\/\d+$/', 'абзацы', $issue) ?? $issue;
                $issueCounts[$key] = ($issueCounts[$key] ?? 0) + 1;
            }

            $owner = $owners[$id] ?? [
                'type' => 'group',
                'id' => 'shared',
                'title' => 'Другое',
                'label' => '',
                'icon' => self::iconUrl($id, $id),
            ];
            $rows[] = [
                'id' => $id,
                'owner_type' => $owner['type'],
                'owner_id' => $owner['id'],
                'owner_title' => $owner['title'],
                'label' => $owner['label'],
                'icon' => $owner['icon'],
                'ru_name' => $ru['name'],
                'en_name' => $en['name'],
                'issues' => $issues,
                'tags' => array_keys($tags),
                'placeholders_ru_only' => $onlyRu,
                'placeholders_en_only' => $onlyEn,
                'params_ru_only' => $paramOnlyRu,
                'params_en_only' => $paramOnlyEn,
                'en_preview' => self::locPreview($en['description'] !== '' ? $en['description'] : $ru['description']),
            ];
        }

        arsort($issueCounts);

        Http::json(200, [
            'ok' => true,
            'checked' => $ok + count($rows),
            'matched' => $ok,
            'mismatched' => count($rows),
            'empty_both' => $emptyBoth,
            'issue_counts' => $issueCounts,
            'rows' => $rows,
        ]);
    }

    public static function icon(): void
    {
        $name = (string) ($_GET['name'] ?? '');
        if ($name === '' || str_contains($name, '..') || preg_match('/^[A-Za-z0-9_\/.\-]+$/', $name) !== 1) {
            Http::json(400, ['ok' => false, 'error' => 'invalid_icon']);
        }

        $path = self::iconPath($name);
        if ($path === null) {
            Http::json(404, ['ok' => false, 'error' => 'icon_not_found']);
        }

        Http::file($path);
    }

    /**
     * @param array<string, array<string, mixed>> $index
     * @return array<string, mixed>
     */
    private static function groupPayload(string $id, string $title, string $file, array $index): array
    {
        $abilities = [];
        foreach ($index as $abilityId => $entry) {
            if (($entry['file'] ?? '') !== $file) {
                continue;
            }
            if (!self::includeListedAbility($abilityId)) {
                continue;
            }
            $abilities[] = self::listAbility($abilityId, $index, 0, '');
        }

        return [
            'id' => $id,
            'title' => $title,
            'abilities' => $abilities,
        ];
    }

    /**
     * @param array<string, array<string, mixed>> $index
     * @return array<string, mixed>
     */
    private static function listAbility(string $id, array $index, int $slot, string $label): array
    {
        $entry = $index[$id] ?? null;
        $kv = is_array($entry['kv'] ?? null) ? $entry['kv'] : [];
        $ru = self::locMap('ru');
        $name = self::locLookup($id, '', $ru);
        if ($name === '') {
            $name = self::locLookup($id, '', self::locMap('en'));
        }
        if ($name === '') {
            $name = $id;
        }

        return [
            'id' => $id,
            'slot' => $slot,
            'label' => $label,
            'name' => $name,
            'texture' => self::textureName($kv, $id),
            'icon' => self::iconUrl(self::textureName($kv, $id), $id),
            'custom' => $entry !== null,
            'shard' => self::truthy($kv['IsGrantedByShard'] ?? null),
            'scepter' => self::truthy($kv['IsGrantedByScepter'] ?? null),
        ];
    }

    /** @return list<string> */
    private static function activeHeroes(): array
    {
        $path = self::npcPath('Activelist.txt');
        $parsed = KeyValues::parse(self::read($path));
        $list = [];
        $whitelist = is_array($parsed['whitelist'] ?? null) ? $parsed['whitelist'] : $parsed;
        foreach ($whitelist as $hero => $flag) {
            if (!is_string($hero) || preg_match(self::HERO_PATTERN, $hero) !== 1) {
                continue;
            }
            if ((string) $flag !== '1') {
                continue;
            }
            $list[$hero] = true;
        }

        $heroes = array_keys($list);
        usort($heroes, static function (string $a, string $b): int {
            $left = self::HERO_TITLES[$a] ?? $a;
            $right = self::HERO_TITLES[$b] ?? $b;
            return strcasecmp($left, $right);
        });

        return $heroes;
    }

    /**
     * @return list<array{id: string, slot: int, label: string}>
     */
    private static function heroSlots(string $heroId): array
    {
        $slots = self::VANILLA_SLOTS[$heroId] ?? [];
        $custom = self::customHeroBlock($heroId);
        for ($i = 1; $i <= 14; $i++) {
            $key = 'Ability' . $i;
            if (isset($custom[$key]) && is_string($custom[$key]) && $custom[$key] !== '') {
                $slots[$i] = $custom[$key];
            }
        }

        $out = [];
        ksort($slots);
        foreach ($slots as $slot => $abilityId) {
            if (!is_string($abilityId) || $abilityId === '' || !self::includeListedAbility($abilityId)) {
                continue;
            }
            $out[] = [
                'id' => $abilityId,
                'slot' => (int) $slot,
                'label' => self::SLOT_LABELS[(int) $slot] ?? ('+' . $slot),
            ];
        }

        return $out;
    }

    /** @return array<string, mixed> */
    private static function customHeroBlock(string $heroId): array
    {
        $parsed = KeyValues::parse(self::read(self::npcPath('npc_heroes_custom.txt')));
        $heroes = is_array($parsed['DOTAHeroes'] ?? null) ? $parsed['DOTAHeroes'] : $parsed;
        $block = $heroes[$heroId] ?? null;

        return is_array($block) ? $block : [];
    }

    /** @return array<string, array<string, mixed>> */
    private static function abilityIndex(): array
    {
        if (self::$abilityIndex !== null) {
            return self::$abilityIndex;
        }

        $index = [];
        $dir = self::repoRoot() . '/Game/scripts/npc/abilities';
        foreach (self::abilityFiles() as $file) {
            $path = $dir . DIRECTORY_SEPARATOR . $file;
            if (!is_file($path)) {
                continue;
            }
            $parsed = KeyValues::parse(self::read($path));
            $abilities = is_array($parsed['DOTAAbilities'] ?? null) ? $parsed['DOTAAbilities'] : $parsed;
            foreach ($abilities as $abilityId => $kv) {
                if (!is_string($abilityId) || preg_match(self::ABILITY_PATTERN, $abilityId) !== 1) {
                    continue;
                }
                if (!is_array($kv)) {
                    continue;
                }
                $index[$abilityId] = [
                    'file' => $file,
                    'kv' => $kv,
                ];
            }
        }

        self::$abilityIndex = $index;
        return $index;
    }

    /** @return list<string> */
    private static function abilityFiles(): array
    {
        $indexPath = self::repoRoot() . '/Game/scripts/npc/abilities/_index.txt';
        $raw = self::read($indexPath);
        $files = [];
        if (preg_match_all('/#base\s+"([^"]+)"/', $raw, $matches) === false) {
            return $files;
        }
        foreach ($matches[1] as $file) {
            if (is_string($file) && $file !== '' && !str_contains($file, '..')) {
                $files[] = $file;
            }
        }

        return $files;
    }

    /**
     * @param array<string, mixed> $kv
     * @return array<string, mixed>
     */
    private static function publicKv(array $kv, bool $editable): array
    {
        $values = [];
        $abilityValues = is_array($kv['AbilityValues'] ?? null) ? $kv['AbilityValues'] : [];
        foreach ($abilityValues as $key => $node) {
            if (!is_string($key) || isset(self::SKIP_VALUE_KEYS[$key]) || str_starts_with($key, 'special_bonus_')) {
                continue;
            }
            $values[] = [
                'key' => $key,
                'value' => self::abilityValueString($node),
            ];
        }

        return [
            'editable' => $editable,
            'cooldown' => self::scalar($kv['AbilityCooldown'] ?? ''),
            'mana' => self::scalar($kv['AbilityManaCost'] ?? ''),
            'cast_range' => self::scalar($kv['AbilityCastRange'] ?? ''),
            'damage' => self::scalar($kv['AbilityDamage'] ?? ''),
            'values' => $values,
        ];
    }

    /**
     * @param array<string, string> $map
     * @return array<string, mixed>
     */
    private static function locFields(string $id, array $map): array
    {
        $params = [];
        $prefix = 'DOTA_Tooltip_ability_' . $id . '_';
        $prefixAlt = 'DOTA_Tooltip_Ability_' . $id . '_';
        foreach ($map as $key => $value) {
            $field = null;
            if (str_starts_with($key, $prefix)) {
                $field = substr($key, strlen($prefix));
            } elseif (str_starts_with($key, $prefixAlt)) {
                $field = substr($key, strlen($prefixAlt));
            }
            if ($field === null || $field === '' || in_array($field, ['Description', 'shard_description', 'scepter_description', 'Lore', 'Note', 'SummaryDescription'], true)) {
                continue;
            }
            if (str_starts_with($field, 'modifier') || str_contains($field, 'Description')) {
                continue;
            }
            $params[$field] = self::cleanLocValue($value);
        }

        return [
            'name' => self::locLookup($id, '', $map),
            'description' => self::locLookup($id, 'Description', $map),
            'shard' => self::locLookup($id, 'shard_description', $map),
            'scepter' => self::locLookup($id, 'scepter_description', $map),
            'params' => $params,
        ];
    }

    /** @param array<string, string> $map */
    private static function locLookup(string $id, string $suffix, array $map): string
    {
        $tails = $suffix === '' ? [''] : ['_' . $suffix];
        if ($suffix === 'shard_description') {
            $tails[] = '_Shard_Description';
        }
        if ($suffix === 'scepter_description') {
            $tails[] = '_Scepter_Description';
        }
        foreach (['DOTA_Tooltip_ability_', 'DOTA_Tooltip_Ability_'] as $prefix) {
            foreach ($tails as $tail) {
                $key = $prefix . $id . $tail;
                if (isset($map[$key])) {
                    return self::cleanLocValue($map[$key]);
                }
            }
        }

        return '';
    }

    /** @return array<string, string> */
    private static function locMap(string $lang): array
    {
        if ($lang === 'ru') {
            if (self::$locRu === null) {
                self::$locRu = self::parseLoc(self::repoRoot() . '/Game/resource/addon_russian.txt');
            }
            return self::$locRu;
        }
        if (self::$locEn === null) {
            self::$locEn = self::parseLoc(self::repoRoot() . '/Game/resource/addon_english.txt');
        }
        return self::$locEn;
    }

    /** @return array<string, string> */
    private static function parseLoc(string $path): array
    {
        $parsed = KeyValues::parse(self::read($path));
        $lang = is_array($parsed['lang'] ?? null) ? $parsed['lang'] : $parsed;
        $tokens = is_array($lang['Tokens'] ?? null) ? $lang['Tokens'] : $lang;
        $out = [];
        foreach ($tokens as $key => $value) {
            if (is_string($key) && (is_string($value) || is_numeric($value))) {
                $out[$key] = (string) $value;
            }
        }

        return $out;
    }

    /** @param array<string, mixed> $fields */
    private static function writeLocalization(string $id, string $lang, array $fields): void
    {
        $path = $lang === 'ru'
            ? self::repoRoot() . '/Game/resource/addon_russian.txt'
            : self::repoRoot() . '/Game/resource/addon_english.txt';
        $map = self::parseLoc($path);
        $raw = self::read($path);
        $original = $raw;

        $updates = [
            '' => (string) ($fields['name'] ?? ''),
            '_Description' => (string) ($fields['description'] ?? ''),
            '_shard_description' => (string) ($fields['shard'] ?? ''),
            '_scepter_description' => (string) ($fields['scepter'] ?? ''),
        ];
        $params = is_array($fields['params'] ?? null) ? $fields['params'] : [];
        foreach ($params as $key => $value) {
            if (!is_string($key) || preg_match(self::ABILITY_PATTERN, $key) !== 1) {
                continue;
            }
            $updates['_' . $key] = (string) $value;
        }

        foreach ($updates as $suffix => $value) {
            $lookup = $suffix === '' ? '' : ltrim($suffix, '_');
            if (self::cleanLocValue(self::locLookup($id, $lookup, $map)) === self::cleanLocValue($value)) {
                continue;
            }
            $raw = self::upsertLocKey($raw, $id, $suffix, $value);
        }

        if ($raw !== $original) {
            self::write($path, $raw);
        }
        if ($lang === 'ru') {
            self::$locRu = null;
        } else {
            self::$locEn = null;
        }
    }

    private static function upsertLocKey(string $raw, string $id, string $suffix, string $value): string
    {
        $candidates = [
            'DOTA_Tooltip_ability_' . $id . $suffix,
            'DOTA_Tooltip_Ability_' . $id . $suffix,
        ];
        foreach ($candidates as $key) {
            $replaced = self::replaceLocKey($raw, $key, $value);
            if ($replaced !== null) {
                return $replaced;
            }
        }

        if (trim($value) === '') {
            return $raw;
        }

        $insertKey = 'DOTA_Tooltip_ability_' . $id . $suffix;
        $line = "\t\t\"" . $insertKey . "\"\t\t\t\t\t\"" . self::escapeLocValue($value) . "\"";
        $anchor = self::lastAbilityLocOffset($raw, $id);
        if ($anchor !== null) {
            return substr($raw, 0, $anchor) . "\n" . $line . substr($raw, $anchor);
        }

        if (preg_match('/\n\t\}\s*\n\}\s*$/', $raw, $match, PREG_OFFSET_CAPTURE) === 1) {
            $at = (int) $match[0][1];
            return substr($raw, 0, $at) . "\n" . $line . substr($raw, $at);
        }

        Http::json(500, ['ok' => false, 'error' => 'loc_structure']);
    }

    private static function replaceLocKey(string $raw, string $key, string $value): ?string
    {
        $pattern = '/^([ \t]*"' . preg_quote($key, '/') . '"[ \t]+")((?:\\\\.|[^"\\\\])*)(")/m';
        $count = 0;
        $updated = preg_replace(
            $pattern,
            '${1}' . self::pregQuoteReplacement(self::escapeLocValue($value)) . '${3}',
            $raw,
            1,
            $count
        );
        if (!is_string($updated) || $count !== 1) {
            return null;
        }

        return $updated;
    }

    private static function lastAbilityLocOffset(string $raw, string $id): ?int
    {
        $pattern = '/^[ \t]*"DOTA_Tooltip_[Aa]bility_' . preg_quote($id, '/') . '[^"]*"[ \t]+"(?:\\\\.|[^"\\\\])*"/m';
        if (preg_match_all($pattern, $raw, $matches, PREG_OFFSET_CAPTURE) < 1) {
            return null;
        }
        $last = $matches[0][count($matches[0]) - 1];

        return (int) $last[1] + strlen($last[0]);
    }

    /** @param array<string, mixed> $kvBody */
    private static function writeKv(string $id, string $file, array $kvBody): void
    {
        $path = self::repoRoot() . '/Game/scripts/npc/abilities/' . $file;
        $raw = self::read($path);
        $span = self::abilitySpan($raw, $id);
        if ($span === null) {
            Http::json(500, ['ok' => false, 'error' => 'ability_block_missing', 'id' => $id]);
        }
        [$start, $end] = $span;
        $block = substr($raw, $start, $end - $start + 1);

        foreach ([
            'AbilityCooldown' => 'cooldown',
            'AbilityManaCost' => 'mana',
            'AbilityCastRange' => 'cast_range',
            'AbilityDamage' => 'damage',
        ] as $kvKey => $bodyKey) {
            if (!array_key_exists($bodyKey, $kvBody)) {
                continue;
            }
            $block = self::upsertTopField($block, $kvKey, trim((string) $kvBody[$bodyKey]));
        }

        $values = is_array($kvBody['values'] ?? null) ? $kvBody['values'] : [];
        foreach ($values as $key => $value) {
            if (is_array($value) && isset($value['key'])) {
                $key = $value['key'];
                $value = $value['value'] ?? '';
            }
            if (!is_string($key) || preg_match(self::ABILITY_PATTERN, $key) !== 1) {
                continue;
            }
            $block = self::upsertAbilityValue($block, $key, trim((string) $value));
        }

        $updated = substr($raw, 0, $start) . $block . substr($raw, $end + 1);
        if ($updated !== $raw) {
            self::write($path, $updated);
        }
    }

    /** @return array{0: int, 1: int}|null */
    private static function abilitySpan(string $raw, string $id): ?array
    {
        if (preg_match('/"' . preg_quote($id, '/') . '"\s*\{/', $raw, $match, PREG_OFFSET_CAPTURE) !== 1) {
            return null;
        }
        $open = (int) $match[0][1] + strlen($match[0][0]) - 1;
        $close = KeyValues::matchingBrace($raw, $open);
        if ($close < 0) {
            return null;
        }

        return [$open, $close];
    }

    private static function upsertTopField(string $block, string $key, string $value): string
    {
        if ($value === '') {
            return $block;
        }
        $replaced = self::replaceQuotedKey($block, $key, $value);
        if ($replaced !== null) {
            return $replaced;
        }
        $line = "\n        \"" . $key . "\"               \"" . self::escapeKv($value) . "\"";
        $valuesPos = strpos($block, '"AbilityValues"');
        if ($valuesPos !== false) {
            return substr($block, 0, $valuesPos) . ltrim($line) . "\n\n        " . substr($block, $valuesPos);
        }
        $close = strrpos($block, '}');
        if ($close === false) {
            return $block;
        }

        return substr($block, 0, $close) . $line . "\n    " . substr($block, $close);
    }

    private static function upsertAbilityValue(string $block, string $key, string $value): string
    {
        $valuesPos = strpos($block, '"AbilityValues"');
        if ($valuesPos === false) {
            return $block;
        }
        $openRel = strpos($block, '{', $valuesPos);
        if ($openRel === false) {
            return $block;
        }
        $close = KeyValues::matchingBrace($block, $openRel);
        if ($close < 0) {
            return $block;
        }
        $inner = substr($block, $openRel, $close - $openRel + 1);
            $patternNested = '/("' . preg_quote($key, '/') . '"\s*\{(?:(?!\})[\s\S])*?"value"\s*")((?:\\\\.|[^"\\\\])*)(")/';
        $count = 0;
        $updatedInner = preg_replace(
            $patternNested,
            '${1}' . self::pregQuoteReplacement(self::escapeKv($value)) . '${3}',
            $inner,
            1,
            $count
        );
        if (is_string($updatedInner) && $count === 1) {
            return substr($block, 0, $openRel) . $updatedInner . substr($block, $close + 1);
        }
        $replaced = self::replaceQuotedKey($inner, $key, $value);
        if ($replaced !== null) {
            return substr($block, 0, $openRel) . $replaced . substr($block, $close + 1);
        }

        return $block;
    }

    private static function replaceQuotedKey(string $block, string $key, string $value): ?string
    {
        $pattern = '/("' . preg_quote($key, '/') . '"\s*")((?:\\\\.|[^"\\\\])*)(")/';
        $count = 0;
        $updated = preg_replace(
            $pattern,
            '${1}' . self::pregQuoteReplacement(self::escapeKv($value)) . '${3}',
            $block,
            1,
            $count
        );
        if (!is_string($updated) || $count !== 1) {
            return null;
        }

        return $updated;
    }

    private static function includeListedAbility(string $id): bool
    {
        if ($id === 'generic_hidden' || $id === 'empty_ability') {
            return false;
        }
        if (str_starts_with($id, 'special_bonus_')) {
            return false;
        }
        if (str_starts_with($id, 'modifier_')) {
            return false;
        }

        return preg_match(self::ABILITY_PATTERN, $id) === 1;
    }

    /**
     * @param array<string, string> $map
     * @return list<string>
     */
    private static function locAbilityIds(array $map): array
    {
        $ids = [];
        foreach (array_keys($map) as $key) {
            if (preg_match('/^DOTA_Tooltip_[Aa]bility_([A-Za-z][A-Za-z0-9_]+)_Description$/', $key, $match) !== 1) {
                continue;
            }
            $ids[] = $match[1];
        }

        return $ids;
    }

    /**
     * @return array<string, array{type: string, id: string, title: string, label: string, icon: string}>
     */
    private static function abilityOwners(): array
    {
        $index = self::abilityIndex();
        $owners = [];
        foreach (self::activeHeroes() as $heroId) {
            $title = self::HERO_TITLES[$heroId] ?? self::heroTitle($heroId);
            foreach (self::heroSlots($heroId) as $slot) {
                $listed = self::listAbility($slot['id'], $index, $slot['slot'], $slot['label']);
                $owners[$slot['id']] = [
                    'type' => 'hero',
                    'id' => $heroId,
                    'title' => $title,
                    'label' => $slot['label'],
                    'icon' => $listed['icon'],
                ];
            }
        }
        foreach ([
            ['shared', 'Shared', 'shared.txt'],
            ['units', 'Units', 'units.txt'],
        ] as [$groupId, $title, $file]) {
            foreach ($index as $abilityId => $entry) {
                if (($entry['file'] ?? '') !== $file || isset($owners[$abilityId])) {
                    continue;
                }
                if (!self::includeListedAbility($abilityId)) {
                    continue;
                }
                $listed = self::listAbility($abilityId, $index, 0, '');
                $owners[$abilityId] = [
                    'type' => 'group',
                    'id' => $groupId,
                    'title' => $title,
                    'label' => '',
                    'icon' => $listed['icon'],
                ];
            }
        }

        return $owners;
    }

    /** @return list<string> */
    private static function locPlaceholders(string $text): array
    {
        preg_match_all('/%([A-Za-z][A-Za-z0-9_]*)%/', $text, $matches);
        $keys = array_values(array_unique($matches[1]));
        sort($keys);

        return $keys;
    }

    private static function locParagraphs(string $text): int
    {
        $text = trim($text);
        if ($text === '') {
            return 0;
        }
        $parts = preg_split("/\n+/", $text) ?: [];

        return count(array_filter($parts, static fn (string $part): bool => trim($part) !== ''));
    }

    private static function locPreview(string $text): string
    {
        $flat = preg_replace('/\s+/', ' ', $text) ?? $text;
        if (strlen($flat) <= 160) {
            return $flat;
        }
        $cut = substr($flat, 0, 160);

        return preg_replace('/[\x80-\xBF]*$/', '', $cut) ?? $cut;
    }

    private static function textureName(array $kv, string $id): string
    {
        $texture = self::scalar($kv['AbilityTextureName'] ?? '');
        return $texture !== '' ? $texture : $id;
    }

    private static function iconUrl(string $texture, string $id): string
    {
        if (self::iconPath($texture) !== null) {
            return '/v1/abilities/icon?name=' . rawurlencode($texture);
        }
        if ($texture !== $id && self::iconPath($id) !== null) {
            return '/v1/abilities/icon?name=' . rawurlencode($id);
        }

        $cdnName = str_replace('\\', '/', $texture);
        $cdnName = basename($cdnName);

        return 'https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/abilities/' . rawurlencode($cdnName) . '.png';
    }

    private static function iconPath(string $name): ?string
    {
        $root = self::repoRoot() . '/Game/resource/flash3/images/spellicons';
        $candidates = [
            $name . '.png',
            basename(str_replace('\\', '/', $name)) . '.png',
        ];
        foreach ($candidates as $relative) {
            if (str_contains($relative, '..')) {
                continue;
            }
            $path = $root . '/' . $relative;
            if (is_file($path)) {
                return $path;
            }
        }

        return null;
    }

    private static function heroPortrait(string $heroId): string
    {
        $short = preg_replace('/^npc_dota_hero_/', '', $heroId) ?? $heroId;
        return 'https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/heroes/' . $short . '.png';
    }

    private static function heroTitle(string $heroId): string
    {
        $short = preg_replace('/^npc_dota_hero_/', '', $heroId) ?? $heroId;
        $short = str_replace('_', ' ', $short);
        return $short;
    }

    private static function abilityValueString(mixed $node): string
    {
        if (is_string($node) || is_int($node) || is_float($node)) {
            return (string) $node;
        }
        if (is_array($node) && array_key_exists('value', $node)) {
            return self::scalar($node['value']);
        }

        return '';
    }

    private static function scalar(mixed $value): string
    {
        if (is_string($value) || is_int($value) || is_float($value)) {
            return (string) $value;
        }

        return '';
    }

    private static function truthy(mixed $value): bool
    {
        return (string) $value === '1';
    }

    private static function cleanLocValue(string $value): string
    {
        $value = preg_replace('/\r\n|\r/', "\n", $value) ?? $value;
        $value = preg_replace('/[ \t]+\n/', "\n", $value) ?? $value;
        $value = preg_replace('/\n[ \t]+/', "\n", $value) ?? $value;
        $value = preg_replace('/\n+/', "\n", $value) ?? $value;
        return trim($value);
    }

    private static function escapeLocValue(string $value): string
    {
        $value = str_replace(["\r\n", "\r"], "\n", $value);
        $value = str_replace(['\\', '"'], ['\\\\', '\\"'], $value);
        $lines = [];
        foreach (explode("\n", $value) as $line) {
            $line = trim($line);
            if ($line !== '') {
                $lines[] = $line;
            }
        }
        if ($lines === []) {
            return '';
        }
        $out = $lines[0];
        for ($i = 1, $n = count($lines); $i < $n; $i++) {
            if (!str_ends_with($out, ' ')) {
                $out .= ' ';
            }
            $out .= "\n\t\t" . $lines[$i];
        }

        return $out;
    }

    private static function escapeKv(string $value): string
    {
        return str_replace(['\\', '"'], ['\\\\', '\\"'], $value);
    }

    private static function pregQuoteReplacement(string $value): string
    {
        return str_replace(['\\', '$'], ['\\\\', '\\$'], $value);
    }

    private static function abilityId(mixed $value): string
    {
        if (!is_string($value) || preg_match(self::ABILITY_PATTERN, $value) !== 1) {
            Http::json(400, ['ok' => false, 'error' => 'invalid_ability']);
        }

        return $value;
    }

    private static function npcPath(string $file): string
    {
        return self::repoRoot() . '/Game/scripts/npc/' . $file;
    }

    private static function repoRoot(): string
    {
        return StickerCatalog::repoRoot();
    }

    private static function read(string $path): string
    {
        $raw = @file_get_contents($path);
        if (!is_string($raw)) {
            Http::json(500, ['ok' => false, 'error' => 'read_failed', 'file' => $path]);
        }
        if (str_starts_with($raw, "\xFF\xFE") || str_starts_with($raw, "\xFE\xFF")) {
            $converted = @mb_convert_encoding($raw, 'UTF-8', 'UTF-16');
            if (is_string($converted) && $converted !== '') {
                return $converted;
            }
        }

        return $raw;
    }

    private static function write(string $path, string $contents): void
    {
        $dir = dirname($path);
        $tmp = $dir . DIRECTORY_SEPARATOR . '.ability-studio.' . bin2hex(random_bytes(6)) . '.tmp';
        if (file_put_contents($tmp, $contents) === false) {
            Http::json(500, ['ok' => false, 'error' => 'write_failed', 'file' => $path]);
        }
        if (!@rename($tmp, $path)) {
            $copied = @copy($tmp, $path);
            @unlink($tmp);
            if (!$copied) {
                Http::json(500, ['ok' => false, 'error' => 'write_failed', 'file' => $path]);
            }
        }
    }
}
