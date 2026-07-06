<#
.SYNOPSIS
    Sincroniza las memorias de Engram contra el repo engram-sync en GitHub.

.DESCRIPTION
    A prueba de conflictos: la DB local (SQLite) es la fuente de verdad y el
    JSON se regenera SIEMPRE. Por eso alineamos con GitHub via `reset --hard`
    antes de re-exportar, y un merge conflict de git se vuelve imposible.

    Flujo:
      1. fetch + reset --hard origin/main   -> alinearse con GitHub
      2. engram import                      -> fusionar lo remoto en la DB
      3. engram export                      -> re-exportar la union
      4. commit + push (solo si hay cambios)
#>

$dir  = Join-Path $HOME '.engram'
$json = Join-Path $dir 'engram-export.json'

# Sanity checks: sin engram o sin el repo, no hay nada que hacer.
if (-not (Get-Command engram -ErrorAction SilentlyContinue)) { exit 0 }
if (-not (Test-Path (Join-Path $dir '.git')))               { exit 0 }

# 1) Alinearse con GitHub. Si no hay red, salir sin romper.
git -C $dir fetch -q origin
if ($LASTEXITCODE -ne 0) { exit 0 }
git -C $dir reset -q --hard origin/main

# 2) Fusionar lo remoto en la DB local (import NO pisa: mergea).
engram import $json 2>$null

# 3) Re-exportar la union (todos los proyectos).
engram export $json | Out-Null

# 4) Commit + push solo si el export cambio algo.
git -C $dir add engram-export.json
git -C $dir diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    git -C $dir commit -q -m "autosync $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    git -C $dir push -q origin main
}
