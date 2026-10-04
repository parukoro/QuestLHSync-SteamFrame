@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" -Action Status -FrameHost "%~1"
set RESULT=%ERRORLEVEL%
pause
exit /b %RESULT%
