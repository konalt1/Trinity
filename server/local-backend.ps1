# Shared start/stop helpers for the local PHP + MariaDB stack.
$ErrorActionPreference = "Stop"

$script:TrinityServerRoot = $PSScriptRoot
$script:TrinityRuntimePath = Join-Path $PSScriptRoot ".local-runtime.json"
$script:TrinityLogDir = Join-Path $PSScriptRoot "logs"
$script:TrinityWatchLog = Join-Path $script:TrinityLogDir "watch-tools.log"

$script:TrinityPhpDir = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\PHP.PHP.8.4_Microsoft.Winget.Source_8wekyb3d8bbwe"
$script:TrinityPhp = Join-Path $script:TrinityPhpDir "php.exe"
$script:TrinityMysqld = "C:\Program Files\MariaDB 12.3\bin\mysqld.exe"
$script:TrinityMyIni = "C:\Program Files\MariaDB 12.3\data\my.ini"

function Test-TrinityPort([int]$Port) {
    $client = $null
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect("127.0.0.1", $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne(250, $false)) {
            return $false
        }
        $client.EndConnect($iar)
        return $true
    } catch {
        return $false
    } finally {
        if ($client) {
            $client.Close()
        }
    }
}

function Wait-TrinityPort([int]$Port, [int]$Tries = 40) {
    $n = 0
    while (-not (Test-TrinityPort $Port) -and $n -lt $Tries) {
        Start-Sleep -Milliseconds 250
        $n++
    }
    return (Test-TrinityPort $Port)
}

$script:TrinityFrontendUrl = "http://127.0.0.1:8080/"

function Open-TrinityWebFrontend {
    param([switch]$Wait)
    if ($Wait -and -not (Wait-TrinityPort 8080 80)) {
        return $false
    }
    if (-not (Test-TrinityPort 8080)) {
        return $false
    }
    Start-Process $script:TrinityFrontendUrl
    return $true
}

function Start-TrinityWebFrontendOpener {
    $backend = Join-Path $PSScriptRoot "local-backend.ps1"
    $command = ". '$backend'; Open-TrinityWebFrontend -Wait | Out-Null"
    $powershell = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
    Start-Process -FilePath $powershell -WindowStyle Hidden -ArgumentList @(
        "-NoLogo",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-Command", $command
    ) | Out-Null
}

function Get-TrinityRuntime {
    if (-not (Test-Path -LiteralPath $script:TrinityRuntimePath)) {
        return [pscustomobject]@{
            phpPid       = $null
            phpStarted   = $false
            mariaPid     = $null
            mariaStarted = $false
        }
    }
    try {
        $raw = Get-Content -LiteralPath $script:TrinityRuntimePath -Raw -ErrorAction Stop
        $data = $raw | ConvertFrom-Json
        return [pscustomobject]@{
            phpPid       = $data.phpPid
            phpStarted   = [bool]$data.phpStarted
            mariaPid     = $data.mariaPid
            mariaStarted = [bool]$data.mariaStarted
        }
    } catch {
        return [pscustomobject]@{
            phpPid       = $null
            phpStarted   = $false
            mariaPid     = $null
            mariaStarted = $false
        }
    }
}

function Save-TrinityRuntime($Runtime) {
    ($Runtime | ConvertTo-Json) | Set-Content -LiteralPath $script:TrinityRuntimePath -Encoding UTF8
}

function Test-TrinityPid([Nullable[int]]$ProcessId, [string[]]$Names) {
    if ($null -eq $ProcessId -or $ProcessId -le 0) {
        return $false
    }
    $proc = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if (-not $proc) {
        return $false
    }
    return $Names -contains $proc.ProcessName
}

function Stop-TrinityPid([Nullable[int]]$ProcessId, [string[]]$Names) {
    if (-not (Test-TrinityPid $ProcessId $Names)) {
        return
    }
    & taskkill.exe /PID $ProcessId /T /F 2>$null | Out-Null
}

function Find-TrinityPhpProcess {
    foreach ($proc in @(Get-CimInstance Win32_Process -Filter "Name = 'php.exe'" -ErrorAction SilentlyContinue)) {
        $cmd = [string]$proc.CommandLine
        if ($cmd -match '127\.0\.0\.1:8080') {
            return $proc
        }
    }
    return $null
}

function Find-TrinityMysqldProcess {
    foreach ($proc in @(Get-CimInstance Win32_Process -Filter "Name = 'mysqld.exe'" -ErrorAction SilentlyContinue)) {
        $exe = [string]$proc.ExecutablePath
        $cmd = [string]$proc.CommandLine
        if ($exe -eq $script:TrinityMysqld -or $cmd -match [regex]::Escape($script:TrinityMyIni)) {
            return $proc
        }
    }
    return $null
}

