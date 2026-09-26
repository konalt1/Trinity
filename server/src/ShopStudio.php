<?php

declare(strict_types=1);

final class ShopStudio
{
    private const ITEM_PATTERN = '/^item_[a-z0-9_]+$/';
    private const ID_PATTERN = '/^[a-z][a-z0-9_]{0,31}$/';
    private const GAMEPLAY_SKIP = ['basic' => true];

    /** @var array<string, string>|null */
    private static ?array $loc = null;

    /** @var array<string, array<string, mixed>>|null */
    private static ?array $itemKv = null;

    public static function catalog(): void
    {
        Http::json(200, self::payload(self::load()));
    }

    public static function save(): void
    {
        $body = Http::body();
        $placements = $body['placements'] ?? null;
        if (!is_array($placements)) {
            Http::json(400, ['ok' => false, 'error' => 'placements_required']);
        }

        $data = self::load();
        $knownItems = $data['items'];
        $byCat = [];
        foreach ($data['categories'] as $category) {
            $catId = (string) ($category['id'] ?? '');
            $byCat[$catId] = $category;
        }

        foreach ($placements as $catId => $subs) {
            if (!is_string($catId) || preg_match(self::ID_PATTERN, $catId) !== 1 || !isset($byCat[$catId])) {
                Http::json(400, ['ok' => false, 'error' => 'unknown_category', 'id' => (string) $catId]);
            }
            if (!is_array($subs)) {
                Http::json(400, ['ok' => false, 'error' => 'bad_subcategories', 'id' => $catId]);
            }
        }

        foreach ($data['categories'] as $index => $category) {
            $catId = (string) $category['id'];
            if (!array_key_exists($catId, $placements)) {
                continue;
            }
            $incoming = is_array($placements[$catId]) ? $placements[$catId] : [];
            $subIndex = [];
            foreach ($category['subcategories'] as $sub) {
                $subIndex[(string) $sub['id']] = true;
            }
            foreach ($incoming as $subId => $names) {
                if (!is_string($subId) || !isset($subIndex[$subId])) {
                    Http::json(400, ['ok' => false, 'error' => 'unknown_subcategory', 'id' => $catId . '/' . (string) $subId]);
                }
            }
            foreach ($data['categories'][$index]['subcategories'] as $subPos => $sub) {
                $subId = (string) $sub['id'];
                $raw = $incoming[$subId] ?? [];
                if (!is_array($raw)) {
                    Http::json(400, ['ok' => false, 'error' => 'bad_items', 'id' => $catId . '/' . $subId]);
                }
                $clean = [];
                $seen = [];
                foreach ($raw as $name) {
                    if (!is_string($name) || preg_match(self::ITEM_PATTERN, $name) !== 1) {
                        Http::json(400, ['ok' => false, 'error' => 'bad_item', 'id' => (string) $name]);
                    }
                    if (!isset($knownItems[$name])) {
                        Http::json(400, ['ok' => false, 'error' => 'unknown_item', 'id' => $name]);
                    }
                    if (isset($seen[$name])) {
                        continue;
                    }
                    $seen[$name] = true;
                    $clean[] = $name;
                }
                $data['categories'][$index]['subcategories'][$subPos]['items'] = $clean;
            }
        }

        $itemCats = [];
        foreach ($data['categories'] as $category) {
            $catId = (string) $category['id'];
            foreach ($category['subcategories'] as $sub) {
                foreach ($sub['items'] as $name) {
                    if (!isset($itemCats[$name])) {
                        $itemCats[$name] = [];
                    }
                    if (!in_array($catId, $itemCats[$name], true)) {
                        $itemCats[$name][] = $catId;
                    }
                }
            }
        }
        foreach ($data['items'] as $name => $item) {
            if (!is_array($item)) {
                continue;
            }
            $data['items'][$name]['categories'] = $itemCats[$name] ?? [];
        }

        self::writeFile($data);
        Http::json(200, array_merge(['ok' => true], self::payload($data)));
    }

