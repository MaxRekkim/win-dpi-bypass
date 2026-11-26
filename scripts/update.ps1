$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
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

Write-Host "[INFO] Local version: $LocalVersion"
try {
    $Release = Invoke-RestMethod -Uri $ApiUrl -Headers $Headers -TimeoutSec 10
    $LatestTag = $Release.tag_name
    Write-Host "[INFO] Latest GitHub release: $LatestTag"
} catch {
    Write-Host "[WARN] Could not query GitHub Releases API ($($_.Exception.Message))."
    $LatestTag = $null
}

$AutoList = Join-Path $Root "lists\domains-auto.txt"
$AutoBackup = Join-Path $env:TEMP "win-dpi-bypass-domains-auto.bak"
if (Test-Path $AutoList) {
    Copy-Item -Force $AutoList $AutoBackup
}

$ServiceName = "win-dpi-bypass"
$Svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
$WasRunning = ($null -ne $Svc -and $Svc.Status -eq "Running")
if ($WasRunning) {
    Write-Host "[INFO] Stopping service $ServiceName..."
    Stop-Service -Name $ServiceName -Force
    Start-Sleep -Seconds 1
}

try {
    $GitDir = Join-Path $Root ".git"
    if ((Test-Path $GitDir) -and (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "[INFO] Updating via git pull --ff-only..."
        Push-Location $Root
        try {
            & git pull --ff-only
            if ($LASTEXITCODE -ne 0) { throw "git pull failed" }
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
            Write-Host "[OK] Already on latest release ($LatestTag)."
            return
        }

        $CacheDir = Join-Path $Root "_cache"
        $TmpDir = Join-Path $CacheDir "update_tmp"
        $ZipPath = Join-Path $CacheDir $Asset.name
        New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null
        if (Test-Path $TmpDir) { Remove-Item -Recurse -Force $TmpDir }

        Write-Host "[INFO] Downloading $($Asset.name)..."
        $DlHeaders = @{ "User-Agent" = "win-dpi-bypass-updater"; "Accept" = "application/octet-stream" }
        if ($Token) { $DlHeaders["Authorization"] = "Bearer $Token" }
        Invoke-WebRequest -Uri $Asset.url -Headers $DlHeaders -OutFile $ZipPath -TimeoutSec 60

        Expand-Archive -Path $ZipPath -DestinationPath $TmpDir -Force
        Copy-Item -Path (Join-Path $TmpDir "*") -Destination $Root -Recurse -Force
        Remove-Item -Recurse -Force $TmpDir
        Write-Host "[OK] Updated to $LatestTag"
    }
} finally {
    if (Test-Path $AutoBackup) {
        Copy-Item -Force $AutoBackup $AutoList
        Remove-Item -Force $AutoBackup
    }
    if ($WasRunning) {
        Write-Host "[INFO] Reinstalling and starting service $ServiceName..."
        & cmd.exe /c "`"$(Join-Path $Root 'service-install.bat')`" --nopause"
    }
}
