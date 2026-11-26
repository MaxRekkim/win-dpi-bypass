$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$LogsDir = Join-Path $Root "logs"
New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null
$UpdateLog = Join-Path $LogsDir "update.log"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-UpdateLog {
    param([string]$Message)
    $Line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $Message
    try {
        [System.IO.File]::AppendAllLines($UpdateLog, @($Line), $Utf8NoBom)
    } catch {}
}

$VersionFile = Join-Path $Root "VERSION"
$LocalVersion = if (Test-Path $VersionFile) { (Get-Content $VersionFile -Raw).Trim() } else { "unknown" }
$Repo = "MaxRekkim/win-dpi-bypass"
$ApiUrl = "https://api.github.com/repos/$Repo/releases/latest"

$Token = $env:GITHUB_TOKEN
if (-not $Token -and (Get-Command gh -ErrorAction SilentlyContinue)) {
    try { $Token = (& gh auth token 2>$null).Trim() } catch {}
}

$Headers = @{ "User-Agent" = "win-dpi-bypass-updater" }
if ($Token) { $Headers["Authorization"] = "Bearer $Token" }

Write-UpdateLog "[INFO] Local version: $LocalVersion"
try {
    $Release = Invoke-RestMethod -Uri $ApiUrl -Headers $Headers -TimeoutSec 10
    $LatestTag = $Release.tag_name
    Write-UpdateLog "[INFO] Latest GitHub release: $LatestTag"
} catch {
    Write-UpdateLog "[WARN] Could not query GitHub Releases API ($($_.Exception.Message))."
    $LatestTag = $null
}

$AutoList = Join-Path $Root "lists\domains-auto.txt"
$AutoBackup = Join-Path $env:TEMP "win-dpi-bypass-domains-auto.bak"
if (Test-Path $AutoList) {
    Copy-Item -Force $AutoList $AutoBackup
}

$ExportCfg = Join-Path $Root "logs-export.path"
$ExportBackup = Join-Path $env:TEMP "win-dpi-bypass-logs-export.bak"
if (Test-Path $ExportCfg) {
    Copy-Item -Force $ExportCfg $ExportBackup
}

$ServiceName = "win-dpi-bypass"
$Svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
$WasRunning = ($null -ne $Svc -and $Svc.Status -eq "Running")
if ($WasRunning) {
    Write-UpdateLog "[INFO] Stopping service $ServiceName..."
    Stop-Service -Name $ServiceName -Force
    Start-Sleep -Seconds 1
}
$WinDivertSvc = Get-Service -Name "WinDivert" -ErrorAction SilentlyContinue
if ($WinDivertSvc -and $WinDivertSvc.Status -eq "Running") {
    Write-UpdateLog "[INFO] Stopping WinDivert driver service..."
    Stop-Service -Name "WinDivert" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

try {
    $GitDir = Join-Path $Root ".git"
    if ((Test-Path $GitDir) -and (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-UpdateLog "[INFO] Updating via git pull --ff-only..."
        Push-Location $Root
        try {
            & git pull --ff-only
            if ($LASTEXITCODE -ne 0) { throw "git pull failed" }
            Write-UpdateLog "[OK] git pull completed."
        } finally {
            Pop-Location
        }
    } else {
        if (-not $Release) {
            throw "No .git folder and GitHub Releases API unavailable. Set GITHUB_TOKEN or make the repo public."
        }
        $Asset = $Release.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
        if (-not $Asset) {
            throw "No .zip asset found in release $LatestTag"
        }
        if ($LocalVersion -eq $LatestTag) {
            Write-UpdateLog "[OK] Already on latest release ($LatestTag)."
            return
        }

        $CacheDir = Join-Path $Root "_cache"
        $TmpDir = Join-Path $CacheDir "update_tmp"
        $ZipPath = Join-Path $CacheDir $Asset.name
        New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null
        if (Test-Path $TmpDir) { Remove-Item -Recurse -Force $TmpDir }

        Write-UpdateLog "[INFO] Downloading $($Asset.name)..."
        $DlHeaders = @{ "User-Agent" = "win-dpi-bypass-updater"; "Accept" = "application/octet-stream" }
        if ($Token) { $DlHeaders["Authorization"] = "Bearer $Token" }
        Invoke-WebRequest -Uri $Asset.url -Headers $DlHeaders -OutFile $ZipPath -TimeoutSec 60

        Expand-Archive -Path $ZipPath -DestinationPath $TmpDir -Force
        Copy-Item -Path (Join-Path $TmpDir "*") -Destination $Root -Recurse -Force
        Remove-Item -Recurse -Force $TmpDir
        Write-UpdateLog "[OK] Updated to $LatestTag"
    }
} catch {
    Write-UpdateLog "[ERROR] Update failed: $($_.Exception.Message)"
    throw
} finally {
    if (Test-Path $AutoBackup) {
        Copy-Item -Force $AutoBackup $AutoList
        Remove-Item -Force $AutoBackup
    }
    if (Test-Path $ExportBackup) {
        Copy-Item -Force $ExportBackup $ExportCfg
        Remove-Item -Force $ExportBackup
    }
    if ($WasRunning) {
        Write-UpdateLog "[INFO] Reinstalling and starting service $ServiceName..."
        & cmd.exe /c "`"$(Join-Path $Root 'service-install.bat')`" --nopause"
    }
}