    /** @param array<string, mixed> $data */
    private static function payload(array $data): array
    {
        $loc = self::locMap();
        $kvIndex = self::itemKv();
        $placeCount = [];
        $placeLabels = [];
        foreach ($data['categories'] as $category) {
            $catId = (string) $category['id'];
            if (isset(self::GAMEPLAY_SKIP[$catId])) {
                continue;
            }
            $catName = self::tokenText($category['token'] ?? '', $loc, $catId);
            foreach ($category['subcategories'] as $sub) {
                $subName = self::tokenText($sub['token'] ?? '', $loc, (string) $sub['id']);
                $label = $catName . ' / ' . $subName;
                foreach ($sub['items'] as $name) {
                    $placeCount[$name] = ($placeCount[$name] ?? 0) + 1;
                    $placeLabels[$name][] = $label;
                }
            }
        }

        $categories = [];
        foreach ($data['categories'] as $category) {
            $catId = (string) $category['id'];
            if (isset(self::GAMEPLAY_SKIP[$catId])) {
                continue;
            }
            $subs = [];
            $itemSet = [];
            foreach ($category['subcategories'] as $sub) {
                $names = [];
                foreach ($sub['items'] as $name) {
                    $names[] = $name;
                    $itemSet[$name] = true;
                }
                $subs[] = [
                    'id' => (string) $sub['id'],
                    'name' => self::tokenText($sub['token'] ?? '', $loc, (string) $sub['id']),
                    'icon' => (string) ($sub['icon'] ?? ''),
                    'color' => (string) ($sub['color'] ?? '#7d8a9e'),
                    'items' => $names,
                ];
            }
            $categories[] = [
                'id' => $catId,
                'name' => self::tokenText($category['token'] ?? '', $loc, $catId),
                'accent' => (string) ($category['accent'] ?? '#7d8a9e'),
                'count' => count($itemSet),
                'subcategories' => $subs,
            ];
        }

        $items = [];
        foreach ($data['items'] as $name => $item) {
            if (!is_string($name) || !is_array($item)) {
                continue;
            }
            $places = $placeCount[$name] ?? 0;
            $kv = $kvIndex[$name] ?? [];
            $items[] = [
                'id' => $name,
                'name' => self::itemName($name, $loc),
                'icon' => self::iconUrl($name),
                'price' => (int) ($item['price'] ?? 0),
                'places' => $places,
                'placeLabels' => $placeLabels[$name] ?? [],
                'unassigned' => $places === 0,
                'over' => $places >= 3,
                'tooltip' => self::itemTooltip($name, $item, $loc, is_array($kv) ? $kv : []),
            ];
        }
        usort($items, static function (array $a, array $b): int {
            if ($a['unassigned'] !== $b['unassigned']) {
                return $a['unassigned'] ? -1 : 1;
            }

            return strcasecmp($a['name'], $b['name']);
        });

        $unassigned = 0;
        $over = 0;
        foreach ($items as $item) {
            if ($item['unassigned']) {
                $unassigned++;
            }
            if ($item['over']) {
                $over++;
            }
        }

        return [
            'ok' => true,
            'categories' => $categories,
            'items' => $items,
            'unassigned' => $unassigned,
            'over' => $over,
        ];
    }

