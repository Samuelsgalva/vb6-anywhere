@echo off
title Desinstalar VB6 Anywhere
cd /d "%~dp0"
echo.
echo   Vas a quitar del registro el VB6 Anywhere (la carpeta no se borra).
set /p CONF=  Escribe S para continuar: 
if /i not "%CONF%"=="S" goto :fin
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Desinstalar.ps1"
:fin
echo.
pause
