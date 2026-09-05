<#
    Shared helpers for bootstrap.ps1 and sync.ps1.

    The two scripts differ only in how they resolve a conflict, meaning a
    destination that exists but is not the symlink the manifest asks for:

        bootstrap  the repository wins   the existing file is moved aside
        sync       the machine wins      the existing file is copied into
                                         the repository first, then relinked

    That second case is not hypothetical. Applications that save with the
    "write a temporary file, then rename it over the original" pattern replace
    the symlink with a regular file. Claude Code does this when settings change
    from inside the tool. Without sync.ps1 the repository would silently drift
    out of date again.
#>

Set-StrictMode -Version Latest

function Get-DotfilesRoot {
    Split-Path -Parent $PSScriptRoot
}

function Import-DotfilesManifest {
    param([string]$Root = (Get-DotfilesRoot))

    $path = Join-Path $Root 'manifest.psd1'
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Manifest not found at $path"
    }
    Import-PowerShellDataFile -LiteralPath $path
}

function Expand-DotfilesToken {
    param([Parameter(Mandatory)][string]$Path)

    $expanded = $Path.
        Replace('{HOME}', $HOME).
        Replace('{APPDATA}', $env:APPDATA)
    $expanded.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
}

function Test-DotfilesSymlink {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $item = Get-Item -LiteralPath $Path -Force
    $item.LinkType -eq 'SymbolicLink'
}

function Get-DotfilesLinkTarget {
    param([Parameter(Mandatory)][string]$Path)

    $item = Get-Item -LiteralPath $Path -Force
    $target = $item.Target
    if ($target -is [array]) { $target = $target[0] }
    if ([string]::IsNullOrEmpty($target)) { return $null }
    try { (Resolve-Path -LiteralPath $target -ErrorAction Stop).Path } catch { $target }
}

<#
    Classify a destination without touching it.

    Linked   already points at the right place, nothing to do
    Relink   is a symlink, but aimed somewhere else
    Foreign  a real file or directory sits in the way
    Missing  nothing is there yet
    Orphan   the manifest names a source that is not in the repository
#>
function Get-DotfilesLinkState {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Target
    )

    if (-not (Test-Path -LiteralPath $Source)) { return 'Orphan' }
    if (-not (Test-Path -LiteralPath $Target)) { return 'Missing' }

    if (Test-DotfilesSymlink -Path $Target) {
        $current  = Get-DotfilesLinkTarget -Path $Target
        $expected = (Resolve-Path -LiteralPath $Source).Path
        if ($current -and $current.TrimEnd('\', '/') -eq $expected.TrimEnd('\', '/')) {
            return 'Linked'
        }
        return 'Relink'
    }

    'Foreign'
}

<#
    Delete a symlink without following it.

    Remove-Item on a directory symlink is a well known footgun: on older hosts
    it can recurse into the link and delete the real content on the other side.
    Deleting through .NET removes only the reparse point.
#>
function Remove-DotfilesLink {
    param([Parameter(Mandatory)][string]$Path)

    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer) {
        [System.IO.Directory]::Delete($item.FullName, $false)
    } else {
        [System.IO.File]::Delete($item.FullName)
    }
}

function New-DotfilesParent {
    param([Parameter(Mandatory)][string]$Path)

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

<#
    Confirm this session can actually create symbolic links.

    On Windows that needs Developer Mode enabled, or an elevated shell. Finding
    out here produces one clear message instead of a failure on every entry.
#>
function Test-SymlinkCapability {
    $probeDir  = Join-Path ([System.IO.Path]::GetTempPath()) ("dotfiles-probe-" + [guid]::NewGuid().ToString('N'))
    $probeFile = Join-Path $probeDir 'source.txt'
    $probeLink = Join-Path $probeDir 'link.txt'
    try {
        New-Item -ItemType Directory -Path $probeDir -Force | Out-Null
        Set-Content -LiteralPath $probeFile -Value 'probe' -NoNewline
        New-Item -ItemType SymbolicLink -Path $probeLink -Value $probeFile -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    } finally {
        Remove-Item -LiteralPath $probeDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Show-SymlinkCapabilityHelp {
    Write-Host ''
    Write-Host '  This shell cannot create symbolic links.' -ForegroundColor Red
    Write-Host ''
    Write-Host '  Fix it in one of two ways:'
    Write-Host '    1. Enable Developer Mode  (recommended, no elevation afterwards)'
    Write-Host '       Settings > System > For developers > Developer Mode: On'
    Write-Host '    2. Re-run this script from a terminal opened as Administrator'
    Write-Host ''
}