    /** @return array<string, mixed> */
    private static function load(): array
    {
        $raw = @file_get_contents(self::dataPath());
        if (!is_string($raw) || $raw === '') {
            Http::json(500, ['ok' => false, 'error' => 'shop_data_missing']);
        }

        $mainPos = strpos($raw, 'var TRINITY_SHOP_DATA');
        if ($mainPos === false) {
            Http::json(500, ['ok' => false, 'error' => 'shop_data_invalid']);
        }
        $main = self::extractObject($raw, $mainPos);
        if ($main === null) {
            Http::json(500, ['ok' => false, 'error' => 'shop_data_invalid']);
        }

        $data = $main['value'];
        if (!isset($data['categories']) || !is_array($data['categories']) || !isset($data['items']) || !is_array($data['items'])) {
            Http::json(500, ['ok' => false, 'error' => 'shop_data_invalid']);
        }

        $recipesPos = strpos($raw, 'TRINITY_SHOP_DATA.recipes');
        if ($recipesPos !== false) {
            $recipes = self::extractObject($raw, $recipesPos);
            if ($recipes !== null) {
                $data['recipes'] = $recipes['value'];
            }
        }
        if (!isset($data['recipes']) || !is_array($data['recipes'])) {
            $data['recipes'] = [];
        }

        $idsPos = strpos($raw, 'TRINITY_SHOP_DATA.itemIds');
        if ($idsPos !== false) {
            $ids = self::extractObject($raw, $idsPos);
            if ($ids !== null) {
                $data['itemIds'] = $ids['value'];
            }
        }
        if (!isset($data['itemIds']) || !is_array($data['itemIds'])) {
            $data['itemIds'] = [];
        }

        $pushPos = strpos($raw, 'TRINITY_SHOP_DATA.categories.push');
        if ($pushPos !== false) {
            $extra = self::extractObject($raw, $pushPos);
            if ($extra !== null && isset($extra['value']['id'])) {
                $id = (string) $extra['value']['id'];
                $exists = false;
                foreach ($data['categories'] as $category) {
                    if ((string) ($category['id'] ?? '') === $id) {
                        $exists = true;
                        break;
                    }
                }
                if (!$exists) {
                    $data['categories'][] = $extra['value'];
                }
            }
        }

        $assignPos = strpos($raw, 'Object.assign(TRINITY_SHOP_DATA.items');
        if ($assignPos !== false) {
            $extraItems = self::extractObject($raw, $assignPos);
            if ($extraItems !== null) {
                foreach ($extraItems['value'] as $name => $item) {
                    if (is_string($name) && is_array($item)) {
                        $data['items'][$name] = $item;
                    }
                }
            }
        }

        foreach ($data['categories'] as $index => $category) {
            if (!is_array($category) || !isset($category['id'], $category['subcategories']) || !is_array($category['subcategories'])) {
                Http::json(500, ['ok' => false, 'error' => 'shop_data_invalid']);
            }
            foreach ($category['subcategories'] as $subPos => $sub) {
                if (!is_array($sub) || !isset($sub['id'])) {
                    Http::json(500, ['ok' => false, 'error' => 'shop_data_invalid']);
                }
                $names = $sub['items'] ?? [];
                $data['categories'][$index]['subcategories'][$subPos]['items'] = is_array($names) ? array_values($names) : [];
            }
        }

        return $data;
    }

    /** @param array<string, mixed> $data */
    private static function writeFile(array $data): void
    {
        $flags = JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT;
        $main = [
            'tiers' => $data['tiers'] ?? [],
            'attributes' => $data['attributes'] ?? [],
            'categories' => array_values($data['categories']),
            'items' => $data['items'],
            'recipes' => $data['recipes'] ?? [],
            'itemIds' => $data['itemIds'] ?? [],
        ];
        $json = json_encode($main, $flags);
        if (!is_string($json)) {
            Http::json(500, ['ok' => false, 'error' => 'encode_failed']);
        }

        $contents = "// Trinity: данные нового магазина по категориям.\n"
            . "// Состав категорий правится в студии http://127.0.0.1:8080/?view=shop\n"
            . "// tier -1: цена ванильная, ценовой категории нет (угол карточки без цвета).\n"
            . "// Подключается в trinity_shop.xml ПЕРЕД trinity_shop.js.\n"
            . "\"use strict\";\n"
            . "var TRINITY_SHOP_DATA = " . $json . ";\n";

        $path = self::dataPath();
        $dir = dirname($path);
        $tmp = $dir . DIRECTORY_SEPARATOR . '.shop-studio.' . bin2hex(random_bytes(6)) . '.tmp';
        if (file_put_contents($tmp, $contents) === false) {
            Http::json(500, ['ok' => false, 'error' => 'write_failed']);
        }
        if (!@rename($tmp, $path)) {
            $copied = @copy($tmp, $path);
            @unlink($tmp);
            if (!$copied) {
                Http::json(500, ['ok' => false, 'error' => 'write_failed']);
            }
        }
    }

