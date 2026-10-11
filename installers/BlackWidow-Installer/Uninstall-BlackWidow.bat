@echo off
setlocal
title Black Widow Uninstaller
cd /d "%~dp0"
if not exist "%~dp0install.ps1" goto :nofiles
if not exist "%~dp0payload\remote-install.sh" goto :nofiles
where powershell >nul 2>&1
if errorlevel 1 goto :nops
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Action Uninstall
set RC=%errorlevel%
echo.
if not "%RC%"=="0" echo The installer stopped with an error. If a red message is above, send a photo of it
if not "%RC%"=="0" echo (and the file install-log.txt in this folder) to whoever sent you this.
echo.
pause
exit /b %RC%

:nofiles
echo.
echo  The installer files were not found next to this file.
echo.
echo  You most likely ran it from INSIDE the zip. Please:
echo    1. Right-click the downloaded zip file and choose "Extract All..."
echo    2. Open the extracted BlackWidow-Installer folder
echo    3. Double-click this file again from there
echo.
pause
exit /b 1

:nops
echo.
echo  Windows PowerShell was not found on this PC, so the installer cannot run.
echo.
pause
exit /b 1
