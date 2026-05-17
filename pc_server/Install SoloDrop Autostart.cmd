@echo off
setlocal

set "APP_DIR=%~dp0"
set "STARTUP_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "SHORTCUT=%STARTUP_DIR%\SoloDrop.lnk"
set "TARGET=%APP_DIR%Start SoloDrop Hidden.vbs"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$Shell = New-Object -ComObject WScript.Shell; $Shortcut = $Shell.CreateShortcut($env:SHORTCUT); $Shortcut.TargetPath = Join-Path $env:WINDIR 'System32\wscript.exe'; $Shortcut.Arguments = ('""' + $env:TARGET + '""'); $Shortcut.WorkingDirectory = $env:APP_DIR; $Shortcut.WindowStyle = 7; $Shortcut.Description = 'Start SoloDrop hidden with Windows'; $Shortcut.Save()"

if errorlevel 1 (
    echo Failed to install SoloDrop autostart.
    pause
    exit /b 1
)

echo SoloDrop autostart installed.
echo Shortcut:
echo %SHORTCUT%
pause
