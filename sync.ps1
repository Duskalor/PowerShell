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

<#
    Rendered configs need the same treatment for a different reason.

    A link cannot drift in content, only in kind. A rendered file is an ordinary
    file, so an edit made on the machine — by hand, or by the application
    rewriting its own config — is invisible to the repository. That is precisely
    the failure this repository exists to prevent, so it gets caught here.

    The rescue is the expansion run backwards: this machine's own paths become
    tokens again and the result is written into the template. The rendered file
    is then produced fresh from that template, which proves the round trip
    worked before anything is reported as saved.
#>
foreach ($render in $manifest.Rendered) {
    $templatePath = Join-Path $root $render.Template.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $target       = Expand-DotfilesToken -Path $render.Target
    $state        = Get-DotfilesRenderState -Template $templatePath -Target $target
    $label        = $render.Template

    if ($state -eq 'Current') {
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
            'Drifted' { 'edited on this machine, the template is behind' }
            'Stale'   { 'still a symbolic link from before this file was templated' }
            'Missing' { 'not rendered on this machine yet' }
        }
        Write-Host "  drifted  $label" -ForegroundColor Yellow
        Write-Host "           $note" -ForegroundColor DarkGray
        $counts.Failed++
        continue
    }

    try {
        if ($state -eq 'Drifted') {
            $tokenized = ConvertTo-DotfilesTemplateText (Read-DotfilesText $target)
            Write-DotfilesText -Path $templatePath -Text $tokenized
            Write-DotfilesText -Path $target -Text (Expand-DotfilesTemplateText $tokenized)
            $counts.Rescued++
            $rescued += $label
            Write-Host "  rescued  $label" -ForegroundColor Magenta
            Write-Host "           machine edits tokenized back into the template" -ForegroundColor DarkGray
            continue
        }

        # Stale means a leftover symbolic link. Removing the link itself matters:
        # writing to it would write through into the repository.
        if ($state -eq 'Stale') { Remove-DotfilesLink -Path $target }

        New-DotfilesParent -Path $target
        Write-DotfilesText -Path $target -Text (Expand-DotfilesTemplateText (Read-DotfilesText $templatePath))
        $counts.Created++
        Write-Host "  rendered $label" -ForegroundColor Green
    } catch {
        $counts.Failed++
        Write-Host "  FAILED   $label" -ForegroundColor Red
        Write-Host "           $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ''
Write-Host "  ok $($counts.Ok)  rescued $($counts.Rescued)  relinked $($counts.Relinked)  written $($counts.Created)  missing $($counts.Missing)  failed $($counts.Failed)"

if ($rescued.Count -gt 0) {
    Write-Host ''
    Write-Host '  Content was pulled back into the repository. Review and commit:' -ForegroundColor Cyan
    Write-Host '    git -C "' -NoNewline; Write-Host $root -NoNewline; Write-Host '" diff'
}

Write-Host ''
if ($counts.Failed -gt 0) { exit 1 }
