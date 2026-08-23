<?php

declare(strict_types=1);

final class Config
{
    private static ?array $values = null;

    public static function load(): array
    {
        if (self::$values !== null) {
            return self::$values;
        }

        $path = dirname(__DIR__) . '/config.php';
        if (!is_file($path)) {
            Http::json(500, [
                'ok' => false,
                'error' => 'missing_config',
                'hint' => 'Copy server/config.example.php to server/config.php',
            ]);
        }

        $loaded = require $path;
        if (!is_array($loaded)) {
            Http::json(500, ['ok' => false, 'error' => 'invalid_config']);
        }

        self::$values = $loaded;
        return self::$values;
    }
}
