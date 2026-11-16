@echo off
title Instalar VB6 Anywhere
cd /d "%~dp0"
echo.
echo   Instalando el VB6 Anywhere...
echo   (si Windows pide permiso, acepta el UAC)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Instalar.ps1"
if errorlevel 1 (
  echo.
  echo   Hubo un problema. Revisa los mensajes de arriba.
  pause
)
