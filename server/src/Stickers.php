<?php

declare(strict_types=1);

final class Stickers
{
    public const SLOT_COUNT = 8;
    public const QUALITY_NORMAL = 1;
    public const QUALITY_ELITE = 2;
    public const COPIES_FOR_ELITE = 5;
    public const PRICE_NORMAL = 5;
    public const PRICE_ELITE = 20;
    public const DAILY_WIN_BOXES = 3;

    private const CATALOG = [
        ['key' => 'Gura', 'rarity' => 'common', 'weight_normal' => 100, 'weight_elite' => 10],
        ['key' => 'NeuroHug', 'rarity' => 'common', 'weight_normal' => 100, 'weight_elite' => 10],
        ['key' => 'Watson', 'rarity' => 'common', 'weight_normal' => 100, 'weight_elite' => 10],
        ['key' => 'Anime', 'rarity' => 'common', 'weight_normal' => 100, 'weight_elite' => 10],
        ['key' => 'Neurodance', 'rarity' => 'rare', 'weight_normal' => 30, 'weight_elite' => 3],
        ['key' => 'Choso', 'rarity' => 'common', 'weight_normal' => 100, 'weight_elite' => 10],
        ['key' => 'StickerOne', 'rarity' => 'rare', 'weight_normal' => 30, 'weight_elite' => 3],
        ['key' => 'StickerTwo', 'rarity' => 'rare', 'weight_normal' => 30, 'weight_elite' => 3],
    ];

