@echo off
setlocal

set "SHORTCUT=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\SoloDrop.lnk"

if exist "%SHORTCUT%" (
    del "%SHORTCUT%"
    echo SoloDrop autostart removed.
) else (
    echo SoloDrop autostart shortcut was not found.
)

pause
