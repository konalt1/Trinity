CREATE DATABASE IF NOT EXISTS trinity
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE trinity;

CREATE TABLE IF NOT EXISTS players (
    steamid BIGINT UNSIGNED NOT NULL,
    games INT UNSIGNED NOT NULL DEFAULT 0,
    rating INT NOT NULL DEFAULT 1000,
    first_lootbox_opened TINYINT(1) NOT NULL DEFAULT 1,
    lootbox_unopened INT UNSIGNED NOT NULL DEFAULT 0,
    lootbox_currency INT UNSIGNED NOT NULL DEFAULT 0,
    lootbox_grants_date DATE NULL,
    lootbox_grants_today TINYINT UNSIGNED NOT NULL DEFAULT 0,
    lootbox_daily_date DATE NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (steamid)
) ENGINE=InnoDB;

ALTER TABLE players
    ADD COLUMN IF NOT EXISTS first_lootbox_opened TINYINT(1) NOT NULL DEFAULT 1;

ALTER TABLE players
    ADD COLUMN IF NOT EXISTS lootbox_unopened INT UNSIGNED NOT NULL DEFAULT 0;

ALTER TABLE players
    ADD COLUMN IF NOT EXISTS lootbox_currency INT UNSIGNED NOT NULL DEFAULT 0;

ALTER TABLE players
    ADD COLUMN IF NOT EXISTS lootbox_grants_date DATE NULL;

ALTER TABLE players
    ADD COLUMN IF NOT EXISTS lootbox_grants_today TINYINT UNSIGNED NOT NULL DEFAULT 0;

ALTER TABLE players
    ADD COLUMN IF NOT EXISTS lootbox_daily_date DATE NULL;

ALTER TABLE players
    MODIFY first_lootbox_opened TINYINT(1) NOT NULL DEFAULT 1;

UPDATE players
SET lootbox_unopened = lootbox_unopened + 1,
    first_lootbox_opened = 1
WHERE first_lootbox_opened = 0;

CREATE TABLE IF NOT EXISTS stickers (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    sticker_key VARCHAR(32) NOT NULL,
    enabled TINYINT(1) NOT NULL DEFAULT 1,
    sort_order INT UNSIGNED NOT NULL DEFAULT 0,
    rarity VARCHAR(16) NOT NULL DEFAULT 'common',
    weight_normal INT UNSIGNED NOT NULL DEFAULT 100,
    weight_elite INT UNSIGNED NOT NULL DEFAULT 10,
    PRIMARY KEY (id),
    UNIQUE KEY uk_stickers_key (sticker_key)
) ENGINE=InnoDB;

ALTER TABLE stickers
    ADD COLUMN IF NOT EXISTS rarity VARCHAR(16) NOT NULL DEFAULT 'common';

ALTER TABLE stickers
    ADD COLUMN IF NOT EXISTS weight_normal INT UNSIGNED NOT NULL DEFAULT 100;

ALTER TABLE stickers
    ADD COLUMN IF NOT EXISTS weight_elite INT UNSIGNED NOT NULL DEFAULT 10;

CREATE TABLE IF NOT EXISTS player_stickers (
    steamid BIGINT UNSIGNED NOT NULL,
    sticker_id INT UNSIGNED NOT NULL,
    quality TINYINT UNSIGNED NOT NULL DEFAULT 1,
    copies TINYINT UNSIGNED NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (steamid, sticker_id),
    CONSTRAINT fk_player_stickers_player FOREIGN KEY (steamid) REFERENCES players (steamid) ON DELETE CASCADE,
    CONSTRAINT fk_player_stickers_sticker FOREIGN KEY (sticker_id) REFERENCES stickers (id) ON DELETE CASCADE
) ENGINE=InnoDB;

ALTER TABLE player_stickers
    ADD COLUMN IF NOT EXISTS quality TINYINT UNSIGNED NOT NULL DEFAULT 1;

ALTER TABLE player_stickers
    ADD COLUMN IF NOT EXISTS copies TINYINT UNSIGNED NOT NULL DEFAULT 1;

