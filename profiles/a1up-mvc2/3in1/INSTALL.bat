@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"
title MVC2 Arcade1Up - 3-in-1 Game Menu Installer
color 0B

set "ADB=%~dp0platform-tools\adb.exe"

echo(
echo  ==================================================================
echo    MARVEL VS CAPCOM 2  Arcade1Up   -   3-in-1 Game Menu
echo  ==================================================================
echo(
echo   Adds two more games to your Marvel vs Capcom 2 cabinet:
echo       *  Big Blue    -  Street Fighter II  Champion Edition
echo       *  Yoga Flame  -  Street Fighter II  Hyper Fighting
echo   ...plus a "SELECT YOUR FIGHTER" menu to pick between all three.
echo(
echo   Your original Marvel vs Capcom 2 is NOT modified.
echo(
echo  ------------------------------------------------------------------
echo   BEFORE YOU START
echo(
echo   1) Turn the cabinet on and let it boot to the game.
echo(
echo   2) Enable USB debugging on the cabinet:
echo        Settings  -^>  Developer options  -^>  USB debugging
echo      If you don't see "Developer options", first open
echo        Settings -^> About  and tap "Build number" 7 times.
echo(
echo   3) Connect a micro-USB DATA cable from this PC to the cabinet's
echo      USB port.  (Charge-only cables will NOT work - if Windows
echo      shows "Unknown USB Device", the cable is the problem.)
echo  ------------------------------------------------------------------
echo(
pause
echo(

"%ADB%" start-server >nul 2>&1

REM -------------------- wait for an authorized device --------------------
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
    echo   The cabinet is connected but NOT authorized yet.
    echo   Look at the CABINET SCREEN for a popup:
    echo       "Allow USB debugging?"   -   choose  ALLOW
    echo       (tick "Always allow from this computer")
    echo   Tip: plug a USB mouse into the cabinet if you can't click it.
    echo(
    echo   Waiting - this continues automatically once you allow it...
    timeout /t 4 >nul
    set /a TRIES+=1
    if !TRIES! LSS 45 goto WAITDEV
    echo   Timed out waiting for authorization.
    goto ENDFAIL
)

echo   No cabinet detected yet...
echo     - Is it a DATA cable?  Try a different cable and USB port.
echo     - Is USB debugging turned ON in Developer options?
echo     - Plug straight into the PC, not through a hub.
echo(
timeout /t 3 >nul
set /a TRIES+=1
if !TRIES! LSS 12 goto WAITDEV
echo   Could not find the cabinet.
goto ENDFAIL

:GOTDEV
echo   Cabinet found:  !SERIAL!
set ADBX="%ADB%" -s !SERIAL!
echo(

REM -------------------- sanity check --------------------
set "HASARCADE="
for /f "usebackq delims=" %%L in (`%ADBX% shell pm list packages com.arcade 2^>nul`) do (
    echo %%L| find "package:com.arcade" >nul && set "HASARCADE=1"
)
if not defined HASARCADE (
    echo   WARNING: this does not look like an Arcade1Up MvC2 cabinet
    echo   ^(the "com.arcade" app was not found^).
    echo   You can still continue, but it may not work correctly.
    echo(
    set /p "GO=Continue anyway? (Y/N): "
    if /I not "!GO!"=="Y" goto ENDFAIL
    echo(
)

echo  ==================================================================
echo   Installing - this takes a minute or two, do not unplug...
echo  ==================================================================
echo(
echo  [1/3] Big Blue  (Street Fighter II Champion Edition)
%ADBX% install -r "%~dp0apk\BigBlue.apk"
if errorlevel 1 goto ENDFAIL
echo(
echo  [2/3] Yoga Flame  (Street Fighter II Hyper Fighting)
%ADBX% install -r "%~dp0apk\YogaFlame.apk"
if errorlevel 1 goto ENDFAIL
echo(
echo  [3/3] SELECT YOUR FIGHTER menu
%ADBX% install -r "%~dp0apk\Frontend.apk"
if errorlevel 1 goto ENDFAIL
echo(

echo  Granting permissions...
for %%P in (RECORD_AUDIO READ_EXTERNAL_STORAGE WRITE_EXTERNAL_STORAGE ACCESS_COARSE_LOCATION) do (
    %ADBX% shell pm grant com.arcade.bigblue android.permission.%%P >nul 2>&1
    %ADBX% shell pm grant com.arcade.yoga   android.permission.%%P >nul 2>&1
)

echo  Setting the SELECT YOUR FIGHTER menu as the boot screen...
%ADBX% shell cmd package set-home-activity com.arcade.frontend/com.arcade.frontend.MainActivity >nul 2>&1

echo  Enabling the "hold both Start buttons" return-to-menu combo...
%ADBX% shell settings put secure enabled_accessibility_services com.arcade.frontend/com.arcade.frontend.SwitchService
%ADBX% shell settings put secure accessibility_enabled 1

echo  Disabling the broken component that causes "Key Chain has stopped"...
%ADBX% shell pm disable-user --user 0 com.android.keychain >nul 2>&1

echo(
echo  ==================================================================
echo    SUCCESS
echo  ==================================================================
echo(
echo   Installed:
%ADBX% shell pm list packages | findstr /I "arcade" 2>nul
echo(
echo   HOW TO USE
echo     * Reboot the cabinet.  It boots to the SELECT YOUR FIGHTER menu.
echo     * Joystick LEFT / RIGHT to choose, any button to play.
echo     * From inside ANY game, hold
echo           PLAYER 1 START  +  PLAYER 2 START   together for 2 seconds
echo       to jump back to the menu.
echo(
echo   To undo everything, run  UNINSTALL.bat
echo(
set /p "RB=Reboot the cabinet now? (Y/N): "
if /I "!RB!"=="Y" (
    %ADBX% reboot
    echo   Rebooting...
)
echo(
pause
exit /b 0

:ENDFAIL
echo(
echo  ------------------------------------------------------------------
echo   Installation did NOT complete.
echo   If you never saw "SUCCESS", nothing lasting was changed.
echo   See README.txt for troubleshooting, then try again.
echo  ------------------------------------------------------------------
echo(
pause
exit /b 1
