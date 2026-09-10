@echo off
title Generador de Reportes AD - Gestión de Usuarios
cls

echo Iniciando extracción de auditoría de altas y bajas en Active Directory...
echo Espere un momento por favor...
echo.

PowerShell -NoProfile -ExecutionPolicy Bypass -File "C:\AuditoriaLocal\Reporte-Usuarios-Quincenal.ps1"

echo.
echo ======================================================
echo    PROCESO COMPLETADO: Ya puede cerrar esta ventana.
echo ======================================================
echo.
