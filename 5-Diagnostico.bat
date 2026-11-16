@echo off
title Diagnostico VB6 Anywhere
cd /d "%~dp0"
echo.
echo   Recogiendo informacion de esta PC...  (no cambia nada)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Herramientas\Diagnostico.ps1"
if errorlevel 1 echo   El diagnostico termino con errores.
echo.
pause
