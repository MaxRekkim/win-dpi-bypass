@echo off
chcp 65001 > nul
cd /d "%~dp0"

set "OUTDIR="
set "QUICK="
set "NOPAUSE="

:parse_args
if "%~1"=="" goto run_script
if /i "%~1"=="--nopause" (
    set "NOPAUSE=1"
) else if /i "%~1"=="--quick" (
    set "QUICK=-Quick"
) else (
    set "OUTDIR=%~1"
)
shift
goto parse_args

:run_script
if not defined OUTDIR goto run_default
if "%OUTDIR:~-1%"=="\" set "OUTDIR=%OUTDIR%."
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\collect-logs.ps1" -OutputDir "%OUTDIR%" %QUICK%
goto done

:run_default
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\collect-logs.ps1" %QUICK%

:done
set "RC=%ERRORLEVEL%"

if not "%NOPAUSE%"=="1" pause
exit /b %RC%
