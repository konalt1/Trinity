# Trinity warmup HUD ability test runner.
# Launches Dota 2, auto-starts 10 warmup cycles at host_timescale 10, parses console.log.

$ErrorActionPreference = "Stop"

$DotaExe = "D:\SteamLibrary\steamapps\common\dota 2 beta\game\bin\win64\dota2.exe"
$ConsoleLog = "D:\Trinity\tools\hud-test.log"
$AutoCfg = "D:\SteamLibrary\steamapps\common\dota 2 beta\game\dota\cfg\trinity_hud_test_auto.cfg"
$AutoTestLua = "D:\Trinity\Game\scripts\vscripts\autotest_config.lua"
$Cycles = 10
$TimeoutSec = 300

if (-not (Test-Path $DotaExe)) {
    throw "dota2.exe not found: $DotaExe"
}

$cfgDir = Split-Path $AutoCfg -Parent
if (-not (Test-Path $cfgDir)) {
    New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null
}

# Reserved for manual debugging; launch is done via +dota_launch_custom_game.
@"
host_timescale 10
jointeam good
"@ | Set-Content -Path $AutoCfg -Encoding ASCII

@"
return {
    auto_hud_test = true,
    cycles = $Cycles,
}
"@ | Set-Content -Path $AutoTestLua -Encoding UTF8

$logMarker = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "Starting Trinity HUD test ($Cycles cycles, host_timescale 10)..."
Write-Host "Log marker: $logMarker"

$SteamExe = "C:\Program Files (x86)\Steam\steam.exe"
if (-not (Test-Path $SteamExe)) {
    throw "steam.exe not found: $SteamExe"
}

# +dota_launch_custom_game must be the last launch tokens (addon + map).
$args = @(
    "-applaunch", "570",
    "-novid",
    "-console",
    "+sv_cheats", "1",
    "+dota_launch_custom_game", "trinity", "new2"
)

$proc = Start-Process -FilePath $SteamExe -ArgumentList $args -PassThru
$deadline = (Get-Date).AddSeconds($TimeoutSec)
$results = @()
$seenCycles = @{}
$allDone = $false

while ((Get-Date) -lt $deadline) {
    if ($proc.HasExited) {
        break
    }

    if (Test-Path $ConsoleLog) {
        $lines = Get-Content -Path $ConsoleLog -Tail 400 -ErrorAction SilentlyContinue
        foreach ($line in $lines) {
            if ($line -match '\[TrinityHudTest\] CYCLE (\d+)/(\d+) (PASS|FAIL) visible=(\d+) total=(\d+)') {
                $cycle = [int]$Matches[1]
                if (-not $seenCycles.ContainsKey($cycle)) {
                    $seenCycles[$cycle] = $true
                    $results += [pscustomobject]@{
                        Cycle = $cycle
                        Status = $Matches[3]
                        Visible = [int]$Matches[4]
                        Total = [int]$Matches[5]
                        Line = $line
                    }
                    Write-Host $line
                }
            }
            if ($line -match '\[TrinityHudTest\] ALL DONE passed=(\d+) failed=(\d+)') {
                $allDone = $true
                Write-Host $line
                break
            }
        }
    }

    if ($allDone) {
        break
    }

    Start-Sleep -Seconds 2
}

if (-not $proc.HasExited) {
    Write-Host "Test finished or timed out; stopping Dota..."
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
}

if (Test-Path $AutoTestLua) {
    Remove-Item $AutoTestLua -Force
}

Write-Host ""
Write-Host "=== Summary ==="
if ($results.Count -eq 0) {
    Write-Host "No cycle results found in console.log. Open console.log manually:"
    Write-Host $ConsoleLog
    exit 2
}

$passed = @($results | Where-Object { $_.Status -eq "PASS" }).Count
$failed = @($results | Where-Object { $_.Status -eq "FAIL" }).Count
Write-Host "Cycles logged: $($results.Count) / $Cycles"
Write-Host "PASS: $passed"
Write-Host "FAIL: $failed"

$results | Sort-Object Cycle | Format-Table -AutoSize

if ($failed -gt 0 -or $results.Count -lt $Cycles) {
    exit 1
}

exit 0
