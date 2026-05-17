@echo off
setlocal
title SoloDrop Server

cd /d "%~dp0"

set "SOLODROP_QUIET=0"
if /i "%~1"=="--quiet" set "SOLODROP_QUIET=1"
if /i "%~1"=="/quiet" set "SOLODROP_QUIET=1"

echo.
echo Starting SoloDrop...
echo Server folder: %cd%
echo.

if not exist ".venv\Scripts\python.exe" (
    echo Creating local Python environment...
    python -m venv .venv
    if errorlevel 1 (
        echo.
        echo Failed to create Python environment. Check that Python is installed.
        if "%SOLODROP_QUIET%"=="0" pause
        exit /b 1
    )
)

echo Installing/updating required packages...
".venv\Scripts\python.exe" -m pip install -r requirements.txt
if errorlevel 1 (
    echo.
    echo Failed to install packages.
    if "%SOLODROP_QUIET%"=="0" pause
    exit /b 1
)

echo.
echo SoloDrop is starting.
echo Open this address on this PC:
echo http://127.0.0.1:8765
echo.
echo On iPhone, open:
echo http://YOUR_PC_IP:8765
echo.
echo Keep this window open. Press Ctrl+C to stop the server.
echo.

".venv\Scripts\python.exe" -m uvicorn main:app --host 0.0.0.0 --port 8765

echo.
echo SoloDrop stopped.
if "%SOLODROP_QUIET%"=="0" pause
