@echo off
chcp 65001 > nul
cd /d "%~dp0"

net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Run this script as Administrator!
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\update.ps1"
if errorlevel 1 (
    echo [ERROR] Update failed.
    pause
    exit /b 1
)

echo [OK] Update finished.
pause