function Write-TrinityWatchLog([string]$Message) {
    if (-not (Test-Path -LiteralPath $script:TrinityLogDir)) {
        New-Item -ItemType Directory -Path $script:TrinityLogDir | Out-Null
    }
    $line = "[{0:yyyy-MM-dd HH:mm:ss}] {1}" -f (Get-Date), $Message
    Add-Content -LiteralPath $script:TrinityWatchLog -Value $line -Encoding UTF8
    if ((Test-Path -LiteralPath $script:TrinityWatchLog) -and ((Get-Item -LiteralPath $script:TrinityWatchLog).Length -gt 256KB)) {
        $kept = Get-Content -LiteralPath $script:TrinityWatchLog -Tail 200
        $kept | Set-Content -LiteralPath $script:TrinityWatchLog -Encoding UTF8
    }
}

function Get-TrinityDota2Processes {
    return @(Get-CimInstance Win32_Process -Filter "Name = 'dota2.exe'" -ErrorAction SilentlyContinue)
}

function Test-TrinityDota2Running {
    return [bool](Get-Process -Name dota2 -ErrorAction SilentlyContinue)
}

function Test-TrinityToolsRunning {
    foreach ($proc in (Get-TrinityDota2Processes)) {
        $cmd = [string]$proc.CommandLine
        if ($cmd -match '(?i)(?:^|\s)-tools(?:\s|$)') {
            return $true
        }
    }
    return $false
}

function Start-TrinityLocalBackend {
    param(
        [switch]$Detached,
        [switch]$Hidden
    )

    $runtime = Get-TrinityRuntime
    $window = [System.Diagnostics.ProcessWindowStyle]::Normal
    if ($Hidden) {
        $window = [System.Diagnostics.ProcessWindowStyle]::Hidden
    }

    if (-not (Test-Path -LiteralPath $script:TrinityPhp)) {
        throw "php.exe not found: $($script:TrinityPhp)"
    }

    if (Test-TrinityPort 3306) {
        if (-not (Test-TrinityPid $runtime.mariaPid @("mysqld"))) {
            $ownedMaria = Find-TrinityMysqldProcess
            if ($ownedMaria) {
                $runtime.mariaPid = [int]$ownedMaria.ProcessId
                $runtime.mariaStarted = $true
            } else {
                $runtime.mariaStarted = $false
                $runtime.mariaPid = $null
            }
        }
    } else {
        if (-not (Test-Path -LiteralPath $script:TrinityMysqld)) {
            throw "mysqld.exe not found: $($script:TrinityMysqld)"
        }
        $maria = Start-Process -FilePath $script:TrinityMysqld -ArgumentList "--defaults-file=`"$($script:TrinityMyIni)`"" -WindowStyle Hidden -PassThru
        if (-not (Wait-TrinityPort 3306)) {
            throw "MariaDB did not start on :3306"
        }
        $runtime.mariaPid = $maria.Id
        $runtime.mariaStarted = $true
    }

    if (Test-TrinityPort 8080) {
        if (-not (Test-TrinityPid $runtime.phpPid @("php"))) {
            $owned = Find-TrinityPhpProcess
            if ($owned) {
                $runtime.phpPid = [int]$owned.ProcessId
                $runtime.phpStarted = $true
            } else {
                $runtime.phpStarted = $false
                $runtime.phpPid = $null
            }
        }
        Save-TrinityRuntime $runtime
        return $runtime
    }

    $ext = Join-Path $script:TrinityPhpDir "ext"
    $public = Join-Path $script:TrinityServerRoot "public"
    $router = Join-Path $public "index.php"
    $phpArgs = @(
        "-d", "extension_dir=$ext",
        "-d", "extension=pdo_mysql",
        "-d", "upload_max_filesize=64M",
        "-d", "post_max_size=64M",
        "-S", "127.0.0.1:8080",
        "-t", $public,
        $router
    )

    if ($Detached) {
        $phpProc = Start-Process -FilePath $script:TrinityPhp -ArgumentList $phpArgs -WorkingDirectory $script:TrinityServerRoot -WindowStyle $window -PassThru
        if (-not (Wait-TrinityPort 8080 40)) {
            throw "PHP did not start on :8080"
        }
        $runtime.phpPid = $phpProc.Id
        $runtime.phpStarted = $true
        Save-TrinityRuntime $runtime
        return $runtime
    }

    Save-TrinityRuntime $runtime
    Set-Location $script:TrinityServerRoot
    & $script:TrinityPhp @phpArgs
}

function Stop-TrinityLocalBackend {
    $runtime = Get-TrinityRuntime
    if ($runtime.phpStarted) {
        Stop-TrinityPid $runtime.phpPid @("php")
    }
    if ($runtime.mariaStarted) {
        Stop-TrinityPid $runtime.mariaPid @("mysqld")
    }
    if (Test-Path -LiteralPath $script:TrinityRuntimePath) {
        Remove-Item -LiteralPath $script:TrinityRuntimePath -Force
    }
}
