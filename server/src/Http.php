<?php

declare(strict_types=1);

final class Http
{
    public static function json(int $status, array $payload): void
    {
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
        exit;
    }

    public static function method(): string
    {
        return strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
    }

    public static function path(): string
    {
        $path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
        if (!is_string($path) || $path === '') {
            return '/';
        }

        $path = '/' . ltrim($path, '/');
        if ($path !== '/') {
            $path = rtrim($path, '/');
        }

        return $path;
    }

    public static function body(): array
    {
        $raw = file_get_contents('php://input');
        if (is_string($raw) && $raw !== '') {
            $decoded = json_decode($raw, true);
            if (is_array($decoded)) {
                return $decoded;
            }
        }

        $posted = $_POST['body'] ?? null;
        if (is_string($posted) && $posted !== '') {
            $decoded = json_decode($posted, true);
            if (is_array($decoded)) {
                return $decoded;
            }
        }

        if (is_string($raw) && $raw !== '') {
            self::json(400, ['ok' => false, 'error' => 'invalid_json']);
        }

        return [];
    }

    public static function redirect(string $location, int $status = 302): void
    {
        header('Location: ' . $location, true, $status);
        exit;
    }

    public static function file(string $absolutePath): void
    {
        if (!is_file($absolutePath)) {
            self::json(404, ['ok' => false, 'error' => 'not_found']);
        }

        $extension = strtolower(pathinfo($absolutePath, PATHINFO_EXTENSION));
        $types = [
            'html' => 'text/html; charset=utf-8',
            'css' => 'text/css; charset=utf-8',
            'js' => 'text/javascript; charset=utf-8',
            'svg' => 'image/svg+xml',
            'png' => 'image/png',
            'ico' => 'image/x-icon',
            'mp4' => 'video/mp4',
            'webm' => 'video/webm',
            'mp3' => 'audio/mpeg',
            'wav' => 'audio/wav',
        ];

        header('Content-Type: ' . ($types[$extension] ?? 'application/octet-stream'));
        header('Cache-Control: no-store');
        header('Content-Length: ' . (string) filesize($absolutePath));
        header('Accept-Ranges: none');
        readfile($absolutePath);
        exit;
    }
}
