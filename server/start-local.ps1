# Start local MariaDB (if needed) and PHP API on http://127.0.0.1:8080
$ErrorActionPreference = "Stop"
try {
    $Host.UI.RawUI.WindowTitle = "Trinity PHP http://127.0.0.1:8080"
} catch {
}

$serverRoot = $PSScriptRoot
$phpDir = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\PHP.PHP.8.4_Microsoft.Winget.Source_8wekyb3d8bbwe"
$php = Join-Path $phpDir "php.exe"
$mysqld = "C:\Program Files\MariaDB 12.3\bin\mysqld.exe"
$defaults = "C:\Program Files\MariaDB 12.3\data\my.ini"

function Test-Port([int]$Port) {
    return [bool](netstat -ano | Select-String ":$Port\s+.+\s+LISTENING")
}

if (-not (Test-Path -LiteralPath $php)) {
    throw "php.exe not found: $php"
}

if (-not (Test-Port 3306)) {
    if (-not (Test-Path -LiteralPath $mysqld)) {
        throw "mysqld.exe not found: $mysqld"
    }
    Write-Host "Starting MariaDB on :3306"
    Start-Process -FilePath $mysqld -ArgumentList "--defaults-file=`"$defaults`"" -WindowStyle Hidden
    $tries = 0
    while (-not (Test-Port 3306) -and $tries -lt 20) {
        Start-Sleep -Milliseconds 250
        $tries++
    }
    if (-not (Test-Port 3306)) {
        throw "MariaDB did not start on :3306"
    }
} else {
    Write-Host "MariaDB already listening on :3306"
}

if (Test-Port 8080) {
    Write-Host "PHP already listening on :8080"
    exit 0
}

$ext = Join-Path $phpDir "ext"
$public = Join-Path $serverRoot "public"
$router = Join-Path $public "index.php"
Write-Host "Starting PHP API on http://127.0.0.1:8080"
Set-Location $serverRoot
& $php -d "extension_dir=$ext" -d extension=pdo_mysql -S 127.0.0.1:8080 -t $public $router
