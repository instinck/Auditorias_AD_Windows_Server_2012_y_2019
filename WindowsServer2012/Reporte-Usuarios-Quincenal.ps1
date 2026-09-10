$OutputHTML = "C:\AuditoriaLocal\Reporte_Gestion_Usuarios_Quincenal.html"
$OutputCSV  = "C:\AuditoriaLocal\Reporte_Gestion_Usuarios_Quincenal.csv"
$FechaLimite = (Get-Date).AddDays(-15)

Write-Host "Buscando gestión de usuarios desde: $($FechaLimite.ToString('dd/MM/yyyy HH:mm:ss'))" -ForegroundColor Cyan

$Events = Get-WinEvent -FilterHashtable @{LogName='Security';Id=4720,4722,4725,4726;StartTime=$FechaLimite} -ErrorAction SilentlyContinue

if ($Events) {
    $DataObjects = foreach ($Event in $Events) {
        $EventXML = [xml]$Event.ToXml()
        $TargetData = $EventXML.Event.EventData.Data
        
        $QuienLoHizo = ($TargetData | Where-Object {$_.Name -eq "SubjectUserName"}).'#text'
        $UsuarioAfectado = ($TargetData | Where-Object {$_.Name -eq "TargetUserName"}).'#text'

        if ($QuienLoHizo -ne "SYSTEM" -and $QuienLoHizo -ne "LOCAL SERVICE" -and $QuienLoHizo -ne "ANONYMOUS LOGON" -and $QuienLoHizo -ne "INICIO DE SESIÓN ANÓNIMO" -and -not ($QuienLoHizo.EndsWith("$")) -and -not ($UsuarioAfectado.EndsWith("$"))) {
            
            $TipoAccionText = switch ($Event.Id) {
                4720 { "Usuario CREADO (Alta)" }
                4722 { "Usuario HABILITADO" }
                4725 { "Usuario DESHABILITADO (Baja Temporal)" }
                4726 { "Usuario ELIMINADO (Baja Definitiva)" }
            }

            [PSCustomObject]@{
                "ID Registro"     = $Event.RecordId
                "Fecha y Hora"     = $Event.TimeCreated.ToString('dd/MM/yyyy HH:mm:ss')
                "Usuario Afectado" = $UsuarioAfectado
                "Quién lo Realizó" = $QuienLoHizo
                "Tipo de Acción"   = $TipoAccionText
            }
        }
    }

    $DataObjects | Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding UTF8

    $Rows = foreach ($Obj in $DataObjects) {
        $BadgeColor = switch -wildcard ($Obj."Tipo de Acción") {
            "*CREADO*"      { "#16a34a" }
            "*HABILITADO*"   { "#2563eb" }
            "*DESHABILITADO*"{ "#ea580c" }
            "*ELIMINADO*"    { "#dc2626" }
        }
        "<tr>
            <td><b>$($Obj."ID Registro")</b></td>
            <td>$($Obj."Fecha y Hora")</td>
            <td>$($Obj."Usuario Afectado")</td>
            <td>$($Obj."Quién lo Realizó")</td>
            <td><span style='color:$BadgeColor; font-weight:bold;'>$($Obj."Tipo de Acción")</span></td>
         </tr>"
    }

    $HTMLHeader = @"
    <html>
    <head><meta charset='UTF-8'><style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 30px; color: #333; }
        h2 { color: #334155; border-bottom: 2px solid #334155; padding-bottom: 10px; font-size: 22px; }
        .meta { margin-bottom: 20px; font-size: 13px; color: #555; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 13px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        th { background-color: #334155; color: white; text-align: left; padding: 12px 10px; }
        td { padding: 10px; border-bottom: 1px solid #e5e7eb; background-color: white; }
        tr:nth-child(even) td { background-color: #f8fafc; }
        .footer { margin-top: 40px; font-size: 11px; color: #9ca3af; text-align: center; }
    </style></head>
    <body>
        <h2>Reporte de Gestión de Cuentas de Usuarios (Altas y Bajas)</h2>
        <div class='meta'><strong>Ámbito:</strong> AD Domain<br><strong>Periodo:</strong> Últimos 15 días<br><strong>Fecha Gen:</strong> $((Get-Date).ToString('dd/MM/yyyy HH:mm:ss'))</div>
        <table><thead><tr><th>ID Registro</th><th>Fecha y Hora</th><th>Usuario Afectado</th><th>Administrador Responsable</th><th>Acción Detectada</th></tr></thead>
        <tbody>$($Rows -join "`n")</tbody></table>
        <div class='footer'>Reporte automático generado por el Sistema de Auditoría de Identidad de Windows Server</div>
    </body></html>
"@
    $HTMLHeader | Out-File -FilePath $OutputHTML -Encoding UTF8
    Write-Host "[OK] Reportes Generados (HTML + CSV)." -ForegroundColor Green
} else { Write-Host "[!] No se encontraron eventos." -ForegroundColor Yellow }
