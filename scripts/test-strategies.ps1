param(
    [string]$LogFile = ""
)

$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Targets = @(
    @{ Name = "YouTube"; Url = "https://www.youtube.com"; MinBytes = 100000 },
    @{ Name = "Discord App"; Url = "https://discord.com/app"; MinBytes = 10000 },
    @{ Name = "X (Twitter)"; Url = "https://x.com"; MinBytes = 10000 }
)

$LogLines = New-Object System.Collections.Generic.List[string]

function Write-CheckLine {
    param([string]$Text, [string]$Color = "")
    if ($Color) {
        Write-Host $Text -ForegroundColor $Color
    } else {
        Write-Host $Text
    }
    $LogLines.Add($Text)
}

Write-CheckLine "=== DPI Bypass Speed & Connectivity Check ==="
foreach ($t in $Targets) {
    $out = & curl.exe -s -o NUL -w "%{http_code}|%{size_download}|%{time_total}|%{speed_download}" --max-time 6 $t.Url
    $parts = @()
    if ($out) { $parts = $out -split "\|" }

    $code = if ($parts.Count -ge 1 -and $parts[0]) { $parts[0] } else { "000" }
    $size = if ($parts.Count -ge 2 -and $parts[1] -match '^\d+$') { [int64]$parts[1] } else { 0 }
    $time = if ($parts.Count -ge 3 -and $parts[2]) { $parts[2] } else { "0" }
    $speedVal = 0.0
    if ($parts.Count -ge 4) { [void][double]::TryParse($parts[3], [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$speedVal) }
    $speedKb = [math]::Round($speedVal / 1024, 1)

    if ($code -eq "200" -and $size -ge $t.MinBytes) {
        Write-CheckLine ("[OK]   {0,-14} HTTP {1} | {2} B | {3} s | {4} KB/s" -f $t.Name, $code, $size, $time, $speedKb) "Green"
    } else {
        Write-CheckLine ("[FAIL] {0,-14} HTTP {1} | {2} B | {3} s | {4} KB/s" -f $t.Name, $code, $size, $time, $speedKb) "Red"
    }
}

if ($LogFile) {
    $LogParent = Split-Path -Parent $LogFile
    if ($LogParent -and -not (Test-Path $LogParent)) {
        New-Item -ItemType Directory -Force -Path $LogParent | Out-Null
    }
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::AppendAllLines($LogFile, $LogLines, $Utf8NoBom)
}
