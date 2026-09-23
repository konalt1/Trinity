# Start local MariaDB (if needed) and PHP API on http://127.0.0.1:8080
param(
    [switch]$Detached,
    [switch]$Hidden
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\local-backend.ps1"

if (-not $Hidden) {
    try {
        $Host.UI.RawUI.WindowTitle = "Trinity PHP http://127.0.0.1:8080"
    } catch {
    }
}

if (Test-TrinityPort 3306) {
    Write-Host "MariaDB already listening on :3306"
} else {
    Write-Host "Starting MariaDB on :3306"
}

$alreadyUp = Test-TrinityPort 8080
$openBrowser = -not $Hidden

if ($alreadyUp) {
    Write-Host "PHP already listening on :8080"
} else {
    Write-Host "Starting PHP API on http://127.0.0.1:8080"
}

if ($openBrowser -and $alreadyUp) {
    Write-Host "Opening $($script:TrinityFrontendUrl)"
    Open-TrinityWebFrontend | Out-Null
} elseif ($openBrowser -and -not $Detached) {
    Write-Host "Opening $($script:TrinityFrontendUrl)"
    Start-TrinityWebFrontendOpener
}

Start-TrinityLocalBackend -Detached:$Detached -Hidden:$Hidden

if ($Detached) {
    Write-Host "PHP API listening on http://127.0.0.1:8080"
}

if ($openBrowser -and $Detached -and -not $alreadyUp) {
    Write-Host "Opening $($script:TrinityFrontendUrl)"
    Open-TrinityWebFrontend | Out-Null
}
