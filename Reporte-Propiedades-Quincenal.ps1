$OutputHTML = "C:\AuditoriaLocal\Reporte_Propiedades_Usuarios_Quincenal.html"
$FechaLimite = (Get-Date).AddDays(-15)

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "   AUDITORÍA FORENSE: MODIFICACIONES Y VALORES REALES   " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Buscando evidencia detallada desde: $($FechaLimite.ToString('dd/MM/yyyy HH:mm:ss'))`n" -ForegroundColor Cyan

# Buscamos 4738 (Modificación) y 5136 (Cambio de valor en el Directorio)
$Events = Get-WinEvent -FilterHashtable @{LogName='Security';Id=4738,5136;StartTime=$FechaLimite} -ErrorAction SilentlyContinue

if ($Events) {
    $Rows = foreach ($Event in $Events) {
        $EventXML = [xml]$Event.ToXml()
        $TargetData = $EventXML.Event.EventData.Data
        $FechaHora = $Event.TimeCreated.ToString('dd/MM/yyyy HH:mm:ss')
        
        $QuienLoHizo = ($TargetData | Where-Object {$_.Name -eq "SubjectUserName"}).'#text'
        
        # Filtros estrictos de exclusión de cuentas de sistema y de máquina ($) inmediatamente
        if ($QuienLoHizo -eq "SYSTEM" -or 
            $QuienLoHizo -eq "LOCAL SERVICE" -and 
            $QuienLoHizo -eq "ANONYMOUS LOGON" -or 
            $QuienLoHizo -eq "INICIO DE SESIÓN ANÓNIMO" -or
            $QuienLoHizo.EndsWith("$") -or 
            $QuienLoHizo -eq "MSOL_") {
            continue
        }

        $DetalleEvidencia = ""
        $UsuarioAfectado = ""

        if ($Event.Id -eq 5136) {
            $DN = ($TargetData | Where-Object {$_.Name -eq "ObjectDN"}).'#text'
            # Extraer el nombre común (CN) del usuario
            if ($DN -match "CN=([^,]+)") { $UsuarioAfectado = $Matches[1] } else { $UsuarioAfectado = $DN }
            
            $AtributoLDAP = ($TargetData | Where-Object {$_.Name -eq "AttributeLDAPDisplayName"}).'#text'
            $ValorCambiado = ($TargetData | Where-Object {$_.Name -eq "AttributeValue"}).'#text'
            $Operacion = ($TargetData | Where-Object {$_.Name -eq "OperationType"}).'#text'
            
            # Diccionario de campos de Active Directory a español claro
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
            
            # CORRECCIÓN CRÍTICA: Validar operación tanto en inglés como en español
            if ($Operacion -eq "1" -or $Operacion -eq "Value Added" -or $Operacion -eq "Valor añadido") {
                $DetalleEvidencia = "Se <span style='color:#16a34a; font-weight:bold;'>AÑADIÓ</span> al campo <b>$CampoAmigable</b> el valor: <code>$ValorCambiado</code>"
            } else {
                $DetalleEvidencia = "Se <span style='color:#dc2626; font-weight:bold;'>ELIMINÓ / CAMBIÓ</span> del campo <b>$CampoAmigable</b> el valor anterior: <span style='color:#b91c1c;'>$ValorCambiado</span>"
            }
        } 
        else {
            # Evento 4738 estándar (Solo lo mostramos si aporta datos específicos)
            $UsuarioAfectado = ($TargetData | Where-Object {$_.Name -eq "TargetUserName"}).'#text'
            if ($UsuarioAfectado.EndsWith("$")) { continue }
            
            $Workstations = $TargetData | Where-Object {$_.Name -eq "UserWorkstations"}
            if ($Workstations -and $Workstations.'#text' -and $Workstations.'#text' -ne "-") {
                $DetalleEvidencia = "Cambio directo en Restricción de Equipos: <code>$($Workstations.'#text')</code>"
            } else {
                # Omitimos las líneas de "Modificación general" repetitivas si ya tenemos auditoría fina activa
                continue 
            }
        }

        # Generar la fila si se logró extraer evidencia real
        if ($DetalleEvidencia -and $UsuarioAfectado) {
            "<tr>
                <td>$FechaHora</td>
                <td><strong>$UsuarioAfectado</strong></td>
                <td>$QuienLoHizo</td>
                <td>$DetalleEvidencia</td>
             </tr>"
        }
    }

    # Diseñar la plantilla estética estilo Reporte Forense / Evidencia
    $HTMLHeader = @"
    <html>
    <head>
    <meta charset='UTF-8'>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 30px; color: #333; background-color: #fcfcfc; }
        h2 { color: #6b21a8; border-bottom: 2px solid #6b21a8; padding-bottom: 10px; font-size: 22px; }
        .meta { margin-bottom: 20px; font-size: 13px; color: #555; line-height: 1.6; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 13px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        th { background-color: #6b21a8; color: white; text-align: left; padding: 12px 10px; font-weight: 600; }
        td { padding: 12px 10px; border-bottom: 1px solid #e5e7eb; background-color: white; vertical-align: top; line-height: 1.5; }
        tr:nth-child(even) td { background-color: #faf5ff; }
        code { background-color: #f3e8ff; color: #581c87; padding: 3px 8px; border-radius: 4px; font-family: Consolas, monospace; font-size: 12px; border: 1px solid #e9d5ff; }
        .footer { margin-top: 40px; font-size: 11px; color: #9ca3af; text-align: center; border-top: 1px solid #e5e7eb; padding-top: 10px; }
    </style>
    </head>
    <body>
        <h2>Reporte de Modificaciones de Usuarios y Registro de Evidencia</h2>
        <div class='meta'>
            <strong>Ámbito:</strong> Active Directory Domain (Auditoría Forense de Atributos)<br>
            <strong>Periodo auditado:</strong> Últimos 15 días (Desde la fecha $($FechaLimite.ToString('dd/MM/yyyy')))<br>
            <strong>Fecha de generación:</strong> $((Get-Date).ToString('dd/MM/yyyy HH:mm:ss'))
        </div>
        <table>
            <thead>
                <tr>
                    <th>Fecha y Hora</th>
                    <th>Usuario Modificado</th>
                    <th>Administrador Responsable</th>
                    <th>Evidencia de Cambios (Propiedad y Valor Real)</th>
                </tr>
            </thead>
            <tbody>
                $($Rows -join "`n")
            </tbody>
        </table>
        <div class='footer'>Reporte de evidencia automática generado por el Sistema de Seguridad de Windows Server</div>
    </body>
    </html>
"@

    $HTMLHeader | Out-File -FilePath $OutputHTML -Encoding UTF8
    Write-Host "[OK] Proceso terminado exitosamente." -ForegroundColor Green
    Write-Host "[OK] Reporte con evidencia de valores generado en: $OutputHTML" -ForegroundColor Green
} else {
    Write-Host "[!] No se encontraron eventos de modificación en los últimos 15 días." -ForegroundColor Yellow
}
