# =========================================================================
#                 SCRIPT MAESTRO: EMPAQUETADO POR MATRIZ BINARIA (WS 2012)
# =========================================================================

$RutaLocal     = "C:\AuditoriaLocal"
$RutaAlmacen   = "C:\AuditoriaLocal\Reportes_Almacenados"
$FechaActual   = (Get-Date).ToString("dd-MM-yyyy")
$NombreZip     = "Auditoria_AD_$FechaActual.zip"
$RutaZipFinal  = Join-Path $RutaAlmacen $NombreZip

# Listado de los 4 reportes generados por tus otros scripts
$ArchivosReporte = @(
    "$RutaLocal\Reporte_Claves_Admin_Quincenal.html",
    "$RutaLocal\Reporte_Gestion_Usuarios_Quincenal.html",
    "$RutaLocal\Reporte_Gestion_Equipos_Quincenal.html",
    "$RutaLocal\Reporte_Propiedades_Usuarios_Quincenal.html"
)

# 1. VALIDACIÓN Y COMPRESIÓN LOCAL
$ExisteAlguno = $false
foreach ($File in $ArchivosReporte) { if (Test-Path $File) { $ExisteAlguno = $true } }

if ($ExisteAlguno) {
    Write-Host "Empaquetando reportes mediante Shell y Matriz Binaria..." -ForegroundColor Cyan
    
    try {
        # Si el archivo ZIP de hoy ya existía, lo eliminamos para evitar duplicados
        if (Test-Path $RutaZipFinal) { Remove-Item $RutaZipFinal -Force }

        # CORRECCIÓN MAESTRA: Matriz de 22 bytes puros para crear la cabecera estándar de un ZIP vacío
        [byte[]]$ZipHeader = 80,75,5,6,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        [System.IO.File]::WriteAllBytes($RutaZipFinal, $ZipHeader)

        # Instanciar el objeto Shell de Windows para el copiado en cascada
        $Shell = New-Object -ComObject Shell.Application
        $FolderZip = $Shell.NameSpace($RutaZipFinal)

        foreach ($File in $ArchivosReporte) {
            if (Test-Path $File) {
                # Copiar cada archivo dentro del contenedor ZIP nativo
                $FolderZip.CopyHere($File)
                # Pausa necesaria para que el explorador de Windows termine de escribir el archivo en disco
                Start-Sleep -Milliseconds 700
            }
        }
        
        Write-Host "[OK] Paquete histórico guardado con éxito en: $RutaZipFinal" -ForegroundColor Green
    } catch {
        Write-Host "[!] Error en compresión binaria: $_" -ForegroundColor Red
        exit
    }
} else {
    Write-Host "[!] No se encontraron archivos de reporte para empaquetar." -ForegroundColor Yellow
    exit
}

# =========================================================================
# 2. CONFIGURACIÓN DEL ENVÍO POR CORREO (PREPARADO PARA CUANDO OPERE EL SMTP)
# =========================================================================
$SMTPServer = "://tu-empresa.com" 
$SMTPPort   = 587
$From       = "alertas-ad@tu-empresa.com"
$To         = "tu-correo@tu-empresa.com"
$Asunto     = "Auditoría Quincenal de Seguridad Active Directory - $FechaActual"
$Cuerpo     = "Buen día,<br><br>Se adjunta el paquete comprimido con los 4 reportes de auditoría quincenal correspondientes al período.<br><br>Saludos cordiales."

try {
    Write-Host "Intentando enviar reportes por correo..." -ForegroundColor Cyan
    
    $SMTPClient = New-Object Net.Mail.SmtpClient($SMTPServer, $SMTPPort)
    $MailMessage = New-Object Net.Mail.MailMessage($From, $To, $Asunto, $Cuerpo)
    $MailMessage.IsBodyHtml = $true
    
    $Attachment = New-Object Net.Mail.Attachment($RutaZipFinal)
    $MailMessage.Attachments.Add($Attachment)
    
    $SMTPClient.Send($MailMessage)
    $Attachment.Dispose()
    
    Write-Host "[OK] Correo enviado exitosamente." -ForegroundColor Green
} 
catch {
    Write-Host "[!] Servidor de correo fuera de servicio. Reportes respaldados localmente de forma exitosa." -ForegroundColor Yellow
}
