<?php

declare(strict_types=1);

/**
 * Copy to config.php and fill in MySQL plus keys.
 * config.php is gitignored.
 */
return [
    'mysql' => [
        'host' => '127.0.0.1',
        'port' => 3306,
        'database' => 'trinity',
        'user' => 'trinity',
        'password' => '',
    ],
    'keys' => [
        // From a Valve dedicated match: GetDedicatedServerKeyV3("trinity")
        'dedicated' => '',
        // Local Host / Workshop Tools: Lua sends this when the dedicated key is unusable
        'tools' => 'trinity-tools-local',
    ],
];
