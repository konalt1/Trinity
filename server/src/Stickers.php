<?php

declare(strict_types=1);

final class Stickers
{
    public const SLOT_COUNT = 8;

    private const CATALOG = [
        'Gura',
        'NeuroHug',
        'Watson',
        'Anime',
        'Neurodance',
        'Choso',
        'StickerOne',
        'StickerTwo',
    ];

    public static function payload(int $steamid): array
    {
        self::ensureCatalog();

        return [
            'owned' => self::ownedKeys($steamid),
            'wheel' => self::wheelKeys($steamid),
            'lootbox_pending' => !self::lootboxOpened($steamid),
        ];
    }

    public static function open(): void
    {
        $steamid = self::steamidFromBody();
        self::ensureCatalog();

        $pdo = Database::pdo();
        $pdo->beginTransaction();
        try {
            self::ensurePlayer($steamid);
            $locked = $pdo->prepare(
                'SELECT first_lootbox_opened FROM players WHERE steamid = :steamid LIMIT 1 FOR UPDATE'
            );
            $locked->execute(['steamid' => $steamid]);
            $row = $locked->fetch();
            if ($row === false) {
                $pdo->rollBack();
                Http::json(500, ['ok' => false, 'error' => 'player_missing']);
            }
            if ((int) $row['first_lootbox_opened'] === 1) {
                $pdo->rollBack();
                Http::json(409, ['ok' => false, 'error' => 'already_opened']);
            }

            $sticker = self::randomEnabledSticker($pdo);
            if ($sticker === null) {
                $pdo->rollBack();
                Http::json(500, ['ok' => false, 'error' => 'empty_catalog']);
            }

            $insert = $pdo->prepare(
                'INSERT IGNORE INTO player_stickers (steamid, sticker_id)
                 VALUES (:steamid, :sticker_id)'
            );
            $insert->execute([
                'steamid' => $steamid,
                'sticker_id' => $sticker['id'],
            ]);
            $duplicate = $insert->rowCount() === 0;

            $pdo->prepare(
                'UPDATE players SET first_lootbox_opened = 1 WHERE steamid = :steamid'
            )->execute(['steamid' => $steamid]);
            $pdo->commit();
        } catch (PDOException) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            Http::json(500, ['ok' => false, 'error' => 'open_failed']);
        }

