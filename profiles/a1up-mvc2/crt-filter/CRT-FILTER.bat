@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"
title Arcade1Up Cabinet - CRT Scanline Filter
color 0B

REM ===================================================================
REM  Turns the CRT / scanline look on and off for the RetroArch games
REM  added by the Cabinet Expansion mod.  Run it once to switch it on,
REM  run it again to switch it off.
REM
REM  Optional arguments, for anyone who wants them:
REM     CRT-FILTER.bat on ^| off ^| status
REM     CRT-FILTER.bat light ^| medium ^| heavy    - on, at that strength
REM ===================================================================

set "ADB=%~dp0platform-tools\adb.exe"
set "RADIR=/storage/emulated/0/RetroArch"
set "SHDIR=%RADIR%/shaders"
set "CFGDIR=%RADIR%/config"
set "PRESET=%CFGDIR%/global.glslp"
set "PARKED=%CFGDIR%/global.glslp.off"
set "TMPF=%TEMP%\cabinet-crt-state.txt"

REM -------------------- what was asked for --------------------
set "WANT=toggle"
set "STYLE="
if /I "%~1"=="on"     set "WANT=on"
if /I "%~1"=="off"    set "WANT=off"
if /I "%~1"=="status" set "WANT=status"
if /I "%~1"=="light"  ( set "WANT=on" & set "STYLE=crt-light"  )
if /I "%~1"=="medium" ( set "WANT=on" & set "STYLE=crt-medium" )
if /I "%~1"=="heavy"  ( set "WANT=on" & set "STYLE=crt-heavy"  )

