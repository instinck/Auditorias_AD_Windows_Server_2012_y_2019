$OutputHTML = "C:\AuditoriaLocal\Reporte_Propiedades_Usuarios_Quincenal.html"
$OutputCSV  = "C:\AuditoriaLocal\Reporte_Propiedades_Usuarios_Quincenal.csv"
$FechaLimite = (Get-Date).AddDays(-15)

Write-Host "Buscando evidencia detallada desde: $($FechaLimite.ToString('dd/MM/yyyy HH:mm:ss'))" -ForegroundColor Cyan

$Events = Get-WinEvent -FilterHashtable @{LogName='Security';Id=4738,5136;StartTime=$FechaLimite} -ErrorAction SilentlyContinue

if ($Events) {
    $DataObjects = foreach ($Event in $Events) {
        $EventXML = [xml]$Event.ToXml()
        $TargetData = $EventXML.Event.EventData.Data
        
        $QuienLoHizo = ($TargetData | Where-Object {$_.Name -eq "SubjectUserName"}).'#text'
        
        if ($QuienLoHizo -eq "SYSTEM" -or $QuienLoHizo -eq "LOCAL SERVICE" -or $QuienLoHizo -eq "ANONYMOUS LOGON" -or $QuienLoHizo -eq "INICIO DE SESIÓN ANÓNIMO" -or $QuienLoHizo.EndsWith("$") -or $QuienLoHizo -eq "MSOL_") {
            continue
        }

        $DetalleEvidenciaText = ""
        $UsuarioAfectado = ""
        $DetalleHTML = ""

        if ($Event.Id -eq 5136) {
            $DN = ($TargetData | Where-Object {$_.Name -eq "ObjectDN"}).'#text'
            if ($DN -match "CN=([^,]+)") { $UsuarioAfectado = $Matches[1] } else { $UsuarioAfectado = $DN }
            
            $AtributoLDAP = ($TargetData | Where-Object {$_.Name -eq "AttributeLDAPDisplayName"}).'#text'
            $ValorCambiado = ($TargetData | Where-Object {$_.Name -eq "AttributeValue"}).'#text'
            $Operacion = ($TargetData | Where-Object {$_.Name -eq "OperationType"}).'#text'
            
            $DiccionarioAtributos = @{
                "mail"              = "Correo Electrónico"
                "telephoneNumber"   = "Teléfono"
                "department"        = "Departamento / Área"
                "title"             = "Puesto / Cargo"
                "userWorkstations"  = "Equipos Permitidos (Logon Workstations)"
                "displayName"       = "Nombre para Mostrar"
                "description"       = "Descripción"
            }
            $CampoAmigable = if ($DiccionarioAtributos.ContainsKey($AtributoLDAP)) { $DiccionarioAtributos[$AtributoLDAP] } else { $AtributoLDAP }
            
            if ($Operacion -eq "1" -or $Operacion -eq "Value Added" -or $Operacion -eq "Valor añadido") {
                $DetalleEvidenciaText = "Añadido al campo $CampoAmigable el valor: $ValorCambiado"
                $DetalleHTML = "Se <span style='color:#16a34a; font-weight:bold;'>AÑADIÓ</span> al campo <b>$CampoAmigable</b> el valor: <code>$ValorCambiado</code>"
            } else {
                $DetalleEvidenciaText = "Eliminado del campo $CampoAmigable el valor anterior: $ValorCambiado"
                $DetalleHTML = "Se <span style='color:#dc2626; font-weight:bold;'>ELIMINÓ / CAMBIÓ</span> del campo <b>$CampoAmigable</b> el valor anterior: <span style='color:#b91c1c;'>$ValorCambiado</span>"
            }
        } 
        else {
            $UsuarioAfectado = ($TargetData | Where-Object {$_.Name -eq "TargetUserName"}).'#text'
            if ($UsuarioAfectado.EndsWith("$")) { continue }
            
            $Workstations = $TargetData | Where-Object {$_.Name -eq "UserWorkstations"}
            if ($Workstations -and $Workstations.'#text' -and $Workstations.'#text' -ne "-") {
                $DetalleEvidenciaText = "Cambio directo en Restricción de Equipos: $($Workstations.'#text')"
                $DetalleHTML = "Cambio directo en Restricción de Equipos: <code>$($Workstations.'#text')</code>"
            } else { continue }
        }

        if ($DetalleEvidenciaText -and $UsuarioAfectado) {
            [PSCustomObject]@{
                "ID Registro"       = $Event.RecordId
                "Fecha y Hora"       = $Event.TimeCreated.ToString('dd/MM/yyyy HH:mm:ss')
                "Usuario Modificado" = $UsuarioAfectado
                "Administrador"      = $QuienLoHizo
                "Evidencia de Cambio"= $DetalleEvidenciaText
                "_HTML_Row"          = $DetalleHTML  # Campo auxiliar interno oculto para el HTML
            }
        }
    }

    # Exportar a CSV filtrando el campo auxiliar de HTML para que quede un Excel limpio
    $DataObjects | Select-Object "ID Registro", "Fecha y Hora", "Usuario Modificado", "Administrador", "Evidencia de Cambio" | Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding UTF8

    # Construir el HTML
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
    <html>
    <head><meta charset='UTF-8'><style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 30px; color: #333; }
        h2 { color: #6b21a8; border-bottom: 2px solid #6b21a8; padding-bottom: 10px; font-size: 22px; }
        .meta { margin-bottom: 20px; font-size: 13px; color: #555; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 13px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        th { background-color: #6b21a8; color: white; text-align: left; padding: 12px 10px; }
        td { padding: 12px 10px; border-bottom: 1px solid #e5e7eb; background-color: white; vertical-align: top; }
        tr:nth-child(even) td { background-color: #faf5ff; }
        code { background-color: #f3e8ff; color: #581c87; padding: 3px 8px; border-radius: 4px; font-family: Consolas, monospace; font-size: 12px; }
        .footer { margin-top: 40px; font-size: 11px; color: #9ca3af; text-align: center; }
    </style></head>
    <body>
        <h2>Reporte de Modificaciones de Usuarios y Registro de Evidencia</h2>
        <div class='meta'><strong>Ámbito:</strong> AD Domain<br><strong>Periodo:</strong> Últimos 15 días<br><strong>Fecha Gen:</strong> $((Get-Date).ToString('dd/MM/yyyy HH:mm:ss'))</div>
        <table><thead><tr><th>ID Registro</th><th>Fecha y Hora</th><th>Usuario Modificado</th><th>Administrador Responsable</th><th>Evidencia de Cambios</th></tr></thead>
        <tbody>$($Rows -join "`n")</tbody></table>
        <div class='footer'>Reporte de evidencia automática generado por el Sistema de Seguridad de Windows Server</div>
    </body></html>
"@
    $HTMLHeader | Out-File -FilePath $OutputHTML -Encoding UTF8
    Write-Host "[OK] Reportes Generados (HTML + CSV)." -ForegroundColor Green
} else { Write-Host "[!] No se encontraron eventos." -ForegroundColor Yellow }
