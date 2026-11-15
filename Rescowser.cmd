@echo off
setlocal
set "ROOT=%~dp0"
if not exist "%ROOT%Scripts\Start-Rescowser.ps1" (
  echo [RESCOWSER] Launcher script is missing.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ROOT%Scripts\Start-Rescowser.ps1" %*
exit /b %errorlevel%
