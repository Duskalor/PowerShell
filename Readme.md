# PowerShell Profile - Guía de Uso

Este es mi perfil personalizado de PowerShell que incluye funciones y atajos para agilizar mi flujo de trabajo en desarrollo.

## 📋 Tabla de Contenidos

- [Instalación](#instalación)
- [Funciones de Navegación](#funciones-de-navegación)
- [Funciones de Desarrollo](#funciones-de-desarrollo)
- [Utilidades](#utilidades)

## 🚀 Instalación

1. Abre PowerShell y ejecuta:
```powershell
notepad $PROFILE
```

2. Copia el contenido del archivo en tu perfil
3. Guarda y reinicia PowerShell

## 📁 Funciones de Navegación

Atajos rápidos para moverte entre directorios de proyectos:

| Función | Descripción | Ruta |
|---------|-------------|------|
| `d` | Directorio principal de proyectos | `Documents\Proyects` |
| `pr` | Proyectos de React | `Documents\Proyects\React` |
| `fr` | FrontEnd Mentor | `Documents\Proyects\React\frontEndMentor` |
| `n` | Proyectos Node.js | `Documents\Proyects\Node` |
| `mono` | MonoRepo | `Documents\Proyects\MonoRepo` |
| `as` | Proyectos Astro | `Documents\Proyects\astro` |
| `l` | Proyectos Laravel | `Documents\Proyects\Laravel` |
| `p` | Proyectos PHP | `Documents\Proyects\PHP` |
| `ne` | Proyectos Next.js | `Documents\Proyects\Nextjs` |
| `js` | JavaScript | `Documents\Proyects\javascript` |
| `nes` | Proyectos NestJS | `Documents\Proyects\nestjs` |
| `power` | Scripts PowerShell | `Documents\PowerShell` (abre VS Code) |


### Ejemplos:
```powershell
# Ir a proyectos de React
pr

# Ir a proyectos de Node
n
```

## 🛠️ Funciones de Desarrollo

### Crear Proyectos Nuevos

#### `vite [nombre]`
Crea un nuevo proyecto con Vite.
```powershell
vite mi-proyecto
```
**Acciones:**
- Crea el proyecto
- Instala dependencias
- Abre VS Code
- Inicia servidor de desarrollo

#### `vitet [nombre]`
Crea un proyecto Vite con Tailwind CSS preconfigurado.
```powershell
vitet mi-app-tailwind
```

#### `next [nombre]`
Crea un nuevo proyecto Next.js.
```powershell
next mi-app-nextjs
```

#### `astro [nombre]`
Crea un nuevo proyecto Astro.
```powershell
astro mi-sitio-astro
```

### Desarrollo

#### `dev`
Ejecuta el comando de desarrollo del proyecto actual.
```powershell
dev
# Equivale a: pnpm run dev
```

## 🗄️ Base de Datos

### `newdb [puerto]`

Crea y levanta un contenedor PostgreSQL con Docker Compose.
```powershell
# Con puerto específico
newdb 5432

# Sin puerto (asigna uno disponible automáticamente)
newdb
```

**Características:**
- Crea archivo `docker-compose.yml` si no existe
- Levanta contenedor PostgreSQL 14.1
- Usuario: `dusk`
- Password: `dusk`
- Base de datos: `dusk`
- Copia la cadena de conexión al portapapeles automáticamente

**Cadena de conexión generada:**
```
DATABASE_URL=postgresql://dusk:dusk@localhost:[PUERTO]/dusk
```

## 📝 Utilidades

### `cf [carpeta] [archivos...]`

Crea carpeta y archivos TypeScript de forma rápida.
```powershell
# Crear carpeta con archivos .ts
cf utils helper config types

# Crear archivos con extensiones específicas
cf components Button.tsx Card.tsx
```

**Comportamiento:**
- Si la carpeta no existe, la crea
- Por defecto añade extensión `.ts`
- Si el archivo incluye un punto, respeta la extensión

### `w`
Abre el explorador de Windows en el directorio actual.
```powershell
w
```


## ⚙️ Configuración Adicional

### PsReadLine
El perfil configura PsReadLine con vista de lista para autocompletado mejorado:
```powershell
Set-PsReadLineOption -PredictionViewStyle ListView
```

## 📌 Notas

- Todas las funciones de navegación se adaptan automáticamente al usuario actual (`$env:USERNAME`)
- Requiere `pnpm` instalado para las funciones de creación de proyectos
- Requiere Docker Desktop para la función `newdb`

## 🤝 Contribuciones

Si tienes sugerencias para mejorar estas funciones, ¡no dudes en abrir un issue o PR!

---

**Autor:** [Tu nombre]  
**Licencia:** MIT