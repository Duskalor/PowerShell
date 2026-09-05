<#
.SYNOPSIS
    Check the links are intact and repair the ones that are not.

.DESCRIPTION
    bootstrap.ps1 sets a machine up once. sync.ps1 keeps it that way.

    Some applications save a file by writing a temporary copy and renaming it
    over the original. That replaces the symbolic link with a regular file. The
    machine keeps working, so nothing looks wrong, but the repository stops
    receiving the changes. This repository already reached that state once: the
    README documented ten setup steps for files that were never committed.

    Where bootstrap treats the repository as the source of truth, sync treats
    the machine as the source of truth. A destination found as a regular file is
    assumed to hold newer content, so it is copied into the repository before
    the link is restored. Local edits are never thrown away.

.PARAMETER Check
    Report status and change nothing. Exits non-zero if anything is broken,
    which makes it usable from a prompt or a scheduled task.

.EXAMPLE
    .\sync.ps1 -Check
    Show which links drifted, without repairing them.

.EXAMPLE
    .\sync.ps1
    Rescue drifted content into the repository and relink.
#>
[CmdletBinding()]
param(
    [switch]$Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/dotfiles.ps1')

$root     = Get-DotfilesRoot
$manifest = Import-DotfilesManifest -Root $root

Write-Host ''
Write-Host '  Dotfiles sync' -ForegroundColor Cyan
if ($Check) { Write-Host '  mode: check only' -ForegroundColor Yellow }
Write-Host ''

$counts  = @{ Ok = 0; Rescued = 0; Relinked = 0; Created = 0; Missing = 0; Failed = 0 }
$rescued = @()

foreach ($link in $manifest.Links) {
    $source = Join-Path $root $link.Repo.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $target = Expand-DotfilesToken -Path $link.Target
    $state  = Get-DotfilesLinkState -Source $source -Target $target
    $label  = $link.Repo

    if ($state -eq 'Linked') {
        $counts.Ok++
        continue
    }
    elseif ($state -eq 'Orphan') {
        $counts.Missing++
        Write-Host "  missing  $label" -ForegroundColor Yellow
        Write-Host "           listed in the manifest but not in the repository" -ForegroundColor DarkGray
        continue
    }

    if ($Check) {
        $note = switch ($state) {
            'Foreign' { 'link was replaced by a real file, repository is behind' }
            'Relink'  { 'link points somewhere else' }
            'Missing' { 'not linked on this machine yet' }
        }
        Write-Host "  drifted  $label" -ForegroundColor Yellow
        Write-Host "           $note" -ForegroundColor DarkGray
        $counts.Failed++
        continue
    }

    try {
        if ($state -eq 'Foreign') {
            # The machine holds the newer content. Bring it into the repository
            # before relinking, otherwise the edits made since the link broke
            # would be lost.
            Copy-Item -LiteralPath $target -Destination $source -Recurse -Force
            Remove-Item -LiteralPath $target -Recurse -Force
            New-Item -ItemType SymbolicLink -Path $target -Value $source -Force | Out-Null
            $counts.Rescued++
            $rescued += $label
            Write-Host "  rescued  $label" -ForegroundColor Magenta
            Write-Host "           local changes copied into the repository, then relinked" -ForegroundColor DarkGray
        }
        elseif ($state -eq 'Relink') {
            Remove-DotfilesLink -Path $target
            New-Item -ItemType SymbolicLink -Path $target -Value $source -Force | Out-Null
            $counts.Relinked++
            Write-Host "  relinked $label" -ForegroundColor Green
        }
        else {
            New-DotfilesParent -Path $target
            New-Item -ItemType SymbolicLink -Path $target -Value $source -Force | Out-Null
            $counts.Created++
            Write-Host "  linked   $label" -ForegroundColor Green
        }
    } catch {
        $counts.Failed++
        Write-Host "  FAILED   $label" -ForegroundColor Red
        Write-Host "           $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ''
Write-Host "  ok $($counts.Ok)  rescued $($counts.Rescued)  relinked $($counts.Relinked)  linked $($counts.Created)  missing $($counts.Missing)  failed $($counts.Failed)"

if ($rescued.Count -gt 0) {
    Write-Host ''
    Write-Host '  Content was pulled back into the repository. Review and commit:' -ForegroundColor Cyan
    Write-Host '    git -C "' -NoNewline; Write-Host $root -NoNewline; Write-Host '" diff'
}

Write-Host ''
if ($counts.Failed -gt 0) { exit 1 }
