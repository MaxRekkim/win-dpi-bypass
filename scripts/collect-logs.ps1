param(
    [string]$OutputDir = "",
    [switch]$Quick
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Root = Split-Path -Parent $PSScriptRoot
$LogsDir = Join-Path $Root "logs"
New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Resolve-ExportDirectory {
    param([string]$CliPath)

    $candidate = ""
    if ($CliPath -and $CliPath.Trim()) {
        $candidate = $CliPath.Trim().Trim('"')
    } elseif ($env:DPI_LOGS_DIR -and $env:DPI_LOGS_DIR.Trim()) {
        $candidate = $env:DPI_LOGS_DIR.Trim().Trim('"')
    } else {
        $cfgFile = Join-Path $Root "logs-export.path"
        if (Test-Path $cfgFile) {
            $lines = Get-Content -Path $cfgFile -Encoding UTF8 -ErrorAction SilentlyContinue
            foreach ($line in $lines) {
                $trimmed = $line.Trim()
                if ($trimmed -and -not $trimmed.StartsWith("#") -and -not $trimmed.StartsWith(";")) {
                    $candidate = $trimmed.Trim('"')
                    break
                }
            }
        }
    }

    if (-not $candidate) {
        $desktop = [Environment]::GetFolderPath("Desktop")
        if ($desktop) {
            $candidate = $desktop
        } elseif ($env:USERPROFILE) {
            $candidate = Join-Path $env:USERPROFILE "Desktop"
        } else {
            $candidate = $LogsDir
        }
    }

    if (-not [System.IO.Path]::IsPathRooted($candidate)) {
        $candidate = Join-Path $Root $candidate
    }
    return [System.IO.Path]::GetFullPath($candidate)
}

function Copy-LogFileSafe {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [int64]$MaxBytes = 2097152
    )
    if (-not (Test-Path $SourcePath)) { return }
    $srcStream = $null
    $dstStream = $null
    try {
        $share = [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
        $srcStream = [System.IO.File]::Open($SourcePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, $share)
        $dstStream = [System.IO.File]::Create($DestPath)
        $len = $srcStream.Length
        if ($len -gt $MaxBytes) {
            $header = [System.Text.Encoding]::UTF8.GetBytes("[truncated to last 2 MB of $len bytes]`r`n")
            $dstStream.Write($header, 0, $header.Length)
            [void]$srcStream.Seek($len - $MaxBytes, [System.IO.SeekOrigin]::Begin)
        }
        $srcStream.CopyTo($dstStream)
    } catch {
        [System.IO.File]::WriteAllText($DestPath, "[WARN] Failed to read $SourcePath : $($_.Exception.Message)`r`n", $Utf8NoBom)
    } finally {
        if ($dstStream) { $dstStream.Dispose() }
        if ($srcStream) { $srcStream.Dispose() }
    }
}

function Copy-LogTailLines {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [int]$MaxLines = 150
    )
    if (-not (Test-Path $SourcePath)) { return }
    $srcStream = $null
    $reader = $null
    try {
        $share = [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
        $srcStream = [System.IO.File]::Open($SourcePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, $share)
        $tailWindow = 262144
        if ($srcStream.Length -gt $tailWindow) {
            [void]$srcStream.Seek($srcStream.Length - $tailWindow, [System.IO.SeekOrigin]::Begin)
        }
        $reader = New-Object System.IO.StreamReader($srcStream, [System.Text.Encoding]::UTF8, $true)
        $queue = New-Object System.Collections.Generic.Queue[string]
        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            $queue.Enqueue($line)
            if ($queue.Count -gt $MaxLines) {
                [void]$queue.Dequeue()
            }
        }
        [System.IO.File]::WriteAllLines($DestPath, $queue.ToArray(), $Utf8NoBom)
    } catch {
        [System.IO.File]::WriteAllText($DestPath, "[WARN] Failed to tail $SourcePath : $($_.Exception.Message)`r`n", $Utf8NoBom)
    } finally {
        if ($reader) { $reader.Dispose() }
        if ($srcStream) { $srcStream.Dispose() }
    }
}

