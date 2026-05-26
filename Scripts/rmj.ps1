param(
    [string]$n = "creado"
)

$route = "C:\Users\$env:USERNAME\Documents\Proyects\rmj"
Set-Location -Path $route
Add-Type -Path "C:\tools\HtmlAgilityPack\HtmlAgilityPack.dll"
$archivoTemp = "config_temp.txt"
"" | Out-File $archivoTemp -Encoding UTF8
Write-Host "Guarda el html ahi y luego cierra"
Write-Host ""

Start-Process notepad.exe -ArgumentList $archivoTemp -Wait

Write-Host "[1/5] Leyendo archivo: $archivoTemp"
if (-not (Test-Path $archivoTemp)) {
    Write-Host "ERROR: No se encuentra el archivo $archivoTemp" -ForegroundColor Red
    exit 1
}

Write-Host "[2/5] Extrayendo sumillas del HTML (HAP)..."

$doc = New-Object HtmlAgilityPack.HtmlDocument
$doc.OptionFixNestedTags = $true
$doc.OptionAutoCloseOnEnd = $true
$doc.LoadHtml((Get-Content $archivoTemp -Raw -Encoding UTF8))

$sumillas = @()
$contador = 1

$panelBodies = $doc.DocumentNode.SelectNodes("//div[contains(@class,'panel-body')]")

if (-not $panelBodies) {
    Write-Host "ERROR: No se encontraron panel-body" -ForegroundColor Red
    exit 1
}

foreach ($b in $panelBodies) {
    $fecha = $b.SelectSingleNode(
        ".//div[normalize-space()='Fecha de Ingreso:' or normalize-space()='Fecha de Resolución:']/following-sibling::div"
    )?.InnerText

    $resolucion = $b.SelectSingleNode(
        ".//div[normalize-space()='Resolución:']/following-sibling::div"
    )?.InnerText

    $acto = $b.SelectSingleNode(
        ".//div[normalize-space()='Acto:']/following-sibling::div"
    )?.InnerText

    $sumilla = $b.SelectSingleNode(
        ".//div[normalize-space()='Sumilla:']/following-sibling::div"
    )?.InnerText

    if ($fecha)      { $fecha      = ($fecha -replace '\s+', ' ').Trim() }
    if ($resolucion) { $resolucion = ($resolucion -replace '\s+', ' ').Trim() }
    if ($acto)       { $acto       = ($acto -replace '\s+', ' ').Trim() }
    if ($sumilla)    { $sumilla    = ($sumilla -replace '\s+', ' ').Trim() }

    if (-not [string]::IsNullOrWhiteSpace($sumilla)) {
        $clave = ("$fecha $acto $resolucion $sumilla" -replace '\s+', ' ').Trim().ToUpper()

        if ($sumillas | Where-Object {
            $itemClave = ("$($_.Fecha)|$($_.Acto)|$($_.Resolucion)|$($_.Texto)" -replace '\s+', ' ').Trim().ToUpper()
            $itemClave -eq $clave
        }) { continue }

        $sumillas += [PSCustomObject]@{
            Numero     = $contador
            Fecha      = $fecha
            Resolucion = $resolucion
            Acto       = $acto
            Texto      = $sumilla
        }
        $contador++
    }
}

Write-Host "      Sumillas encontradas: $($sumillas.Count)"

$sumillas = $sumillas | Sort-Object Numero -Descending
$i = 1
foreach ($s in $sumillas) { $s.Numero = $i; $i++ }

Write-Host "[3/5] Generando archivo TXT: $n.txt"
$txtContent = ""
foreach ($s in $sumillas) {
    $txtContent += "[$($s.Numero)] Fecha: $($s.Fecha) | Resolucion: $($s.Resolucion) | Acto: $($s.Acto)`n"
    $txtContent += "Sumilla: $($s.Texto)`n`n"
}
$txtContent | Out-File "$($n).txt" -Encoding UTF8
Write-Host "      Archivo TXT generado exitosamente"

Write-Host "[4/5] Calculando estadisticas..."
$conResolucion = ($sumillas | Where-Object {
    $_.Resolucion -and $_.Resolucion -ne '' -and $_.Resolucion -ne 'S/N'
}).Count
Write-Host "      Resoluciones: $conResolucion"

Write-Host "[5/5] Generando HTML visualizable: $n.html"

