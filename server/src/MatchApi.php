<?php

declare(strict_types=1);

final class MatchApi
{
    private const DEFAULT_RATING = 1000;
    private const RATING_STEP = 25;

    public static function matchStart(): void
    {
        $body = Http::body();
        $matchId = self::matchId($body);
        $players = self::steamIds($body['players'] ?? []);
        $cheats = !empty($body['isCheatsMode']);

        $pdo = Database::pdo();
        $statement = $pdo->prepare(
            'INSERT INTO match_sessions (match_id, match_key, map_name, cluster_id, region_id, cheats)
             VALUES (:match_id, :match_key, :map_name, :cluster_id, :region_id, :cheats)
             ON DUPLICATE KEY UPDATE
                match_key = VALUES(match_key),
                map_name = VALUES(map_name),
                cluster_id = VALUES(cluster_id),
                region_id = VALUES(region_id),
                cheats = VALUES(cheats)'
        );
        $statement->execute([
            'match_id' => $matchId,
            'match_key' => self::text($body['matchKey'] ?? '', 64),
            'map_name' => self::text($body['mapName'] ?? '', 64),
            'cluster_id' => self::integer($body['cluster'] ?? 0),
            'region_id' => self::integer($body['region'] ?? 0),
            'cheats' => $cheats ? 1 : 0,
        ]);

        $ratings = self::ratings($players);
        $sum = 0;
        $payload = [];
        foreach ($players as $steamid) {
            $rating = $ratings[$steamid] ?? self::DEFAULT_RATING;
            $sum += $rating;
            $payload[] = [
                'playerId' => (string) $steamid,
                'rating' => $rating,
                'games' => self::games($steamid),
            ];
        }

        Http::json(200, [
            'ok' => true,
            'isStatsMatch' => !$cheats && $players !== [],
            'seasonName' => 'Trinity',
            'averageRating' => $players === [] ? 0 : (int) floor($sum / count($players)),
            'players' => $payload,
        ]);
    }

    public static function matchDetails(): void
    {
        $players = self::steamIds(Http::body());
        $rows = [];
        foreach ($players as $steamid) {
            $rows[] = [
                'playerId' => (string) $steamid,
                'matchCount' => self::games($steamid),
                'favoriteHero' => self::favoriteHero($steamid),
                'places' => self::places($steamid),
                'matches' => self::recentMatches($steamid),
            ];
        }
        Http::json(200, $rows);
    }

    public static function leaderboard(): void
    {
        $statement = Database::pdo()->query(
            'SELECT steamid, rating, games FROM players ORDER BY rating DESC, games DESC LIMIT 20'
        );
        $solo = [];
        foreach ($statement->fetchAll() as $row) {
            $steamid = (int) $row['steamid'];
            $solo[] = [
                'playerId' => (string) $steamid,
                'rating' => (int) $row['rating'],
                'matchCount' => (int) $row['games'],
                'favoriteHero' => self::favoriteHero($steamid),
            ];
        }
        Http::json(200, ['solo' => $solo, 'duo' => []]);
    }

    public static function unrankedStats(): void
    {
        Http::json(200, []);
    }

