# Script interactivo para procesar expedientes
# Uso: .\procesar_facil.ps1

Write-Host "======================================"
Write-Host "PROCESADOR DE EXPEDIENTES - MODO FACIL"
Write-Host "======================================"
Write-Host ""

# Crear archivo temporal para que el usuario escriba
$archivoTemp = "config_temp.txt"

# Contenido inicial del archivo
$contenidoInicial = @"
# INSTRUCCIONES:
# 1. Escribe el nombre del archivo HTML que quieres procesar
# 2. Guarda y cierra este archivo (Ctrl+S, luego cierra)
# 3. El script procesara automaticamente

ARCHIVO_HTML=test.html
ARCHIVO_TXT_SALIDA=sumillas_extraidas.txt
ARCHIVO_HTML_SALIDA=expediente_visualizable.html
"@

# Crear y abrir archivo temporal
$contenidoInicial | Out-File $archivoTemp -Encoding UTF8
Write-Host "Abriendo archivo de configuracion..."
Write-Host "Edita los nombres de archivo y guarda (Ctrl+S)"
Write-Host ""

# Abrir en notepad y esperar a que cierre
Start-Process notepad.exe -ArgumentList $archivoTemp -Wait

# Leer configuracion
Write-Host ""
Write-Host "Leyendo configuracion..."
$config = Get-Content $archivoTemp -Encoding UTF8

$archivoHTML = ""
$archivoTXT = ""
$archivoHTMLSalida = ""

foreach ($linea in $config) {
    if ($linea -match '^ARCHIVO_HTML=(.+)$') {
        $archivoHTML = $matches[1].Trim()
    }
    if ($linea -match '^ARCHIVO_TXT_SALIDA=(.+)$') {
        $archivoTXT = $matches[1].Trim()
    }
    if ($linea -match '^ARCHIVO_HTML_SALIDA=(.+)$') {
        $archivoHTMLSalida = $matches[1].Trim()
    }
}

# Mostrar configuracion
Write-Host ""
Write-Host "Configuracion detectada:"
Write-Host "  Archivo de entrada: $archivoHTML"
Write-Host "  Archivo TXT salida: $archivoTXT"
Write-Host "  Archivo HTML salida: $archivoHTMLSalida"
Write-Host ""

# Eliminar archivo temporal
Remove-Item $archivoTemp -Force

# Preguntar si continuar
$respuesta = Read-Host "Procesar ahora? (S/N)"
if ($respuesta -ne 'S' -and $respuesta -ne 's') {
    Write-Host "Cancelado por el usuario"
    exit 0
}

Write-Host ""
Write-Host "Iniciando procesamiento..."
Write-Host ""

# Llamar al script principal
& .\procesar_completo.ps1 -archivoHTML $archivoHTML -archivoTXT $archivoTXT -archivoHTMLSalida $archivoHTMLSalida

Write-Host ""
Write-Host "PROCESO FINALIZADO"
Write-Host ""

# Preguntar si abrir resultados
$abrirTXT = Read-Host "Abrir archivo TXT? (S/N)"
if ($abrirTXT -eq 'S' -or $abrirTXT -eq 's') {
    Start-Process notepad.exe -ArgumentList $archivoTXT
}

$abrirHTML = Read-Host "Abrir archivo HTML en navegador? (S/N)"
if ($abrirHTML -eq 'S' -or $abrirHTML -eq 's') {
    Start-Process $archivoHTMLSalida
}

Write-Host ""
Write-Host "Listo!"
