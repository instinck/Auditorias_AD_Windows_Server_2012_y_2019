$OutputHTML = "C:\AuditoriaLocal\Reporte_Propiedades_Usuarios_2019.html"
$OutputCSV  = "C:\AuditoriaLocal\Reporte_Propiedades_Usuarios_2019.csv"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "   AUDITORIA FORENSE: PROPIEDADES (POWERSHELL 5.1)    " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

$QueryXML = @'
<QueryList>
  <Query Id="0" Path="Security">
    <Select Path="Security">*[System[(EventID=4738 or EventID=5136) and TimeCreated[timediff(@SystemTime) &lt;= 1296000000]]]</Select>
  </Query>
</QueryList>
'@

$Events = Get-WinEvent -FilterXml $QueryXML -ErrorAction SilentlyContinue

if ($Events) {
    $DataObjects = foreach ($Event in $Events) {
        $EventXML = [xml]$Event.ToXml()
        $TargetData = $EventXML.Event.EventData.Data
        $FechaHora = $Event.TimeCreated.ToString('dd/MM/yyyy HH:mm:ss')
        
        $QuienLoHizo = ($TargetData | Where-Object {$_.Name -eq "SubjectUserName"}).'#text'
        
        if ($QuienLoHizo -eq "SYSTEM" -or $QuienLoHizo -eq "LOCAL SERVICE" -or $QuienLoHizo -eq "ANONYMOUS LOGON" -or $QuienLoHizo.EndsWith("$") -or $QuienLoHizo -eq "MSOL_") {
            continue
        }

        $DetalleEvidenciaCSV = ""
        $UsuarioAfectado = ""
        $DetalleHTML = ""

        if ($Event.Id -eq 5136) {
            $DN = ($TargetData | Where-Object {$_.Name -eq "ObjectDN"}).'#text'
            if ($DN -match "CN=([^,]+)") { $UsuarioAfectado = $Matches[1] } else { $UsuarioAfectado = $DN }
            
            $AtributoLDAP = ($TargetData | Where-Object {$_.Name -eq "AttributeLDAPDisplayName"}).'#text'
            $ValorCambiado = ($TargetData | Where-Object {$_.Name -eq "AttributeValue"}).'#text'
            $Operacion = ($TargetData | Where-Object {$_.Name -eq "OperationType"}).'#text'
            
            $DiccionarioAtributos = @{
                "mail"              = "Correo Electronico"
                "telephoneNumber"   = "Telefono"
                "department"        = "Departamento / Area"
                "title"             = "Puesto / Cargo"
                "userWorkstations"  = "Equipos Permitidos (Logon Workstations)"
                "displayName"       = "Nombre para Mostrar"
                "description"       = "Descripcion"
            }
            $CampoAmigable = if ($DiccionarioAtributos.ContainsKey($AtributoLDAP)) { $DiccionarioAtributos[$AtributoLDAP] } else { $AtributoLDAP }
            
            if ($Operacion -eq "1" -or $Operacion -eq "Value Added" -or $Operacion -eq "Valor añadido") {
                $DetalleEvidenciaCSV = "Anadido al campo $CampoAmigable el valor: $ValorCambiado"
                $DetalleHTML = "Se <span style='color:#16a34a; font-weight:bold;'>ANADIO</span> al campo <b>$CampoAmigable</b> el valor: <code>$ValorCambiado</code>"
            } else {
                $DetalleEvidenciaCSV = "Eliminado del campo $CampoAmigable el valor anterior: $ValorCambiado"
                $DetalleHTML = "Se <span style='color:#dc2626; font-weight:bold;'>ELIMINO / CAMBIO</span> del campo <b>$CampoAmigable</b> el valor anterior: <span style='color:#b91c1c;'>$ValorCambiado</span>"
            }
        } 
        else {
            $UsuarioAfectado = ($TargetData | Where-Object {$_.Name -eq "TargetUserName"}).'#text'
            if ($UsuarioAfectado.EndsWith("$")) { continue }
            
            $Workstations = $TargetData | Where-Object {$_.Name -eq "UserWorkstations"}
            if ($Workstations -and $Workstations.'#text' -and $Workstations.'#text' -ne "-") {
                $DetalleEvidenciaCSV = "Cambio directo en Restriccion de Equipos: $($Workstations.'#text')"
                $DetalleHTML = "Cambio directo en Restriccion de Equipos: <code>$($Workstations.'#text')</code>"
            } else { continue }
        }

        if ($DetalleEvidenciaCSV -and $UsuarioAfectado) {
            [PSCustomObject]@{
                "ID Registro"       = $Event.RecordId
                "Fecha y Hora"       = $FechaHora
                "Usuario Modificado" = $UsuarioAfectado
                "Administrador"      = $QuienLoHizo
                "Evidencia de Cambio"= $DetalleEvidenciaCSV
                "_HTML_Row"          = $DetalleHTML
            }
        }
    }

    if (-not $DataObjects) {
        Write-Host "[!] No se encontraron eventos tras aplicar filtros." -ForegroundColor Yellow
        exit
    }

    $DataObjects | Select-Object "ID Registro", "Fecha y Hora", "Usuario Modificado", "Administrador", "Evidencia de Cambio" | Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding ascii

    $Rows = foreach ($Obj in $DataObjects) {
        "<tr>
            <td><b>$($Obj."ID Registro")</b></td>
            <td>$($Obj."Fecha y Hora")</td>
            <td><strong>$($Obj."Usuario Modificado")</strong></td>
            <td>$($Obj."Administrador")</td>
            <td>$($Obj._HTML_Row)</td>
         </tr>"
    }

    $HTMLHeader = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Reporte Forense AD 2019</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 30px; color: #333; background-color: #fcfcfc; }
        h2 { color: #6b21a8; border-bottom: 2px solid #6b21a8; padding-bottom: 10px; font-size: 22px; }
        .meta { margin-bottom: 20px; font-size: 13px; color: #555; line-height: 1.6; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 13px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        th { background-color: #6b21a8; color: white; text-align: left; padding: 12px 10px; font-weight: 600; }
        td { padding: 12px 10px; border-bottom: 1px solid #e5e7eb; background-color: white; vertical-align: top; line-height: 1.5; }
        tr:nth-child(even) td { background-color: #faf5ff; }
        code { background-color: #f3e8ff; color: #581c87; padding: 3px 8px; border-radius: 4px; font-family: Consolas, monospace; font-size: 12px; border: 1px solid #e9d5ff; }
        .footer { margin-top: 40px; font-size: 11px; color: #9ca3af; text-align: center; }
    </style>
</head>
<body>
    <h2>Reporte de Modificaciones de Usuarios y Registro de Evidencia (Plataforma Server 2019)</h2>
    <div class='meta'>
        <strong>&Aacute;mbito:</strong> Active Directory Domain (Auditor&iacute;a Forense)<br>
        <strong>Periodo:</strong> &Uacute;ltimos 15 d&iacute;as<br>
        <strong>Fecha de generaci&oacute;n:</strong> $((Get-Date).ToString('dd/MM/yyyy HH:mm:ss'))
    </div>
    <table>
        <thead>
            <tr>
                <th>ID Registro</th>
                <th>Fecha y Hora</th>
                <th>Usuario Modificado</th>
                <th>Administrador Responsable</th>
                <th>Evidencia de Cambios</th>
            </tr>
        </thead>
        <tbody>
            $($Rows -join "`n")
        </tbody>
    </table>
    <div class='footer'>Reporte de evidencia autom&aacute;tico - Generaci&oacute;n Moderna PowerShell 5.1</div>
</body>
</html>
"@

    $HTMLHeader | Out-File -FilePath $OutputHTML -Encoding utf8 -Force
    Write-Host "[OK] Reporte forense 2019 generado con éxito." -ForegroundColor Green
} else {
    Write-Host "[!] No se encontraron eventos de modificacion en los ultimos 15 dias." -ForegroundColor Yellow
}
