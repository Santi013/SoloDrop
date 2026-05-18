@echo off
setlocal

cd /d "%~dp0"

if not exist "dist\SoloDropServer\SoloDropServer.exe" (
  call build_exe.bat
  if errorlevel 1 exit /b 1
)

set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"

if not exist "%ISCC%" (
  echo Inno Setup 6 was not found.
  echo Install it from https://jrsoftware.org/isinfo.php and run this script again.
  pause
  exit /b 1
)

"%ISCC%" "SoloDrop.iss"
if errorlevel 1 (
  echo.
  echo Installer build failed.
  pause
  exit /b 1
)

echo.
echo Installer complete:
echo   %CD%\installer\SoloDropSetup.exe
echo.
pause
