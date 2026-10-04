@echo off
setlocal
cd /d "%~dp0"
call build.bat || exit /b 1
python frame\build.py || exit /b 1
python release.py --frame-only || exit /b 1
