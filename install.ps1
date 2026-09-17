<#
.SYNOPSIS
    Take a fresh Windows machine from nothing to this configuration.

.DESCRIPTION
    bootstrap.ps1 links configuration that is already cloned. install.ps1 is the
    step before it: on a machine with nothing on it there is no git to clone
    with, no PowerShell 7 to run the profile, and none of the tools the profile
    calls. This script installs those, clones the repository into the real
    PowerShell profile directory, and then hands over to bootstrap.ps1.

    On a bare machine:

        irm https://raw.githubusercontent.com/Duskalor/PowerShell/main/install.ps1 | iex

    Every step checks before it acts, so running this again on a configured
    machine repairs it rather than duplicating anything.

    It deliberately runs under Windows PowerShell 5.1 as well as PowerShell 7,
    because 5.1 is what a fresh Windows install actually ships with.

.PARAMETER SkipPackages
    Do not install applications with winget.

.PARAMETER AllPackages
    Restore packages/winget.json, the full snapshot of this machine, instead of
    packages/winget-core.json. The snapshot includes games, office suites and
    redistributables — everything that happened to be installed when it was
    exported.

.PARAMETER SkipFont
    Do not install IosevkaTerm Nerd Font.

.PARAMETER SkipEngram
    Do not install the engram binary.

.PARAMETER DryRun
    Report every step and change nothing.

.EXAMPLE
    .\install.ps1 -DryRun
    Read the whole plan before any of it happens.

.EXAMPLE
    .\install.ps1
    Install the toolchain, clone, link, and be done.
#>
[CmdletBinding()]
param(
    [switch]$SkipPackages,
    [switch]$AllPackages,
    [switch]$SkipFont,
    [switch]$SkipEngram,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RepoUrl   = 'https://github.com/Duskalor/PowerShell.git'
$FontUrl   = 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/IosevkaTerm.zip'
$FontName  = 'IosevkaTermNerdFont'
$EngramApi = 'https://api.github.com/repos/Gentleman-Programming/engram/releases/latest'

$script:Done    = @()
$script:Skipped = @()
$script:Failed  = @()

function Write-Head { param([string]$Text) Write-Host ''; Write-Host "  $Text" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Text) Write-Host "  ok       $Text" -ForegroundColor Green;    $script:Done    += $Text }
function Write-Skip { param([string]$Text) Write-Host "  skip     $Text" -ForegroundColor DarkGray; $script:Skipped += $Text }
function Write-Warn { param([string]$Text) Write-Host "  warn     $Text" -ForegroundColor Yellow }
function Write-Bad  { param([string]$Text) Write-Host "  FAILED   $Text" -ForegroundColor Red;      $script:Failed  += $Text }
function Write-Plan { param([string]$Text) Write-Host "  would    $Text" -ForegroundColor Yellow }
function Write-Note { param([string]$Text) Write-Host "           $Text" -ForegroundColor DarkGray }

function Test-Tool {
    param([Parameter(Mandatory)][string]$Name)
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

<#
    Re-read PATH from the registry.

    winget writes its shims into a directory that is on PATH only for shells
    started afterwards. Without this, the rest of the run cannot see what the
    previous step just installed.
#>
function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (@($machine, $user) | Where-Object { $_ }) -join ';'
}

<#
    Where PowerShell 7 expects the profile to live.

    Not "$HOME\Documents": OneDrive redirects the Documents folder on many
    machines, and the shell folder API is what actually knows where it went.
    Cloning to the wrong path produces a repository that links every config
    correctly and a profile that never loads.
#>
function Get-RepoPath {
    $docs = [Environment]::GetFolderPath('MyDocuments')
    if ([string]::IsNullOrWhiteSpace($docs)) { $docs = Join-Path $HOME 'Documents' }
    Join-Path $docs 'PowerShell'
}

