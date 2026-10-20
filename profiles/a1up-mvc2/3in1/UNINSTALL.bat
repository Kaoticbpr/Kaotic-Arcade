@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"
title MVC2 Arcade1Up - Uninstaller  (revert to stock)
color 0E

set "ADB=%~dp0platform-tools\adb.exe"

echo(
echo  ==================================================================
echo    MARVEL VS CAPCOM 2  Arcade1Up   -   UNINSTALL / REVERT TO STOCK
echo  ==================================================================
echo(
echo   This removes Big Blue, Yoga Flame and the SELECT A GAME menu,
echo   puts the boot screen back to the original Marvel vs Capcom 2,
echo   and re-enables the component that was disabled.
echo(
echo   Your original Marvel vs Capcom 2 was never touched and stays.
echo(
echo  ------------------------------------------------------------------
echo   Connect the micro-USB DATA cable from this PC to the cabinet,
echo   with USB debugging turned on (same as when you installed).
echo  ------------------------------------------------------------------
echo(
pause
echo(

"%ADB%" start-server >nul 2>&1

set /a TRIES=0
:WAITDEV
set "SERIAL="
set "UNAUTH="
for /f "usebackq skip=1 tokens=1,2" %%A in (`"%ADB%" devices`) do (
    if /I "%%B"=="device"       set "SERIAL=%%A"
    if /I "%%B"=="unauthorized" set "UNAUTH=%%A"
)
if defined SERIAL goto GOTDEV
if defined UNAUTH (
    echo   Not authorized yet - choose ALLOW on the cabinet screen.
    timeout /t 4 >nul
    set /a TRIES+=1
    if !TRIES! LSS 45 goto WAITDEV
    goto ENDFAIL
)
echo   No cabinet detected yet...
timeout /t 3 >nul
set /a TRIES+=1
if !TRIES! LSS 12 goto WAITDEV
goto ENDFAIL

:GOTDEV
echo   Cabinet found:  !SERIAL!
set ADBX="%ADB%" -s !SERIAL!
echo(

echo  Restoring the original Marvel vs Capcom 2 boot screen...
%ADBX% shell cmd package set-home-activity com.arcade/com.arcade.activity.legal.LegalActivity >nul 2>&1

echo  Turning off the return-to-menu combo...
%ADBX% shell settings delete secure enabled_accessibility_services >nul 2>&1
%ADBX% shell settings put secure enabled_accessibility_services null >nul 2>&1
%ADBX% shell settings put secure accessibility_enabled 0 >nul 2>&1

echo  Re-enabling com.android.keychain...
%ADBX% shell pm enable com.android.keychain >nul 2>&1
%ADBX% shell pm enable-user --user 0 com.android.keychain >nul 2>&1

echo  Removing the added games and menu...
%ADBX% uninstall com.arcade.frontend
%ADBX% uninstall com.arcade.bigblue
%ADBX% uninstall com.arcade.yoga

echo(
echo  ==================================================================
echo    DONE - cabinet reverted to stock.
echo  ==================================================================
echo(
%ADBX% shell pm list packages | findstr /I "arcade" 2>nul
echo(
set /p "RB=Reboot the cabinet now? (Y/N): "
if /I "!RB!"=="Y" %ADBX% reboot
echo(
pause
exit /b 0

:ENDFAIL
echo(
echo   Could not reach the cabinet. Check the connection and try again.
echo(
pause
exit /b 1
