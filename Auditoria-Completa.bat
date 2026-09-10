@echo off
title Ejecutor Central de Auditoria AD
cls

echo ======================================================
echo          PROCESANDO AUDITORIA QUINCENAL TOTAL
echo ======================================================

echo 1 de 5: Procesando contraseñas...
start /wait "" cmd /c "C:\AuditoriaLocal\Ejecutar-Contrasenas.bat"

echo 2 de 5: Procesando gestion de usuarios...
start /wait "" cmd /c "C:\AuditoriaLocal\Ejecutar-Usuarios.bat"

echo 3 de 5: Procesando gestion de equipos...
start /wait "" cmd /c "C:\AuditoriaLocal\Ejecutar-Equipos.bat"

echo 4 de 5: Procesando evidencia de propiedades de usuario...
start /wait "" cmd /c "C:\AuditoriaLocal\Ejecutar-Propiedades.bat"

echo 5 de 5: Generando paquete ZIP historico...
PowerShell -NoProfile -ExecutionPolicy Bypass -File "C:\AuditoriaLocal\Enviar-Y-Empaquetar.ps1"

echo.
echo ======================================================
echo              TODO EL PROCESO HA FINALIZADO
echo ======================================================
pause