# The same probe bootstrap.ps1 uses, inlined because lib/ is not cloned yet.
function Test-SymlinkCapability {
    $probeDir  = Join-Path ([System.IO.Path]::GetTempPath()) ('install-probe-' + [guid]::NewGuid().ToString('N'))
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

Write-Host ''
Write-Host '  Dev environment installer' -ForegroundColor Cyan
Write-Host "  host: PowerShell $($PSVersionTable.PSVersion) on $([Environment]::OSVersion.VersionString)"
if ($DryRun) { Write-Host '  mode: dry run, nothing will change' -ForegroundColor Yellow }

# --- 1. Prerequisites ---------------------------------------------------------
Write-Head '1. Prerequisites'

if (-not (Test-Tool 'winget')) {
    Write-Bad 'winget is not available'
    Write-Note 'Install "App Installer" from the Microsoft Store, then run this again:'
    Write-Note 'https://apps.microsoft.com/detail/9nblggh4nns1'
    exit 1
}
Write-Ok 'winget'

if (Test-SymlinkCapability) {
    Write-Ok 'symbolic links allowed'
} else {
    Write-Bad 'this shell cannot create symbolic links'
    Write-Note 'Settings > System > For developers > Developer Mode: On'
    Write-Note 'or re-run this script from a terminal opened as Administrator.'
    exit 1
}

if (Test-Tool 'git') {
    Write-Ok 'git'
} elseif ($DryRun) {
    Write-Plan 'install Git.Git'
} else {
    Write-Host '  ...      installing git' -ForegroundColor DarkGray
    winget install --id Git.Git --exact --source winget --silent --accept-package-agreements --accept-source-agreements | Out-Null
    Update-SessionPath
    if (Test-Tool 'git') {
        Write-Ok 'git installed'
    } else {
        Write-Bad 'git was installed but is not on PATH — open a new terminal and run this again'
        exit 1
    }
}

# PowerShell 7 is what the profile is written for. Installing it here means the
# clone in the next step lands somewhere that will actually be read.
if ($PSVersionTable.PSVersion.Major -lt 6 -and -not (Test-Tool 'pwsh')) {
    if ($DryRun) {
        Write-Plan 'install Microsoft.PowerShell (PowerShell 7)'
    } else {
        Write-Host '  ...      installing PowerShell 7' -ForegroundColor DarkGray
        winget install --id Microsoft.PowerShell --exact --source winget --silent --accept-package-agreements --accept-source-agreements | Out-Null
        Update-SessionPath
        if (Test-Tool 'pwsh') { Write-Ok 'PowerShell 7 installed' } else { Write-Warn 'PowerShell 7 not on PATH yet' }
    }
} else {
    Write-Ok 'PowerShell 7'
}

# --- 2. Repository ------------------------------------------------------------
Write-Head '2. Repository'

$repo = Get-RepoPath
Write-Note $repo

if (Test-Path -LiteralPath (Join-Path $repo '.git')) {
    if ($DryRun) {
        Write-Plan 'pull the latest commits'
    } else {
        git -C $repo pull --ff-only 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok 'repository up to date'
        } else {
            Write-Warn 'could not fast-forward — leaving the working copy untouched'
        }
    }
} elseif ($DryRun) {
    Write-Plan "clone $RepoUrl"
} else {
    # A profile directory usually already exists and holds a stock profile.
    # git refuses to clone into a non-empty directory, so move the old one aside
    # instead of failing or deleting anything.
    if ((Test-Path -LiteralPath $repo) -and (Get-ChildItem -LiteralPath $repo -Force | Select-Object -First 1)) {
        $moved = "$repo.before-dotfiles-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
        Move-Item -LiteralPath $repo -Destination $moved
        Write-Warn "existing profile directory moved to $moved"
    }
    git clone $RepoUrl $repo 2>&1 | Out-Null
    if (Test-Path -LiteralPath (Join-Path $repo '.git')) {
        Write-Ok 'cloned'
    } else {
        Write-Bad 'clone failed'
        exit 1
    }
}

# --- 3. Packages --------------------------------------------------------------
Write-Head '3. Packages'

if ($SkipPackages) {
    Write-Skip 'packages (-SkipPackages)'
} else {
    if ($AllPackages) {
        $listName = 'winget.json'
        Write-Note 'full machine snapshot — this includes games and office suites'
    } else {
        $listName = 'winget-core.json'
        Write-Note 'curated toolchain. Pass -AllPackages for the full snapshot.'
    }
    $listPath = Join-Path $repo (Join-Path 'packages' $listName)

    if (-not (Test-Path -LiteralPath $listPath)) {
        Write-Warn "$listName not found, nothing to import"
    } elseif ($DryRun) {
        Write-Plan "winget import $listName"
    } else {
        Write-Host '  ...      installing, this takes a while' -ForegroundColor DarkGray
        # import exits non-zero when any single package is already present or
        # unavailable in this region, which is normal. Report it, do not abort.
        winget import --import-file $listPath --accept-package-agreements --accept-source-agreements --ignore-unavailable --disable-interactivity
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "$listName imported"
        } else {
            Write-Warn "$listName imported with warnings (exit $LASTEXITCODE) — usually packages already installed"
        }
        Update-SessionPath
    }
}

# --- 4. Font ------------------------------------------------------------------
Write-Head '4. Font'

$fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$already = @(Get-ChildItem -LiteralPath $fontDir -Filter "$FontName-*.ttf" -ErrorAction SilentlyContinue)

