@echo off
title Lanzador Central Auditoria 2019
cls

echo ======================================================
echo       PROCESANDO AUDITORIA QUINCENAL TOTAL 2019
echo ======================================================

echo 1 de 5: Procesando contraseñas...
start /wait "" cmd /c "C:\AuditoriaLocal\Ejecutar-Contrasenas-2019.bat"

echo 2 de 5: Procesando gestion de usuarios...
start /wait "" cmd /c "C:\AuditoriaLocal\Ejecutar-Usuarios-2019.bat"

echo 3 de 5: Procesando gestion de equipos...
start /wait "" cmd /c "C:\AuditoriaLocal\Ejecutar-Equipos-2019.bat"

echo 4 de 5: Procesando evidencia de propiedades de usuario...
start /wait "" cmd /c "C:\AuditoriaLocal\Ejecutar-Propiedades-2019.bat"

echo 5 de 5: Generando paquete ZIP y auto-limpieza...
PowerShell -NoProfile -ExecutionPolicy Bypass -File "C:\AuditoriaLocal\Enviar-Y-Empaquetar-2019.ps1"

echo.
echo ======================================================
echo         PROCESO TERMINADO - DIRECTORIO LIMPIO
echo ======================================================
exit
