$OutputHTML = "C:\AuditoriaLocal\Reporte_Gestion_Equipos_2019.html"
$OutputCSV  = "C:\AuditoriaLocal\Reporte_Gestion_Equipos_2019.csv"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "   AUDITANDO GESTION DE EQUIPOS (POWERSHELL 5.1)      " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

$QueryXML = @'
<QueryList>
  <Query Id="0" Path="Security">
    <Select Path="Security">*[System[(EventID=4741 or EventID=4742 or EventID=4743) and TimeCreated[timediff(@SystemTime) &lt;= 1296000000]]]</Select>
  </Query>
</QueryList>
'@

$Events = Get-WinEvent -FilterXml $QueryXML -ErrorAction SilentlyContinue

if ($Events) {
    $DataObjects = foreach ($Event in $Events) {
        $EventXML = [xml]$Event.ToXml()
        $TargetData = $EventXML.Event.EventData.Data
        
        $QuienLoHizo     = ($TargetData | Where-Object {$_.Name -eq "SubjectUserName"}).'#text'
        $EquipoAfectado  = ($TargetData | Where-Object {$_.Name -eq "TargetUserName"}).'#text'
        $FechaHora       = $Event.TimeCreated.ToString('dd/MM/yyyy HH:mm:ss')

        if ($QuienLoHizo -and $EquipoAfectado -and $QuienLoHizo -ne "SYSTEM" -and $QuienLoHizo -ne "LOCAL SERVICE" -and $QuienLoHizo -ne "ANONYMOUS LOGON" -and $QuienLoHizo -ne "NETWORK SERVICE") {
            
            $TipoAccionCSV = switch ($Event.Id) {
                4741 { "Equipo UNIDO al dominio (Creado)" }
                4743 { "Equipo ELIMINADO del dominio" }
                4742 { "Propiedades de equipo modificadas / Estado cambiado" }
            }

            [PSCustomObject]@{
                "ID Registro"     = $Event.RecordId
                "Fecha y Hora"     = $FechaHora
                "Equipo Afectado"  = $EquipoAfectado
                "Quien lo Realizo" = $QuienLoHizo
                "Tipo de Accion"   = $TipoAccionCSV
            }
        }
    }

    if (-not $DataObjects) {
        Write-Host "[!] No se encontraron eventos tras aplicar filtros." -ForegroundColor Yellow
        exit
    }

    $DataObjects | Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding ascii

    $Rows = foreach ($Obj in $DataObjects) {
        "<tr>
            <td><b>$($Obj."ID Registro")</b></td>
            <td>$($Obj."Fecha y Hora")</td>
            <td><strong>$($Obj."Equipo Afectado")</strong></td>
            <td>$($Obj."Quien lo Realizo")</td>
            <td>$($Obj."Tipo de Accion")</td>
         </tr>"
    }

    $HTMLHeader = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Reporte Equipos AD 2019</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 30px; color: #333; background-color: #fcfcfc; }
        h2 { color: #0f766e; border-bottom: 2px solid #0f766e; padding-bottom: 10px; font-size: 22px; }
        .meta { margin-bottom: 20px; font-size: 13px; color: #555; line-height: 1.6; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 13px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        th { background-color: #0f766e; color: white; text-align: left; padding: 12px 10px; font-weight: 600; }
        td { padding: 10px; border-bottom: 1px solid #e5e7eb; background-color: white; }
        tr:nth-child(even) td { background-color: #f0fdfa; }
        .footer { margin-top: 40px; font-size: 11px; color: #9ca3af; text-align: center; }
    </style>
</head>
<body>
    <h2>Reporte de Altas, Bajas y Modificaciones de Equipos (Plataforma Server 2019)</h2>
    <div class='meta'>
        <strong>&Aacute;mbito:</strong> Active Directory Domain (Computadoras)<br>
        <strong>Periodo:</strong> &Uacute;ltimos 15 d&iacute;as<br>
        <strong>Fecha de generaci&oacute;n:</strong> $((Get-Date).ToString('dd/MM/yyyy HH:mm:ss'))
    </div>
    <table>
        <thead>
            <tr>
                <th>ID Registro</th>
                <th>Fecha y Hora</th>
                <th>Equipo Afectado (Nombre)</th>
                <th>Operador / Administrador</th>
                <th>Acci&oacute;n Detectada</th>
            </tr>
        </thead>
        <tbody>
            $($Rows -join "`n")
        </tbody>
    </table>
    <div class='footer'>Reporte autom&aacute;tico de seguridad - Generaci&oacute;n Moderna PowerShell 5.1</div>
</body>
</html>
"@

    $HTMLHeader | Out-File -FilePath $OutputHTML -Encoding utf8 -Force
    Write-Host "[OK] Reporte de equipos 2019 generado con éxito." -ForegroundColor Green
} else { 
    Write-Host "[!] No se encontraron eventos de equipos en los ultimos 15 dias." -ForegroundColor Yellow 
}
