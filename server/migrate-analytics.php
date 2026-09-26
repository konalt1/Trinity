<?php

declare(strict_types=1);

$configPath = __DIR__ . '/config.php';
if (!is_file($configPath)) {
    fwrite(STDERR, "Missing server/config.php\n");
    exit(1);
}

$config = require $configPath;
$mysql = $config['mysql'] ?? [];
$dsn = sprintf(
    'mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4',
    (string) ($mysql['host'] ?? '127.0.0.1'),
    (int) ($mysql['port'] ?? 3306),
    (string) ($mysql['database'] ?? 'trinity')
);

$pdo = new PDO($dsn, (string) ($mysql['user'] ?? ''), (string) ($mysql['password'] ?? ''), [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
]);

$pdo->exec(
    'CREATE TABLE IF NOT EXISTS analytics_matches (
        match_id VARCHAR(64) NOT NULL,
        started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        ended_at TIMESTAMP NULL,
        last_game_time INT UNSIGNED NOT NULL DEFAULT 0,
        winner_team TINYINT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (match_id)
    ) ENGINE=InnoDB'
);

$pdo->exec(
    'ALTER TABLE analytics_matches
     ADD COLUMN IF NOT EXISTS winner_team TINYINT UNSIGNED NOT NULL DEFAULT 0'
);

$pdo->exec(
    'ALTER TABLE analytics_matches
     ADD COLUMN IF NOT EXISTS boss_kills INT UNSIGNED NULL'
);

$pdo->exec(
    'CREATE TABLE IF NOT EXISTS analytics_snapshots (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        match_id VARCHAR(64) NOT NULL,
        minute INT UNSIGNED NOT NULL,
        game_time INT UNSIGNED NOT NULL DEFAULT 0,
        is_final TINYINT(1) NOT NULL DEFAULT 0,
        hero VARCHAR(64) NOT NULL,
        player_id TINYINT UNSIGNED NOT NULL,
        steamid BIGINT UNSIGNED NOT NULL DEFAULT 0,
        team TINYINT UNSIGNED NOT NULL DEFAULT 0,
        networth INT UNSIGNED NOT NULL DEFAULT 0,
        xp INT UNSIGNED NULL,
        hero_kills INT UNSIGNED NULL,
        lane_creeps INT UNSIGNED NOT NULL DEFAULT 0,
        jungle_creeps INT UNSIGNED NOT NULL DEFAULT 0,
        hero_damage INT UNSIGNED NOT NULL DEFAULT 0,
        skill_damage JSON NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY uk_analytics_match_minute_player (match_id, minute, player_id),
        KEY idx_analytics_hero_minute (hero, minute),
        KEY idx_analytics_hero_match (hero, match_id),
        CONSTRAINT fk_analytics_snapshots_match FOREIGN KEY (match_id) REFERENCES analytics_matches (match_id) ON DELETE CASCADE
    ) ENGINE=InnoDB'
);

$pdo->exec(
    'ALTER TABLE analytics_snapshots
     ADD COLUMN IF NOT EXISTS xp INT UNSIGNED NULL'
);

$pdo->exec(
    'ALTER TABLE analytics_snapshots
     ADD COLUMN IF NOT EXISTS hero_kills INT UNSIGNED NULL'
);

fwrite(STDOUT, "Analytics tables ready.\n");