    /** @return array{value: array<string, mixed>, end: int}|null */
    private static function extractObject(string $raw, int $from): ?array
    {
        $start = strpos($raw, '{', $from);
        if ($start === false) {
            return null;
        }
        $n = strlen($raw);
        $depth = 0;
        $inString = false;
        $escape = false;
        for ($i = $start; $i < $n; $i++) {
            $ch = $raw[$i];
            if ($inString) {
                if ($escape) {
                    $escape = false;
                    continue;
                }
                if ($ch === '\\') {
                    $escape = true;
                    continue;
                }
                if ($ch === '"') {
                    $inString = false;
                }
                continue;
            }
            if ($ch === '"') {
                $inString = true;
                continue;
            }
            if ($ch === '{') {
                $depth++;
            } elseif ($ch === '}') {
                $depth--;
                if ($depth === 0) {
                    $slice = substr($raw, $start, $i - $start + 1);
                    $decoded = json_decode($slice, true);
                    if (!is_array($decoded)) {
                        return null;
                    }

                    return ['value' => $decoded, 'end' => $i + 1];
                }
            }
        }

        return null;
    }

    /**
     * @param array<string, mixed> $item
     * @param array<string, string> $loc
     * @param array<string, mixed> $kv
     * @return array<string, mixed>
     */
    private static function itemTooltip(string $id, array $item, array $loc, array $kv): array
    {
        $values = self::abilityValues($kv);
        $bonuses = [];
        $stats = [];
        foreach ($values as $key => $value) {
            $label = self::locField($id, $key, $loc);
            if ($label === '') {
                continue;
            }
            $label = self::expandVars($label, $loc);
            $row = [
                'key' => $key,
                'label' => $label,
                'value' => $value,
            ];
            if (str_starts_with($label, '+') || str_starts_with($label, '%+')) {
                $bonuses[] = $row;
            } else {
                $stats[] = $row;
            }
        }

        $notes = [];
        for ($n = 0; $n < 12; $n++) {
            $note = self::locField($id, 'Note' . $n, $loc);
            if ($note === '') {
                break;
            }
            $notes[] = $note;
        }

        return [
            'name' => self::itemName($id, $loc),
            'description' => self::locField($id, 'Description', $loc),
            'lore' => self::locField($id, 'Lore', $loc),
            'notes' => $notes,
            'bonuses' => $bonuses,
            'stats' => $stats,
            'cooldown' => self::scalar($kv['AbilityCooldown'] ?? ''),
            'mana' => self::scalar($kv['AbilityManaCost'] ?? ''),
            'price' => (int) ($item['price'] ?? 0),
            'values' => $values,
        ];
    }

