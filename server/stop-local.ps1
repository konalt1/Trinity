# Stop PHP/MariaDB only if this stack started them.
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\local-backend.ps1"
Stop-TrinityLocalBackend
Write-Host "Stopped Trinity processes started by the local backend."