$DestDir = Resolve-ExportDirectory -CliPath $OutputDir
try {
    New-Item -ItemType Directory -Force -Path $DestDir -ErrorAction Stop | Out-Null
} catch {
    Write-Host "[ERROR] Cannot create export directory '$DestDir': $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$LatestDir = Join-Path $LogsDir "latest"
if (Test-Path $LatestDir) {
    Remove-Item -Path $LatestDir -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Force -Path $LatestDir | Out-Null

Write-Host "[INFO] Aggregating logs into $LatestDir..."

$DiagScript = Join-Path $PSScriptRoot "diagnose.ps1"
if (Test-Path $DiagScript) {
    if ($Quick) {
        & $DiagScript -SkipSpeedTest
    } else {
        & $DiagScript
    }
    $DiagLog = Join-Path $LogsDir "diagnose.log"
    if (Test-Path $DiagLog) {
        Copy-LogFileSafe -SourcePath $DiagLog -DestPath (Join-Path $LatestDir "diagnose.log")
    }
}

$NetReport = New-Object System.Collections.Generic.List[string]
$NetReport.Add("=== Service & Driver Status ===")
$NetReport.Add((& sc.exe qc win-dpi-bypass 2>&1 | Out-String).TrimEnd())
$SvcReg = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\win-dpi-bypass" -ErrorAction SilentlyContinue
if ($SvcReg -and $SvcReg.ImagePath) {
    $NetReport.Add("Registry ImagePath: $($SvcReg.ImagePath)")
}
$NetReport.Add("")
$NetReport.Add((& sc.exe query win-dpi-bypass 2>&1 | Out-String).TrimEnd())
$NetReport.Add("")
$NetReport.Add((& sc.exe query WinDivert 2>&1 | Out-String).TrimEnd())
$NetReport.Add("")
$NetReport.Add("=== Running winws Processes ===")
$Procs = Get-Process -Name "winws*" -ErrorAction SilentlyContinue | Select-Object Name, Id, StartTime, CPU, WorkingSet64
if ($Procs) {
    $NetReport.Add(($Procs | Format-Table -AutoSize | Out-String).TrimEnd())
} else {
    $NetReport.Add("None")
}
$NetReport.Add("")
$NetReport.Add("=== Active Network Adapters ===")
$NetReport.Add((Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object Name, Status, LinkSpeed, InterfaceDescription | Format-Table -AutoSize | Out-String).TrimEnd())
$NetReport.Add("=== IPv6 Bindings (ms_tcpip6) ===")
$NetReport.Add((Get-NetAdapterBinding -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue | Select-Object Name, Enabled | Format-Table -AutoSize | Out-String).TrimEnd())
$NetReport.Add("=== DNS Client Servers ===")
$NetReport.Add((Get-DnsClientServerAddress -AddressFamily IPv4,IPv6 -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddresses.Count -gt 0 } | Select-Object InterfaceAlias, AddressFamily, ServerAddresses | Format-Table -AutoSize | Out-String).TrimEnd())
$NetReport.Add("=== Recent System Events (win-dpi-bypass / WinDivert) ===")
try {
    $Events = Get-WinEvent -FilterHashtable @{ LogName = "System" } -MaxEvents 200 -ErrorAction SilentlyContinue |
        Where-Object { $_.Message -match "win-dpi-bypass|WinDivert" } |
        Select-Object -First 25 TimeCreated, Id, LevelDisplayName, ProviderName, Message
    if ($Events) {
        $NetReport.Add(($Events | Format-List | Out-String).TrimEnd())
    } else {
        $NetReport.Add("No matching events in last 200 System log entries.")
    }
} catch {
    $NetReport.Add("Event log read skipped: $($_.Exception.Message)")
}
[System.IO.File]::WriteAllLines((Join-Path $LatestDir "network-and-service.txt"), $NetReport, $Utf8NoBom)

$ExistingLogs = Get-ChildItem -Path $LogsDir -File -Filter "*.log" -ErrorAction SilentlyContinue
foreach ($lf in $ExistingLogs) {
    if ($lf.Name -eq "diagnose.log") { continue }
    Copy-LogFileSafe -SourcePath $lf.FullName -DestPath (Join-Path $LatestDir $lf.Name)
}

$AutoDomains = Join-Path $Root "lists\domains-auto.txt"
if (Test-Path $AutoDomains) {
    Copy-LogFileSafe -SourcePath $AutoDomains -DestPath (Join-Path $LatestDir "domains-auto.txt")
}

if ($env:APPDATA) {
    $DiscordLogs = Join-Path $env:APPDATA "discord\logs"
    if (Test-Path $DiscordLogs) {
        $Rjs = Join-Path $DiscordLogs "renderer_js.log"
        $Rtc = Join-Path $DiscordLogs "discord-webrtc_0"
        if (Test-Path $Rjs) {
            Copy-LogTailLines -SourcePath $Rjs -DestPath (Join-Path $LatestDir "discord-renderer-tail.log") -MaxLines 150
        }
        if (Test-Path $Rtc) {
            Copy-LogTailLines -SourcePath $Rtc -DestPath (Join-Path $LatestDir "discord-webrtc-tail.log") -MaxLines 150
        }
    }
}

$VersionFile = Join-Path $Root "VERSION"
$Version = if (Test-Path $VersionFile) { (Get-Content $VersionFile -Raw).Trim() } else { "unknown" }
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$ZipName = "win-dpi-bypass-logs-$Stamp.zip"
$DestZip = Join-Path $DestDir $ZipName

$Collected = Get-ChildItem -Path $LatestDir -File | Sort-Object Name
$Summary = New-Object System.Collections.Generic.List[string]
$Summary.Add("win-dpi-bypass log bundle")
$Summary.Add("Generated : " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
$Summary.Add("Version   : $Version")
$Summary.Add("OS        : " + [System.Environment]::OSVersion.VersionString)
$Summary.Add("Install   : $Root")
$Summary.Add("Archive   : $DestZip")
$Summary.Add("")
$Summary.Add("Files included:")
foreach ($f in $Collected) {
    $Summary.Add(("  - {0,-30} {1,8} KB" -f $f.Name, [math]::Round($f.Length / 1KB, 1)))
}
[System.IO.File]::WriteAllLines((Join-Path $LatestDir "summary.txt"), $Summary, $Utf8NoBom)

if (Test-Path $DestZip) { Remove-Item -Force $DestZip -ErrorAction SilentlyContinue }
try {
    Compress-Archive -Path (Join-Path $LatestDir "*") -DestinationPath $DestZip -Force -ErrorAction Stop
} catch {
    Write-Host "[ERROR] Failed to create archive '$DestZip': $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $DestZip)) {
    Write-Host "[ERROR] Archive was not created at $DestZip" -ForegroundColor Red
    exit 1
}

[System.IO.File]::WriteAllLines((Join-Path $LogsDir "last-export.txt"), @("$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $DestZip"), $Utf8NoBom)

$ZipSizeKb = [math]::Round((Get-Item $DestZip).Length / 1KB, 1)
Write-Host ""
Write-Host "[OK] Centralized logs folder : $LatestDir" -ForegroundColor Green
Write-Host "[OK] Exported archive        : $DestZip ($ZipSizeKb KB)" -ForegroundColor Green
