@echo off
setlocal

cd /d "%~dp0"

set "SOLODROP_IP="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$ip=(Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } | Select-Object -First 1 -ExpandProperty IPv4Address).IPAddress; if (-not $ip) { $ip=(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -ne '127.0.0.1' } | Select-Object -First 1 -ExpandProperty IPAddress) }; if ($ip) { $ip }"`) do set "SOLODROP_IP=%%I"
if not defined SOLODROP_IP set "SOLODROP_IP=127.0.0.1"

echo SoloDrop Server
echo.
echo Local URL: http://%SOLODROP_IP%:8000
echo Health:    http://%SOLODROP_IP%:8000/health
echo Pair PIN:  http://%SOLODROP_IP%:8000/pair/code
echo QR PNG:    http://%SOLODROP_IP%:8000/pair/qr
echo.
echo If iPhone cannot connect, allow SoloDrop through Windows Firewall for Private networks.
echo.

if exist "SoloDropServer.exe" (
  "SoloDropServer.exe"
) else if exist "dist\SoloDropServer\SoloDropServer.exe" (
  "dist\SoloDropServer\SoloDropServer.exe"
) else if exist ".venv\Scripts\python.exe" (
  ".venv\Scripts\python.exe" "run_server.py"
) else (
  py -3 "run_server.py"
)

if errorlevel 1 (
  echo.
  echo SoloDrop Server stopped with an error.
  pause
)
