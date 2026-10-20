@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"
title MvC2 Arcade1Up - Cabinet Expansion v2 Installer
color 0B

set "ADB=%~dp0platform-tools\adb.exe"

echo(
echo  ==================================================================
echo    MARVEL VS CAPCOM 2  Arcade1Up   -   CABINET EXPANSION  v2
echo  ==================================================================
echo(
echo   Adds Big Blue, Yoga Flame, and an EXTRA GAMES menu that runs
echo   up to 20 more arcade games - with sound, TWO-PLAYER support,
echo   per-game control screens and menu music.
echo(
echo   Your original Marvel vs Capcom 2 is NOT modified.
echo(
echo  ------------------------------------------------------------------
echo   BEFORE YOU START   (see INSTALL-GUIDE.txt for detail)
echo(
echo    1) USB keyboard plugged into the back of the cabinet.
echo    2) USB debugging turned ON:
echo         WINDOWS+N on the keyboard opens the notification shade,
echo         then the settings cog. There is no app drawer.
echo         About tablet -^> "Build number" x7, then
echo         Developer options -^> USB debugging
echo    3) A micro-USB DATA cable from this PC to the cabinet.
echo       Charge-only cables will NOT work.
echo    4) Your ROMs copied into the  roms  folder (optional).
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
    echo   Look at the CABINET SCREEN for the popup:
    echo       "Allow USB debugging?"   -^>  tick "Always allow", choose ALLOW
    echo   Use the USB keyboard to answer it.
    echo(
    echo   Waiting - this continues by itself once you allow it...
    timeout /t 4 >nul
    set /a TRIES+=1
    if !TRIES! LSS 45 goto WAITDEV
    echo   Timed out waiting for authorization.
    goto ENDFAIL
)

echo   No cabinet detected yet...
echo     - Is it a DATA cable?  This is the usual cause.
echo     - Is USB debugging ON in Developer options?
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
    echo(
    set /p "GO=Continue anyway? (Y/N): "
    if /I not "!GO!"=="Y" goto ENDFAIL
    echo(
)

echo  ==================================================================
echo   Installing - this takes several minutes.  Do not unplug.
echo  ==================================================================
echo(

echo  [1/8] Big Blue  (Street Fighter II Champion Edition)
%ADBX% install -r "%~dp0apk\BigBlue.apk"
if errorlevel 1 goto ENDFAIL
echo(
echo  [2/8] Yoga Flame  (Street Fighter II Hyper Fighting)
%ADBX% install -r "%~dp0apk\YogaFlame.apk"
if errorlevel 1 goto ENDFAIL
echo(
echo  [3/8] RetroArch  (runs the 20 extra games - this one is big)
%ADBX% install -r "%~dp0apk\RetroArch_aarch64.apk"
if errorlevel 1 goto ENDFAIL
echo(
echo  [4/8] The menu  (front-end, 2-player bridge, music)
%ADBX% install -r "%~dp0apk\Frontend.apk"
if errorlevel 1 goto ENDFAIL
echo(

echo  [5/8] Permissions
for %%P in (READ_EXTERNAL_STORAGE WRITE_EXTERNAL_STORAGE) do (
    %ADBX% shell pm grant com.arcade.bigblue      android.permission.%%P >nul 2>&1
    %ADBX% shell pm grant com.arcade.yoga         android.permission.%%P >nul 2>&1
    %ADBX% shell pm grant com.retroarch.aarch64   android.permission.%%P >nul 2>&1
)
REM Lets the menu re-enable the LIVE button by itself after every reboot.
REM WRITE_SECURE_SETTINGS is grantable over adb because its protection level
REM includes "development".  No root needed, and the grant survives reboots.
%ADBX% shell pm grant com.arcade.frontend android.permission.WRITE_SECURE_SETTINGS >nul 2>&1
echo(

echo  [6/8] Emulator cores, settings and NAOMI save data
%ADBX% shell mkdir -p /sdcard/RetroArch/system >nul 2>&1
%ADBX% shell mkdir -p /sdcard/RetroArch/saves/Flycast/reicast >nul 2>&1
%ADBX% shell mkdir -p /sdcard/roms >nul 2>&1
%ADBX% shell mkdir -p /data/local/tmp/cores >nul 2>&1
echo        cores (about 95 MB, takes a moment)...
%ADBX% push "%~dp0cores\fbneo_libretro_android.so"   /data/local/tmp/cores/ >nul 2>&1
%ADBX% push "%~dp0cores\flycast_libretro_android.so" /data/local/tmp/cores/ >nul 2>&1
REM The cores have to sit on /data, which is mounted exec-capable - /sdcard is noexec,
REM so a core there can never be loaded.  755 lets RetroArch read them from its own uid.
%ADBX% shell chmod 755 /data/local/tmp/cores >nul 2>&1
%ADBX% shell chmod 644 /data/local/tmp/cores/fbneo_libretro_android.so >nul 2>&1
%ADBX% shell chmod 644 /data/local/tmp/cores/flycast_libretro_android.so >nul 2>&1
%ADBX% push "%~dp0config\cabinet.cfg" /sdcard/RetroArch/cabinet.cfg >nul 2>&1
rem Core override for Flycast only: NAOMI output is quieter than the CPS games, so lift its
rem digital level rather than the amp (raising the amp instead just adds speaker hiss).
%ADBX% shell mkdir -p /sdcard/RetroArch/config/Flycast >nul 2>&1
%ADBX% push "%~dp0config\Flycast.cfg" /sdcard/RetroArch/config/Flycast/Flycast.cfg >nul 2>&1

rem Per-game button remaps for the 3- and 4-button games, so their buttons read left-to-right
rem across the top row instead of starting on the bottom row. These cover PLAYER 1 only;
rem player 2 is remapped inside the menu app, because RetroArch does not apply remap files to
rem network-gamepad input.
%ADBX% shell mkdir -p "/sdcard/RetroArch/config/remaps/FinalBurn Neo" >nul 2>&1
%ADBX% shell mkdir -p /sdcard/RetroArch/config/remaps/Flycast >nul 2>&1
%ADBX% push "%~dp0config\remaps\FinalBurn Neo" /sdcard/RetroArch/config/remaps/ >nul 2>&1
%ADBX% push "%~dp0config\remaps\Flycast" /sdcard/RetroArch/config/remaps/ >nul 2>&1
rem Pre-seeded save data, so nobody has to sit through a first-boot error screen.
rem The NAOMI games open on "BACKUPRAM ID Err ... Press any key" and the four Mortal
rem Kombat boards on "CMOS INVALID - FACTORY SETTINGS RESTORED" until their NVRAM has
rem been written once, and it is only written on a clean shutdown - which quitting with
rem the LIVE button is not. Shipping the files means the player never meets either screen.
%ADBX% shell mkdir -p "/sdcard/RetroArch/saves/FinalBurn Neo/fbneo" >nul 2>&1
for %%F in ("%~dp0nvram\flycast\*.*") do %ADBX% push "%%F" /sdcard/RetroArch/saves/Flycast/reicast/ >nul 2>&1
for %%F in ("%~dp0nvram\fbneo\*.*")   do %ADBX% push "%%F" "/sdcard/RetroArch/saves/FinalBurn Neo/fbneo/" >nul 2>&1
echo        done
echo(

echo  [7/8] Checking and copying your ROMs
echo(
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\verify-roms.ps1"
REM exit 2 = no ROMs present at all; exit 1 = at least one set did not match.
if errorlevel 2 goto ROMCOPY
if errorlevel 1 (
    echo(
    echo   Some sets did not match. They will still be copied - a mismatched
    echo   set sometimes works anyway - but if a game refuses to load later,
    echo   this is why.
    echo(
    set /p "RC=Continue? (Y/N): "
    if /I not "!RC!"=="Y" goto ENDFAIL
)

:ROMCOPY
echo(
set "ROMCOUNT=0"
for %%F in ("%~dp0roms\*.zip") do (
    set /a ROMCOUNT+=1
    echo        %%~nxF
    if /I "%%~nxF"=="naomi.zip" (
        rem naomi.zip must go in BOTH places. Flycast resolves the NAOMI BIOS relative to
        rem the CONTENT directory, so with it only in system\ every NAOMI game fails with
        rem "cannot load BIOS naomi" even though the file is present and correct.
        %ADBX% push "%%F" /sdcard/RetroArch/system/ >nul 2>&1
        %ADBX% push "%%F" /sdcard/roms/ >nul 2>&1
    ) else if /I "%%~nxF"=="neogeo.zip" (
        %ADBX% push "%%F" /sdcard/RetroArch/system/ >nul 2>&1
    ) else (
        %ADBX% push "%%F" /sdcard/roms/ >nul 2>&1
    )
)
if "!ROMCOUNT!"=="0" (
    echo        No ROMs found - see roms\PUT-YOUR-ROMS-HERE.txt
    echo        You can add them later and just run this installer again.
)
echo(

echo  [8/8] Making the menu the boot screen and arming the LIVE button
%ADBX% shell cmd package set-home-activity com.arcade.frontend/com.arcade.frontend.MainActivity >nul 2>&1
REM Clearing first forces a REBIND.  Setting the same value again leaves the
REM previously-bound (now stale) service running, and the LIVE button stays dead.
%ADBX% shell settings put secure enabled_accessibility_services "" >nul 2>&1
timeout /t 2 >nul
%ADBX% shell settings put secure enabled_accessibility_services com.arcade.frontend/com.arcade.frontend.SwitchService >nul 2>&1
%ADBX% shell settings put secure accessibility_enabled 1 >nul 2>&1
%ADBX% shell am startservice -n com.arcade.frontend/.P2BridgeService >nul 2>&1
%ADBX% shell pm disable-user --user 0 com.android.keychain >nul 2>&1
echo        done
echo(

echo  ==================================================================
echo    INSTALLED
echo  ==================================================================
echo(
echo   Everything is installed - including the two emulator cores,
echo   so there is nothing left to download.
echo(
echo  ------------------------------------------------------------------
echo   HOW TO USE
echo     * The cabinet boots to the menu.
echo     * Joystick LEFT / RIGHT to choose, any button to select.
echo     * EXTRA GAMES tile has the 10 added games.
echo     * Hold the LIVE button 3 seconds to quit a game.
echo     * Player 1 and Player 2 both work everywhere.
echo(
echo   To undo everything, run UNINSTALL.bat
echo  ------------------------------------------------------------------
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
echo   If you never saw "INSTALLED", nothing lasting was changed.
echo   See INSTALL-GUIDE.txt for troubleshooting, then try again.
echo  ------------------------------------------------------------------
echo(
pause
exit /b 1
