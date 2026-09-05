<#
.SYNOPSIS
    Set up this machine from the repository.

.DESCRIPTION
    Reads manifest.psd1 and creates a symbolic link for every entry, so the
    repository becomes the single copy of each config file. Editing the file at
    either path edits the same bytes, which means the repository can no longer
    drift out of date.

    Anything already present at a destination is moved into .backup/<timestamp>
    rather than deleted, so a first run on a machine that already has configs is
    safe to try.

.PARAMETER DryRun
    Report what would happen and change nothing.

.PARAMETER Force
    Replace destinations without keeping a backup copy.

.EXAMPLE
    .\bootstrap.ps1 -DryRun
    Preview every action before committing to it.

.EXAMPLE
    .\bootstrap.ps1
    Link everything, backing up whatever is in the way.
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/dotfiles.ps1')

$root      = Get-DotfilesRoot
$manifest  = Import-DotfilesManifest -Root $root
$backupDir = Join-Path $root ('.backup/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))

Write-Host ''
Write-Host '  Dotfiles bootstrap' -ForegroundColor Cyan
Write-Host "  repository: $root"
if ($DryRun) { Write-Host '  mode: dry run, nothing will change' -ForegroundColor Yellow }
Write-Host ''

if (-not $DryRun -and -not (Test-SymlinkCapability)) {
    Show-SymlinkCapabilityHelp
    exit 1
}

$counts = @{ Linked = 0; Created = 0; Replaced = 0; Skipped = 0; Failed = 0 }

foreach ($link in $manifest.Links) {
    $source = Join-Path $root $link.Repo.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $target = Expand-DotfilesToken -Path $link.Target
    $state  = Get-DotfilesLinkState -Source $source -Target $target
    $label  = $link.Repo

    # Note: `continue` inside a switch exits the switch, it does not advance the
    # enclosing foreach. These two cases use if/elseif so the skip really skips.
    if ($state -eq 'Linked') {
        $counts.Linked++
        Write-Verbose "already linked: $label"
        continue
    }
    elseif ($state -eq 'Orphan') {
        $counts.Skipped++
        Write-Host "  skip     $label" -ForegroundColor DarkGray
        Write-Host "           not in the repository, nothing to link" -ForegroundColor DarkGray
        continue
    }

    if ($DryRun) {
        $action = switch ($state) {
            'Missing' { 'would create ' }
            'Relink'  { 'would relink ' }
            'Foreign' { 'would back up' }
        }
        Write-Host "  $action $label" -ForegroundColor Yellow
        Write-Host "           -> $target" -ForegroundColor DarkGray
        continue
    }

    try {
        # Move whatever is in the way, keeping a copy unless -Force says otherwise.
        if ($state -eq 'Foreign') {
            if ($Force) {
                Remove-Item -LiteralPath $target -Recurse -Force
            } else {
                $relative = $target.Replace($HOME, '').TrimStart('\', '/')
                $saveTo   = Join-Path $backupDir $relative
                New-DotfilesParent -Path $saveTo
                Move-Item -LiteralPath $target -Destination $saveTo -Force
            }
        } elseif ($state -eq 'Relink') {
            Remove-DotfilesLink -Path $target
        }

        New-DotfilesParent -Path $target
        New-Item -ItemType SymbolicLink -Path $target -Value $source -Force | Out-Null

        if ($state -eq 'Foreign') {
            $counts.Replaced++
            Write-Host "  replaced $label" -ForegroundColor Green
        } else {
            $counts.Created++
            Write-Host "  linked   $label" -ForegroundColor Green
        }
    } catch {
        $counts.Failed++
        Write-Host "  FAILED   $label" -ForegroundColor Red
        Write-Host "           $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Machine specific values live outside git. Seed them from their examples so a
# fresh machine starts with a valid file to edit instead of a missing one.
foreach ($template in $manifest.Templates) {
    $example = Join-Path $root $template.Example.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $target  = Expand-DotfilesToken -Path $template.Target

    if (-not (Test-Path -LiteralPath $example)) { continue }
    if (Test-Path -LiteralPath $target) {
        Write-Host "  kept     $(Split-Path -Leaf $target) (already exists, not overwritten)" -ForegroundColor DarkGray
        continue
    }
    if ($DryRun) {
        Write-Host "  would seed $(Split-Path -Leaf $target) from $($template.Example)" -ForegroundColor Yellow
        continue
    }
    New-DotfilesParent -Path $target
    Copy-Item -LiteralPath $example -Destination $target
    Write-Host "  seeded   $(Split-Path -Leaf $target) — fill in your own values" -ForegroundColor Green
}

Write-Host ''
Write-Host "  linked $($counts.Created)  replaced $($counts.Replaced)  already ok $($counts.Linked)  skipped $($counts.Skipped)  failed $($counts.Failed)"
if (-not $DryRun -and $counts.Replaced -gt 0 -and -not $Force) {
    Write-Host "  previous files kept in $backupDir" -ForegroundColor DarkGray
}
Write-Host ''
Write-Host '  Still to do by hand (see README):' -ForegroundColor Cyan
Write-Host '    - install IosevkaTerm Nerd Font'
Write-Host '    - restore packages:  scoop import packages/scoop.json'
Write-Host '                         winget import -i packages/winget.json'
Write-Host '    - place engram.exe in ~/bin and add it to PATH'
Write-Host ''
if ($counts.Failed -gt 0) { exit 1 }
