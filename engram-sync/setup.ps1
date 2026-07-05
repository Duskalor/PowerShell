<#
.SYNOPSIS
    Registra la tarea programada 'engram-autosync' que corre cada 30 minutos.

.DESCRIPTION
    Se ejecuta UNA vez. Idempotente: si la tarea ya existe, la reemplaza.
    Apunta al autosync.ps1 de este mismo repo (ruta absoluta al momento del setup).
    Si moves el repo de lugar, volve a correr este setup.
#>

$taskName = 'engram-autosync'
$dir      = Join-Path $HOME '.engram'
$autosync = Join-Path $PSScriptRoot 'autosync.ps1'

# --- Prerrequisitos ---
if (-not (Get-Command engram -ErrorAction SilentlyContinue)) {
    Write-Warning "engram no esta instalado."
    Write-Host   "  Instalalo con: go install github.com/Gentleman-Programming/engram/cmd/engram@latest"
    return
}
if (-not (Test-Path (Join-Path $dir '.git'))) {
    Write-Warning "~/.engram no es un clon de engram-sync."
    Write-Host   "  Cloná primero:  git clone https://github.com/Duskalor/engram-sync.git `"$dir`""
    Write-Host   "  (si ya tenés una DB local, ver el README de engram-sync para preservarla)"
    return
}

# --- (Re)registrar la tarea ---
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

$action  = New-ScheduledTaskAction -Execute 'pwsh' `
    -Argument "-NoProfile -WindowStyle Hidden -File `"$autosync`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 30)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable `
    -DontStopOnIdleEnd -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Settings $settings -Description 'Sincroniza memorias de Engram cada 30 min' | Out-Null

Write-Host "OK: tarea '$taskName' registrada (cada 30 min)." -ForegroundColor Green
Write-Host "Verificala con:  Get-ScheduledTask -TaskName $taskName"
Write-Host "Correla ya con:  Start-ScheduledTask -TaskName $taskName"
