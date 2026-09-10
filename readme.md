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
## 🛠️ Requisitos de Instalación y Despliegue

Antes de ejecutar los lanzadores en producción, es obligatorio preparar la estructura de archivos en el Servidor (ya sea versión 2012 o 2019):

1. Crear una carpeta dedicada directamente en la raíz del disco local: `C:\AuditoriaLocal`
2. Copiar dentro de esa carpeta los archivos `.ps1` y `.bat` correspondientes a la versión de tu sistema operativo.
3. Crear una subcarpeta obligatoria para el almacenamiento histórico del empaquetador ZIP: `C:\AuditoriaLocal\Reportes_Almacenados`

> ⚠️ **Nota de Seguridad:** Todos los accesos directos y tareas programadas deben configurarse con la opción **"Ejecutar con los privilegios más altos"** para tener acceso de lectura al registro de seguridad de Active Directory.

## 🔒 Configuración Obligatoria del Servidor (Directivas de Auditoría)

Para que los reportes de ambas plataformas extraigan datos reales y no salgan en blanco, es indispensable activar el registro de eventos en Windows Server mediante los siguientes pasos:

### 1. Desbloquear Auditoría Avanzada GPO (Para Server 2012 y 2019)
1. Abrir la consola de **Administración de Directivas de Grupo** (`gpmc.msc`).
2. Editar la **Default Domain Controllers Policy** en la carpeta *Domain Controllers*.
3. Navegar a: *Configuración del equipo ➔ Directivas ➔ Configuración de Windows ➔ Configuración de seguridad ➔ Configuración de política de auditoría avanzada ➔ Políticas de auditoría de sistema ➔ Acceso a DS*.
4. Habilitar la política **Auditar cambios en el servicio de directorio** (Audit Directory Service Changes) en modo **Correcto** (Success).
5. Forzar la actualización inmediata en la consola del servidor con el comando: `gpupdate /force`

### 2. Activar el Rastreo de Atributos Finos y Herencia (Para Evidencia Forense)
Para recopilar el valor real anterior/nuevo en las modificaciones de usuarios:
1. En la consola de comandos de Windows ejecutada como Administrador, activar la subcategoría:
   `auditpol /set /subcategory:"Cambios en los servicios de directorio" /success:enable`
2. En **Usuarios y equipos de Active Directory** (`dsa.msc`), activar las *Características Avanzadas* en el menú *Ver*.
3. Clic derecho en la **Raíz del Dominio** ➔ *Propiedades* ➔ Pestaña *Seguridad* ➔ *Opciones avanzadas* ➔ Pestaña *Auditoría*.
4. Agregar una regla para la entidad **Todos** (Everyone), configurando:
   - **Tipo:** Correcto (Success)
   - **Se aplica a:** Este objeto y todos los descendientes.
   - **Permisos:** Marcar la casilla **Escribir todas las propiedades** o *Modificar propiedades*.
5. Asegurarse de que las Unidades Organizativas (OUs) de producción tengan **Habilitada la Herencia** en su pestaña de seguridad avanzada.
