@echo off
setlocal
set VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe
for /f "usebackq delims=" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set VS=%%i
if not defined VS exit /b 1
call "%VS%\VC\Auxiliary\Build\vcvars64.bat" >nul || exit /b 1
cd /d "%~dp0.."
if not exist build\solver-tests mkdir build\solver-tests
cl /nologo /O2 /EHsc /std:c++17 /MT /W3 /DNOMINMAX /D_CRT_SECURE_NO_WARNINGS /Fobuild\solver-tests\ tests\solver_regression.cpp src\driver\sync.cpp /Fe:build\solver-tests\solver_regression.exe /link /NOLOGO || exit /b 1
build\solver-tests\solver_regression.exe
exit /b %ERRORLEVEL%
