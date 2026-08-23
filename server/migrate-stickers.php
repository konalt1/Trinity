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

$sql = file_get_contents(__DIR__ . '/schema.sql');
if (!is_string($sql) || $sql === '') {
    fwrite(STDERR, "Missing schema.sql\n");
    exit(1);
}

$statements = array_filter(array_map('trim', preg_split('/;\\s*\\n/', $sql) ?: []));
foreach ($statements as $statement) {
    if ($statement === '' || str_starts_with($statement, 'CREATE DATABASE') || str_starts_with($statement, 'USE ')) {
        continue;
    }
    $pdo->exec($statement);
}

fwrite(STDOUT, "Sticker tables ready.\n");
