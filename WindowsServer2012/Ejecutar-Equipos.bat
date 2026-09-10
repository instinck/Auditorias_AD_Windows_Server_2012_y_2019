
@echo off
title Generador de Reportes AD - Equipos
cls

echo Iniciando extracción de auditoría de equipos en Active Directory...
echo Espere un momento por favor...
echo.

PowerShell -NoProfile -ExecutionPolicy Bypass -File "C:\AuditoriaLocal\Reporte-Equipos-Quincenal.ps1"

echo.
echo ======================================================
echo    PROCESO COMPLETADO: Ya puede cerrar esta ventana.
echo ======================================================
echo.
