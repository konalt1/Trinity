<?php

declare(strict_types=1);

require dirname(__DIR__) . '/src/bootstrap.php';

$method = Http::method();
$path = Http::path();
error_log($method . ' ' . ($_SERVER['REQUEST_URI'] ?? $path));

if ($path === '/v1/health' && $method === 'GET') {
    Http::json(200, ['ok' => true]);
}

if ($path === '/v1/players' && $method === 'GET') {
    Auth::requireKey();
    Players::get();
}

if ($path === '/v1/players' && $method === 'POST') {
    Auth::requireKey();
    Players::save();
}

if ($path === '/v1/stickers/open' && $method === 'POST') {
    Auth::requireKey();
    Stickers::open();
}

if ($path === '/v1/stickers/wheel' && $method === 'POST') {
    Auth::requireKey();
    Stickers::saveWheel();
}

if ($path === '/v1/stickers/buy' && $method === 'POST') {
    Auth::requireKey();
    Stickers::buy();
}

if ($path === '/v1/stickers/grant' && $method === 'POST') {
    Auth::requireKey();
    Stickers::grant();
}

if ($path === '/v1/stickers/grant-lootbox' && $method === 'POST') {
    Auth::requireKey();
    Stickers::grantLootbox();
}

if ($path === '/v1/stickers/reset-lootbox' && $method === 'POST') {
    Auth::requireKey();
    Stickers::grantLootbox();
}

if ($path === '/v1/stickers/grant-daily' && $method === 'POST') {
    Auth::requireKey();
    Stickers::grantDaily();
}

if ($path === '/v1/stickers/grant-win' && $method === 'POST') {
    Auth::requireKey();
    Stickers::grantWin();
}

Http::json(404, ['ok' => false, 'error' => 'not_found']);
