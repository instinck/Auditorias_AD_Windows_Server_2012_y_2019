$OutputHTML = "C:\AuditoriaLocal\Reporte_Gestion_Equipos_Quincenal.html"
$FechaLimite = (Get-Date).AddDays(-15)

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "     AUDITANDO GESTIÓN DE EQUIPOS EN EL DOMINIO       " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Buscando eventos desde: $($FechaLimite.ToString('dd/MM/yyyy HH:mm:ss'))`n" -ForegroundColor Cyan

# Filtrar eventos de equipos: 4741 (Creado), 4742 (Modificado), 4743 (Eliminado)
$Events = Get-WinEvent -FilterHashtable @{LogName='Security';Id=4741,4742,4743;StartTime=$FechaLimite} -ErrorAction SilentlyContinue

if ($Events) {
    $Rows = foreach ($Event in $Events) {
        $EventXML = [xml]$Event.ToXml()
        $TargetData = $EventXML.Event.EventData.Data
        
        $QuienLoHizo = ($TargetData | Where-Object {$_.Name -eq "SubjectUserName"}).'#text'
        $EquipoAfectado = ($TargetData | Where-Object {$_.Name -eq "TargetUserName"}).'#text'
        $FechaHora = $Event.TimeCreated.ToString('dd/MM/yyyy HH:mm:ss')

        # FILTROS CRÍTICOS: Omitir cuentas de sistema y accesos anónimos automatizados
        if ($QuienLoHizo -ne "SYSTEM" -and 
            $QuienLoHizo -ne "LOCAL SERVICE" -and 
            $QuienLoHizo -ne "ANONYMOUS LOGON" -and 
            $QuienLoHizo -ne "INICIO DE SESIÓN ANÓNIMO" -and
            $QuienLoHizo -ne "NETWORK SERVICE") {
            
            # Determinar la acción exacta y traducirla de forma amigable
            if ($Event.Id -eq 4741) {
                $TipoAccion = "Equipo UNIDO al dominio (Creado)"
            }
            elseif ($Event.Id -eq 4743) {
                $TipoAccion = "Equipo ELIMINADO del dominio"
            }
            elseif ($Event.Id -eq 4742) {
                $TipoAccion = "Propiedades de equipo modificadas / Estado cambiado"
            }

            "<tr>
                <td>$FechaHora</td>
                <td><strong>$EquipoAfectado</strong></td>
                <td>$QuienLoHizo</td>
                <td>$TipoAccion</td>
             </tr>"
        }
    }

    # Diseñar la plantilla estética del reporte HTML
    $HTMLHeader = @"
    <html>
    <head>
    <meta charset='UTF-8'>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 30px; color: #333; background-color: #fcfcfc; }
        h2 { color: #0f766e; border-bottom: 2px solid #0f766e; padding-bottom: 10px; font-size: 22px; }
        .meta { margin-bottom: 20px; font-size: 13px; color: #555; line-height: 1.6; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 13px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        th { background-color: #0f766e; color: white; text-align: left; padding: 12px 10px; font-weight: 600; }
        td { padding: 10px; border-bottom: 1px solid #e5e7eb; background-color: white; }
        tr:nth-child(even) td { background-color: #f0fdfa; }
        .footer { margin-top: 40px; font-size: 11px; color: #9ca3af; text-align: center; border-top: 1px solid #e5e7eb; padding-top: 10px; }
    </style>
    </head>
    <body>
        <h2>Reporte de Altas, Bajas y Modificaciones de Equipos</h2>
        <div class='meta'>
            <strong>Ámbito:</strong> Active Directory Domain (Computadoras/Servidores)<br>
            <strong>Periodo auditado:</strong> Últimos 15 días (Desde la fecha $($FechaLimite.ToString('dd/MM/yyyy')))<br>
            <strong>Fecha de generación:</strong> $((Get-Date).ToString('dd/MM/yyyy HH:mm:ss'))
        </div>
        <table>
            <thead>
                <tr>
                    <th>Fecha y Hora</th>
                    <th>Equipo Afectado (Nombre)</th>
                    <th>Operador / Administrador</th>
                    <th>Acción Detectada</th>
                </tr>
            </thead>
            <tbody>
                $($Rows -join "`n")
            </tbody>
        </table>
        <div class='footer'>Reporte automático generado por el Sistema de Auditoría de Infraestructura de Windows Server</div>
    </body>
    </html>
"@

    $HTMLHeader | Out-File -FilePath $OutputHTML -Encoding UTF8
    Write-Host "[OK] Proceso terminado exitosamente." -ForegroundColor Green
    Write-Host "[OK] Reporte de equipos generado en: $OutputHTML" -ForegroundColor Green
} else {
    Write-Host "[!] No se encontraron movimientos de cuentas de equipo en los últimos 15 días." -ForegroundColor Yellow
}
