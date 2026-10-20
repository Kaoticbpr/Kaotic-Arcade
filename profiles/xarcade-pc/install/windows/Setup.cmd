@echo off
rem VPX Cabinet Kit - double-click to install Visual Pinball X + ES-DE into C:\Pinball
title VPX Cabinet Kit - Setup
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%~dp0' -Recurse -File | Unblock-File"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0kit\Setup-Cabinet.ps1"
pause
