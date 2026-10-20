@echo off
cd /d "%~dp0"
title X-Men '97 Cabinet Expansion - ROM check
color 0B
echo(
echo  ==================================================================
echo    CHECKING THE ROMS IN THE  roms  FOLDER
echo  ==================================================================
echo(
echo   Compares every file inside each zip (name, size and CRC32)
echo   against the sets that are known to work on a real cabinet.
echo   Nothing is installed or changed - this only reports.
echo(
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\verify-roms.ps1"
echo(
pause
