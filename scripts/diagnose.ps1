$ErrorActionPreference = "SilentlyContinue"

$Root = Split-Path -Parent $PSScriptRoot
Write-Host "=== win-dpi-bypass Diagnostics ==="

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host ("Admin privileges : " + $(if ($IsAdmin) { "YES" } else { "NO (run as Administrator)" }))

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
    Write-Host ("File {0,-26}: {1}" -f $f, $(if ($ok) { "OK" } else { "MISSING" }))
}

$OldZapret = Get-Service -Name "zapret" -ErrorAction SilentlyContinue
if ($OldZapret) {
    Write-Host "[WARN] Legacy 'zapret' service found ($($OldZapret.Status)). Remove it to avoid conflicts." -ForegroundColor Yellow
}

$OurSvc = Get-Service -Name "win-dpi-bypass" -ErrorAction SilentlyContinue
Write-Host ("Service win-dpi-bypass : " + $(if ($OurSvc) { $OurSvc.Status } else { "Not installed" }))

$WinwsProcs = Get-Process -Name "winws*" -ErrorAction SilentlyContinue
Write-Host ("Running winws procs    : " + $(if ($WinwsProcs) { ($WinwsProcs | ForEach-Object { "$($_.Name)($($_.Id))" }) -join ", " } else { "None" }))

$BrokenIPv6 = Get-NetAdapterBinding -ComponentID ms_tcpip6 | Where-Object { $_.Enabled -eq $true -and $_.Name -notmatch "Tailscale|Loopback" }
if ($BrokenIPv6) {
    Write-Host "[WARN] IPv6 enabled on: $($BrokenIPv6.Name -join ', ') (can cause 15s delays if ISP has no IPv6)." -ForegroundColor Yellow
} else {
    Write-Host "IPv6 check             : Clean"
}

Write-Host ""
& (Join-Path $PSScriptRoot "test-strategies.ps1")
