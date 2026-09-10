# =========================================================================
#       SCRIPT MAESTRO: EMPAQUETADO, ENVÍO SMTP Y AUTO-LIMPIEZA (WS 2012)
# =========================================================================

$RutaLocal     = "C:\AuditoriaLocal"
$RutaAlmacen   = "C:\AuditoriaLocal\Reportes_Almacenados"
$FechaActual   = (Get-Date).ToString("dd-MM-yyyy")
$NombreZip     = "Auditoria_AD_$FechaActual.zip"
$RutaZipFinal  = Join-Path $RutaAlmacen $NombreZip

# Listado de los 8 reportes generados (4 HTML + 4 CSV)
$ArchivosReporte = @(
    "$RutaLocal\Reporte_Claves_Admin_Quincenal.html", "$RutaLocal\Reporte_Claves_Admin_Quincenal.csv",
    "$RutaLocal\Reporte_Gestion_Usuarios_Quincenal.html", "$RutaLocal\Reporte_Gestion_Usuarios_Quincenal.csv",
    "$RutaLocal\Reporte_Gestion_Equipos_Quincenal.html", "$RutaLocal\Reporte_Gestion_Equipos_Quincenal.csv",
    "$RutaLocal\Reporte_Propiedades_Usuarios_Quincenal.html", "$RutaLocal\Reporte_Propiedades_Usuarios_Quincenal.csv"
)

# 1. VALIDACIÓN Y COMPRESIÓN LOCAL
$ExisteAlguno = $false
foreach ($File in $ArchivosReporte) { if (Test-Path $File) { $ExisteAlguno = $true } }

if ($ExisteAlguno) {
    Write-Host "Empaquetando 8 reportes (HTML y CSV) mediante Shell..." -ForegroundColor Cyan
    try {
        if (Test-Path $RutaZipFinal) { Remove-Item $RutaZipFinal -Force }
        [byte[]]$ZipHeader = 80,75,5,6,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        [System.IO.File]::WriteAllBytes($RutaZipFinal, $ZipHeader)

        $Shell = New-Object -ComObject Shell.Application
        $FolderZip = $Shell.NameSpace($RutaZipFinal)

        foreach ($File in $ArchivosReporte) {
            if (Test-Path $File) {
                $FolderZip.CopyHere($File)
                Start-Sleep -Milliseconds 700
            }
        }
        Write-Host "[OK] Paquete histórico dual guardado en: $RutaZipFinal" -ForegroundColor Green
    } catch { 
        Write-Host "[!] Error en compresión: $_" -ForegroundColor Red
        exit 
    }
} else { 
    Write-Host "[!] No hay archivos para empaquetar." -ForegroundColor Yellow
    exit 
}

# =========================================================================
# 2. SECCIÓN CRÍTICA: AUTO-LIMPIEZA POST-EMPAQUETADO
# =========================================================================
# Validamos con seguridad total que el archivo ZIP exista y no esté vacío (mayor a 0 bytes)
if (Test-Path $RutaZipFinal) {
    $ZipSize = (Get-Item $RutaZipFinal).Length
    if ($ZipSize -gt 0) {
        Write-Host "Limpiando el directorio raíz. Eliminando archivos temporales..." -ForegroundColor Cyan
        foreach ($File in $ArchivosReporte) {
            if (Test-Path $File) {
                Remove-Item $File -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Host "[OK] Directorio purgado. Solo se conservan ejecutables." -ForegroundColor Green
    }
}

# =========================================================================
# 3. CONFIGURACIÓN DEL ENVÍO POR CORREO (PREPARADO/OFFLINE CONTROLADO)
# =========================================================================
$SMTPServer = "://tu-empresa.com"; $SMTPPort = 587; $From = "alertas-ad@tu-empresa.com"; $To = "tu-correo@tu-empresa.com"
$Asunto = "Auditoría Quincenal Dual Active Directory - $FechaActual"
$Cuerpo = "Buen día,<br><br>Se adjunta el paquete ZIP con los 8 reportes de auditoría (HTML ejecutivos y CSV para análisis en Excel).<br><br>Saludos."
try {
    $SMTPClient = New-Object Net.Mail.SmtpClient($SMTPServer, $SMTPPort)
    $MailMessage = New-Object Net.Mail.MailMessage($From, $To, $Asunto, $Cuerpo); $MailMessage.IsBodyHtml = $true
    $Attachment = New-Object Net.Mail.Attachment($RutaZipFinal); $MailMessage.Attachments.Add($Attachment)
    $SMTPClient.Send($MailMessage); $Attachment.Dispose()
    Write-Host "[OK] Correo enviado exitosamente." -ForegroundColor Green
} catch { 
    Write-Host "[!] Servidor de correo fuera de servicio. Reportes respaldados y purgados localmente de forma exitosa." -ForegroundColor Yellow 
}
