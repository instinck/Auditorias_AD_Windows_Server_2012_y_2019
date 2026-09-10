# =========================================================================
#       REPORTE DE CONTRASEÑAS 2019: RESOLUCIÓN DUAL DE ENCODING (WS 2019)
# =========================================================================
$OutputHTML = "C:\AuditoriaLocal\Reporte_Claves_Admin_2019.html"
$OutputCSV  = "C:\AuditoriaLocal\Reporte_Claves_Admin_2019.csv"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "   AUDITANDO CAMBIOS DE CLAVE (POWERSHELL 5.1 / 2019)  " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# Filtro XML de alta velocidad para los últimos 15 días (ID 4724)
$QueryXML = @"
<QueryList>
  <Query Id="0" Path="Security">
    <Select Path="Security">*[System[(EventID=4724) and TimeCreated[timediff(@SystemTime) &lt;= 1296000000]]]</Select>
  </Query>
</QueryList>
"@

$Events = Get-WinEvent -FilterXml $QueryXML -ErrorAction SilentlyContinue

if ($Events) {
    $DataObjects = foreach ($Event in $Events) {
        $EventXML = [xml]$Event.ToXml()
        $TargetData = $EventXML.Event.EventData.Data
        
        $QuienLoHizo     = ($TargetData | Where-Object {$_.Name -eq "SubjectUserName"}).'#text'
        $UsuarioAfectado = ($TargetData | Where-Object {$_.Name -eq "TargetUserName"}).'#text'
        $FechaHora       = $Event.TimeCreated.ToString('dd/MM/yyyy HH:mm:ss')

        if ($QuienLoHizo -and $UsuarioAfectado -and $QuienLoHizo -ne "SYSTEM" -and $QuienLoHizo -ne "LOCAL SERVICE" -and -not ($QuienLoHizo.EndsWith("$")) -and -not ($UsuarioAfectado.EndsWith("$"))) {
            # SOLUCIÓN DE RAÍZ PARA CSV: Encabezados y valores planos sin caracteres especiales
            [PSCustomObject]@{
                "ID Registro"      = $Event.RecordId
                "Fecha y Hora"     = $FechaHora
                "Usuario Afectado" = $UsuarioAfectado
                "Quien lo Realizo" = $QuienLoHizo
                "Tipo de Accion"   = "Restablecido por Administrador"
            }
        }
    }

    if (-not $DataObjects) {
        Write-Host "[!] No se encontraron eventos tras aplicar filtros." -ForegroundColor Yellow
        exit
    }

    # 1. EXPORTACIÓN UNIVERSAL CSV: Al usar caracteres planos y codificación ASCII, abrirá perfecto siempre
    $DataObjects | Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding ascii

    # 2. Construir filas HTML (Aquí sí mantenemos el formato visual corporativo)
    $Rows = foreach ($Obj in $DataObjects) {
        "<tr>
            <td><b>$($Obj."ID Registro")</b></td>
            <td>$($Obj."Fecha y Hora")</td>
            <td>$($Obj."Usuario Afectado")</td>
            <td><strong>$($Obj."Quien lo Realizo")</strong></td>
            <td>Restablecido por Administrador</td>
         </tr>"
    }

    $HTMLHeader = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Reporte AD 2019</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 30px; color: #333; background-color: #fcfcfc; }
        h2 { color: #2563eb; border-bottom: 2px solid #2563eb; padding-bottom: 10px; font-size: 22px; }
        .meta { margin-bottom: 20px; font-size: 13px; color: #555; line-height: 1.6; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 13px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        th { background-color: #2563eb; color: white; text-align: left; padding: 12px 10px; font-weight: 600; }
        td { padding: 10px; border-bottom: 1px solid #e5e7eb; background-color: white; }
        tr:nth-child(even) td { background-color: #f8fafc; }
        .footer { margin-top: 40px; font-size: 11px; color: #9ca3af; text-align: center; }
    </style>
</head>
<body>
    <h2>Reporte de Gesti&oacute;n de Contrase&ntilde;as por Administradores (Plataforma Server 2019)</h2>
    <div class='meta'>
        <strong>&Aacute;mbito:</strong> Active Directory Domain<br>
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

    # 3. Guardar el archivo HTML forzando UTF-8 con BOM para el navegador
    $HTMLHeader | Out-File -FilePath $OutputHTML -Encoding utf8 -Force
    
    Write-Host "[OK] Reportes 2019 unificados con éxito. HTML estético y CSV compatible con Excel." -ForegroundColor Green
} else {
    Write-Host "[!] No se encontraron eventos de reseteo de claves en los últimos 15 días." -ForegroundColor Yellow
}
