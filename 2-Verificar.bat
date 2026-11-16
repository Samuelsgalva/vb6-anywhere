@echo off
title Verificar VB6 Anywhere
cd /d "%~dp0"
echo.
echo   Comprobando el entorno (no modifica nada)...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Instalar.ps1" -SoloVerificar -NoPause
echo.
pause
