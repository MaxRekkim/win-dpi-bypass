$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Version = "v1.0.7"
$ZipUrl = "https://github.com/bol-van/zapret2/releases/download/$Version/zapret2-$Version.zip"
$CacheDir = Join-Path $Root "_cache"
$ZipPath = Join-Path $CacheDir "zapret2-$Version.zip"
$ExtractDir = Join-Path $CacheDir "extract"

New-Item -ItemType Directory -Force -Path $CacheDir, (Join-Path $Root "bin"), (Join-Path $Root "lua"), (Join-Path $Root "files\fake"), (Join-Path $Root "logs") | Out-Null

if (-not (Test-Path $ZipPath)) {
    Write-Host "Downloading zapret2 $Version..."
    Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath
}

if (Test-Path $ExtractDir) {
    Remove-Item -Recurse -Force $ExtractDir
}

Expand-Archive -Path $ZipPath -DestinationPath $ExtractDir -Force
$Src = Join-Path $ExtractDir "zapret2-$Version"

Copy-Item -Force (Join-Path $Src "binaries\windows-x86_64\winws2.exe") (Join-Path $Root "bin\")
Copy-Item -Force (Join-Path $Src "binaries\windows-x86_64\WinDivert.dll") (Join-Path $Root "bin\")
Copy-Item -Force (Join-Path $Src "binaries\windows-x86_64\WinDivert64.sys") (Join-Path $Root "bin\")
Copy-Item -Force (Join-Path $Src "lua\*.lua") (Join-Path $Root "lua\")
Copy-Item -Force (Join-Path $Src "files\fake\*") (Join-Path $Root "files\fake\")

Write-Host "Setup complete. Run run-smart.bat as Administrator."