$html = @"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Expediente Judicial</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 20px; color: #333; }
        .container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 10px; box-shadow: 0 10px 40px rgba(0,0,0,.2); overflow: hidden; }
        .header { background: linear-gradient(135deg, #9A1413 0%, #c41a18 100%); color: white; padding: 30px; text-align: center; }
        .header h1 { font-size: 28px; margin-bottom: 10px; }
        .header p { font-size: 16px; opacity: .9; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit,minmax(200px,1fr)); gap: 20px; padding: 30px; background: #f8f9fa; border-bottom: 2px solid #e9ecef; }
        .stat-card { background: white; padding: 20px; border-radius: 8px; text-align: center; box-shadow: 0 2px 8px rgba(0,0,0,.1); }
        .stat-card h3 { color: #9A1413; font-size: 32px; margin-bottom: 5px; }
        .stat-card p { color: #666; font-size: 14px; }
        .content { padding: 30px; }
        .filter-bar { margin-bottom: 20px; padding: 15px; background: #f8f9fa; border-radius: 8px; display: flex; gap: 10px; flex-wrap: wrap; align-items: center; }
        .filter-bar input { flex: 1; min-width: 200px; padding: 10px 15px; border: 2px solid #ddd; border-radius: 5px; font-size: 14px; }
        .filter-bar input:focus { outline: none; border-color: #9A1413; }
        .filter-bar button { padding: 10px 20px; background: #9A1413; color: white; border: none; border-radius: 5px; cursor: pointer; font-size: 14px; transition: background .3s; }
        .filter-bar button:hover { background: #7a0f0e; }
        .sumilla-item { background: white; border: 1px solid #e9ecef; border-left: 4px solid #9A1413; padding: 20px; margin-bottom: 15px; border-radius: 8px; transition: all .3s; }
        .sumilla-item:hover { box-shadow: 0 4px 12px rgba(0,0,0,.1); transform: translateY(-2px); }
        .sumilla-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; flex-wrap: wrap; gap: 10px; }
        .sumilla-numero { background: #9A1413; color: white; padding: 5px 12px; border-radius: 20px; font-weight: bold; font-size: 14px; }
        .sumilla-meta { display: flex; gap: 15px; flex-wrap: wrap; }
        .meta-item { display: flex; align-items: center; gap: 5px; font-size: 14px; color: #666; }
        .meta-item strong { color: #333; }
        .badge { padding: 4px 10px; border-radius: 12px; font-size: 12px; font-weight: 600; }
        .badge-resolucion { background: #e3f2fd; color: #1565c0; }
        .badge-sn { background: #f3e5f5; color: #7b1fa2; }
        .sumilla-texto { color: #444; line-height: 1.6; font-size: 15px; margin-top: 10px; }
        .no-results { text-align: center; padding: 40px; color: #999; font-size: 18px; }
        @media (max-width:768px) { .header h1 { font-size: 22px; } .stats { grid-template-columns: 1fr; } .sumilla-header { flex-direction: column; align-items: flex-start; } }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Expediente Judicial</h1>
            <p>Sistema de Consulta de Sumillas</p>
        </div>
        <div class="stats">
            <div class="stat-card"><h3>$($sumillas.Count)</h3><p>Total de Sumillas</p></div>
            <div class="stat-card"><h3>$conResolucion</h3><p>Resoluciones</p></div>
            <div class="stat-card"><h3>2021-2025</h3><p>Periodo</p></div>
        </div>
        <div class="content">
            <div class="filter-bar">
                <input type="text" id="searchInput" placeholder="Buscar por fecha, resolucion o sumilla...">
                <button onclick="filtrar()">Buscar</button>
                <button onclick="limpiarFiltro()">Limpiar</button>
            </div>
            <div id="sumillas-container">
"@

foreach ($s in $sumillas) {
    $badgeClass = if ($s.Resolucion -eq 'S/N') { 'badge-sn' } else { 'badge-resolucion' }
    $html += @"
                <div class="sumilla-item">
                    <div class="sumilla-header">
                        <span class="sumilla-numero">#$($s.Numero)</span>
                        <div class="sumilla-meta">
                            <div class="meta-item"><strong>Fecha:</strong> $($s.Fecha)</div>
                            <div class="meta-item"><span class="badge $badgeClass">$($s.Resolucion)</span></div>
                            <div class="meta-item"><strong>Acto:</strong> $($s.Acto)</div>
                        </div>
                    </div>
                    <div class="sumilla-texto">$($s.Texto)</div>
                </div>
"@
}

$html += @"
            </div>
        </div>
    </div>
    <script>
        function filtrar() {
            const input = document.getElementById('searchInput');
            const filter = input.value.toUpperCase();
            const container = document.getElementById('sumillas-container');
            const items = container.getElementsByClassName('sumilla-item');
            let visibleCount = 0;
            for (let i = 0; i < items.length; i++) {
                const txtValue = items[i].textContent || items[i].innerText;
                if (txtValue.toUpperCase().indexOf(filter) > -1) { items[i].style.display = ""; visibleCount++; }
                else { items[i].style.display = "none"; }
            }
            let noResults = document.getElementById('no-results-msg');
            if (visibleCount === 0) {
                if (!noResults) { noResults = document.createElement('div'); noResults.id = 'no-results-msg'; noResults.className = 'no-results'; noResults.textContent = 'No se encontraron resultados'; container.appendChild(noResults); }
            } else { if (noResults) noResults.remove(); }
        }
        function limpiarFiltro() {
            document.getElementById('searchInput').value = '';
            const items = document.getElementById('sumillas-container').getElementsByClassName('sumilla-item');
            for (let i = 0; i < items.length; i++) items[i].style.display = "";
            const noResults = document.getElementById('no-results-msg');
            if (noResults) noResults.remove();
        }
        document.getElementById('searchInput').addEventListener('keypress', e => { if (e.key === 'Enter') filtrar(); });
        document.getElementById('searchInput').addEventListener('input', filtrar);
    </script>
</body>
</html>
"@

$html | Out-File "$n.html" -Encoding UTF8
Remove-Item $archivoTemp -Force

Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "PROCESO COMPLETADO" -ForegroundColor Green
Write-Host "======================================"
Write-Host "Archivos generados:"
Write-Host "  1. TXT: $($n).txt"
Write-Host "  2. HTML: $($n).html"
Write-Host ""
Write-Host "Sumillas procesadas: $($sumillas.Count)"
Write-Host "Resoluciones: $conResolucion"
Write-Host ""

$routeEscaped = $route -replace ' ', '%20'
$url = "file:///$routeEscaped/$n.html".Replace('\', '/')
Start-Process chrome.exe -ArgumentList $url
