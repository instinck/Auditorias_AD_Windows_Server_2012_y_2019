# =========================================================================
#     SCRIPT MAESTRO 2019: COMPRESIÓN NATIVA, SMTP Y AUTO-LIMPIEZA (WS 2019)
# =========================================================================

$RutaLocal     = "C:\AuditoriaLocal"
$RutaAlmacen   = "C:\AuditoriaLocal\Reportes_Almacenados"
$FechaActual   = (Get-Date).ToString("dd-MM-yyyy")
$NombreZip     = "Auditoria_AD_2019_$FechaActual.zip"
$RutaZipFinal  = Join-Path $RutaAlmacen $NombreZip

# Listado de los 8 reportes generados por tus scripts modernos de 2019
$ArchivosReporte = @(
    "$RutaLocal\Reporte_Claves_Admin_2019.html", "$RutaLocal\Reporte_Claves_Admin_2019.csv",
    "$RutaLocal\Reporte_Gestion_Usuarios_2019.html", "$RutaLocal\Reporte_Gestion_Usuarios_2019.csv",
    "$RutaLocal\Reporte_Gestion_Equipos_2019.html", "$RutaLocal\Reporte_Gestion_Equipos_2019.csv",
    "$RutaLocal\Reporte_Propiedades_Usuarios_2019.html", "$RutaLocal\Reporte_Propiedades_Usuarios_2019.csv"
)

# 1. COMPRESIÓN MODERNA Y NATIVA (ZIP)
$ExisteAlguno = $false
foreach ($File in $ArchivosReporte) { if (Test-Path $File) { $ExisteAlguno = $true } }

if ($ExisteAlguno) {
    Write-Host "Empaquetando 8 reportes mediante Compress-Archive nativo..." -ForegroundColor Cyan
    try {
        if (Test-Path $RutaZipFinal) { Remove-Item $RutaZipFinal -Force }
        
        # En Server 2019 comprimimos con una sola línea limpia de código nativa
        Compress-Archive -Path $ArchivosReporte -DestinationPath $RutaZipFinal -Force
        
        Write-Host "[OK] Paquete histórico 2019 guardado en: $RutaZipFinal" -ForegroundColor Green
    } catch { 
        Write-Host "[!] Error en compresión moderna: $_" -ForegroundColor Red
        exit 
    }
} else { 
    Write-Host "[!] No se encontraron archivos de reporte para empaquetar." -ForegroundColor Yellow
    exit 
}

# =========================================================================
# 2. SECCIÓN CRÍTICA: AUTO-LIMPIEZA POST-EMPAQUETADO
# =========================================================================
if (Test-Path $RutaZipFinal) {
    $ZipSize = (Get-Item $RutaZipFinal).Length
    if ($ZipSize -gt 0) {
        Write-Host "Limpiando directorio raíz. Eliminando archivos temporales..." -ForegroundColor Cyan
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
$Asunto = "Auditoría Quincenal Dual Active Directory 2019 - $FechaActual"
$Cuerpo = "Buen día,<br><br>Se adjunta el paquete ZIP con los 8 reportes de auditoría moderna correspondientes al período.<br><br>Saludos."
try {
    $SMTPClient = New-Object Net.Mail.SmtpClient($SMTPServer, $SMTPPort)
    $MailMessage = New-Object Net.Mail.MailMessage($From, $To, $Asunto, $Cuerpo); $MailMessage.IsBodyHtml = $true
    $Attachment = New-Object Net.Mail.Attachment($RutaZipFinal); $MailMessage.Attachments.Add($Attachment)
    $SMTPClient.Send($MailMessage); $Attachment.Dispose()
    Write-Host "[OK] Correo enviado exitosamente." -ForegroundColor Green
} catch { 
    Write-Host "[!] Servidor de correo fuera de servicio. Reportes respaldados y purgados localmente de forma exitosa." -ForegroundColor Yellow 
}
