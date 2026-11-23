@echo off
chcp 65001 > nul
net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Run this script as Administrator!
    pause
    exit /b 1
)

sc stop "win-dpi-bypass"
sc delete "win-dpi-bypass"
sc stop "WinDivert" >nul 2>&1
sc delete "WinDivert" >nul 2>&1
echo [INFO] Service removed.
pause