    public static function endMatch(): void
    {
        $body = Http::body();
        $matchId = self::matchId($body);
        $steamid = self::steamid($body['playerId'] ?? null);
        if ($steamid === null) {
            Http::json(400, ['ok' => false, 'error' => 'invalid_steamid']);
        }

        $pdo = Database::pdo();
        $existing = $pdo->prepare(
            'SELECT rating_change FROM match_results WHERE match_id = :match_id AND steamid = :steamid LIMIT 1'
        );
        $existing->execute(['match_id' => $matchId, 'steamid' => $steamid]);
        $previous = $existing->fetch();
        if ($previous !== false) {
            Http::json(200, [
                'ok' => true,
                'ratingChange' => (int) $previous['rating_change'],
                'rating' => self::ratings([$steamid])[$steamid] ?? self::DEFAULT_RATING,
            ]);
        }

        $session = $pdo->prepare('SELECT cheats FROM match_sessions WHERE match_id = :match_id LIMIT 1');
        $session->execute(['match_id' => $matchId]);
        $sessionRow = $session->fetch();
        $counted = $sessionRow !== false && (int) $sessionRow['cheats'] === 0;
        $win = (int) ($body['place'] ?? 2) === 1;
        $change = 0;
        if ($counted) {
            $change = $win ? self::RATING_STEP : -self::RATING_STEP;
        }

        $current = self::ratings([$steamid])[$steamid] ?? self::DEFAULT_RATING;
        $rating = max(0, $current + $change);

        $pdo->beginTransaction();
        try {
            $insert = $pdo->prepare(
                'INSERT INTO match_results (
                    match_id, steamid, hero_name, team, win, kills, deaths, assists,
                    networth, gpm, xpm, level, items_json, end_time, is_leaver, rating_before, rating_change
                 ) VALUES (
                    :match_id, :steamid, :hero_name, :team, :win, :kills, :deaths, :assists,
                    :networth, :gpm, :xpm, :level, :items_json, :end_time, :is_leaver, :rating_before, :rating_change
                 )'
            );
            $insert->execute([
                'match_id' => $matchId,
                'steamid' => $steamid,
                'hero_name' => self::text($body['heroName'] ?? '', 64),
                'team' => self::integer($body['team'] ?? 0),
                'win' => $win ? 1 : 0,
                'kills' => self::integer($body['kills'] ?? 0),
                'deaths' => self::integer($body['deaths'] ?? 0),
                'assists' => self::integer($body['assists'] ?? 0),
                'networth' => self::integer($body['networth'] ?? 0),
                'gpm' => self::integer($body['gpm'] ?? 0),
                'xpm' => self::integer($body['xpm'] ?? 0),
                'level' => self::integer($body['level'] ?? 0),
                'items_json' => json_encode($body['items'] ?? [], JSON_UNESCAPED_UNICODE),
                'end_time' => self::integer($body['endTime'] ?? 0),
                'is_leaver' => !empty($body['isLeaver']) ? 1 : 0,
                'rating_before' => $current,
                'rating_change' => $change,
            ]);
            $pdo->prepare(
                'INSERT INTO players (steamid, games, rating) VALUES (:steamid, 0, :rating)
                 ON DUPLICATE KEY UPDATE rating = VALUES(rating)'
            )->execute(['steamid' => $steamid, 'rating' => $rating]);
            $pdo->commit();
        } catch (Throwable $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $error;
        }

