@echo off
title Abrir VB6
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Herramientas\Abrir-VB6.ps1"
if errorlevel 1 pause
