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
    ('StickerTwo', 1, 8, 'rare', 30, 3)
ON DUPLICATE KEY UPDATE
    enabled = VALUES(enabled),
    sort_order = VALUES(sort_order),
    rarity = VALUES(rarity),
    weight_normal = VALUES(weight_normal),
    weight_elite = VALUES(weight_elite);
