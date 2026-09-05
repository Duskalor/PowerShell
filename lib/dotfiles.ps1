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
        Replace('{LOCALAPPDATA}', $env:LOCALAPPDATA).
        Replace('{APPDATA}', $env:APPDATA).
        Replace('{HOME}', $HOME)
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
    ---------------------------------------------------------------------------
    Rendered templates
    ---------------------------------------------------------------------------

    A symbolic link cannot hold a value that differs per machine. Three configs
    contain absolute paths that include the Windows user name, and none of the
    three tools reading them resolves a bare command from PATH:

        alacritty.toml     the zellij binary it launches as the shell
        zellij/config.kdl  the same binary, plus two layout paths
        opencode.json      ten agent prompt files and one MCP command

    On a machine with a different user name those paths are simply wrong, so
    the terminal never starts and the agents never load. Those three are kept
    as .template files carrying tokens, and written out as real files.

    That trades away the property the rest of this repository relies on: a real
    file receives edits that the repository never sees. ConvertTo-DotfilesTemplateText
    is the way back. It is the exact inverse of the expansion, so sync.ps1 can
    take a rendered file that was edited on the machine, turn the machine's own
    paths back into tokens, and write it into the template. Nothing is lost, in
    either direction.
#>

<#
    Token expansions, longest first.

    Order matters both ways. %LOCALAPPDATA% and %APPDATA% both begin with the
    home directory, so replacing HOME first would leave "{HOME}\AppData\Local"
    behind and no LOCALAPPDATA token would ever match again.
#>
function Get-DotfilesTokenMap {
    $map = [ordered]@{}
    if ($env:LOCALAPPDATA) { $map['LOCALAPPDATA'] = $env:LOCALAPPDATA.TrimEnd('\', '/') }
    if ($env:APPDATA)      { $map['APPDATA']      = $env:APPDATA.TrimEnd('\', '/') }
    if ($HOME)             { $map['HOME']         = $HOME.TrimEnd('\', '/') }
    $map
}

<#
    Turn tokens into this machine's paths.

    Each token comes in three spellings because the three file formats disagree
    on how a Windows path is written:

        {HOME}    C:\Users\me        native, for a plain string
        {HOME/}   C:/Users/me        forward slashes, as zellij and opencode use
        {HOME\\}  C:\\Users\\me      escaped, as a JSON or TOML string literal
#>
function Expand-DotfilesTemplateText {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    foreach ($entry in (Get-DotfilesTokenMap).GetEnumerator()) {
        $native = $entry.Value
        $Text = $Text.
            Replace("{$($entry.Key)\\}", $native.Replace('\', '\\')).
            Replace("{$($entry.Key)/}",  $native.Replace('\', '/')).
            Replace("{$($entry.Key)}",   $native)
    }
    $Text
}

# The inverse. Same order, so the most specific path wins here too.
function ConvertTo-DotfilesTemplateText {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    foreach ($entry in (Get-DotfilesTokenMap).GetEnumerator()) {
        $native = $entry.Value
        $Text = $Text.
            Replace($native.Replace('\', '\\'), "{$($entry.Key)\\}").
            Replace($native.Replace('\', '/'),  "{$($entry.Key)/}").
            Replace($native,                    "{$($entry.Key)}")
    }
    $Text
}

<#
    Read and write without touching the bytes.

    Get-Content and Set-Content rewrite line endings and add a BOM. These files
    are read by alacritty, zellij and opencode, all of which want LF and none of
    which want a BOM, so the raw .NET calls are the correct tool here.
#>
function Read-DotfilesText {
    param([Parameter(Mandatory)][string]$Path)
    [System.IO.File]::ReadAllText($Path)
}

function Write-DotfilesText {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

<#
    Classify a rendered destination without touching it.

    Current  matches what the template produces on this machine
    Drifted  is a real file, but its content is not what the template says
    Stale    is still a symbolic link, left over from before this file was
             templated. Writing to it would write through the link and into
             the repository, so it has to be removed rather than overwritten.
    Missing  nothing is there yet
    Orphan   the manifest names a template that is not in the repository
#>
function Get-DotfilesRenderState {
    param(
        [Parameter(Mandatory)][string]$Template,
        [Parameter(Mandatory)][string]$Target
    )

    if (-not (Test-Path -LiteralPath $Template)) { return 'Orphan' }
    if (-not (Test-Path -LiteralPath $Target))   { return 'Missing' }
    if (Test-DotfilesSymlink -Path $Target)      { return 'Stale' }

    $expected = Expand-DotfilesTemplateText (Read-DotfilesText $Template)
    if ($expected -eq (Read-DotfilesText $Target)) { return 'Current' }
    'Drifted'
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
