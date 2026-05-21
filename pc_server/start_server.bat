@echo off
setlocal

cd /d "%~dp0"

set "SOLODROP_QUIET=0"
if /i "%~1"=="--quiet" set "SOLODROP_QUIET=1"
if /i "%~1"=="/quiet" set "SOLODROP_QUIET=1"

echo SoloDrop Server
echo.

if exist "SoloDropServer.exe" (
  "SoloDropServer.exe"
) else if exist "dist\SoloDropServer\SoloDropServer.exe" (
  "dist\SoloDropServer\SoloDropServer.exe"
) else (
  call :ensure_dev_environment
  if errorlevel 1 goto failed
  ".venv\Scripts\python.exe" "run_server.py"
)

if errorlevel 1 goto failed
exit /b 0

:ensure_dev_environment
if not exist "requirements.txt" (
  echo requirements.txt was not found in %CD%.
  exit /b 1
)

if not exist ".venv\Scripts\python.exe" (
  echo Creating local Python environment...
  py -3 -m venv .venv
  if errorlevel 1 (
    echo Could not create .venv. Install Python 3.10+ and make sure the py launcher is available.
    exit /b 1
  )
)

".venv\Scripts\python.exe" -c "import fastapi, uvicorn, multipart, qrcode, zeroconf; from PIL import Image; import pillow_heif" >nul 2>nul
if errorlevel 1 (
  echo Installing SoloDrop server dependencies...
  ".venv\Scripts\python.exe" -m pip install -r requirements.txt
  if errorlevel 1 (
    echo Dependency installation failed. Check your internet connection and Python installation.
    exit /b 1
  )
)

exit /b 0

:failed
echo.
echo SoloDrop Server stopped with an error.
if "%SOLODROP_QUIET%"=="0" pause
exit /b 1
