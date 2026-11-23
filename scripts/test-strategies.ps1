$ErrorActionPreference = "SilentlyContinue"

$Targets = @(
    @{ Name = "YouTube"; Url = "https://www.youtube.com"; MinBytes = 100000 },
    @{ Name = "Discord App"; Url = "https://discord.com/app"; MinBytes = 10000 },
    @{ Name = "X (Twitter)"; Url = "https://x.com"; MinBytes = 10000 }
)

Write-Host "=== DPI Bypass Speed & Connectivity Check ==="
foreach ($t in $Targets) {
    $out = & curl.exe -s -o NUL -w "%{http_code}|%{size_download}|%{time_total}|%{speed_download}" --max-time 6 $t.Url
    $parts = $out -split "\|"
    $code = $parts[0]
    $size = [int64]$parts[1]
    $time = $parts[2]
    $speedKb = [math]::Round(([double]$parts[3]) / 1024, 1)

    if ($code -eq "200" -and $size -ge $t.MinBytes) {
        Write-Host ("[OK]   {0,-14} HTTP {1} | {2} B | {3} s | {4} KB/s" -f $t.Name, $code, $size, $time, $speedKb) -ForegroundColor Green
    } else {
        Write-Host ("[FAIL] {0,-14} HTTP {1} | {2} B | {3} s | {4} KB/s" -f $t.Name, $code, $size, $time, $speedKb) -ForegroundColor Red
    }
}
