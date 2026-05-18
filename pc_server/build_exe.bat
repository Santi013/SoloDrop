@echo off
setlocal

cd /d "%~dp0"

if not exist ".venv\Scripts\python.exe" (
  py -3 -m venv .venv
)

set "PYTHON=.venv\Scripts\python.exe"

"%PYTHON%" -m pip install --upgrade pip
"%PYTHON%" -m pip install -r requirements.txt pyinstaller

if not exist "config.example.json" (
  echo config.example.json is missing.
  pause
  exit /b 1
)

if exist "dist\SoloDropServer" rmdir /s /q "dist\SoloDropServer"
if exist "build\SoloDropServer" rmdir /s /q "build\SoloDropServer"

"%PYTHON%" -m PyInstaller ^
  --noconfirm ^
  --clean ^
  --onedir ^
  --console ^
  --name SoloDropServer ^
  --add-data "static;static" ^
  --hidden-import fastapi ^
  --hidden-import multipart ^
  --hidden-import qrcode ^
  --hidden-import zeroconf ^
  --hidden-import uvicorn.logging ^
  --hidden-import uvicorn.loops.auto ^
  --hidden-import uvicorn.protocols.http.auto ^
  --hidden-import uvicorn.protocols.websockets.auto ^
  --hidden-import uvicorn.lifespan.on ^
  run_server.py

if errorlevel 1 (
  echo.
  echo PyInstaller build failed.
  pause
  exit /b 1
)

if not exist "dist\SoloDropServer\data" mkdir "dist\SoloDropServer\data"
if not exist "dist\SoloDropServer\data\uploads" mkdir "dist\SoloDropServer\data\uploads"
if not exist "dist\SoloDropServer\data\previews" mkdir "dist\SoloDropServer\data\previews"
if not exist "dist\SoloDropServer\certs" mkdir "dist\SoloDropServer\certs"
copy /Y "config.example.json" "dist\SoloDropServer\config.json" >nul
copy /Y "start_server.bat" "dist\SoloDropServer\start_server.bat" >nul

echo.
echo Build complete:
echo   %CD%\dist\SoloDropServer\SoloDropServer.exe
echo.
pause