    public static function payload(int $steamid): array
    {
        self::ensureCatalog();

        return [
            'owned' => self::ownedMap($steamid),
            'wheel' => self::wheelKeys($steamid),
            'lootboxes' => self::playerInt($steamid, 'lootbox_unopened'),
            'currency' => self::playerInt($steamid, 'lootbox_currency'),
            'prices' => [
                'normal' => self::PRICE_NORMAL,
                'elite' => self::PRICE_ELITE,
            ],
            'catalog' => self::catalogPublic(),
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
                'SELECT lootbox_unopened, lootbox_currency
                 FROM players WHERE steamid = :steamid LIMIT 1 FOR UPDATE'
            );
            $locked->execute(['steamid' => $steamid]);
            $row = $locked->fetch();
            if ($row === false) {
                $pdo->rollBack();
                Http::json(500, ['ok' => false, 'error' => 'player_missing']);
            }
            if ((int) $row['lootbox_unopened'] < 1) {
                $pdo->rollBack();
                Http::json(409, ['ok' => false, 'error' => 'no_lootboxes']);
            }

            $reward = self::rollReward($pdo);
            if ($reward === null) {
                $pdo->rollBack();
                Http::json(500, ['ok' => false, 'error' => 'empty_catalog']);
            }

            $applied = self::applyReward($pdo, $steamid, $reward['key'], $reward['quality']);
            $pdo->prepare(
                'UPDATE players
                 SET lootbox_unopened = lootbox_unopened - 1,
                     lootbox_currency = lootbox_currency + 1
                 WHERE steamid = :steamid'
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
            'sticker' => $reward['key'],
            'quality' => $applied['quality'],
            'copies' => $applied['copies'],
            'converted' => $applied['converted'],
            'duplicate' => $applied['duplicate'],
            'player' => array_merge(['steamid' => $steamid], self::payload($steamid)),
        ]);
    }

    public static function buy(): void
    {
        $body = Http::body();
        $steamid = self::parseSteamid($body['steamid'] ?? null);
        $key = self::parseStickerKey($body['sticker'] ?? null);
        $quality = self::parseQuality($body['quality'] ?? null);
        if ($steamid === null || $key === null || $quality === null) {
            Http::json(400, ['ok' => false, 'error' => 'invalid_buy']);
        }

        self::ensureCatalog();
        $ids = self::stickerIds();
        if (!isset($ids[$key])) {
            Http::json(400, ['ok' => false, 'error' => 'unknown_sticker']);
        }

        $cost = $quality === self::QUALITY_ELITE ? self::PRICE_ELITE : self::PRICE_NORMAL;
        $pdo = Database::pdo();
        $pdo->beginTransaction();
        try {
            self::ensurePlayer($steamid);
            $locked = $pdo->prepare(
                'SELECT lootbox_currency FROM players WHERE steamid = :steamid LIMIT 1 FOR UPDATE'
            );
            $locked->execute(['steamid' => $steamid]);
            $row = $locked->fetch();
            if ($row === false) {
                $pdo->rollBack();
                Http::json(500, ['ok' => false, 'error' => 'player_missing']);
            }
            if ((int) $row['lootbox_currency'] < $cost) {
                $pdo->rollBack();
                Http::json(409, ['ok' => false, 'error' => 'insufficient_currency']);
            }

            $current = self::ownedRow($pdo, $steamid, $ids[$key]);
            if ($current !== null && (int) $current['quality'] === self::QUALITY_ELITE) {
                $pdo->rollBack();
                Http::json(409, ['ok' => false, 'error' => 'already_elite']);
            }

            $applied = self::applyReward($pdo, $steamid, $key, $quality);
            $pdo->prepare(
                'UPDATE players SET lootbox_currency = lootbox_currency - :cost WHERE steamid = :steamid'
            )->execute([
                'cost' => $cost,
                'steamid' => $steamid,
            ]);
            $pdo->commit();
        } catch (PDOException) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            Http::json(500, ['ok' => false, 'error' => 'buy_failed']);
        }

        Http::json(200, [
            'ok' => true,
            'sticker' => $key,
            'quality' => $applied['quality'],
            'copies' => $applied['copies'],
            'converted' => $applied['converted'],
            'duplicate' => $applied['duplicate'],
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

        $pdo = Database::pdo();
        self::ensurePlayer($steamid);
        self::applyReward($pdo, $steamid, $key, self::QUALITY_ELITE);

        Http::json(200, [
            'ok' => true,
            'sticker' => $key,
            'quality' => self::QUALITY_ELITE,
            'player' => array_merge(['steamid' => $steamid], self::payload($steamid)),
        ]);
    }

    public static function grantLootbox(): void
    {
        $steamid = self::steamidFromBody();
        self::ensurePlayer($steamid);
        Database::pdo()->prepare(
            'UPDATE players SET lootbox_unopened = lootbox_unopened + 1 WHERE steamid = :steamid'
        )->execute(['steamid' => $steamid]);

        Http::json(200, [
            'ok' => true,
            'player' => array_merge(['steamid' => $steamid], self::payload($steamid)),
        ]);
    }

    public static function grantDaily(): void
    {
        $steamid = self::steamidFromBody();
        $today = (new DateTimeImmutable('now', new DateTimeZone('UTC')))->format('Y-m-d');
        $granted = false;
        $pdo = Database::pdo();
        $pdo->beginTransaction();
        try {
            self::ensurePlayer($steamid);
            $locked = $pdo->prepare(
                'SELECT lootbox_unopened, lootbox_daily_date
                 FROM players WHERE steamid = :steamid LIMIT 1 FOR UPDATE'
            );
            $locked->execute(['steamid' => $steamid]);
            $row = $locked->fetch();
            if ($row === false) {
                $pdo->rollBack();
                Http::json(500, ['ok' => false, 'error' => 'player_missing']);
            }

            if ((string) ($row['lootbox_daily_date'] ?? '') !== $today) {
                $pdo->prepare(
                    'UPDATE players
                     SET lootbox_unopened = lootbox_unopened + 1,
                         lootbox_daily_date = :grant_date
                     WHERE steamid = :steamid'
                )->execute([
                    'grant_date' => $today,
                    'steamid' => $steamid,
                ]);
                $granted = true;
            }
            $pdo->commit();
        } catch (PDOException) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            Http::json(500, ['ok' => false, 'error' => 'daily_grant_failed']);
        }

        Http::json(200, [
            'ok' => true,
            'granted' => $granted,
            'player' => array_merge(['steamid' => $steamid], self::payload($steamid)),
        ]);
    }

    public static function grantWin(): void
    {
        $body = Http::body();
        $steamids = self::parseSteamidList($body['steamids'] ?? $body['steamid'] ?? null);
        if ($steamids === []) {
            Http::json(400, ['ok' => false, 'error' => 'invalid_steamids']);
        }

        $today = (new DateTimeImmutable('now', new DateTimeZone('UTC')))->format('Y-m-d');
        $granted = [];
        $skipped = [];
        $players = [];
        $pdo = Database::pdo();

        foreach ($steamids as $steamid) {
            $pdo->beginTransaction();
            try {
                self::ensurePlayer($steamid);
                $locked = $pdo->prepare(
                    'SELECT lootbox_unopened, lootbox_grants_date, lootbox_grants_today
                     FROM players WHERE steamid = :steamid LIMIT 1 FOR UPDATE'
                );
                $locked->execute(['steamid' => $steamid]);
                $row = $locked->fetch();
                if ($row === false) {
                    $pdo->rollBack();
                    $skipped[] = $steamid;
                    continue;
                }

                $grantsToday = (string) ($row['lootbox_grants_date'] ?? '') === $today
                    ? (int) $row['lootbox_grants_today']
                    : 0;
                if ($grantsToday >= self::DAILY_WIN_BOXES) {
                    $pdo->commit();
                    $skipped[] = $steamid;
                    $players[(string) $steamid] = self::payload($steamid);
                    continue;
                }

                $pdo->prepare(
                    'UPDATE players
                     SET lootbox_unopened = lootbox_unopened + 1,
                         lootbox_grants_date = :grant_date,
                         lootbox_grants_today = :grants_today
                     WHERE steamid = :steamid'
                )->execute([
                    'grant_date' => $today,
                    'grants_today' => $grantsToday + 1,
                    'steamid' => $steamid,
                ]);
                $pdo->commit();
                $granted[] = $steamid;
                $players[(string) $steamid] = self::payload($steamid);
            } catch (PDOException) {
                if ($pdo->inTransaction()) {
                    $pdo->rollBack();
                }
                $skipped[] = $steamid;
            }
        }

        Http::json(200, [
            'ok' => true,
            'granted' => $granted,
            'skipped' => $skipped,
            'players' => $players,
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
            'INSERT INTO stickers (sticker_key, enabled, sort_order, rarity, weight_normal, weight_elite)
             VALUES (:sticker_key, 1, :sort_order, :rarity, :weight_normal, :weight_elite)
             ON DUPLICATE KEY UPDATE
                sort_order = VALUES(sort_order),
                rarity = VALUES(rarity),
                weight_normal = VALUES(weight_normal),
                weight_elite = VALUES(weight_elite)'
        );
        foreach (self::CATALOG as $index => $entry) {
            $insert->execute([
                'sticker_key' => $entry['key'],
                'sort_order' => $index + 1,
                'rarity' => $entry['rarity'],
                'weight_normal' => $entry['weight_normal'],
                'weight_elite' => $entry['weight_elite'],
            ]);
        }
        $ready = true;
    }

    private static function ensurePlayer(int $steamid): void
    {
        Database::pdo()->prepare(
            'INSERT INTO players (steamid, games, rating, first_lootbox_opened)
             VALUES (:steamid, 0, :rating, 1)
             ON DUPLICATE KEY UPDATE steamid = steamid'
        )->execute([
            'steamid' => $steamid,
            'rating' => 1000,
        ]);
    }

    /** @return array{quality: int, copies: int, converted: bool, duplicate: bool} */
    private static function applyReward(PDO $pdo, int $steamid, string $key, int $quality): array
    {
        $ids = self::stickerIds();
        $stickerId = $ids[$key];
        $current = self::ownedRow($pdo, $steamid, $stickerId);

        if ($quality === self::QUALITY_ELITE) {
            if ($current !== null && (int) $current['quality'] === self::QUALITY_ELITE) {
                return [
                    'quality' => self::QUALITY_ELITE,
                    'copies' => 0,
                    'converted' => false,
                    'duplicate' => true,
                ];
            }
            self::upsertOwned($pdo, $steamid, $stickerId, self::QUALITY_ELITE, 0);
            return [
                'quality' => self::QUALITY_ELITE,
                'copies' => 0,
                'converted' => false,
                'duplicate' => false,
            ];
        }

        if ($current === null) {
            self::upsertOwned($pdo, $steamid, $stickerId, self::QUALITY_NORMAL, 1);
            return [
                'quality' => self::QUALITY_NORMAL,
                'copies' => 1,
                'converted' => false,
                'duplicate' => false,
            ];
        }

        if ((int) $current['quality'] === self::QUALITY_ELITE) {
            return [
                'quality' => self::QUALITY_ELITE,
                'copies' => 0,
                'converted' => false,
                'duplicate' => true,
            ];
        }

        $copies = (int) $current['copies'] + 1;
        if ($copies >= self::COPIES_FOR_ELITE) {
            self::upsertOwned($pdo, $steamid, $stickerId, self::QUALITY_ELITE, 0);
            return [
                'quality' => self::QUALITY_ELITE,
                'copies' => 0,
                'converted' => true,
                'duplicate' => false,
            ];
        }

        self::upsertOwned($pdo, $steamid, $stickerId, self::QUALITY_NORMAL, $copies);
        return [
            'quality' => self::QUALITY_NORMAL,
            'copies' => $copies,
            'converted' => false,
            'duplicate' => false,
        ];
    }

    private static function upsertOwned(PDO $pdo, int $steamid, int $stickerId, int $quality, int $copies): void
    {
        $pdo->prepare(
            'INSERT INTO player_stickers (steamid, sticker_id, quality, copies)
             VALUES (:steamid, :sticker_id, :quality, :copies)
             ON DUPLICATE KEY UPDATE
                quality = VALUES(quality),
                copies = VALUES(copies)'
        )->execute([
            'steamid' => $steamid,
            'sticker_id' => $stickerId,
            'quality' => $quality,
            'copies' => $copies,
        ]);
    }

    /** @return array{quality: int, copies: int}|null */
    private static function ownedRow(PDO $pdo, int $steamid, int $stickerId): ?array
    {
        $statement = $pdo->prepare(
            'SELECT quality, copies FROM player_stickers
             WHERE steamid = :steamid AND sticker_id = :sticker_id LIMIT 1'
        );
        $statement->execute([
            'steamid' => $steamid,
            'sticker_id' => $stickerId,
        ]);
        $row = $statement->fetch();
        if ($row === false) {
            return null;
        }

        return [
            'quality' => (int) $row['quality'],
            'copies' => (int) $row['copies'],
        ];
    }

    /** @return array{key: string, quality: int}|null */
    private static function rollReward(PDO $pdo): ?array
    {
        $rows = $pdo->query(
            'SELECT sticker_key, weight_normal, weight_elite FROM stickers WHERE enabled = 1'
        )->fetchAll();
        $pool = [];
        $total = 0;
        foreach ($rows as $row) {
            $normal = max(0, (int) $row['weight_normal']);
            $elite = max(0, (int) $row['weight_elite']);
            if ($normal > 0) {
                $pool[] = ['key' => (string) $row['sticker_key'], 'quality' => self::QUALITY_NORMAL, 'weight' => $normal];
                $total += $normal;
            }
            if ($elite > 0) {
                $pool[] = ['key' => (string) $row['sticker_key'], 'quality' => self::QUALITY_ELITE, 'weight' => $elite];
                $total += $elite;
            }
        }
        if ($total < 1 || $pool === []) {
            return null;
        }

        $roll = random_int(1, $total);
        $cursor = 0;
        foreach ($pool as $item) {
            $cursor += $item['weight'];
            if ($roll <= $cursor) {
                return [
                    'key' => $item['key'],
                    'quality' => $item['quality'],
                ];
            }
        }

        $last = $pool[array_key_last($pool)];
        return [
            'key' => $last['key'],
            'quality' => $last['quality'],
        ];
    }

    /** @return array<string, array{quality: int, copies: int}> */
    private static function ownedMap(int $steamid): array
    {
        $statement = Database::pdo()->prepare(
            'SELECT s.sticker_key, ps.quality, ps.copies
             FROM player_stickers ps
             INNER JOIN stickers s ON s.id = ps.sticker_id
             WHERE ps.steamid = :steamid
             ORDER BY s.sort_order ASC, s.id ASC'
        );
        $statement->execute(['steamid' => $steamid]);

        $owned = [];
        foreach ($statement->fetchAll() as $row) {
            $quality = (int) $row['quality'];
            if ($quality < self::QUALITY_NORMAL) {
                continue;
            }
            $owned[(string) $row['sticker_key']] = [
                'quality' => $quality,
                'copies' => (int) $row['copies'],
            ];
        }

        return $owned;
    }

    /** @return array<string, true> */
    private static function ownedSet(int $steamid): array
    {
        $set = [];
        foreach (self::ownedMap($steamid) as $key => $_info) {
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

    private static function playerInt(int $steamid, string $column): int
    {
        static $allowed = [
            'lootbox_unopened' => true,
            'lootbox_currency' => true,
        ];
        if (!isset($allowed[$column])) {
            return 0;
        }

        $statement = Database::pdo()->prepare(
            "SELECT {$column} FROM players WHERE steamid = :steamid LIMIT 1"
        );
        $statement->execute(['steamid' => $steamid]);
        $row = $statement->fetch();
        if ($row === false) {
            return 0;
        }

        return max(0, (int) $row[$column]);
    }

    /** @return list<array{key: string, rarity: string, weight_normal: int, weight_elite: int}> */
    private static function catalogPublic(): array
    {
        $list = [];
        foreach (self::CATALOG as $entry) {
            $list[] = [
                'key' => $entry['key'],
                'rarity' => $entry['rarity'],
                'weight_normal' => $entry['weight_normal'],
                'weight_elite' => $entry['weight_elite'],
            ];
        }

        return $list;
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
        foreach (self::CATALOG as $entry) {
            if ($entry['key'] === $value) {
                return $value;
            }
        }

        return null;
    }

    private static function parseQuality(mixed $value): ?int
    {
        if ($value === self::QUALITY_NORMAL || $value === '1' || $value === 'normal') {
            return self::QUALITY_NORMAL;
        }
        if ($value === self::QUALITY_ELITE || $value === '2' || $value === 'elite') {
            return self::QUALITY_ELITE;
        }

        return null;
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

    /** @return list<int> */
    private static function parseSteamidList(mixed $value): array
    {
        if (!is_array($value)) {
            $single = self::parseSteamid($value);
            return $single === null ? [] : [$single];
        }

        $list = [];
        $used = [];
        foreach ($value as $item) {
            $steamid = self::parseSteamid($item);
            if ($steamid === null || isset($used[$steamid])) {
                continue;
            }
            $used[$steamid] = true;
            $list[] = $steamid;
        }

        return $list;
    }
}
