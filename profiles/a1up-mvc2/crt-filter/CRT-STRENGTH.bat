@echo off
setlocal
cd /d "%~dp0"
title Arcade1Up Cabinet - CRT Filter Strength
color 0B

echo(
echo  ==================================================================
echo    CABINET CRT FILTER   -   how strong?
echo  ==================================================================
echo(
echo    [1]  LIGHT    A hint of scanline, no grille.  Brightest, and the
echo                  kindest to the busy CPS3 games (Street Fighter III,
echo                  Red Earth).
echo(
echo    [2]  MEDIUM   Scanlines plus a soft aperture grille.  The closest
echo                  match to a real cabinet monitor.  Recommended.
echo(
echo    [3]  HEAVY    Deep gaps and a strong grille.  Very authentic, but
echo                  noticeably darker - best in a dim room.
echo(
echo    [4]  OFF      Switch the filter off.
echo(
echo    [5]  Cancel
echo(

choice /C 12345 /N /M "  Pick 1-5: "
set "PICK=%ERRORLEVEL%"
echo(

if "%PICK%"=="1" call "%~dp0CRT-FILTER.bat" light  & goto :EOF
if "%PICK%"=="2" call "%~dp0CRT-FILTER.bat" medium & goto :EOF
if "%PICK%"=="3" call "%~dp0CRT-FILTER.bat" heavy  & goto :EOF
if "%PICK%"=="4" call "%~dp0CRT-FILTER.bat" off    & goto :EOF

echo   Cancelled - nothing was changed.
echo(
pause
