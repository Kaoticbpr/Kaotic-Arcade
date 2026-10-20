@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"
title MvC2 Arcade1Up - Cabinet Expansion v2 Uninstaller
color 0C

set "ADB=%~dp0platform-tools\adb.exe"

echo(
echo  ==================================================================
echo    MvC2 Arcade1Up  -  UNINSTALL
echo  ==================================================================
echo(
echo   This removes everything this mod added and puts the cabinet
echo   back to booting straight into Marvel vs Capcom 2.
echo(
echo   Removed:  Big Blue, Yoga Flame, the menu, the 2-player bridge
echo   Optional: RetroArch, and the ROMs you copied over
echo(
echo   Your original Marvel vs Capcom 2 was never modified and is
echo   not touched here.
echo(
pause
echo(

"%ADB%" start-server >nul 2>&1

set "SERIAL="
for /f "usebackq skip=1 tokens=1,2" %%A in (`"%ADB%" devices`) do (
    if /I "%%B"=="device" set "SERIAL=%%A"
)
if not defined SERIAL (
    echo   No cabinet detected.  Check the cable and USB debugging.
    echo(
    pause
    exit /b 1
)
echo   Cabinet found:  !SERIAL!
set ADBX="%ADB%" -s !SERIAL!
echo(

echo  [1/5] Putting the boot screen back to Marvel vs Capcom 2
%ADBX% shell cmd package set-home-activity com.arcade/com.arcade.activity.NewHomeActivity >nul 2>&1

echo  [2/5] Turning off the LIVE button service
%ADBX% shell settings put secure enabled_accessibility_services "" >nul 2>&1
%ADBX% shell settings put secure accessibility_enabled 0 >nul 2>&1

echo  [3/5] Removing the menu, Big Blue and Yoga Flame
%ADBX% uninstall com.arcade.frontend >nul 2>&1
%ADBX% uninstall com.arcade.bigblue  >nul 2>&1
%ADBX% uninstall com.arcade.yoga     >nul 2>&1

echo(
set /p "RA=Also remove RetroArch and the extra games? (Y/N): "
if /I "!RA!"=="Y" (
    echo  [4/5] Removing RetroArch and its files
    %ADBX% uninstall com.retroarch.aarch64 >nul 2>&1
    rem Keep /sdcard/RetroArch/system - that is the user.s own BIOS files
    rem (naomi.zip, neogeo.zip), which they may not have another copy of.
    for %%D in (config saves states screenshots temp downloads playlists) do (
        %ADBX% shell rm -rf /sdcard/RetroArch/%%D >nul 2>&1
    )
    %ADBX% shell rm -f /sdcard/RetroArch/cabinet.cfg >nul 2>&1
    %ADBX% shell rm -rf /sdcard/roms >nul 2>&1
    %ADBX% shell rm -rf /data/local/tmp/cores >nul 2>&1
) else (
    echo  [4/5] Leaving RetroArch and your ROMs in place
)

echo  [5/5] Re-enabling the component the installer disabled
%ADBX% shell pm enable com.android.keychain >nul 2>&1

echo(
echo  ==================================================================
echo    DONE  -  reboot the cabinet and it is back to normal.
echo  ==================================================================
echo(
echo   Remaining packages:
%ADBX% shell pm list packages | findstr /I "arcade retroarch" 2>nul
echo(
set /p "RB=Reboot the cabinet now? (Y/N): "
if /I "!RB!"=="Y" (
    %ADBX% reboot
    echo   Rebooting...
)
echo(
pause
exit /b 0
