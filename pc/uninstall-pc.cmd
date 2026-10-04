@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" -Action Remove
set RESULT=%ERRORLEVEL%
pause
exit /b %RESULT%
