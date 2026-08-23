<?php

declare(strict_types=1);

final class Auth
{
    public static function requireKey(): void
    {
        $provided = self::requestKey();
        if ($provided === '') {
            Http::json(401, ['ok' => false, 'error' => 'missing_key']);
        }

        foreach (self::acceptedKeys() as $valid) {
            if (hash_equals($valid, $provided)) {
                return;
            }
        }

        Http::json(403, ['ok' => false, 'error' => 'invalid_key']);
    }

    private static function requestKey(): string
    {
        $header = $_SERVER['HTTP_X_TRINITY_KEY'] ?? '';
        if (is_string($header) && $header !== '') {
            return $header;
        }

        $query = $_GET['key'] ?? '';
        return is_string($query) ? $query : '';
    }

    /** @return list<string> */
    private static function acceptedKeys(): array
    {
        $keys = Config::load()['keys'] ?? [];
        $accepted = [];
        foreach (['dedicated', 'tools'] as $name) {
            $value = $keys[$name] ?? '';
            if (is_string($value) && $value !== '') {
                $accepted[] = $value;
            }
        }

        return $accepted;
    }
}
