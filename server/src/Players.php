<?php

declare(strict_types=1);

final class Players
{
    private const DEFAULT_RATING = 1000;

    public static function get(): void
    {
        $steamid = self::parseSteamid($_GET['steamid'] ?? null);
        if ($steamid === null) {
            Http::json(400, ['ok' => false, 'error' => 'invalid_steamid']);
        }

        $statement = Database::pdo()->prepare(
            'SELECT steamid, games, rating FROM players WHERE steamid = :steamid LIMIT 1'
        );
        $statement->execute(['steamid' => $steamid]);
        $row = $statement->fetch();

        $stickers = Stickers::payload($steamid);

        if ($row === false) {
            Http::json(200, [
                'ok' => true,
                'player' => array_merge([
                    'steamid' => $steamid,
                    'games' => 0,
                    'rating' => self::DEFAULT_RATING,
                    'created' => false,
                ], $stickers),
            ]);
        }

        Http::json(200, [
            'ok' => true,
            'player' => array_merge([
                'steamid' => (int) $row['steamid'],
                'games' => (int) $row['games'],
                'rating' => (int) $row['rating'],
                'created' => true,
            ], $stickers),
        ]);
    }

    public static function save(): void
    {
        $body = Http::body();
        $players = $body['players'] ?? null;
        if (!is_array($players) || $players === []) {
            Http::json(400, ['ok' => false, 'error' => 'missing_players']);
        }

        $pdo = Database::pdo();
        $statement = $pdo->prepare(
            'INSERT INTO players (steamid, games, rating)
             VALUES (:steamid, :games, :rating)
             ON DUPLICATE KEY UPDATE
                games = VALUES(games),
                rating = VALUES(rating)'
        );

        $saved = 0;
        foreach ($players as $player) {
            if (!is_array($player)) {
                continue;
            }

            $steamid = self::parseSteamid($player['steamid'] ?? null);
            if ($steamid === null) {
                continue;
            }

            $games = self::parseUnsignedInt($player['games'] ?? 0);
            $rating = self::parseInt($player['rating'] ?? self::DEFAULT_RATING);

            $statement->execute([
                'steamid' => $steamid,
                'games' => $games,
                'rating' => $rating,
            ]);
            $saved++;
        }

        if ($saved === 0) {
            Http::json(400, ['ok' => false, 'error' => 'no_valid_players']);
        }

        Http::json(200, ['ok' => true, 'saved' => $saved]);
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

    private static function parseUnsignedInt(mixed $value): int
    {
        $number = self::parseInt($value);
        return max(0, $number);
    }

    private static function parseInt(mixed $value): int
    {
        if (is_int($value)) {
            return $value;
        }
        if (is_string($value) && preg_match('/^-?\d+$/', $value) === 1) {
            return (int) $value;
        }

        return 0;
    }
}
