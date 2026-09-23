<?php

declare(strict_types=1);

final class StickerCatalog
{
    public const KEY_PATTERN = '/^[A-Za-z_][A-Za-z0-9_]{0,31}$/';

    /** @return list<array<string, mixed>> */
    public static function all(): array
    {
        $path = self::path();
        if (!is_file($path)) {
            Http::json(500, ['ok' => false, 'error' => 'missing_sticker_catalog']);
        }

        $raw = file_get_contents($path);
        if (!is_string($raw) || $raw === '') {
            Http::json(500, ['ok' => false, 'error' => 'empty_sticker_catalog']);
        }

        $decoded = json_decode($raw, true);
        $list = is_array($decoded) ? ($decoded['stickers'] ?? null) : null;
        if (!is_array($list) || $list === []) {
            Http::json(500, ['ok' => false, 'error' => 'invalid_sticker_catalog']);
        }

        $stickers = [];
        foreach ($list as $entry) {
            $normalized = self::normalize($entry, false);
            if ($normalized === null) {
                Http::json(500, ['ok' => false, 'error' => 'invalid_sticker_catalog_entry']);
            }
            $stickers[] = $normalized;
        }

        return $stickers;
    }

    /** @return list<array{key: string, rarity: string, weight_normal: int, weight_elite: int}> */
    public static function dropEntries(): array
    {
        $list = [];
        foreach (self::all() as $entry) {
            $list[] = [
                'key' => $entry['key'],
                'rarity' => $entry['rarity'],
                'weight_normal' => $entry['weight_normal'],
                'weight_elite' => $entry['weight_elite'],
            ];
        }

        return $list;
    }

    /** @return array<string, mixed>|null */
    public static function find(string $key): ?array
    {
        foreach (self::all() as $entry) {
            if ($entry['key'] === $key) {
                return $entry;
            }
        }

        return null;
    }

    /** @param list<array<string, mixed>> $stickers */
    public static function write(array $stickers): void
    {
        $payload = ['stickers' => array_values($stickers)];
        $json = json_encode($payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        if (!is_string($json)) {
            Http::json(500, ['ok' => false, 'error' => 'catalog_encode_failed']);
        }

        $path = self::path();
        $dir = dirname($path);
        $tmp = $dir . DIRECTORY_SEPARATOR . '.stickers-catalog.' . bin2hex(random_bytes(6)) . '.tmp';
        if (file_put_contents($tmp, $json . "\n") === false) {
            Http::json(500, ['ok' => false, 'error' => 'catalog_write_failed']);
        }
        if (!rename($tmp, $path)) {
            @unlink($tmp);
            Http::json(500, ['ok' => false, 'error' => 'catalog_replace_failed']);
        }
    }

    /** @param array<mixed> $entry */
    public static function normalize(array $entry, bool $requireNames): ?array
    {
        $key = $entry['key'] ?? null;
        if (!is_string($key) || preg_match(self::KEY_PATTERN, $key) !== 1) {
            return null;
        }

        $nameRu = self::optionalString($entry['name_ru'] ?? null);
        $nameEn = self::optionalString($entry['name_en'] ?? null);
        if ($requireNames && ($nameRu === '' || $nameEn === '')) {
            return null;
        }

        $rarity = self::optionalString($entry['rarity'] ?? 'common');
        if ($rarity !== 'common' && $rarity !== 'rare') {
            $rarity = 'common';
        }

        $defaults = $rarity === 'rare'
            ? ['weight_normal' => 30, 'weight_elite' => 3]
            : ['weight_normal' => 100, 'weight_elite' => 10];

        $maxTime = self::number($entry['max_time'] ?? 1.5, 0.2, 10.0, 1.5);
        $weightNormal = (int) self::number($entry['weight_normal'] ?? $defaults['weight_normal'], 0, 10000, $defaults['weight_normal']);
        $weightElite = (int) self::number($entry['weight_elite'] ?? $defaults['weight_elite'], 0, 10000, $defaults['weight_elite']);
        $sound = self::optionalString($entry['sound'] ?? '');
        $soundFile = self::optionalString($entry['sound_file'] ?? null);
        $soundVolume = (float) self::number($entry['sound_volume'] ?? 1, 0.1, 100, 1);

        $normalized = [
            'key' => $key,
            'name_ru' => $nameRu !== '' ? $nameRu : $key,
            'name_en' => $nameEn !== '' ? $nameEn : $key,
            'max_time' => $maxTime,
            'rarity' => $rarity,
            'weight_normal' => $weightNormal,
            'weight_elite' => $weightElite,
            'sound' => $sound !== '' ? $sound : 'high_five.impact',
        ];
        if ($soundFile !== '') {
            $normalized['sound_file'] = $soundFile;
        }
        if (abs($soundVolume - 1.0) >= 0.0001) {
            $normalized['sound_volume'] = $soundVolume;
        }

        return $normalized;
    }

    public static function path(): string
    {
        return dirname(__DIR__) . DIRECTORY_SEPARATOR . 'stickers-catalog.json';
    }

    public static function repoRoot(): string
    {
        return dirname(__DIR__, 2);
    }

    private static function optionalString(mixed $value): string
    {
        if (!is_string($value)) {
            return '';
        }

        return trim($value);
    }

    private static function number(mixed $value, float $min, float $max, float $fallback): float
    {
        if (is_int($value) || is_float($value) || (is_string($value) && is_numeric($value))) {
            $number = (float) $value;
            if ($number >= $min && $number <= $max) {
                return $number;
            }
        }

        return $fallback;
    }
}
