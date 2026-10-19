<#
.SYNOPSIS
    Stop dev servers started inside Zellij panes.

.DESCRIPTION
    Ctrl+C does not reach child processes inside Zellij on Windows: the key is
    delivered, but what the pane's shell receives has Break semantics rather
    than an interrupt, so nothing downstream is signalled. A dev server
    therefore survives Ctrl+C, survives closing the pane, and keeps holding its
    port. Verified on zellij 0.43.1-win32.5, Windows 11 build 26300.

    This finds processes that are listening on a TCP port and were started from
    a shell running inside Zellij, then kills each one from the top of its
    runner chain. Killing the top matters: supervisors such as `tsx watch` or
    `nodemon` respawn the server if only the leaf process dies.

    Orphans are included. Closing a pane leaves the chain parentless but still
    listening, so those are exactly the leftovers worth clearing.

.PARAMETER WhatIfOnly
    Report what would be killed without killing anything.

.PARAMETER Quiet
    Print nothing when there was nothing to stop.

.EXAMPLE
    Stop-DevServer
    Stop every dev server running in a Zellij pane.

.EXAMPLE
    Stop-DevServer -WhatIfOnly
    List them first.
#>
[CmdletBinding()]
param(
    [switch] $WhatIfOnly,
    [switch] $Quiet
)

# Shells and multiplexers host a runner chain but are not part of it.
$shells = @('pwsh.exe', 'powershell.exe', 'cmd.exe')
$hosts_ = @('zellij.exe', 'WindowsTerminal.exe', 'OpenConsole.exe', 'conhost.exe',
            'alacritty.exe', 'wezterm-gui.exe', 'explorer.exe')

# Never touch Claude's own processes: its MCP servers are node too.
$never = @('claude.exe', 'Code.exe', 'devenv.exe')

# Command-line markers of something that serves during development.
$runnerish = 'tsx|nodemon|vite|next|ng serve|react-scripts|webpack|nest|astro|' +
             'remix|nuxt|svelte|dotnet run|uvicorn|flask|django|rails|air |go run'

function Get-Chain([int] $StartId) {
    # Walk up, newest first, until a shell or host is reached.
    $chain = @()
    $id = $StartId
    while ($true) {
        $p = Get-CimInstance Win32_Process -Filter "ProcessId=$id" -ErrorAction SilentlyContinue
        if (-not $p) { break }
        $chain += $p
        if ($p.Name -in $shells -or $p.Name -in $hosts_ -or $p.Name -in $never) { break }
        if ($p.ParentProcessId -le 4) { break }
        $id = $p.ParentProcessId
    }
    return $chain
}

function Test-UnderZellij([int] $StartId) {
    # True when any ancestor is zellij.exe.
    $id = $StartId
    for ($hops = 0; $hops -lt 24; $hops++) {
        $p = Get-CimInstance Win32_Process -Filter "ProcessId=$id" -ErrorAction SilentlyContinue
        if (-not $p) { return $false }
        if ($p.Name -eq 'zellij.exe') { return $true }
        if ($p.Name -in $never) { return $false }
        if ($p.ParentProcessId -le 4) { return $false }
        $id = $p.ParentProcessId
    }
    return $false
}

$listeners = @(
    Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty OwningProcess -Unique
)

$targets = @{}

foreach ($owner in $listeners) {
    $chain = Get-Chain $owner
    if (-not $chain) { continue }

    # Anything belonging to an editor or to Claude is off limits.
    if ($chain | Where-Object { $_.Name -in $never }) { continue }

    $last = $chain[-1]

    $inZellij = ($last.Name -in $shells) -and (Test-UnderZellij $last.ProcessId)

    # Parentless chain: the shell is gone but the server kept running.
    $orphaned = -not (Get-CimInstance Win32_Process -Filter "ProcessId=$($last.ParentProcessId)" -ErrorAction SilentlyContinue)
    $looksDev = ($chain | Where-Object { $_.CommandLine -and $_.CommandLine -match $runnerish }).Count -gt 0

    if (-not ($inZellij -or ($orphaned -and $looksDev))) { continue }

    # Top of the runner chain is the entry just below the shell, so a
    # supervisor cannot outlive the kill and restart its child.
    $top = if ($last.Name -in $shells) {
        if ($chain.Count -ge 2) { $chain[-2] } else { $null }
    } else {
        $last
    }
    if (-not $top) { continue }

    $ports = @(
        Get-NetTCPConnection -State Listen -OwningProcess $owner -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty LocalPort -Unique
    )

    if (-not $targets.ContainsKey($top.ProcessId)) {
        $targets[$top.ProcessId] = [pscustomobject]@{
            Pid   = $top.ProcessId
            Name  = $top.Name
            Ports = [System.Collections.Generic.List[int]]::new()
        }
    }
    foreach ($pt in $ports) {
        if (-not $targets[$top.ProcessId].Ports.Contains($pt)) {
            $targets[$top.ProcessId].Ports.Add($pt)
        }
    }
}

if ($targets.Count -eq 0) {
    if (-not $Quiet) { Write-Host 'No dev server running in a Zellij pane.' -ForegroundColor DarkGray }
    return
}

foreach ($t in $targets.Values) {
    $portList = ($t.Ports | Sort-Object) -join ', '
    $label = "$($t.Name) (PID $($t.Pid)) on port $portList"

    if ($WhatIfOnly) {
        Write-Host "would stop  $label" -ForegroundColor Yellow
        continue
    }

    taskkill /PID $t.Pid /T /F 2>&1 | Out-Null
    Start-Sleep -Milliseconds 400

    $stillUp = @(
        $t.Ports | Where-Object {
            Get-NetTCPConnection -State Listen -LocalPort $_ -ErrorAction SilentlyContinue
        }
    )

    if ($stillUp.Count -gt 0) {
        Write-Host "STILL UP    $label  (port $($stillUp -join ', ') held)" -ForegroundColor Red
    } else {
        Write-Host "stopped     $label" -ForegroundColor Green
    }
}
