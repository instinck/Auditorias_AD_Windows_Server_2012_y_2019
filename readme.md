# Sistema de Auditoría Automatizada para Active Directory (WS 2012 / 2019)

Este repositorio contiene una solución modular y robusta basada en **PowerShell** y **scripts de procesamiento por lotes (.bat)** diseñada para auditar de manera forense los cambios críticos de identidad e infraestructura dentro de un dominio de **Active Directory**.

El proyecto está diseñado bajo una arquitectura de ejecución en segundo plano 100% autónoma, ideal para ser programada mediante el *Task Scheduler* de Windows sin interferir con las operaciones del servidor de producción.

## 🚀 Características Clave

- **Soporte Multi-Plataforma:** Scripts optimizados de forma independiente para **Windows Server 2012** (PowerShell 4.0) y **Windows Server 2019** (PowerShell 5.1).
- **Módulos de Reportes Independientes (Quincenales):**
  1. 🔑 **Gestión de Contraseñas:** Tracking exclusivo de reseteos de claves realizados por administradores humanos (limpio de ruido de autoservicio).
  2. 👥 **Ciclo de Vida de Usuarios:** Reporte detallado de altas (creados), habilitados, deshabilitados y bajas definitivas (eliminados).
  3. 🖥️ **Inventario de Equipos:** Registro de altas y bajas de computadoras y servidores en el dominio, excluyendo accesos anónimos del sistema.
  4. 📝 **Auditoría Forense de Atributos:** Extracción milimétrica con valor de evidencia que muestra el **campo modificado y el valor real (anterior/nuevo)** en perfiles de usuario (Teléfono, Área, Correo, Logon Workstations).
- **Formatos de Salida Dual:** Generación automática de archivos **CSV estructurados** para análisis de datos y plantillas **HTML estéticas** con estilos corporativos listos para impresión nativa a PDF o visualización ejecutiva.
- **Respaldo e Integración SMTP:** Automatización quincenal que empaqueta localmente los reportes en un contenedor `.zip` fechado cronológicamente para contingencias y los transmite vía correo electrónico.

## 📁 Estructura del Repositorio

```text
AuditoriaActiveDirectory/
├── WindowsServer2012/       # Scripts adaptados con compatibilidad binaria para PS 4.0
│   ├── Reporte-Contrasenas-Quincenal.ps1
│   ├── ...
└── WindowsServer2019/       # Scripts optimizados con filtros XML de alta velocidad y PS 5.1
    ├── Reporte-Contrasenas-2019.ps1
    └── ...
```
