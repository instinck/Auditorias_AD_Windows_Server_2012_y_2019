$OutputHTML = "C:\AuditoriaLocal\Reporte_Gestion_Usuarios_2019.html"
$OutputCSV  = "C:\AuditoriaLocal\Reporte_Gestion_Usuarios_2019.csv"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "   AUDITANDO GESTION DE USUARIOS (POWERSHELL 5.1)     " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

$QueryXML = @'
<QueryList>
  <Query Id="0" Path="Security">
    <Select Path="Security">*[System[(EventID=4720 or EventID=4722 or EventID=4725 or EventID=4726) and TimeCreated[timediff(@SystemTime) &lt;= 1296000000]]]</Select>
  </Query>
</QueryList>
'@

$Events = Get-WinEvent -FilterXml $QueryXML -ErrorAction SilentlyContinue

if ($Events) {
    $DataObjects = foreach ($Event in $Events) {
        $EventXML = [xml]$Event.ToXml()
        $TargetData = $EventXML.Event.EventData.Data
        
        $QuienLoHizo     = ($TargetData | Where-Object {$_.Name -eq "SubjectUserName"}).'#text'
        $UsuarioAfectado = ($TargetData | Where-Object {$_.Name -eq "TargetUserName"}).'#text'
        $FechaHora       = $Event.TimeCreated.ToString('dd/MM/yyyy HH:mm:ss')

        if ($QuienLoHizo -and $UsuarioAfectado -and $QuienLoHizo -ne "SYSTEM" -and $QuienLoHizo -ne "LOCAL SERVICE" -and $QuienLoHizo -ne "ANONYMOUS LOGON" -and -not ($QuienLoHizo.EndsWith("$")) -and -not ($UsuarioAfectado.EndsWith("$"))) {
            
            $TipoAccionCSV = switch ($Event.Id) {
                4720 { "Usuario CREADO (Alta)" }
                4722 { "Usuario HABILITADO" }
                4725 { "Usuario DESHABILITADO (Baja Temporal)" }
                4726 { "Usuario ELIMINADO (Baja Definitiva)" }
            }

            [PSCustomObject]@{
                "ID Registro"     = $Event.RecordId
                "Fecha y Hora"     = $FechaHora
                "Usuario Afectado" = $UsuarioAfectado
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
        $BadgeColor = switch -wildcard ($Obj."Tipo de Accion") {
            "*CREADO*"        { "#16a34a" }
            "*HABILITADO*"    { "#2563eb" }
            "*DESHABILITADO*" { "#ea580c" }
            "*ELIMINADO*"     { "#dc2626" }
        }

        "<tr>
            <td><b>$($Obj."ID Registro")</b></td>
            <td>$($Obj."Fecha y Hora")</td>
            <td>$($Obj."Usuario Afectado")</td>
            <td>$($Obj."Quien lo Realizo")</td>
            <td><span style='color:$BadgeColor; font-weight:bold;'>$($Obj."Tipo de Accion")</span></td>
         </tr>"
    }

    $HTMLHeader = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Reporte Usuarios AD 2019</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 30px; color: #333; background-color: #fcfcfc; }
        h2 { color: #334155; border-bottom: 2px solid #334155; padding-bottom: 10px; font-size: 22px; }
        .meta { margin-bottom: 20px; font-size: 13px; color: #555; line-height: 1.6; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 13px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        th { background-color: #334155; color: white; text-align: left; padding: 12px 10px; font-weight: 600; }
        td { padding: 10px; border-bottom: 1px solid #e5e7eb; background-color: white; }
        tr:nth-child(even) td { background-color: #f8fafc; }
        .footer { margin-top: 40px; font-size: 11px; color: #9ca3af; text-align: center; }
    </style>
</head>
<body>
    <h2>Reporte de Gesti&oacute;n de Cuentas de Usuarios (Altas y Bajas - Plataforma Server 2019)</h2>
    <div class='meta'>
        <strong>&Aacute;mbito:</strong> Active Directory Domain (Ciclo de Vida)<br>
        <strong>Periodo:</strong> &Uacute;ltimos 15 d&iacute;as<br>
        <strong>Fecha de generaci&oacute;n:</strong> $((Get-Date).ToString('dd/MM/yyyy HH:mm:ss'))
    </div>
    <table>
        <thead>
            <tr>
                <th>ID Registro</th>
                <th>Fecha y Hora</th>
                <th>Usuario Afectado</th>
                <th>Administrador Responsable</th>
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
    Write-Host "[OK] Reporte de usuarios 2019 generado con éxito." -ForegroundColor Green
} else { 
    Write-Host "[!] No se encontraron eventos de gestion de usuarios en los ultimos 15 dias." -ForegroundColor Yellow 
}
