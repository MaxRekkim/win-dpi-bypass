$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Winws = Join-Path $Root "bin\win\winws2.exe"
$Sys = Join-Path $Root "bin\win\WinDivert64.sys"

if (-not (Test-Path $Winws) -or -not (Test-Path $Sys)) {
    throw "Missing bin\win\winws2.exe or WinDivert64.sys"
}

try {
    Add-MpPreference -ExclusionPath $Root -ErrorAction Stop
    Write-Host "Added Windows Defender exclusion: $Root"
} catch {
    Write-Host "Skipped Defender exclusion (run as Admin if needed)."
}

Write-Host "Ready. Run run-smart.bat as Administrator."