    /** @param array<string, mixed> $kv @return array<string, string> */
    private static function abilityValues(array $kv): array
    {
        $out = [];
        $abilityValues = is_array($kv['AbilityValues'] ?? null) ? $kv['AbilityValues'] : [];
        foreach ($abilityValues as $key => $node) {
            if (!is_string($key) || str_starts_with($key, 'special_bonus_')) {
                continue;
            }
            $value = self::abilityValueString($node);
            if ($value !== '') {
                $out[$key] = $value;
            }
        }

        return $out;
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

    /** @param array<string, string> $loc */
    private static function locField(string $id, string $suffix, array $loc): string
    {
        $tail = $suffix === '' ? '' : '_' . $suffix;
        foreach (['DOTA_Tooltip_ability_', 'DOTA_Tooltip_Ability_'] as $prefix) {
            $key = $prefix . $id . $tail;
            if (isset($loc[$key]) && $loc[$key] !== '') {
                return $loc[$key];
            }
        }

        return '';
    }

    /** @param array<string, string> $loc */
    private static function expandVars(string $label, array $loc): string
    {
        return preg_replace_callback('/\$([A-Za-z][A-Za-z0-9_]*)/', static function (array $match) use ($loc): string {
            $key = 'dota_ability_variable_' . $match[1];
            if (isset($loc[$key]) && $loc[$key] !== '') {
                return $loc[$key];
            }

            return $match[0];
        }, $label) ?? $label;
    }

    /** @return array<string, string> */
    private static function locMap(): array
    {
        if (self::$loc !== null) {
            return self::$loc;
        }

        $out = self::valveItemLoc();
        foreach (self::addonTokens() as $key => $value) {
            $out[$key] = $value;
        }
        self::$loc = $out;

        return $out;
    }

    /** @return array<string, string> */
    private static function addonTokens(): array
    {
        $path = StickerCatalog::repoRoot() . '/Game/resource/addon_russian.txt';
        $parsed = KeyValues::parse(self::stripBom((string) @file_get_contents($path)));
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

    /** @return array<string, string> */
    private static function valveItemLoc(): array
    {
        $dirVpk = self::dotaDirVpk();
        if ($dirVpk === null) {
            return [];
        }
        $mtime = (int) @filemtime($dirVpk);
        $cache = dirname(__DIR__) . '/cache/dota_item_loc_ru.json';
        if (is_file($cache)) {
            $cached = json_decode((string) file_get_contents($cache), true);
            if (is_array($cached) && (int) ($cached['mtime'] ?? 0) === $mtime && is_array($cached['tokens'] ?? null)) {
                $tokens = [];
                foreach ($cached['tokens'] as $key => $value) {
                    if (is_string($key) && (is_string($value) || is_numeric($value))) {
                        $tokens[$key] = (string) $value;
                    }
                }

                return $tokens;
            }
        }

        $raw = self::vpkRead($dirVpk, 'resource/localization/abilities_russian.txt');
        if ($raw === null) {
            return [];
        }
        $all = self::parseLocTokens($raw);
        $tokens = [];
        foreach ($all as $key => $value) {
            if (str_starts_with($key, 'dota_ability_variable_') || str_contains($key, '_item_')) {
                $tokens[$key] = $value;
            }
        }

        $dir = dirname($cache);
        if (!is_dir($dir)) {
            @mkdir($dir, 0777, true);
        }
        @file_put_contents($cache, json_encode(['mtime' => $mtime, 'tokens' => $tokens], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));

        return $tokens;
    }

    /** @return array<string, string> */
    private static function parseLocTokens(string $raw): array
    {
        $raw = self::stripBom($raw);
        $pos = strpos($raw, '"Tokens"');
        if ($pos === false) {
            $pos = 0;
        }
        $brace = strpos($raw, '{', $pos);
        if ($brace === false) {
            return [];
        }
        $end = KeyValues::matchingBrace($raw, $brace);
        if ($end < 0) {
            $end = strlen($raw);
        }
        $block = substr($raw, $brace + 1, $end - $brace - 1);
        $quoted = [];
        $n = strlen($block);
        $i = 0;
        while ($i < $n) {
            $ch = $block[$i];
            if ($ch === '/' && $i + 1 < $n && $block[$i + 1] === '/') {
                $nl = strpos($block, "\n", $i);
                $i = $nl === false ? $n : $nl + 1;
                continue;
            }
            if ($ch === '"') {
                $i++;
                $buf = '';
                while ($i < $n) {
                    $cur = $block[$i];
                    if ($cur === '\\' && $i + 1 < $n) {
                        $next = $block[$i + 1];
                        $buf .= match ($next) {
                            'n' => "\n",
                            't' => "\t",
                            'r' => "\r",
                            '"' => '"',
                            '\\' => '\\',
                            default => $next,
                        };
                        $i += 2;
                        continue;
                    }
                    if ($cur === '"') {
                        $i++;
                        break;
                    }
                    $buf .= $cur;
                    $i++;
                }
                $quoted[] = $buf;
                continue;
            }
            $i++;
        }

        $out = [];
        for ($k = 0, $c = count($quoted); $k + 1 < $c; $k += 2) {
            $out[$quoted[$k]] = $quoted[$k + 1];
        }

        return $out;
    }

    private static function vpkRead(string $dirVpk, string $want): ?string
    {
        $fh = @fopen($dirVpk, 'rb');
        if ($fh === false) {
            return null;
        }
        $header = fread($fh, 12);
        if (!is_string($header) || strlen($header) < 12) {
            fclose($fh);

            return null;
        }
        $meta = unpack('Vsig/Vver/Vtree', $header);
        if (!is_array($meta) || (int) $meta['sig'] !== 0x55AA1234) {
            fclose($fh);

            return null;
        }
        $version = (int) $meta['ver'];
        if ($version === 2) {
            fread($fh, 16);
        }

        $found = null;
        while (true) {
            $ext = self::readCString($fh);
            if ($ext === '') {
                break;
            }
            while (true) {
                $path = self::readCString($fh);
                if ($path === '') {
                    break;
                }
                while (true) {
                    $name = self::readCString($fh);
                    if ($name === '') {
                        break;
                    }
                    $entry = unpack('Vcrc/vpreload/varchive/Voffset/Vlength/vterm', (string) fread($fh, 18));
                    $preload = (int) ($entry['preload'] ?? 0);
                    if ($preload > 0) {
                        fread($fh, $preload);
                    }
                    $full = ($path === ' ' ? '' : $path . '/') . $name . '.' . $ext;
                    if ($full === $want) {
                        $found = [
                            'archive' => (int) $entry['archive'],
                            'offset' => (int) $entry['offset'],
                            'length' => (int) $entry['length'],
                        ];
                        break 3;
                    }
                }
            }
        }
        fclose($fh);
        if ($found === null || $found['length'] <= 0) {
            return null;
        }

        $archiveIndex = $found['archive'];
        if ($archiveIndex === 0x7fff) {
            $source = $dirVpk;
        } else {
            $source = dirname($dirVpk) . DIRECTORY_SEPARATOR . sprintf('pak01_%03d.vpk', $archiveIndex);
        }
        $data = @file_get_contents($source, false, null, $found['offset'], $found['length']);

        return is_string($data) && $data !== '' ? $data : null;
    }

    /** @param resource $fh */
    private static function readCString($fh): string
    {
        $out = '';
        while (true) {
            $ch = fread($fh, 1);
            if ($ch === false || $ch === '' || $ch === "\0") {
                break;
            }
            $out .= $ch;
        }

        return $out;
    }

    private static function dotaDirVpk(): ?string
    {
        $real = realpath(StickerCatalog::repoRoot() . '/Game');
        if (!is_string($real)) {
            return null;
        }
        $dota = dirname($real, 2) . DIRECTORY_SEPARATOR . 'dota' . DIRECTORY_SEPARATOR . 'pak01_dir.vpk';

        return is_file($dota) ? $dota : null;
    }

    /** @return array<string, array<string, mixed>> */
    private static function itemKv(): array
    {
        if (self::$itemKv !== null) {
            return self::$itemKv;
        }

        $out = [];
        $root = StickerCatalog::repoRoot();
        foreach ([$root . '/Game/scripts/npc/Items.txt', $root . '/Game/scripts/npc/npc_items_custom.txt'] as $path) {
            $parsed = KeyValues::parse(self::stripBom((string) @file_get_contents($path)));
            $abilities = is_array($parsed['DOTAAbilities'] ?? null) ? $parsed['DOTAAbilities'] : $parsed;
            foreach ($abilities as $name => $kv) {
                if (!is_string($name) || preg_match(self::ITEM_PATTERN, $name) !== 1 || !is_array($kv)) {
                    continue;
                }
                if (!isset($out[$name])) {
                    $out[$name] = $kv;
                    continue;
                }
                $out[$name] = array_merge($out[$name], $kv);
            }
        }
        self::$itemKv = $out;

        return $out;
    }

    private static function stripBom(string $raw): string
    {
        if (str_starts_with($raw, "\xEF\xBB\xBF")) {
            return substr($raw, 3);
        }

        return $raw;
    }

    /** @param array<string, string> $loc */
    private static function tokenText(mixed $token, array $loc, string $fallback): string
    {
        $key = ltrim((string) $token, '#');
        if ($key !== '' && isset($loc[$key]) && $loc[$key] !== '') {
            return $loc[$key];
        }

        return $fallback;
    }

    /** @param array<string, string> $loc */
    private static function itemName(string $id, array $loc): string
    {
        $named = self::locField($id, '', $loc);
        if ($named !== '') {
            return $named;
        }

        $short = preg_replace('/^item_/', '', $id) ?? $id;

        return ucwords(str_replace('_', ' ', $short));
    }

    private static function iconUrl(string $id): string
    {
        $short = preg_replace('/^item_/', '', $id) ?? $id;
        $aliases = [
            'ultimate_scepter_2' => 'ultimate_scepter',
            'travel_boots_2' => 'travel_boots_t2',
        ];
        if (isset($aliases[$short])) {
            $short = $aliases[$short];
        }

        return 'https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/items/' . $short . '.png';
    }

    private static function dataPath(): string
    {
        return StickerCatalog::repoRoot() . '/Content/panorama/scripts/custom_game/trinity_shop/shop_data.js';
    }
}
