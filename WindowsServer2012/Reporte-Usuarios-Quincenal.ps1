$OutputHTML = "C:\AuditoriaLocal\Reporte_Gestion_Usuarios_Quincenal.html"
$FechaLimite = (Get-Date).AddDays(-15)

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "     AUDITANDO GESTIÓN DE USUARIOS (ALTAS Y BAJAS)     " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Buscando eventos desde: $($FechaLimite.ToString('dd/MM/yyyy HH:mm:ss'))`n" -ForegroundColor Cyan

# Filtrar eventos 4720 (creado), 4722 (habilitado), 4725 (deshabilitado), 4726 (eliminado)
$Events = Get-WinEvent -FilterHashtable @{LogName='Security';Id=4720,4722,4725,4726;StartTime=$FechaLimite} -ErrorAction SilentlyContinue

if ($Events) {
    $Rows = foreach ($Event in $Events) {
        $EventXML = [xml]$Event.ToXml()
        $TargetData = $EventXML.Event.EventData.Data
        
        $QuienLoHizo = ($TargetData | Where-Object {$_.Name -eq "SubjectUserName"}).'#text'
        $UsuarioAfectado = ($TargetData | Where-Object {$_.Name -eq "TargetUserName"}).'#text'
        $FechaHora = $Event.TimeCreated.ToString('dd/MM/yyyy HH:mm:ss')

        # FILTROS CRÍTICOS: Omitir cuentas de sistema corporativas y cuentas de máquina ($)
        if ($QuienLoHizo -ne "SYSTEM" -and 
            $QuienLoHizo -ne "LOCAL SERVICE" -and 
            $QuienLoHizo -ne "ANONYMOUS LOGON" -and 
            $QuienLoHizo -ne "INICIO DE SESIÓN ANÓNIMO" -and
            -not ($QuienLoHizo.EndsWith("$")) -and 
            -not ($UsuarioAfectado.EndsWith("$"))) {
            
            # Traducir la acción según el ID del evento de forma dinámica y visual
            $TipoAccion = switch ($Event.Id) {
                4720 { "<span style='color:#16a34a; font-weight:bold;'>Usuario CREADO (Alta)</span>" }
                4722 { "<span style='color:#2563eb; font-weight:bold;'>Usuario HABILITADO</span>" }
                4725 { "<span style='color:#ea580c; font-weight:bold;'>Usuario DESHABILITADO (Baja Temporal)</span>" }
                4726 { "<span style='color:#dc2626; font-weight:bold;'>Usuario ELIMINADO (Baja Definitiva)</span>" }
            }

            "<tr>
                <td>$FechaHora</td>
                <td><strong>$UsuarioAfectado</strong></td>
                <td>$QuienLoHizo</td>
                <td>$TipoAccion</td>
             </tr>"
        }
    }

    # Diseñar la plantilla estética del reporte en HTML (Estilo Azul Marino / Gris Seguridad)
    $HTMLHeader = @"
    <html>
    <head>
    <meta charset='UTF-8'>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 30px; color: #333; background-color: #fcfcfc; }
        h2 { color: #334155; border-bottom: 2px solid #334155; padding-bottom: 10px; font-size: 22px; }
        .meta { margin-bottom: 20px; font-size: 13px; color: #555; line-height: 1.6; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 13px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        th { background-color: #334155; color: white; text-align: left; padding: 12px 10px; font-weight: 600; }
        td { padding: 10px; border-bottom: 1px solid #e5e7eb; background-color: white; vertical-align: top; }
        tr:nth-child(even) td { background-color: #f8fafc; }
        .footer { margin-top: 40px; font-size: 11px; color: #9ca3af; text-align: center; border-top: 1px solid #e5e7eb; padding-top: 10px; }
    </style>
    </head>
    <body>
        <h2>Reporte de Gestión de Cuentas de Usuarios (Altas, Bajas y Estados)</h2>
        <div class='meta'>
            <strong>Ámbito:</strong> Active Directory Domain (Ciclo de Vida de Usuarios)<br>
            <strong>Periodo auditado:</strong> Últimos 15 días (Desde la fecha $($FechaLimite.ToString('dd/MM/yyyy')))<br>
            <strong>Fecha de generación:</strong> $((Get-Date).ToString('dd/MM/yyyy HH:mm:ss'))
        </div>
        <table>
            <thead>
                <tr>
                    <th>Fecha y Hora</th>
                    <th>Usuario Afectado</th>
                    <th>Administrador Responsable</th>
                    <th>Acción Detectada</th>
                </tr>
            </thead>
            <tbody>
                $($Rows -join "`n")
            </tbody>
        </table>
        <div class='footer'>Reporte automático generado por el Sistema de Auditoría de Identidad de Windows Server</div>
    </body>
    </html>
"@

    $HTMLHeader | Out-File -FilePath $OutputHTML -Encoding UTF8
    Write-Host "[OK] Proceso terminado exitosamente." -ForegroundColor Green
    Write-Host "[OK] Reporte de gestión de usuarios generado en: $OutputHTML" -ForegroundColor Green
} else {
    Write-Host "[!] No se encontraron eventos de gestión de usuarios en los últimos 15 días." -ForegroundColor Yellow
}
