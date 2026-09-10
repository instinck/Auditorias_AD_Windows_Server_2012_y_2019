$OutputHTML = "C:\AuditoriaLocal\Reporte_Gestion_Equipos_Quincenal.html"
$OutputCSV  = "C:\AuditoriaLocal\Reporte_Gestion_Equipos_Quincenal.csv"
$FechaLimite = (Get-Date).AddDays(-15)

Write-Host "Buscando gestión de equipos desde: $($FechaLimite.ToString('dd/MM/yyyy HH:mm:ss'))" -ForegroundColor Cyan

$Events = Get-WinEvent -FilterHashtable @{LogName='Security';Id=4741,4742,4743;StartTime=$FechaLimite} -ErrorAction SilentlyContinue

if ($Events) {
    $DataObjects = foreach ($Event in $Events) {
        $EventXML = [xml]$Event.ToXml()
        $TargetData = $EventXML.Event.EventData.Data
        
        $QuienLoHizo = ($TargetData | Where-Object {$_.Name -eq "SubjectUserName"}).'#text'
        $EquipoAfectado = ($TargetData | Where-Object {$_.Name -eq "TargetUserName"}).'#text'

        if ($QuienLoHizo -ne "SYSTEM" -and $QuienLoHizo -ne "LOCAL SERVICE" -and $QuienLoHizo -ne "ANONYMOUS LOGON" -and $QuienLoHizo -ne "INICIO DE SESIÓN ANÓNIMO" -and $QuienLoHizo -ne "NETWORK SERVICE") {
            
            $TipoAccionText = switch ($Event.Id) {
                4741 { "Equipo UNIDO al dominio (Creado)" }
                4743 { "Equipo ELIMINADO del dominio" }
                4742 { "Propiedades de equipo modificadas / Estado cambiado" }
            }

            [PSCustomObject]@{
                "ID Registro"     = $Event.RecordId
                "Fecha y Hora"     = $Event.TimeCreated.ToString('dd/MM/yyyy HH:mm:ss')
                "Equipo Afectado"  = $EquipoAfectado
                "Operador"         = $QuienLoHizo
                "Tipo de Acción"   = $TipoAccionText
            }
        }
    }

    $DataObjects | Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding UTF8

    $Rows = foreach ($Obj in $DataObjects) {
        "<tr>
            <td><b>$($Obj."ID Registro")</b></td>
            <td>$($Obj."Fecha y Hora")</td>
            <td><strong>$($Obj."Equipo Afectado")</strong></td>
            <td>$($Obj."Operador")</td>
            <td>$($Obj."Tipo de Acción")</td>
         </tr>"
    }

    $HTMLHeader = @"
    <html>
    <head><meta charset='UTF-8'><style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 30px; color: #333; }
        h2 { color: #0f766e; border-bottom: 2px solid #0f766e; padding-bottom: 10px; font-size: 22px; }
        .meta { margin-bottom: 20px; font-size: 13px; color: #555; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 13px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        th { background-color: #0f766e; color: white; text-align: left; padding: 12px 10px; }
        td { padding: 10px; border-bottom: 1px solid #e5e7eb; background-color: white; }
        tr:nth-child(even) td { background-color: #f0fdfa; }
        .footer { margin-top: 40px; font-size: 11px; color: #9ca3af; text-align: center; }
    </style></head>
    <body>
        <h2>Reporte de Altas, Bajas y Modificaciones de Equipos</h2>
        <div class='meta'><strong>Ámbito:</strong> AD Domain (Computadoras)<br><strong>Periodo:</strong> Últimos 15 días<br><strong>Fecha Gen:</strong> $((Get-Date).ToString('dd/MM/yyyy HH:mm:ss'))</div>
        <table><thead><tr><th>ID Registro</th><th>Fecha y Hora</th><th>Equipo Afectado (Nombre)</th><th>Operador / Administrador</th><th>Acción Detectada</th></tr></thead>
        <tbody>$($Rows -join "`n")</tbody></table>
        <div class='footer'>Reporte automático generado por el Sistema de Auditoría de Infraestructura de Windows Server</div>
    </body></html>
"@
    $HTMLHeader | Out-File -FilePath $OutputHTML -Encoding UTF8
    Write-Host "[OK] Reportes Generados (HTML + CSV)." -ForegroundColor Green
} else { Write-Host "[!] No se encontraron eventos." -ForegroundColor Yellow }
