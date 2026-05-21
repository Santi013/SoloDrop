@echo off
title Stop SoloDrop
set "SOLODROP_QUIET=0"
if /i "%~1"=="--quiet" set "SOLODROP_QUIET=1"
if /i "%~1"=="/quiet" set "SOLODROP_QUIET=1"

echo Stopping SoloDrop on port 8000...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like '* -File *SoloDrop Tray.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }" >nul 2>nul

for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8000" ^| findstr "LISTENING"') do (
    taskkill /PID %%a /F
)

echo Done.
if "%SOLODROP_QUIET%"=="0" pause
