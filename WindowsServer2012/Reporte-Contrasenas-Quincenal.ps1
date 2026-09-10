$OutputHTML = "C:\AuditoriaLocal\Reporte_Claves_Admin_Quincenal.html"
$OutputCSV  = "C:\AuditoriaLocal\Reporte_Claves_Admin_Quincenal.csv"
$FechaLimite = (Get-Date).AddDays(-15)

Write-Host "Buscando cambios de clave desde: $($FechaLimite.ToString('dd/MM/yyyy HH:mm:ss'))" -ForegroundColor Cyan

$Events = Get-WinEvent -FilterHashtable @{LogName='Security';Id=4724;StartTime=$FechaLimite} -ErrorAction SilentlyContinue

if ($Events) {
    # 1. Crear el objeto de datos en memoria agregando el RecordID
    $DataObjects = foreach ($Event in $Events) {
        $EventXML = [xml]$Event.ToXml()
        $TargetData = $EventXML.Event.EventData.Data
        
        $QuienLoHizo = ($TargetData | Where-Object {$_.Name -eq "SubjectUserName"}).'#text'
        $UsuarioAfectado = ($TargetData | Where-Object {$_.Name -eq "TargetUserName"}).'#text'

        if ($QuienLoHizo -ne "SYSTEM" -and $QuienLoHizo -ne "LOCAL SERVICE" -and -not ($QuienLoHizo.EndsWith("$")) -and -not ($UsuarioAfectado.EndsWith("$"))) {
            [PSCustomObject]@{
                "ID Registro"     = $Event.RecordId
                "Fecha y Hora"     = $Event.TimeCreated.ToString('dd/MM/yyyy HH:mm:ss')
                "Usuario Afectado" = $UsuarioAfectado
                "Quién lo Realizó" = $QuienLoHizo
                "Tipo de Acción"   = "Restablecido por Administrador"
            }
        }
    }

    # 2. Exportar inmediatamente a CSV para Excel
    $DataObjects | Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding UTF8

    # 3. Generar el HTML Corporativo usando los mismos datos del objeto
    $Rows = foreach ($Obj in $DataObjects) {
        "<tr>
            <td><b>$($Obj."ID Registro")</b></td>
            <td>$($Obj."Fecha y Hora")</td>
            <td>$($Obj."Usuario Afectado")</td>
            <td><strong>$($Obj."Quién lo Realizó")</strong></td>
            <td>$($Obj."Tipo de Acción")</td>
         </tr>"
    }

    $HTMLHeader = @"
    <html>
    <head><meta charset='UTF-8'><style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 30px; color: #333; }
        h2 { color: #1e3a8a; border-bottom: 2px solid #1e3a8a; padding-bottom: 10px; font-size: 22px; }
        .meta { margin-bottom: 20px; font-size: 13px; color: #555; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 13px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        th { background-color: #1e3a8a; color: white; text-align: left; padding: 12px 10px; font-weight: 600; }
        td { padding: 10px; border-bottom: 1px solid #e5e7eb; background-color: white; }
        tr:nth-child(even) td { background-color: #f8fafc; }
        .footer { margin-top: 40px; font-size: 11px; color: #9ca3af; text-align: center; }
    </style></head>
    <body>
        <h2>Reporte de Gestión de Contraseñas por Administradores</h2>
        <div class='meta'><strong>Ámbito:</strong> Active Directory Domain<br><strong>Periodo:</strong> Últimos 15 días<br><strong>Fecha Gen:</strong> $((Get-Date).ToString('dd/MM/yyyy HH:mm:ss'))</div>
        <table><thead><tr><th>ID Registro</th><th>Fecha y Hora</th><th>Usuario Afectado</th><th>Administrador Responsable</th><th>Acción Detectada</th></tr></thead>
        <tbody>$($Rows -join "`n")</tbody></table>
        <div class='footer'>Reporte automático generado por el Sistema de Auditoría de Identidad de Windows Server</div>
    </body></html>
"@
    $HTMLHeader | Out-File -FilePath $OutputHTML -Encoding UTF8
    Write-Host "[OK] Reportes Generados (HTML + CSV)." -ForegroundColor Green
} else { Write-Host "[!] No se encontraron eventos." -ForegroundColor Yellow }