if ($SkipFont) {
    Write-Skip 'font (-SkipFont)'
} elseif ($already.Count -gt 0) {
    Write-Skip "IosevkaTerm Nerd Font already installed ($($already.Count) faces)"
} elseif ($DryRun) {
    Write-Plan 'download and install IosevkaTerm Nerd Font for this user'
} else {
    try {
        $zip     = Join-Path $env:TEMP 'IosevkaTerm-NF.zip'
        $extract = Join-Path $env:TEMP 'IosevkaTerm-NF'
        Write-Host '  ...      downloading IosevkaTerm Nerd Font' -ForegroundColor DarkGray
        Invoke-WebRequest -Uri $FontUrl -OutFile $zip -UseBasicParsing
        if (Test-Path -LiteralPath $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
        Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force

        # The release carries three families: the plain one plus Mono and Propo
        # variants. alacritty.toml and .wezterm.lua ask for "IosevkaTerm NF",
        # which is the plain one, so only those faces are installed.
        $faces = @(Get-ChildItem -LiteralPath $extract -Filter "$FontName-*.ttf" -Recurse)
        if ($faces.Count -eq 0) { throw "no $FontName-*.ttf inside the release archive" }

        # Per-user install needs no elevation: copy the file into the user font
        # directory and name it in the user font registry key.
        New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
        $regKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
        if (-not (Test-Path $regKey)) { New-Item -Path $regKey -Force | Out-Null }

        foreach ($face in $faces) {
            $dest = Join-Path $fontDir $face.Name
            Copy-Item -LiteralPath $face.FullName -Destination $dest -Force
            $entry = [System.IO.Path]::GetFileNameWithoutExtension($face.Name) + ' (TrueType)'
            New-ItemProperty -Path $regKey -Name $entry -Value $dest -PropertyType String -Force | Out-Null
        }

        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue
        Write-Ok "IosevkaTerm Nerd Font ($($faces.Count) faces)"
        Write-Note 'terminals that are already open keep the old font until restarted'
    } catch {
        Write-Bad "font install: $($_.Exception.Message)"
    }
}

# --- 5. Engram ----------------------------------------------------------------
Write-Head '5. Engram'

$binDir     = Join-Path $HOME 'bin'
$engramPath = Join-Path $binDir 'engram.exe'

if ($SkipEngram) {
    Write-Skip 'engram (-SkipEngram)'
} elseif (Test-Path -LiteralPath $engramPath) {
    Write-Skip 'engram.exe already in ~/bin'
} elseif ($DryRun) {
    Write-Plan 'download the latest engram release into ~/bin'
} else {
    try {
        if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { $arch = 'arm64' } else { $arch = 'amd64' }
        $release = Invoke-RestMethod -Uri $EngramApi -Headers @{ 'User-Agent' = 'dotfiles-installer' }
        $asset   = @($release.assets | Where-Object { $_.name -like "*windows_$arch.zip" })[0]
        if (-not $asset) { throw "no windows_$arch asset in release $($release.tag_name)" }

        $zip     = Join-Path $env:TEMP $asset.name
        $extract = Join-Path $env:TEMP 'engram-release'
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing
        if (Test-Path -LiteralPath $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
        Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force

        $exe = @(Get-ChildItem -LiteralPath $extract -Filter 'engram*.exe' -Recurse)[0]
        if (-not $exe) { throw 'no engram executable inside the archive' }

        New-Item -ItemType Directory -Path $binDir -Force | Out-Null
        Copy-Item -LiteralPath $exe.FullName -Destination $engramPath -Force
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue
        Write-Ok "engram $($release.tag_name)"
    } catch {
        Write-Bad "engram install: $($_.Exception.Message)"
    }
}

# ~/bin holds engram and gga, so it goes on PATH whether or not engram landed.
if ($DryRun) {
    if (($env:Path -split ';') -notcontains $binDir) { Write-Plan 'add ~/bin to the user PATH' }
} else {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($null -eq $userPath) { $userPath = '' }
    if (($userPath -split ';') -notcontains $binDir) {
        [Environment]::SetEnvironmentVariable('Path', ($userPath.TrimEnd(';') + ';' + $binDir).TrimStart(';'), 'User')
        Update-SessionPath
        Write-Ok '~/bin added to PATH'
    }
}

# --- 6. Link the configuration ------------------------------------------------
Write-Head '6. Link the configuration'

$bootstrap = Join-Path $repo 'bootstrap.ps1'
if (-not (Test-Path -LiteralPath $bootstrap)) {
    Write-Bad "bootstrap.ps1 not found at $bootstrap"
} elseif ($DryRun) {
    & $bootstrap -DryRun
} else {
    & $bootstrap
}

# --- Summary ------------------------------------------------------------------
Write-Host ''
Write-Host "  installer: done $($script:Done.Count)  skipped $($script:Skipped.Count)  failed $($script:Failed.Count)"
if ($script:Failed.Count -gt 0) {
    Write-Host ''
    Write-Host '  These need attention:' -ForegroundColor Red
    foreach ($item in $script:Failed) { Write-Host "    - $item" -ForegroundColor Red }
}
Write-Host ''
Write-Host '  Next:' -ForegroundColor Cyan
Write-Host '    1. close this terminal and open Alacritty'
Write-Host '    2. run  cmds            to see every command the profile defines'
Write-Host '    3. run  .\sync.ps1 -Check   whenever something feels out of date'
Write-Host ''
if ($script:Failed.Count -gt 0) { exit 1 }
