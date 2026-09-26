<?php

declare(strict_types=1);

final class Analytics
{
    private const HERO_PATTERN = '/^npc_dota_hero_[a-z0-9_]+$/';
    private const MATCH_PATTERN = '/^[A-Za-z0-9._-]{1,64}$/';
    private const SKILL_PATTERN = '/^[A-Za-z0-9_.:-]{1,64}$/';
    private const MAX_HEROES = 16;
    private const MAX_SKILLS = 48;
    private const MAX_MINUTE = 180;

    public static function saveSnapshots(): void
    {
        $body = Http::body();
        $matchId = self::parseMatchId($body['match_id'] ?? null);
        if ($matchId === null) {
            Http::json(400, ['ok' => false, 'error' => 'invalid_match_id']);
        }

        $minute = self::parseUnsignedInt($body['minute'] ?? null);
        if ($minute < 1 || $minute > self::MAX_MINUTE) {
            Http::json(400, ['ok' => false, 'error' => 'invalid_minute']);
        }

        $gameTime = self::parseUnsignedInt($body['game_time'] ?? ($minute * 60));
        $isFinal = self::parseBool($body['is_final'] ?? false);
        $heroes = $body['heroes'] ?? null;
        if (!is_array($heroes) || $heroes === []) {
            Http::json(400, ['ok' => false, 'error' => 'missing_heroes']);
        }

        $pdo = Database::pdo();
        $pdo->beginTransaction();
        try {
            $bossKills = array_key_exists('boss_kills', $body)
                ? self::parseUnsignedInt($body['boss_kills'])
                : null;
            $matchStatement = $pdo->prepare(
                'INSERT INTO analytics_matches (match_id, started_at, last_game_time, winner_team, boss_kills)
                 VALUES (:match_id, CURRENT_TIMESTAMP, :game_time, :winner_team, :boss_kills)
                 ON DUPLICATE KEY UPDATE
                    last_game_time = GREATEST(last_game_time, VALUES(last_game_time)),
                    ended_at = IF(:is_final = 1, CURRENT_TIMESTAMP, ended_at),
                    winner_team = IF(VALUES(winner_team) IN (2, 3), VALUES(winner_team), winner_team),
                    boss_kills = IF(:has_boss_kills = 1, VALUES(boss_kills), boss_kills)'
            );
            $matchStatement->execute([
                'match_id' => $matchId,
                'game_time' => $gameTime,
                'winner_team' => self::parseWinner($body['winner_team'] ?? 0),
                'boss_kills' => $bossKills,
                'has_boss_kills' => $bossKills === null ? 0 : 1,
                'is_final' => $isFinal ? 1 : 0,
            ]);

            $snapshotStatement = $pdo->prepare(
                'INSERT INTO analytics_snapshots (
                    match_id, minute, game_time, is_final, hero, player_id, steamid, team,
                    networth, xp, hero_kills, lane_creeps, jungle_creeps, hero_damage, skill_damage
                 ) VALUES (
                    :match_id, :minute, :game_time, :is_final, :hero, :player_id, :steamid, :team,
                    :networth, :xp, :hero_kills, :lane_creeps, :jungle_creeps, :hero_damage, :skill_damage
                 )
                 ON DUPLICATE KEY UPDATE
                    game_time = VALUES(game_time),
                    is_final = VALUES(is_final),
                    hero = VALUES(hero),
                    steamid = VALUES(steamid),
                    team = VALUES(team),
                    networth = VALUES(networth),
                    xp = IF(:has_xp = 1, VALUES(xp), xp),
                    hero_kills = IF(:has_hero_kills = 1, VALUES(hero_kills), hero_kills),
                    lane_creeps = VALUES(lane_creeps),
                    jungle_creeps = VALUES(jungle_creeps),
                    hero_damage = VALUES(hero_damage),
                    skill_damage = VALUES(skill_damage)'
            );

            $saved = 0;
            $index = 0;
            foreach ($heroes as $heroRow) {
                if ($index >= self::MAX_HEROES) {
                    break;
                }
                $index++;
                if (!is_array($heroRow)) {
                    continue;
                }

                $hero = self::parseHero($heroRow['hero'] ?? null);
                if ($hero === null) {
                    continue;
                }

                $snapshotStatement->execute([
                    'match_id' => $matchId,
                    'minute' => $minute,
                    'game_time' => $gameTime,
                    'is_final' => $isFinal ? 1 : 0,
                    'hero' => $hero,
                    'player_id' => self::clampInt($heroRow['player_id'] ?? 0, 0, 63),
                    'steamid' => self::parseUnsignedInt($heroRow['steamid'] ?? 0),
                    'team' => self::clampInt($heroRow['team'] ?? 0, 0, 15),
                    'networth' => self::parseUnsignedInt($heroRow['networth'] ?? 0),
                    'xp' => array_key_exists('xp', $heroRow) ? self::parseUnsignedInt($heroRow['xp']) : null,
                    'has_xp' => array_key_exists('xp', $heroRow) ? 1 : 0,
                    'hero_kills' => array_key_exists('hero_kills', $heroRow)
                        ? self::parseUnsignedInt($heroRow['hero_kills'])
                        : null,
                    'has_hero_kills' => array_key_exists('hero_kills', $heroRow) ? 1 : 0,
                    'lane_creeps' => self::parseUnsignedInt($heroRow['lane_creeps'] ?? 0),
                    'jungle_creeps' => self::parseUnsignedInt($heroRow['jungle_creeps'] ?? 0),
                    'hero_damage' => self::parseUnsignedInt($heroRow['hero_damage'] ?? 0),
                    'skill_damage' => json_encode(
                        self::parseSkillDamage($heroRow['skill_damage'] ?? []),
                        JSON_UNESCAPED_UNICODE
                    ),
                ]);
                $saved++;
            }

            if ($saved === 0) {
                $pdo->rollBack();
                Http::json(400, ['ok' => false, 'error' => 'no_valid_heroes']);
            }

            $pdo->commit();
        } catch (PDOException) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            Http::json(500, ['ok' => false, 'error' => 'save_failed']);
        }

        Http::json(200, ['ok' => true, 'saved' => $saved, 'match_id' => $matchId, 'minute' => $minute]);
    }

    public static function overview(): void
    {
        $pdo = Database::pdo();
        $bounds = $pdo->query(
            "SELECT
                UTC_TIMESTAMP() AS now_at,
                DATE_FORMAT(UTC_TIMESTAMP() - INTERVAL 7 DAY, '%Y-%m-%d %H:%i:%s') AS week_from,
                DATE_FORMAT(DATE_FORMAT(UTC_TIMESTAMP(), '%Y-%m-01'), '%Y-%m-%d %H:%i:%s') AS month_from"
        )->fetch();

        Http::json(200, [
            'ok' => true,
            'timezone' => 'UTC',
            'week' => self::periodStats($pdo, 'UTC_TIMESTAMP() - INTERVAL 7 DAY', (string) ($bounds['week_from'] ?? ''), (string) ($bounds['now_at'] ?? '')),
            'month' => self::periodStats($pdo, "CONCAT(DATE_FORMAT(UTC_TIMESTAMP(), '%Y-%m-01'), ' 00:00:00')", (string) ($bounds['month_from'] ?? ''), (string) ($bounds['now_at'] ?? '')),
            'all' => self::lifetimeStats($pdo),
        ]);
    }

    public static function heroes(): void
    {
        $stats = self::heroStatsMap();
        $heroes = [];
        $seen = [];
        foreach (self::roster() as $hero) {
            $seen[$hero] = true;
            $heroes[] = self::heroListRow($hero, $stats[$hero] ?? null);
        }
        foreach ($stats as $hero => $row) {
            if (isset($seen[$hero])) {
                continue;
            }
            $heroes[] = self::heroListRow($hero, $row);
        }

        Http::json(200, [
            'ok' => true,
            'total_matches' => self::totalMatches(),
            'heroes' => $heroes,
        ]);
    }

    public static function hero(): void
    {
        $hero = self::parseHero($_GET['hero'] ?? null);
        if ($hero === null) {
            Http::json(400, ['ok' => false, 'error' => 'invalid_hero']);
        }

        $pdo = Database::pdo();
        $rowsStatement = $pdo->prepare(
            'SELECT match_id, minute, game_time, networth, lane_creeps, jungle_creeps, hero_damage, skill_damage
             FROM analytics_snapshots
             WHERE hero = :hero AND is_final = 0
             ORDER BY minute ASC, match_id ASC'
        );
        $rowsStatement->execute(['hero' => $hero]);
        $rows = $rowsStatement->fetchAll();

        $matchesStatement = $pdo->prepare(
            'SELECT s.match_id,
                    MIN(m.started_at) AS started_at,
                    MAX(s.game_time) AS duration,
                    MAX(s.minute) AS minutes,
                    MAX(s.team) AS team,
                    MAX(m.winner_team) AS winner_team,
                    SUBSTRING_INDEX(GROUP_CONCAT(s.networth ORDER BY s.minute DESC), ",", 1) AS networth,
                    SUBSTRING_INDEX(GROUP_CONCAT(s.hero_damage ORDER BY s.minute DESC), ",", 1) AS hero_damage,
                    SUBSTRING_INDEX(GROUP_CONCAT(s.lane_creeps ORDER BY s.minute DESC), ",", 1) AS lane_creeps,
                    SUBSTRING_INDEX(GROUP_CONCAT(s.jungle_creeps ORDER BY s.minute DESC), ",", 1) AS jungle_creeps
             FROM analytics_snapshots s
             INNER JOIN analytics_matches m ON m.match_id = s.match_id
             WHERE s.hero = :hero
             GROUP BY s.match_id
             ORDER BY started_at DESC'
        );
        $matchesStatement->execute(['hero' => $hero]);
        $stats = self::heroStatsMap()[$hero] ?? self::emptyHeroStats();

        Http::json(200, [
            'ok' => true,
            'hero' => $hero,
            'matches_count' => $stats['matches'],
            'wins' => $stats['wins'],
            'pick_rate' => $stats['pick_rate'],
            'win_rate' => $stats['win_rate'],
            'average' => self::averageSeries($rows),
            'matches' => self::matchSummaries($matchesStatement->fetchAll()),
        ]);
    }

    public static function players(): void
    {
        $statement = Database::pdo()->query(
            'SELECT p.steamid,
                    COUNT(*) AS matches,
                    SUM(CASE WHEN p.winner_team IN (2, 3) THEN 1 ELSE 0 END) AS decided,
                    SUM(CASE WHEN p.winner_team IN (2, 3) AND p.team = p.winner_team THEN 1 ELSE 0 END) AS wins,
                    MAX(p.started_at) AS last_match_at
             FROM (
                 SELECT s.match_id,
                        s.steamid,
                        MIN(s.team) AS team,
                        MAX(m.winner_team) AS winner_team,
                        MIN(m.started_at) AS started_at
                 FROM analytics_snapshots s
                 INNER JOIN analytics_matches m ON m.match_id = s.match_id
                 WHERE s.steamid > 0
                 GROUP BY s.match_id, s.steamid
             ) p
             GROUP BY p.steamid
             ORDER BY last_match_at DESC, matches DESC, p.steamid ASC'
        );

        $players = [];
        foreach ($statement->fetchAll() as $row) {
            $matches = (int) $row['matches'];
            $decided = (int) $row['decided'];
            $wins = (int) $row['wins'];
            $players[] = [
                'steamid' => (string) $row['steamid'],
                'matches' => $matches,
                'wins' => $wins,
                'decided' => $decided,
                'win_rate' => $decided > 0 ? self::roundStat($wins / $decided * 100) : null,
                'last_match_at' => $row['last_match_at'] !== null ? (string) $row['last_match_at'] : null,
            ];
        }

        Http::json(200, [
            'ok' => true,
            'players' => $players,
        ]);
    }

    public static function player(): void
    {
        $steamid = self::parseSteamId($_GET['steamid'] ?? null);
        if ($steamid === null) {
            Http::json(400, ['ok' => false, 'error' => 'invalid_steamid']);
        }

        $statement = Database::pdo()->prepare(
            'SELECT s.match_id,
                    MIN(m.started_at) AS started_at,
                    MAX(s.game_time) AS duration,
                    MAX(s.minute) AS minutes,
                    MIN(s.team) AS team,
                    MAX(m.winner_team) AS winner_team,
                    SUBSTRING_INDEX(GROUP_CONCAT(s.hero ORDER BY s.minute DESC), ",", 1) AS hero,
                    SUBSTRING_INDEX(GROUP_CONCAT(s.networth ORDER BY s.minute DESC), ",", 1) AS networth,
                    SUBSTRING_INDEX(GROUP_CONCAT(s.hero_damage ORDER BY s.minute DESC), ",", 1) AS hero_damage
             FROM analytics_snapshots s
             INNER JOIN analytics_matches m ON m.match_id = s.match_id
             WHERE s.steamid = :steamid
             GROUP BY s.match_id
             ORDER BY started_at DESC'
        );
        $statement->execute(['steamid' => $steamid]);
        $rows = $statement->fetchAll();
        if ($rows === []) {
            Http::json(404, ['ok' => false, 'error' => 'player_not_found']);
        }

        $matches = self::playerMatchSummaries($rows);
        $wins = 0;
        $decided = 0;
        foreach ($matches as $match) {
            if ($match['won'] === true) {
                $wins++;
                $decided++;
            } elseif ($match['won'] === false) {
                $decided++;
            }
        }

        Http::json(200, [
            'ok' => true,
            'steamid' => $steamid,
            'matches_count' => count($matches),
            'wins' => $wins,
            'decided' => $decided,
            'win_rate' => $decided > 0 ? self::roundStat($wins / $decided * 100) : null,
            'matches' => $matches,
        ]);
    }

    public static function match(): void
    {
        $matchId = self::parseMatchId($_GET['id'] ?? null);
        if ($matchId === null) {
            Http::json(400, ['ok' => false, 'error' => 'invalid_match_id']);
        }

        $pdo = Database::pdo();
        $matchStatement = $pdo->prepare(
            'SELECT match_id, started_at, ended_at, last_game_time
             FROM analytics_matches
             WHERE match_id = :match_id
             LIMIT 1'
        );
        $matchStatement->execute(['match_id' => $matchId]);
        $match = $matchStatement->fetch();
        if ($match === false) {
            Http::json(404, ['ok' => false, 'error' => 'match_not_found']);
        }

        $rowsStatement = $pdo->prepare(
            'SELECT minute, game_time, is_final, hero, player_id, steamid, team,
                    networth, lane_creeps, jungle_creeps, hero_damage, skill_damage
             FROM analytics_snapshots
             WHERE match_id = :match_id
             ORDER BY player_id ASC, minute ASC'
        );
        $rowsStatement->execute(['match_id' => $matchId]);

        Http::json(200, [
            'ok' => true,
            'match' => [
                'match_id' => (string) $match['match_id'],
                'started_at' => (string) $match['started_at'],
                'ended_at' => $match['ended_at'] !== null ? (string) $match['ended_at'] : null,
                'duration' => (int) $match['last_game_time'],
            ],
            'heroes' => self::matchHeroSeries($rowsStatement->fetchAll()),
        ]);
    }

    /** @param list<array<string, mixed>> $rows */
    private static function averageSeries(array $rows): array
    {
        $buckets = [];
        foreach ($rows as $row) {
            $minute = (int) $row['minute'];
            if (!isset($buckets[$minute])) {
                $buckets[$minute] = [
                    'count' => 0,
                    'networth' => 0.0,
                    'lane_creeps' => 0.0,
                    'jungle_creeps' => 0.0,
                    'hero_damage' => 0.0,
                    'skills' => [],
                ];
            }

            $bucket =& $buckets[$minute];
            $bucket['count']++;
            $bucket['networth'] += (int) $row['networth'];
            $bucket['lane_creeps'] += (int) $row['lane_creeps'];
            $bucket['jungle_creeps'] += (int) $row['jungle_creeps'];
            $bucket['hero_damage'] += (int) $row['hero_damage'];
            foreach (self::decodeSkillDamage($row['skill_damage'] ?? null) as $skill => $value) {
                $bucket['skills'][$skill] = ($bucket['skills'][$skill] ?? 0.0) + $value;
            }
            unset($bucket);
        }

        ksort($buckets);
        $minutes = array_map('intval', array_keys($buckets));
        $skillNames = [];
        foreach ($buckets as $bucket) {
            foreach (array_keys($bucket['skills']) as $skill) {
                $skillNames[$skill] = true;
            }
        }
        ksort($skillNames);

        $average = [
            'minutes' => $minutes,
            'samples' => [],
            'networth' => [],
            'lane_creeps' => [],
            'jungle_creeps' => [],
            'hero_damage' => [],
            'skills' => [],
        ];
        foreach (array_keys($skillNames) as $skill) {
            $average['skills'][$skill] = [];
        }

        foreach ($buckets as $bucket) {
            $count = max(1, $bucket['count']);
            $average['samples'][] = $bucket['count'];
            $average['networth'][] = self::roundStat($bucket['networth'] / $count);
            $average['lane_creeps'][] = self::roundStat($bucket['lane_creeps'] / $count);
            $average['jungle_creeps'][] = self::roundStat($bucket['jungle_creeps'] / $count);
            $average['hero_damage'][] = self::roundStat($bucket['hero_damage'] / $count);
            foreach (array_keys($skillNames) as $skill) {
                $average['skills'][$skill][] = self::roundStat(($bucket['skills'][$skill] ?? 0.0) / $count);
            }
        }

        return $average;
    }

    /** @param list<array<string, mixed>> $rows */
    private static function matchSummaries(array $rows): array
    {
        $matches = [];
        foreach ($rows as $row) {
            $matches[] = [
                'match_id' => (string) $row['match_id'],
                'started_at' => (string) $row['started_at'],
                'duration' => (int) $row['duration'],
                'minutes' => (int) $row['minutes'],
                'networth' => (int) $row['networth'],
                'hero_damage' => (int) $row['hero_damage'],
                'lane_creeps' => (int) $row['lane_creeps'],
                'jungle_creeps' => (int) $row['jungle_creeps'],
                'won' => self::matchWon($row),
            ];
        }

        return $matches;
    }

    /** @param list<array<string, mixed>> $rows */
    private static function playerMatchSummaries(array $rows): array
    {
        $matches = [];
        foreach ($rows as $row) {
            $matches[] = [
                'match_id' => (string) $row['match_id'],
                'started_at' => (string) $row['started_at'],
                'hero' => (string) $row['hero'],
                'team' => (int) $row['team'],
                'duration' => (int) $row['duration'],
                'minutes' => (int) $row['minutes'],
                'networth' => (int) $row['networth'],
                'hero_damage' => (int) $row['hero_damage'],
                'won' => self::matchWon($row),
            ];
        }

        return $matches;
    }

    /** @param list<array<string, mixed>> $rows */
    private static function matchHeroSeries(array $rows): array
    {
        $heroes = [];
        foreach ($rows as $row) {
            $hero = (string) $row['hero'];
            $playerId = (int) $row['player_id'];
            $key = $hero . ':' . $playerId;
            if (!isset($heroes[$key])) {
                $heroes[$key] = [
                    'hero' => $hero,
                    'player_id' => $playerId,
                    'steamid' => (int) $row['steamid'],
                    'team' => (int) $row['team'],
                    'minutes' => [],
                    'game_time' => [],
                    'networth' => [],
                    'lane_creeps' => [],
                    'jungle_creeps' => [],
                    'hero_damage' => [],
                    'skills' => [],
                ];
            }

            $heroes[$key]['minutes'][] = (int) $row['minute'];
            $heroes[$key]['game_time'][] = (int) $row['game_time'];
            $heroes[$key]['networth'][] = (int) $row['networth'];
            $heroes[$key]['lane_creeps'][] = (int) $row['lane_creeps'];
            $heroes[$key]['jungle_creeps'][] = (int) $row['jungle_creeps'];
            $heroes[$key]['hero_damage'][] = (int) $row['hero_damage'];

            $values = self::decodeSkillDamage($row['skill_damage'] ?? null);
            foreach ($values as $skill => $value) {
                if (!isset($heroes[$key]['skills'][$skill])) {
                    $heroes[$key]['skills'][$skill] = array_fill(0, count($heroes[$key]['minutes']) - 1, 0);
                }
            }
            foreach ($heroes[$key]['skills'] as $skill => $series) {
                $heroes[$key]['skills'][$skill][] = $values[$skill] ?? 0;
            }
        }

        return array_values($heroes);
    }

    private static function decodeSkillDamage(mixed $raw): array
    {
        if (is_array($raw)) {
            return self::parseSkillDamage($raw);
        }
        if (!is_string($raw) || $raw === '') {
            return [];
        }

        $decoded = json_decode($raw, true);
        return is_array($decoded) ? self::parseSkillDamage($decoded) : [];
    }

    private static function parseSkillDamage(mixed $raw): array
    {
        if (!is_array($raw)) {
            return [];
        }

        $skills = [];
        foreach ($raw as $name => $value) {
            if (count($skills) >= self::MAX_SKILLS) {
                break;
            }
            $skill = is_string($name) ? $name : (string) $name;
            if (preg_match(self::SKILL_PATTERN, $skill) !== 1) {
                continue;
            }
            $amount = self::parseUnsignedInt($value);
            if ($amount <= 0) {
                continue;
            }
            $skills[$skill] = $amount;
        }

        ksort($skills);
        return $skills;
    }

    /** @return list<string> */
    private static function roster(): array
    {
        $path = dirname(__DIR__, 2) . DIRECTORY_SEPARATOR . 'Game' . DIRECTORY_SEPARATOR
            . 'scripts' . DIRECTORY_SEPARATOR . 'npc' . DIRECTORY_SEPARATOR . 'Activelist.txt';
        if (!is_file($path)) {
            return [];
        }

        $contents = file_get_contents($path);
        if (!is_string($contents) || $contents === '') {
            return [];
        }

        preg_match_all('/"(npc_dota_hero_[a-z0-9_]+)"\s+"1"/', $contents, $matches);
        $heroes = [];
        $seen = [];
        foreach ($matches[1] as $hero) {
            if (isset($seen[$hero])) {
                continue;
            }
            $seen[$hero] = true;
            $heroes[] = $hero;
        }

        return $heroes;
    }

    /** @return array<string, array{matches: int, wins: int, pick_rate: float, win_rate: ?float}> */
    private static function heroStatsMap(): array
    {
        $total = self::totalMatches();
        $statement = Database::pdo()->query(
            'SELECT p.hero,
                    COUNT(*) AS picks,
                    SUM(CASE WHEN p.winner_team IN (2, 3) THEN 1 ELSE 0 END) AS decided,
                    SUM(CASE WHEN p.winner_team IN (2, 3) AND p.team = p.winner_team THEN 1 ELSE 0 END) AS wins
             FROM (
                 SELECT s.match_id, s.hero, MIN(s.team) AS team, MAX(m.winner_team) AS winner_team
                 FROM analytics_snapshots s
                 INNER JOIN analytics_matches m ON m.match_id = s.match_id
                 GROUP BY s.match_id, s.hero
             ) p
             GROUP BY p.hero'
        );

        $stats = [];
        foreach ($statement->fetchAll() as $row) {
            $picks = (int) $row['picks'];
            $decided = (int) $row['decided'];
            $wins = (int) $row['wins'];
            $stats[(string) $row['hero']] = [
                'matches' => $picks,
                'wins' => $wins,
                'pick_rate' => $total > 0 ? self::roundStat($picks / $total * 100) : 0.0,
                'win_rate' => $decided > 0 ? self::roundStat($wins / $decided * 100) : null,
            ];
        }

        return $stats;
    }

    /** @return array{matches: int, wins: int, pick_rate: float, win_rate: ?float} */
    private static function emptyHeroStats(): array
    {
        return [
            'matches' => 0,
            'wins' => 0,
            'pick_rate' => 0.0,
            'win_rate' => null,
        ];
    }

    /** @param array{matches: int, wins: int, pick_rate: float, win_rate: ?float}|null $stats */
    private static function heroListRow(string $hero, ?array $stats): array
    {
        $row = $stats ?? self::emptyHeroStats();
        return [
            'hero' => $hero,
            'matches' => $row['matches'],
            'wins' => $row['wins'],
            'pick_rate' => $row['pick_rate'],
            'win_rate' => $row['win_rate'],
        ];
    }

    private static function totalMatches(): int
    {
        return (int) Database::pdo()->query('SELECT COUNT(*) FROM analytics_matches')->fetchColumn();
    }

    /**
     * @return array{
     *   matches: int,
     *   six_player_matches: int,
     *   unfinished_rate: float|null,
     *   kills_per_minute: float|null,
     *   median_gpm: float|null,
     *   median_xpm: float|null,
     *   avg_bosses: float|null,
     *   avg_creeps_radiant: float|null,
     *   avg_creeps_dire: float|null,
     *   avg_duration: float|null,
     *   avg_duration_radiant_win: float|null,
     *   avg_duration_dire_win: float|null
     * }
     */
    private static function lifetimeStats(PDO $pdo): array
    {
        $sixPlayer = $pdo->query(
            'SELECT m.match_id, m.winner_team, m.last_game_time, m.boss_kills
             FROM analytics_matches m
             INNER JOIN (
                 SELECT match_id
                 FROM analytics_snapshots
                 GROUP BY match_id
                 HAVING COUNT(DISTINCT player_id) = 6
             ) six ON six.match_id = m.match_id'
        )->fetchAll();

        $sixPlayerCount = count($sixPlayer);
        $completedIds = [];
        foreach ($sixPlayer as $row) {
            $winner = (int) $row['winner_team'];
            if ($winner === 2 || $winner === 3) {
                $completedIds[(string) $row['match_id']] = $row;
            }
        }
        $completedCount = count($completedIds);

        $empty = [
            'matches' => $completedCount,
            'six_player_matches' => $sixPlayerCount,
            'unfinished_rate' => $sixPlayerCount > 0
                ? self::roundStat((($sixPlayerCount - $completedCount) / $sixPlayerCount) * 100)
                : null,
            'kills_per_minute' => null,
            'median_gpm' => null,
            'median_xpm' => null,
            'avg_bosses' => null,
            'avg_creeps_radiant' => null,
            'avg_creeps_dire' => null,
            'avg_duration' => null,
            'avg_duration_radiant_win' => null,
            'avg_duration_dire_win' => null,
        ];
        if ($completedIds === []) {
            return $empty;
        }

        $placeholders = implode(',', array_fill(0, count($completedIds), '?'));
        $statement = $pdo->prepare(
            "SELECT s.match_id, s.player_id, s.team, s.networth, s.xp, s.hero_kills,
                    s.lane_creeps, s.jungle_creeps, m.last_game_time, m.winner_team, m.boss_kills
             FROM analytics_snapshots s
             INNER JOIN analytics_matches m ON m.match_id = s.match_id
             INNER JOIN (
                 SELECT match_id, player_id, MAX(minute) AS minute
                 FROM analytics_snapshots
                 WHERE match_id IN ({$placeholders})
                 GROUP BY match_id, player_id
             ) last ON last.match_id = s.match_id
                  AND last.player_id = s.player_id
                  AND last.minute = s.minute
             WHERE s.match_id IN ({$placeholders})"
        );
        $ids = array_keys($completedIds);
        $statement->execute([...$ids, ...$ids]);

        $matches = [];
        foreach ($statement->fetchAll() as $row) {
            $matchId = (string) $row['match_id'];
            if (!isset($matches[$matchId])) {
                $matches[$matchId] = [
                    'duration' => (int) $row['last_game_time'],
                    'winner' => (int) $row['winner_team'],
                    'boss_kills' => $row['boss_kills'] === null ? null : (int) $row['boss_kills'],
                    'heroes' => [],
                ];
            }
            $matches[$matchId]['heroes'][] = [
                'team' => (int) $row['team'],
                'networth' => (int) $row['networth'],
                'xp' => $row['xp'] === null ? null : (int) $row['xp'],
                'hero_kills' => $row['hero_kills'] === null ? null : (int) $row['hero_kills'],
                'creeps' => (int) $row['lane_creeps'] + (int) $row['jungle_creeps'],
            ];
        }

        $kpm = [];
        $gpm = [];
        $xpm = [];
        $bosses = [];
        $creepsRadiant = [];
        $creepsDire = [];
        $durations = [];
        $radiantWinDurations = [];
        $direWinDurations = [];

        foreach ($matches as $match) {
            $seconds = (int) $match['duration'];
            if ($seconds <= 0) {
                continue;
            }
            $minutes = $seconds / 60.0;
            $durations[] = $seconds;
            if ($match['winner'] === 2) {
                $radiantWinDurations[] = $seconds;
            } elseif ($match['winner'] === 3) {
                $direWinDurations[] = $seconds;
            }

            $radiantCreeps = 0;
            $direCreeps = 0;
            $kills = 0;
            $killsKnown = 0;
            foreach ($match['heroes'] as $hero) {
                $gpm[] = $hero['networth'] / $minutes;
                if ($hero['xp'] !== null) {
                    $xpm[] = $hero['xp'] / $minutes;
                }
                if ($hero['hero_kills'] !== null) {
                    $kills += $hero['hero_kills'];
                    $killsKnown++;
                }
                if ($hero['team'] === 2) {
                    $radiantCreeps += $hero['creeps'];
                } elseif ($hero['team'] === 3) {
                    $direCreeps += $hero['creeps'];
                }
            }

            $creepsRadiant[] = $radiantCreeps;
            $creepsDire[] = $direCreeps;
            if ($killsKnown > 0) {
                $kpm[] = $kills / $minutes;
            }
            if ($match['boss_kills'] !== null) {
                $bosses[] = $match['boss_kills'];
            }
        }

        $empty['kills_per_minute'] = self::averageOrNull($kpm);
        $empty['median_gpm'] = self::medianOrNull($gpm);
        $empty['median_xpm'] = self::medianOrNull($xpm);
        $empty['avg_bosses'] = self::averageOrNull($bosses);
        $empty['avg_creeps_radiant'] = self::averageOrNull($creepsRadiant);
        $empty['avg_creeps_dire'] = self::averageOrNull($creepsDire);
        $empty['avg_duration'] = self::averageOrNull($durations, 0);
        $empty['avg_duration_radiant_win'] = self::averageOrNull($radiantWinDurations, 0);
        $empty['avg_duration_dire_win'] = self::averageOrNull($direWinDurations, 0);

        return $empty;
    }

    /** @param list<float|int> $values */
    private static function averageOrNull(array $values, int $precision = 1): ?float
    {
        if ($values === []) {
            return null;
        }

        return round(array_sum($values) / count($values), $precision);
    }

    /** @param list<float|int> $values */
    private static function medianOrNull(array $values): ?float
    {
        if ($values === []) {
            return null;
        }

        sort($values, SORT_NUMERIC);
        $count = count($values);
        $middle = intdiv($count, 2);
        if ($count % 2 === 1) {
            return self::roundStat((float) $values[$middle]);
        }

        return self::roundStat(((float) $values[$middle - 1] + (float) $values[$middle]) / 2);
    }

    /**
     * @return array{
     *   from: string,
     *   to: string,
     *   matches: int,
     *   decided: int,
     *   radiant_wins: int,
     *   dire_wins: int,
     *   radiant_win_rate: float|null,
     *   dire_win_rate: float|null,
     *   unique_players: int
     * }
     */
    private static function periodStats(PDO $pdo, string $fromSql, string $from, string $to): array
    {
        $match = $pdo->query(
            "SELECT
                COUNT(*) AS matches,
                SUM(CASE WHEN winner_team IN (2, 3) THEN 1 ELSE 0 END) AS decided,
                SUM(CASE WHEN winner_team = 2 THEN 1 ELSE 0 END) AS radiant_wins,
                SUM(CASE WHEN winner_team = 3 THEN 1 ELSE 0 END) AS dire_wins
             FROM analytics_matches
             WHERE started_at >= {$fromSql}"
        )->fetch();

        $players = $pdo->query(
            "SELECT COUNT(DISTINCT s.steamid) AS unique_players
             FROM analytics_snapshots s
             INNER JOIN analytics_matches m ON m.match_id = s.match_id
             WHERE m.started_at >= {$fromSql}
               AND s.steamid > 0"
        )->fetch();

        $decided = (int) ($match['decided'] ?? 0);
        $radiantWins = (int) ($match['radiant_wins'] ?? 0);
        $direWins = (int) ($match['dire_wins'] ?? 0);

        return [
            'from' => $from,
            'to' => $to,
            'matches' => (int) ($match['matches'] ?? 0),
            'decided' => $decided,
            'radiant_wins' => $radiantWins,
            'dire_wins' => $direWins,
            'radiant_win_rate' => $decided > 0 ? self::roundStat(($radiantWins / $decided) * 100) : null,
            'dire_win_rate' => $decided > 0 ? self::roundStat(($direWins / $decided) * 100) : null,
            'unique_players' => (int) ($players['unique_players'] ?? 0),
        ];
    }

    /** @param array<string, mixed> $row */
    private static function matchWon(array $row): ?bool
    {
        $team = (int) ($row['team'] ?? 0);
        $winner = (int) ($row['winner_team'] ?? 0);
        if ($team !== 2 && $team !== 3) {
            return null;
        }
        if ($winner !== 2 && $winner !== 3) {
            return null;
        }

        return $team === $winner;
    }

    private static function parseWinner(mixed $value): int
    {
        $winner = self::parseUnsignedInt($value);
        return ($winner === 2 || $winner === 3) ? $winner : 0;
    }

    private static function parseHero(mixed $value): ?string
    {
        if (!is_string($value)) {
            return null;
        }
        $hero = strtolower(trim($value));
        return preg_match(self::HERO_PATTERN, $hero) === 1 ? $hero : null;
    }

    private static function parseSteamId(mixed $value): ?string
    {
        if (is_int($value) && $value > 0) {
            return (string) $value;
        }
        if (is_string($value) && preg_match('/^[1-9]\d{0,19}$/', $value) === 1) {
            return $value;
        }

        return null;
    }

    private static function parseMatchId(mixed $value): ?string
    {
        if (!is_string($value)) {
            return null;
        }
        $matchId = trim($value);
        return preg_match(self::MATCH_PATTERN, $matchId) === 1 ? $matchId : null;
    }

    private static function parseUnsignedInt(mixed $value): int
    {
        if (is_int($value)) {
            return max(0, $value);
        }
        if (is_float($value)) {
            return max(0, (int) round($value));
        }
        if (is_string($value) && preg_match('/^-?\d+$/', $value) === 1) {
            return max(0, (int) $value);
        }

        return 0;
    }

    private static function parseBool(mixed $value): bool
    {
        if (is_bool($value)) {
            return $value;
        }
        if (is_int($value)) {
            return $value === 1;
        }
        if (is_string($value)) {
            $normalized = strtolower($value);
            return $normalized === '1' || $normalized === 'true';
        }

        return false;
    }

    private static function clampInt(mixed $value, int $min, int $max): int
    {
        return max($min, min($max, self::parseUnsignedInt($value)));
    }

    private static function roundStat(float $value): float
    {
        return round($value, 1);
    }
}
