param(
    [switch]$SkipSpeedTest
)

$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Root = Split-Path -Parent $PSScriptRoot
$LogsDir = Join-Path $Root "logs"
New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null
$DiagLog = Join-Path $LogsDir "diagnose.log"

$Lines = New-Object System.Collections.Generic.List[string]
function Write-DiagLine {
    param([string]$Text, [string]$Color = "")
    if ($Color) {
        Write-Host $Text -ForegroundColor $Color
    } else {
        Write-Host $Text
    }
    $Lines.Add($Text)
}

$VersionFile = Join-Path $Root "VERSION"
$Version = if (Test-Path $VersionFile) { (Get-Content $VersionFile -Raw).Trim() } else { "unknown" }
$Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-DiagLine "=== win-dpi-bypass Diagnostics ($Stamp) ==="
Write-DiagLine ("Version                : " + $Version)

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-DiagLine ("Admin privileges       : " + $(if ($IsAdmin) { "YES" } else { "NO (run as Administrator)" }))

$ReqFiles = @(
    "bin\win\winws2.exe",
    "bin\win\WinDivert.dll",
    "bin\win\WinDivert64.sys",
    "bin\win\cygwin1.dll",
    "lua\zapret-lib.lua",
    "lua\zapret-antidpi.lua",
    "lua\zapret-auto.lua",
    "lua\custom-dpi.lua"
)
foreach ($f in $ReqFiles) {
    $ok = Test-Path (Join-Path $Root $f)
    Write-DiagLine ("File {0,-26}: {1}" -f $f, $(if ($ok) { "OK" } else { "MISSING" }))
}

$OldZapret = Get-Service -Name "zapret" -ErrorAction SilentlyContinue
if ($OldZapret) {
    Write-DiagLine "[WARN] Legacy 'zapret' service found ($($OldZapret.Status)). Remove it to avoid conflicts." "Yellow"
}

$OurSvc = Get-Service -Name "win-dpi-bypass" -ErrorAction SilentlyContinue
Write-DiagLine ("Service win-dpi-bypass : " + $(if ($OurSvc) { $OurSvc.Status } else { "Not installed" }))

$WinwsProcs = Get-Process -Name "winws*" -ErrorAction SilentlyContinue
Write-DiagLine ("Running winws procs    : " + $(if ($WinwsProcs) { ($WinwsProcs | ForEach-Object { "$($_.Name)($($_.Id))" }) -join ", " } else { "None" }))

$BrokenIPv6 = Get-NetAdapterBinding -ComponentID ms_tcpip6 | Where-Object { $_.Enabled -eq $true -and $_.Name -notmatch "Tailscale|Loopback" }
if ($BrokenIPv6) {
    Write-DiagLine "[WARN] IPv6 enabled on: $($BrokenIPv6.Name -join ', ') (can cause 15s delays if ISP has no IPv6)." "Yellow"
} else {
    Write-DiagLine "IPv6 check             : Clean"
}

$LogFiles = Get-ChildItem -Path $LogsDir -File -Filter "*.log" -ErrorAction SilentlyContinue
if ($LogFiles) {
    $Summary = ($LogFiles | ForEach-Object { "$($_.Name) ($([math]::Round($_.Length / 1KB, 1)) KB)" }) -join ", "
    Write-DiagLine ("Log files in logs\     : " + $Summary)
} else {
    Write-DiagLine "Log files in logs\     : None yet"
}

Write-DiagLine ""

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($DiagLog, $Lines, $Utf8NoBom)

if (-not $SkipSpeedTest) {
    & (Join-Path $PSScriptRoot "test-strategies.ps1") -LogFile $DiagLog
} else {
    Write-Host "[INFO] Speed test skipped (-SkipSpeedTest)."
    [System.IO.File]::AppendAllLines($DiagLog, @("[INFO] Speed test skipped (-SkipSpeedTest)."), $Utf8NoBom)
}