CREATE TABLE IF NOT EXISTS player_wheel (
    steamid BIGINT UNSIGNED NOT NULL,
    slot TINYINT UNSIGNED NOT NULL,
    sticker_id INT UNSIGNED NULL,
    PRIMARY KEY (steamid, slot),
    CONSTRAINT fk_player_wheel_player FOREIGN KEY (steamid) REFERENCES players (steamid) ON DELETE CASCADE,
    CONSTRAINT fk_player_wheel_sticker FOREIGN KEY (sticker_id) REFERENCES stickers (id) ON DELETE SET NULL
) ENGINE=InnoDB;

INSERT INTO stickers (sticker_key, enabled, sort_order, rarity, weight_normal, weight_elite) VALUES
    ('Gura', 1, 1, 'common', 100, 10),
    ('NeuroHug', 1, 2, 'common', 100, 10),
    ('Watson', 1, 3, 'common', 100, 10),
    ('Anime', 1, 4, 'common', 100, 10),
    ('Neurodance', 1, 5, 'rare', 30, 3),
    ('Choso', 1, 6, 'common', 100, 10),
    ('StickerOne', 1, 7, 'rare', 30, 3),
    ('StickerTwo', 1, 8, 'rare', 30, 3),
    ('NO_GOD', 1, 9, 'rare', 30, 3)
ON DUPLICATE KEY UPDATE
    enabled = VALUES(enabled),
    sort_order = VALUES(sort_order),
    rarity = VALUES(rarity),
    weight_normal = VALUES(weight_normal),
    weight_elite = VALUES(weight_elite);

CREATE TABLE IF NOT EXISTS analytics_matches (
    match_id VARCHAR(64) NOT NULL,
    started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP NULL,
    last_game_time INT UNSIGNED NOT NULL DEFAULT 0,
    winner_team TINYINT UNSIGNED NOT NULL DEFAULT 0,
    boss_kills INT UNSIGNED NULL,
    PRIMARY KEY (match_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS analytics_snapshots (
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
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS match_sessions (
    match_id VARCHAR(64) NOT NULL,
    match_key VARCHAR(64) NOT NULL DEFAULT '',
    map_name VARCHAR(64) NOT NULL DEFAULT '',
    cluster_id INT NOT NULL DEFAULT 0,
    region_id INT NOT NULL DEFAULT 0,
    cheats TINYINT(1) NOT NULL DEFAULT 0,
    started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (match_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS match_results (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    match_id VARCHAR(64) NOT NULL,
    steamid BIGINT UNSIGNED NOT NULL,
    hero_name VARCHAR(64) NOT NULL DEFAULT '',
    team TINYINT UNSIGNED NOT NULL DEFAULT 0,
    win TINYINT(1) NOT NULL DEFAULT 0,
    kills INT NOT NULL DEFAULT 0,
    deaths INT NOT NULL DEFAULT 0,
    assists INT NOT NULL DEFAULT 0,
    networth INT NOT NULL DEFAULT 0,
    gpm INT NOT NULL DEFAULT 0,
    xpm INT NOT NULL DEFAULT 0,
    level INT NOT NULL DEFAULT 0,
    items_json TEXT NULL,
    end_time INT NOT NULL DEFAULT 0,
    is_leaver TINYINT(1) NOT NULL DEFAULT 0,
    rating_before INT NOT NULL DEFAULT 1000,
    rating_change INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_match_results_player (match_id, steamid)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS match_leaves (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    match_id VARCHAR(64) NOT NULL,
    steamid BIGINT UNSIGNED NOT NULL,
    leave_time INT NOT NULL DEFAULT 0,
    safe_to_leave TINYINT(1) NOT NULL DEFAULT 0,
    player_name VARCHAR(64) NOT NULL DEFAULT '',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS match_reports (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    match_id VARCHAR(64) NOT NULL,
    reporter BIGINT UNSIGNED NOT NULL,
    reported1 BIGINT UNSIGNED NOT NULL,
    reported2 BIGINT UNSIGNED NOT NULL DEFAULT 0,
    report_type INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB;
