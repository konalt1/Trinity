# Hidden watcher: start local backend when Dota 2 Workshop Tools launches,
# stop PHP and any MariaDB we started when all dota2.exe processes exit.
param(
    [switch]$Install
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\local-backend.ps1"

$taskName = "TrinityToolsBackend"
$pollMs = 2000
$graceMs = 8000

function Install-TrinityToolsWatcher {
    $powershell = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
    $scriptPath = Join-Path $PSScriptRoot "watch-tools.ps1"
    $arg = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""

    $action = New-ScheduledTaskAction -Execute $powershell -Argument $arg
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1) `
        -MultipleInstances IgnoreNew `
        -ExecutionTimeLimit ([TimeSpan]::Zero)
    $settings.Hidden = $true
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
    Start-ScheduledTask -TaskName $taskName
    Write-Host "Registered and started scheduled task '$taskName'."
}

if ($Install) {
    Install-TrinityToolsWatcher
    return
}

$mutex = New-Object System.Threading.Mutex($false, "Global\TrinityToolsBackendWatcher")
if (-not $mutex.WaitOne(0)) {
    return
}

try {
    Write-TrinityWatchLog "watcher started"
    $holdUntilDotaExits = $false
    $dotaGoneSince = $null

    while ($true) {
        $tools = Test-TrinityToolsRunning
        $dota = Test-TrinityDota2Running

        if ($tools) {
            if (-not $holdUntilDotaExits) {
                try {
                    Write-TrinityWatchLog "tools detected, starting backend"
                    Start-TrinityLocalBackend -Detached -Hidden | Out-Null
                    Write-TrinityWatchLog "backend up"
                } catch {
                    Write-TrinityWatchLog "start failed: $($_.Exception.Message)"
                    Start-Sleep -Milliseconds $pollMs
                    continue
                }
            }
            $holdUntilDotaExits = $true
            $dotaGoneSince = $null
        } elseif ($holdUntilDotaExits) {
            if ($dota) {
                $dotaGoneSince = $null
            } elseif ($null -eq $dotaGoneSince) {
                $dotaGoneSince = Get-Date
            } elseif (((Get-Date) - $dotaGoneSince).TotalMilliseconds -ge $graceMs) {
                Write-TrinityWatchLog "dota2 gone, stopping backend"
                try {
                    Stop-TrinityLocalBackend
                } catch {
                    Write-TrinityWatchLog "stop failed: $($_.Exception.Message)"
                }
                $holdUntilDotaExits = $false
                $dotaGoneSince = $null
            }
        }

        Start-Sleep -Milliseconds $pollMs
    }
} finally {
    Write-TrinityWatchLog "watcher stopped"
    $mutex.ReleaseMutex() | Out-Null
    $mutex.Dispose()
}