        Http::json(200, [
            'ok' => true,
            'ratingChange' => $change,
            'rating' => $rating,
        ]);
    }

    public static function leave(): void
    {
        $body = Http::body();
        $steamid = self::steamid($body['playerId'] ?? null);
        if ($steamid === null) {
            Http::json(400, ['ok' => false, 'error' => 'invalid_steamid']);
        }

        Database::pdo()->prepare(
            'INSERT INTO match_leaves (match_id, steamid, leave_time, safe_to_leave, player_name)
             VALUES (:match_id, :steamid, :leave_time, :safe_to_leave, :player_name)'
        )->execute([
            'match_id' => self::matchId($body),
            'steamid' => $steamid,
            'leave_time' => self::integer($body['leaveTime'] ?? 0),
            'safe_to_leave' => !empty($body['isSafeToLeave']) ? 1 : 0,
            'player_name' => self::text($body['playerName'] ?? '', 64),
        ]);

        Http::json(200, ['ok' => true]);
    }

    public static function report(): void
    {
        $body = Http::body();
        $reporter = self::steamid($body['reporter'] ?? null);
        $reported = self::steamid($body['reported1'] ?? null);
        if ($reporter === null || $reported === null) {
            Http::json(400, ['ok' => false, 'error' => 'invalid_steamid']);
        }
        $second = self::steamid($body['reported2'] ?? null) ?? 0;

        Database::pdo()->prepare(
            'INSERT INTO match_reports (match_id, reporter, reported1, reported2, report_type)
             VALUES (:match_id, :reporter, :reported1, :reported2, :report_type)'
        )->execute([
            'match_id' => self::matchId($body),
            'reporter' => $reporter,
            'reported1' => $reported,
            'reported2' => $second,
            'report_type' => self::integer($body['type'] ?? 0),
        ]);

        Http::json(200, ['ok' => true]);
    }

    public static function httpErrors(): void
    {
        $body = Http::body();
        error_log('[trinity-http] ' . json_encode([
            'url' => $body['Url'] ?? '',
            'status' => $body['StatusCode'] ?? 0,
            'matchId' => $body['matchId'] ?? '',
        ], JSON_UNESCAPED_UNICODE));
        Http::json(200, ['ok' => true]);
    }

    private static function matchId(array $body): string
    {
        $id = self::text($body['matchId'] ?? '', 64);
        return $id !== '' ? $id : '0';
    }

    /** @param mixed $value */
    private static function steamid($value): ?int
    {
        if (is_int($value) && $value > 0) {
            return $value;
        }
        if (is_string($value) && ctype_digit($value)) {
            $parsed = (int) $value;
            return $parsed > 0 ? $parsed : null;
        }
        if (is_float($value) && $value > 0) {
            return (int) $value;
        }
        return null;
    }

    /** @param mixed $source
     *  @return list<int>
     */
    private static function steamIds($source): array
    {
        if (!is_array($source)) {
            return [];
        }
        $ids = [];
        foreach ($source as $value) {
            $steamid = self::steamid($value);
            if ($steamid !== null) {
                $ids[$steamid] = $steamid;
            }
        }
        return array_values($ids);
    }

    /** @param list<int> $steamids
     *  @return array<int, int>
     */
    private static function ratings(array $steamids): array
    {
        if ($steamids === []) {
            return [];
        }
        $placeholders = implode(',', array_fill(0, count($steamids), '?'));
        $statement = Database::pdo()->prepare(
            "SELECT steamid, rating FROM players WHERE steamid IN ($placeholders)"
        );
        $statement->execute($steamids);
        $ratings = [];
        foreach ($statement->fetchAll() as $row) {
            $ratings[(int) $row['steamid']] = (int) $row['rating'];
        }
        return $ratings;
    }

    private static function games(int $steamid): int
    {
        $statement = Database::pdo()->prepare('SELECT games FROM players WHERE steamid = :steamid LIMIT 1');
        $statement->execute(['steamid' => $steamid]);
        $row = $statement->fetch();
        return $row === false ? 0 : (int) $row['games'];
    }

    private static function favoriteHero(int $steamid): string
    {
        $statement = Database::pdo()->prepare(
            'SELECT hero_name FROM match_results
             WHERE steamid = :steamid AND hero_name <> ""
             GROUP BY hero_name
             ORDER BY COUNT(*) DESC
             LIMIT 1'
        );
        $statement->execute(['steamid' => $steamid]);
        $row = $statement->fetch();
        return $row === false ? '' : (string) $row['hero_name'];
    }

    /** @return array<string, int> */
    private static function places(int $steamid): array
    {
        $statement = Database::pdo()->prepare(
            'SELECT win, COUNT(*) AS total FROM match_results WHERE steamid = :steamid GROUP BY win'
        );
        $statement->execute(['steamid' => $steamid]);
        $places = ['1' => 0, '2' => 0];
        foreach ($statement->fetchAll() as $row) {
            $place = (int) $row['win'] === 1 ? '1' : '2';
            $places[$place] = (int) $row['total'];
        }
        return $places;
    }

    /** @return list<array<string, mixed>> */
    private static function recentMatches(int $steamid): array
    {
        $statement = Database::pdo()->prepare(
            'SELECT hero_name, win, kills, deaths, rating_change, end_time
             FROM match_results WHERE steamid = :steamid
             ORDER BY id DESC LIMIT 8'
        );
        $statement->execute(['steamid' => $steamid]);
        $matches = [];
        foreach ($statement->fetchAll() as $row) {
            $matches[] = [
                'heroName' => (string) $row['hero_name'],
                'place' => (int) $row['win'] === 1 ? 1 : 2,
                'kills' => (int) $row['kills'],
                'deaths' => (int) $row['deaths'],
                'ratingChange' => (int) $row['rating_change'],
                'endTime' => (int) $row['end_time'],
            ];
        }
        return $matches;
    }

    /** @param mixed $value */
    private static function text($value, int $limit): string
    {
        $text = is_string($value) ? $value : (is_scalar($value) ? (string) $value : '');
        if (strlen($text) > $limit) {
            return substr($text, 0, $limit);
        }
        return $text;
    }

    /** @param mixed $value */
    private static function integer($value): int
    {
        if (is_int($value)) {
            return $value;
        }
        if (is_string($value) && preg_match('/^-?\d+$/', $value) === 1) {
            return (int) $value;
        }
        if (is_float($value)) {
            return (int) $value;
        }
        return 0;
    }
}
