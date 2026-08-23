CREATE DATABASE IF NOT EXISTS trinity
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE trinity;

CREATE TABLE IF NOT EXISTS players (
    steamid BIGINT UNSIGNED NOT NULL,
    games INT UNSIGNED NOT NULL DEFAULT 0,
    rating INT NOT NULL DEFAULT 1000,
    first_lootbox_opened TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (steamid)
) ENGINE=InnoDB;

ALTER TABLE players
    ADD COLUMN IF NOT EXISTS first_lootbox_opened TINYINT(1) NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS stickers (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    sticker_key VARCHAR(32) NOT NULL,
    enabled TINYINT(1) NOT NULL DEFAULT 1,
    sort_order INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY uk_stickers_key (sticker_key)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS player_stickers (
    steamid BIGINT UNSIGNED NOT NULL,
    sticker_id INT UNSIGNED NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (steamid, sticker_id),
    CONSTRAINT fk_player_stickers_player FOREIGN KEY (steamid) REFERENCES players (steamid) ON DELETE CASCADE,
    CONSTRAINT fk_player_stickers_sticker FOREIGN KEY (sticker_id) REFERENCES stickers (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS player_wheel (
    steamid BIGINT UNSIGNED NOT NULL,
    slot TINYINT UNSIGNED NOT NULL,
    sticker_id INT UNSIGNED NULL,
    PRIMARY KEY (steamid, slot),
    CONSTRAINT fk_player_wheel_player FOREIGN KEY (steamid) REFERENCES players (steamid) ON DELETE CASCADE,
    CONSTRAINT fk_player_wheel_sticker FOREIGN KEY (sticker_id) REFERENCES stickers (id) ON DELETE SET NULL
) ENGINE=InnoDB;

INSERT INTO stickers (sticker_key, enabled, sort_order) VALUES
    ('Gura', 1, 1),
    ('NeuroHug', 1, 2),
    ('Watson', 1, 3),
    ('Anime', 1, 4),
    ('Neurodance', 1, 5),
    ('Choso', 1, 6),
    ('StickerOne', 1, 7),
    ('StickerTwo', 1, 8)
ON DUPLICATE KEY UPDATE
    enabled = VALUES(enabled),
    sort_order = VALUES(sort_order);
