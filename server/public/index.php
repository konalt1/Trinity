<?php

declare(strict_types=1);

if (PHP_SAPI === 'cli-server') {
    $requestPath = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
    if (is_string($requestPath) && $requestPath !== '/' && !str_contains($requestPath, '..')) {
        $file = __DIR__ . $requestPath;
        if (is_file($file)) {
            return false;
        }
    }
}

require dirname(__DIR__) . '/src/bootstrap.php';

$method = Http::method();
$path = Http::path();
error_log($method . ' ' . ($_SERVER['REQUEST_URI'] ?? $path));

if ($method === 'GET' && $path === '/') {
    Http::file(__DIR__ . '/app/index.html');
}

if ($method === 'GET' && $path === '/analytics') {
    Http::redirect('/?view=analytics');
}

if ($method === 'GET' && $path === '/stickers') {
    Http::redirect('/?view=stickers');
}

if ($method === 'GET' && $path === '/players') {
    Http::redirect('/?view=players');
}

if ($method === 'GET' && $path === '/abilities') {
    Http::redirect('/?view=abilities');
}

if ($method === 'GET' && $path === '/balance') {
    Http::redirect('/?view=abilities&tab=numbers');
}

if ($method === 'GET' && $path === '/localization') {
    Http::redirect('/?view=abilities&tab=check');
}

if ($method === 'GET' && $path === '/shop') {
    Http::redirect('/?view=shop');
}

if ($method === 'GET' && $path === '/app/style.css') {
    Http::file(__DIR__ . '/app/style.css');
}

if ($method === 'GET' && $path === '/app/shell.js') {
    Http::file(__DIR__ . '/app/shell.js');
}

if ($method === 'GET' && $path === '/app/analytics.js') {
    Http::file(__DIR__ . '/app/analytics.js');
}

if ($method === 'GET' && $path === '/app/stickers.js') {
    Http::file(__DIR__ . '/app/stickers.js');
}

if ($method === 'GET' && $path === '/app/home.js') {
    Http::file(__DIR__ . '/app/home.js');
}

if ($method === 'GET' && $path === '/app/players.js') {
    Http::file(__DIR__ . '/app/players.js');
}

if ($method === 'GET' && $path === '/app/abilities.js') {
    Http::file(__DIR__ . '/app/abilities.js');
}

if ($method === 'GET' && $path === '/app/shop.js') {
    Http::file(__DIR__ . '/app/shop.js');
}

if ($path === '/v1/stickers/studio' && $method === 'GET') {
    StickerStudio::list();
}

if ($path === '/v1/stickers/studio/players' && $method === 'GET') {
    StickerStudio::players();
}

if ($path === '/v1/stickers/studio/grant-lootbox' && $method === 'POST') {
    Stickers::grantLootbox();
}

if ($path === '/v1/stickers/studio' && $method === 'POST') {
    StickerStudio::save();
}

if ($path === '/v1/stickers/studio/delete' && $method === 'POST') {
    StickerStudio::delete();
}

if ($path === '/v1/stickers/studio/media' && $method === 'GET') {
    StickerStudio::media();
}

if ($path === '/v1/analytics/snapshots' && $method === 'POST') {
    Auth::requireKey();
    Analytics::saveSnapshots();
}

if ($path === '/v1/analytics/overview' && $method === 'GET') {
    Analytics::overview();
}

if ($path === '/v1/analytics/heroes' && $method === 'GET') {
    Analytics::heroes();
}

if ($path === '/v1/analytics/hero' && $method === 'GET') {
    Analytics::hero();
}

if ($path === '/v1/analytics/players' && $method === 'GET') {
    Analytics::players();
}

if ($path === '/v1/analytics/player' && $method === 'GET') {
    Analytics::player();
}

if ($path === '/v1/analytics/match' && $method === 'GET') {
    Analytics::match();
}

if ($path === '/v1/abilities/catalog' && $method === 'GET') {
    AbilityStudio::catalog();
}

if ($path === '/v1/abilities/ability' && $method === 'GET') {
    AbilityStudio::ability();
}

if ($path === '/v1/abilities/save' && $method === 'POST') {
    AbilityStudio::save();
}

if ($path === '/v1/abilities/icon' && $method === 'GET') {
    AbilityStudio::icon();
}

if ($path === '/v1/localization/report' && $method === 'GET') {
    AbilityStudio::locReport();
}

if ($path === '/v1/shop/catalog' && $method === 'GET') {
    ShopStudio::catalog();
}

if ($path === '/v1/shop/save' && $method === 'POST') {
    ShopStudio::save();
}

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

if ($path === '/match_start' && $method === 'POST') {
    Auth::requireKey();
    MatchApi::matchStart();
}

if ($path === '/match_details' && $method === 'POST') {
    Auth::requireKey();
    MatchApi::matchDetails();
}

if ($path === '/match_leaderboard' && $method === 'POST') {
    Auth::requireKey();
    MatchApi::leaderboard();
}

if ($path === '/unranked_stats' && $method === 'POST') {
    Auth::requireKey();
    MatchApi::unrankedStats();
}

if ($path === '/end' && $method === 'POST') {
    Auth::requireKey();
    MatchApi::endMatch();
}

if ($path === '/leave' && $method === 'POST') {
    Auth::requireKey();
    MatchApi::leave();
}

if ($path === '/report' && $method === 'POST') {
    Auth::requireKey();
    MatchApi::report();
}

if ($path === '/http-errors' && $method === 'POST') {
    Auth::requireKey();
    MatchApi::httpErrors();
}

Http::json(404, ['ok' => false, 'error' => 'not_found']);
