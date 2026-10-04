@echo off
if "%~1"=="" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" -Action Install
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" -Action Install -FrameHost "%~1"
)
set RESULT=%ERRORLEVEL%
pause
exit /b %RESULT%