echo(
echo  ==================================================================
echo    CABINET CRT FILTER   -   scanlines on / off
echo  ==================================================================
echo(
echo   Affects the games in the EXTRA GAMES menu only.
echo   Marvel vs Capcom 2, Big Blue and Yoga Flame are left alone -
echo   they do not run through RetroArch.
echo(
echo  ------------------------------------------------------------------
echo    The cabinet must be plugged into this PC with a DATA micro-USB
echo    cable and have USB debugging switched on - the same as when you
echo    ran the installer.
echo  ------------------------------------------------------------------
echo(

if not exist "%ADB%" (
    echo   ERROR: platform-tools\adb.exe is missing.
    echo   Unzip the WHOLE folder and run this from inside it.
    goto ENDFAIL
)

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
    echo   Look at the CABINET SCREEN for "Allow USB debugging?" and
    echo   answer it with the USB keyboard - tick "Always allow", ALLOW.
    echo(
    timeout /t 4 >nul
    set /a TRIES+=1
    if !TRIES! LSS 30 goto WAITDEV
    echo   Timed out waiting for authorization.
    goto ENDFAIL
)

echo   Looking for the cabinet...
timeout /t 3 >nul
set /a TRIES+=1
if !TRIES! LSS 10 goto WAITDEV
echo(
echo   Could not find the cabinet.
echo     - Is it a DATA cable?  This is the usual cause.
echo     - Is USB debugging still ON in Developer options?
echo     - Plug straight into the PC, not through a hub.
goto ENDFAIL

:GOTDEV
set ADBX="%ADB%" -s !SERIAL!
echo   Cabinet found:  !SERIAL!
echo(

REM -------------------- is the mod actually installed? --------------------
%ADBX% shell "pm list packages com.retroarch.aarch64" > "%TMPF%" 2>nul
findstr /C:"com.retroarch.aarch64" "%TMPF%" >nul
if errorlevel 1 (
    echo   RetroArch is not installed on this cabinet, so there are no
    echo   extra games for the filter to apply to.  Run the Cabinet
    echo   Expansion installer first.
    goto ENDFAIL
)

REM -------------------- read the current state --------------------
%ADBX% shell "if [ -f %PRESET% ]; then echo STATE_IS_ON; elif [ -f %PARKED% ]; then echo STATE_IS_OFF; else echo STATE_IS_NONE; fi; cat %PRESET% %PARKED% 2>/dev/null | grep -o 'crt-[a-z]*'" > "%TMPF%" 2>nul

set "CUR=NONE"
findstr /C:"STATE_IS_ON"  "%TMPF%" >nul && set "CUR=ON"
findstr /C:"STATE_IS_OFF" "%TMPF%" >nul && set "CUR=OFF"

set "CURSTYLE=crt-medium"
findstr /C:"crt-light" "%TMPF%" >nul && set "CURSTYLE=crt-light"
findstr /C:"crt-heavy" "%TMPF%" >nul && set "CURSTYLE=crt-heavy"
del "%TMPF%" >nul 2>&1

if not defined STYLE set "STYLE=%CURSTYLE%"
set "STYLENAME=%STYLE:crt-=%"
set "CURNAME=%CURSTYLE:crt-=%"

if "%WANT%"=="status" (
    if "!CUR!"=="ON" (
        echo   The CRT filter is currently  ON   ^(!CURNAME!^)
    ) else (
        echo   The CRT filter is currently  OFF
    )
    goto ENDOK
)

if "%WANT%"=="toggle" (
    if "!CUR!"=="ON" ( set "WANT=off" ) else ( set "WANT=on" )
)

if "!WANT!"=="off" goto TURNOFF

REM ==================== ON ====================
:TURNON
echo   Turning the CRT filter ON  ^(!STYLENAME!^)...
echo(

%ADBX% shell "mkdir -p %SHDIR% %CFGDIR%" >nul 2>&1
for %%F in ("%~dp0shaders\*") do (
    %ADBX% push "%%F" %SHDIR%/ >nul 2>&1
    if errorlevel 1 (
        echo   ERROR: could not copy the shader files onto the cabinet.
        goto ENDFAIL
    )
)

REM global.glslp is RetroArch's "apply to every game" auto-preset.  Holding it
REM as a one-line #reference means the strength can be changed by rewriting one
REM short file, and none of the installer's own settings files get touched.
%ADBX% shell "printf '#reference \"%SHDIR%/!STYLE!.glslp\"\n' > %PRESET% && rm -f %PARKED%" >nul 2>&1

call :SETFLAG true
if errorlevel 1 goto ENDFAIL

%ADBX% shell "[ -f %PRESET% ] && echo VERIFIED" > "%TMPF%" 2>nul
findstr /C:"VERIFIED" "%TMPF%" >nul
if errorlevel 1 (
    echo   ERROR: the preset did not stick.  Nothing was changed.
    goto ENDFAIL
)
del "%TMPF%" >nul 2>&1

echo   DONE - the CRT filter is now ON.
echo(
echo   Start any game from the EXTRA GAMES menu to see it.  A game that
echo   is already running keeps the old look until you quit back to the
echo   menu ^(hold P1 + P2 Start^) and go in again.
echo(
echo   Too strong, or too dim?   Run  CRT-STRENGTH.bat  to choose
echo   Light, Medium or Heavy.
goto ENDOK

REM ==================== OFF ====================
:TURNOFF
echo   Turning the CRT filter OFF...
echo(

REM Parked, not deleted, so the next switch-on comes back at whatever
REM strength was last chosen.
%ADBX% shell "[ -f %PRESET% ] && mv %PRESET% %PARKED%" >nul 2>&1

call :SETFLAG false
if errorlevel 1 goto ENDFAIL

echo   DONE - the CRT filter is now OFF.
echo(
echo   Start any game from the EXTRA GAMES menu to see the clean image.
goto ENDOK

REM ==================== helper ====================
REM Flips video_shader_enable in cabinet.cfg.  RetroArch ignores the auto-preset
REM completely unless this is "true", so the flag has to be set as well as the
REM preset file - checked on the cabinet, not assumed.  The rewrite happens on
REM the cabinet through a temp file that is only committed when it comes out
REM non-empty, so a half-written config can never replace a good one.
:SETFLAG
%ADBX% shell "cd %RADIR% && [ -f cabinet.cfg ] && grep -v '^video_shader_enable' cabinet.cfg > .crt.tmp && printf 'video_shader_enable = \"%~1\"\n' >> .crt.tmp && [ -s .crt.tmp ] && mv .crt.tmp cabinet.cfg && echo FLAG_OK" > "%TMPF%" 2>nul
findstr /C:"FLAG_OK" "%TMPF%" >nul
if errorlevel 1 (
    echo   ERROR: could not update  RetroArch\cabinet.cfg  on the cabinet.
    echo   Nothing was changed.  Re-run the Cabinet Expansion installer if
    echo   that file has gone missing.
    exit /b 1
)
del "%TMPF%" >nul 2>&1
exit /b 0

:ENDOK
echo(
echo  ==================================================================
echo(
pause
endlocal
exit /b 0

:ENDFAIL
echo(
echo  ------------------------------------------------------------------
echo   Nothing was changed.
echo  ------------------------------------------------------------------
echo(
pause
endlocal
exit /b 1
