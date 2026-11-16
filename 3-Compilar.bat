@echo off
setlocal
title Compilar proyecto VB6
cd /d "%~dp0"

set "VBP=%~1"
set "SALIDA=%~2"

if not "%VBP%"=="" goto :compilar

echo.
echo   Compilar un proyecto de Visual Basic 6
echo   ----------------------------------------
echo   Arrastra el archivo .vbp sobre este .bat,
echo   o escribe la ruta completa aqui abajo.
echo.
set /p "VBP=  Ruta del .vbp: "
if "%VBP%"=="" goto :fin
rem quitar comillas si las pegaron
set VBP=%VBP:"=%

:compilar
if not exist "%VBP%" (
  echo.
  echo   No existe el archivo:
  echo     %VBP%
  goto :fin
)
echo.
if "%SALIDA%"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Herramientas\Compilar.ps1" -Vbp "%VBP%"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Herramientas\Compilar.ps1" -Vbp "%VBP%" -Salida "%SALIDA%"
)
if errorlevel 1 (
  echo.
  echo   La compilacion no termino bien. Revisa el mensaje de arriba.
)
:fin
echo.
pause
endlocal