        Http::json(200, [
            'ok' => true,
            'sticker' => $sticker['sticker_key'],
            'duplicate' => $duplicate,
            'player' => array_merge(['steamid' => $steamid], self::payload($steamid)),
        ]);
    }

    public static function saveWheel(): void
    {
        $body = Http::body();
        $steamid = self::parseSteamid($body['steamid'] ?? null);
        if ($steamid === null) {
            Http::json(400, ['ok' => false, 'error' => 'invalid_steamid']);
        }

        $slots = $body['slots'] ?? null;
        if (!is_array($slots)) {
            Http::json(400, ['ok' => false, 'error' => 'invalid_slots']);
        }

        $normalized = self::normalizeSlots($slots);
        if ($normalized === null) {
            Http::json(400, ['ok' => false, 'error' => 'invalid_slots']);
        }

        self::ensureCatalog();
        $owned = self::ownedSet($steamid);
        $used = [];
        foreach ($normalized as $key) {
            if ($key === null) {
                continue;
            }
            if (!isset($owned[$key])) {
                Http::json(400, ['ok' => false, 'error' => 'unowned_sticker', 'sticker' => $key]);
            }
            if (isset($used[$key])) {
                Http::json(400, ['ok' => false, 'error' => 'duplicate_slot', 'sticker' => $key]);
            }
            $used[$key] = true;
        }

        $ids = self::stickerIds();
        $pdo = Database::pdo();
        $pdo->beginTransaction();
        try {
            self::ensurePlayer($steamid);
            $upsert = $pdo->prepare(
                'INSERT INTO player_wheel (steamid, slot, sticker_id)
                 VALUES (:steamid, :slot, :sticker_id)
                 ON DUPLICATE KEY UPDATE sticker_id = VALUES(sticker_id)'
            );
            for ($slot = 0; $slot < self::SLOT_COUNT; $slot++) {
                $key = $normalized[$slot];
                $upsert->execute([
                    'steamid' => $steamid,
                    'slot' => $slot,
                    'sticker_id' => $key === null ? null : $ids[$key],
                ]);
            }
            $pdo->commit();
        } catch (PDOException) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            Http::json(500, ['ok' => false, 'error' => 'wheel_save_failed']);
        }

        Http::json(200, [
            'ok' => true,
            'player' => array_merge(['steamid' => $steamid], self::payload($steamid)),
        ]);
    }

    public static function grant(): void
    {
        $body = Http::body();
        $steamid = self::parseSteamid($body['steamid'] ?? null);
        $key = self::parseStickerKey($body['sticker'] ?? null);
        if ($steamid === null || $key === null) {
            Http::json(400, ['ok' => false, 'error' => 'invalid_grant']);
        }

        self::ensureCatalog();
        $ids = self::stickerIds();
        if (!isset($ids[$key])) {
            Http::json(400, ['ok' => false, 'error' => 'unknown_sticker']);
        }

        self::ensurePlayer($steamid);
        Database::pdo()->prepare(
            'INSERT IGNORE INTO player_stickers (steamid, sticker_id)
             VALUES (:steamid, :sticker_id)'
        )->execute([
            'steamid' => $steamid,
            'sticker_id' => $ids[$key],
        ]);

        Http::json(200, [
            'ok' => true,
            'sticker' => $key,
            'player' => array_merge(['steamid' => $steamid], self::payload($steamid)),
        ]);
    }

    public static function resetLootbox(): void
    {
        $steamid = self::steamidFromBody();
        self::ensurePlayer($steamid);
        Database::pdo()->prepare(
            'UPDATE players SET first_lootbox_opened = 0 WHERE steamid = :steamid'
        )->execute(['steamid' => $steamid]);

        Http::json(200, [
            'ok' => true,
            'player' => array_merge(['steamid' => $steamid], self::payload($steamid)),
        ]);
    }

    private static function steamidFromBody(): int
    {
        $body = Http::body();
        $steamid = self::parseSteamid($body['steamid'] ?? null);
        if ($steamid === null) {
            Http::json(400, ['ok' => false, 'error' => 'invalid_steamid']);
        }

        return $steamid;
    }

    private static function ensureCatalog(): void
    {
        static $ready = false;
        if ($ready) {
            return;
        }

        $insert = Database::pdo()->prepare(
            'INSERT INTO stickers (sticker_key, enabled, sort_order)
             VALUES (:sticker_key, 1, :sort_order)
             ON DUPLICATE KEY UPDATE sort_order = VALUES(sort_order)'
        );
        foreach (self::CATALOG as $index => $key) {
            $insert->execute([
                'sticker_key' => $key,
                'sort_order' => $index + 1,
            ]);
        }
        $ready = true;
    }

    private static function ensurePlayer(int $steamid): void
    {
        Database::pdo()->prepare(
            'INSERT INTO players (steamid, games, rating)
             VALUES (:steamid, 0, :rating)
             ON DUPLICATE KEY UPDATE steamid = steamid'
        )->execute([
            'steamid' => $steamid,
            'rating' => 1000,
        ]);
    }

    private static function lootboxOpened(int $steamid): bool
    {
        $statement = Database::pdo()->prepare(
            'SELECT first_lootbox_opened FROM players WHERE steamid = :steamid LIMIT 1'
        );
        $statement->execute(['steamid' => $steamid]);
        $row = $statement->fetch();
        if ($row === false) {
            return false;
        }

        return (int) $row['first_lootbox_opened'] === 1;
    }

    /** @return list<string> */
    private static function ownedKeys(int $steamid): array
    {
        $statement = Database::pdo()->prepare(
            'SELECT s.sticker_key
             FROM player_stickers ps
             INNER JOIN stickers s ON s.id = ps.sticker_id
             WHERE ps.steamid = :steamid
             ORDER BY s.sort_order ASC, s.id ASC'
        );
        $statement->execute(['steamid' => $steamid]);

        $keys = [];
        foreach ($statement->fetchAll() as $row) {
            $keys[] = (string) $row['sticker_key'];
        }

        return $keys;
    }

    /** @return array<string, true> */
    private static function ownedSet(int $steamid): array
    {
        $set = [];
        foreach (self::ownedKeys($steamid) as $key) {
            $set[$key] = true;
        }

        return $set;
    }

    /** @return list<string|null> */
    private static function wheelKeys(int $steamid): array
    {
        $wheel = array_fill(0, self::SLOT_COUNT, null);
        $statement = Database::pdo()->prepare(
            'SELECT pw.slot, s.sticker_key
             FROM player_wheel pw
             LEFT JOIN stickers s ON s.id = pw.sticker_id
             WHERE pw.steamid = :steamid'
        );
        $statement->execute(['steamid' => $steamid]);
        foreach ($statement->fetchAll() as $row) {
            $slot = (int) $row['slot'];
            if ($slot < 0 || $slot >= self::SLOT_COUNT) {
                continue;
            }
            $key = $row['sticker_key'] ?? null;
            $wheel[$slot] = is_string($key) && $key !== '' ? $key : null;
        }

        return $wheel;
    }

    /** @return array<string, int> */
    private static function stickerIds(): array
    {
        $ids = [];
        foreach (Database::pdo()->query('SELECT id, sticker_key FROM stickers')->fetchAll() as $row) {
            $ids[(string) $row['sticker_key']] = (int) $row['id'];
        }

        return $ids;
    }

    /** @return array{id: int, sticker_key: string}|null */
    private static function randomEnabledSticker(PDO $pdo): ?array
    {
        $row = $pdo->query(
            'SELECT id, sticker_key FROM stickers WHERE enabled = 1 ORDER BY RAND() LIMIT 1'
        )->fetch();
        if ($row === false) {
            return null;
        }

        return [
            'id' => (int) $row['id'],
            'sticker_key' => (string) $row['sticker_key'],
        ];
    }

    /** @param array<mixed> $slots */
    private static function normalizeSlots(array $slots): ?array
    {
        $normalized = array_fill(0, self::SLOT_COUNT, null);
        foreach ($slots as $index => $value) {
            $slot = (int) $index;
            if ($slot < 0 || $slot >= self::SLOT_COUNT) {
                return null;
            }
            if ($value === null || $value === '' || $value === false) {
                $normalized[$slot] = null;
                continue;
            }
            $key = self::parseStickerKey($value);
            if ($key === null) {
                return null;
            }
            $normalized[$slot] = $key;
        }

        return $normalized;
    }

    private static function parseStickerKey(mixed $value): ?string
    {
        if (!is_string($value) || $value === '') {
            return null;
        }
        if (!in_array($value, self::CATALOG, true)) {
            return null;
        }

        return $value;
    }

    private static function parseSteamid(mixed $value): ?int
    {
        if (is_int($value) && $value > 0) {
            return $value;
        }
        if (is_string($value) && ctype_digit($value)) {
            $parsed = (int) $value;
            return $parsed > 0 ? $parsed : null;
        }

        return null;
    }
}
