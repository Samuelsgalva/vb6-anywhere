@echo off
title Reparar el IDE de VB6
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','\""%~dp0Herramientas\Reparar-IDE.ps1\""'"
if errorlevel 1 pause
