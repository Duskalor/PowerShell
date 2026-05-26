$user = $env:USERNAME

Set-PsReadLineOption -PredictionViewStyle ListView

Import-Module Terminal-Icons

# Zellij: persistencia de cwd con archivo global (mecanismo original simple)
# Todos los panes/flotantes leen el mismo archivo al iniciar y restauran.
# Trade-off: si cambias de tab y abris flotante, este puede tener la cwd de la tab anterior.
if ($env:ZELLIJ) {
    $_zjLastCwdFile = "$env:TEMP\zellij_cwd.txt"

    # Al iniciar shell: restaurar cwd guardada
    if (Test-Path $_zjLastCwdFile) {
        $_last = (Get-Content $_zjLastCwdFile -Raw).Trim()
        if ($_last -and (Test-Path $_last)) {
            Set-Location $_last
        }
    }

    # En cada prompt: escribir cwd actual al archivo global
    function prompt {
        (Get-Location).Path | Set-Content $_zjLastCwdFile -NoNewline
        "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) "
    }
}

# â”€â”€â”€ Floating pane toggle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# _zflt:   Crea/toggle pane flotante con el CWD del panel actual.
# _zfltf:  Fuerza creaciÃ³n (Ãºtil si mataron el proceso flotante).
#
# 1er Alt+F en un panel         â†’ crea floating pane en el CWD de ESE panel.
# 2do Alt+F en el mismo panel    â†’ toggle (hide/show). El proceso sigue vivo.
# Alt+F, f (rÃ¡pido, secuencia)   â†’ fuerza crear uno nuevo (reset).
#
# NOTA: Desde la ventana flotante misma NO uses Alt+F (crearÃ­a otra).
#       UsÃ¡ click, Alt+arrow o Ctrl+g, p, w para salir/volver.
$script:ZjFloatCreated = $false

function _zflt {
    if ($script:ZjFloatCreated) {
        # Ya existe un floating pane desde este panel â†’ toggle
        $null = zellij action toggle-floating-panes 2>&1
    } else {
        # Primera vez â†’ crear con el CWD actual
        $null = zellij action new-pane --floating --cwd "$($PWD.Path)" 2>&1
        $script:ZjFloatCreated = $true
    }
}

function _zfltf {
    # Forzar creaciÃ³n de floating pane en el CWD actual
    $null = zellij action new-pane --floating --cwd "$($PWD.Path)" 2>&1
    $script:ZjFloatCreated = $true
}

# Alt+F â†’ toggle/crear (solo si estamos dentro de Zellij)
Set-PSReadLineKeyHandler -Chord "Alt+f" -ScriptBlock {
    if ($env:ZELLIJ_SESSION_NAME) { _zflt }
}

# Alt+F, f  â†’ fuerza crear nuevo floating pane (secuencia: apretÃ¡ Alt+F, soltÃ¡, y despuÃ©s f)
Set-PSReadLineKeyHandler -Chord "Alt+f,f" -ScriptBlock {
    if ($env:ZELLIJ_SESSION_NAME) { _zfltf }
}

# No ensuciar el historial con comandos _z*
Set-PSReadLineOption -AddToHistoryHandler {
    param([string]$line)
    return $line -notmatch '^_z'
}

# Zellij auto-start removed: Alacritty now launches zellij directly (faster)

# Engram sync helpers
function engram-push {
    $dir = "$HOME\.engram"
    engram export "$dir\engram-export.json"
    Push-Location $dir
    git add -A
    git commit -m "sync $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    git push
    Pop-Location
}
function engram-pull {
    $dir = "$HOME\.engram"
    Push-Location $dir
    git pull
    Pop-Location
    engram import "$dir\engram-export.json"
}


function newdb { & "$PSScriptRoot\Scripts\newdb.ps1" @args }


# --- Git shortcuts -----------------------------------------------------------
function gs   { git status }
function ga   { git add $args }
function gc   { git commit -m $args[0] }
function gp   { git push }
function gpl  { git pull }
function gl   { git log --oneline --graph --decorate -10 }
function gsw  { git switch $args }
function gswc { git switch -c $args[0] }
function gb   { git branch $args }
function gbd  { git branch -d $args[0] }
function gbD  { git branch -D $args[0] }
function gm   { git merge $args }
function grs  { git restore $args }
function gst  { git stash }
function gstp { git stash pop }

function ghelp {
    Write-Host ""
    Write-Host "  Git shortcuts" -ForegroundColor Cyan
    Write-Host "  -----------------------------------------" -ForegroundColor DarkGray
    Write-Host "  gs            git status"
    Write-Host "  ga <files>    git add"
    Write-Host "  gc 'msg'      git commit -m"
    Write-Host "  gp            git push"
    Write-Host "  gpl           git pull"
    Write-Host "  gl            git log (graph, ultimos 10)"
    Write-Host ""
    Write-Host "  Ramas" -ForegroundColor Cyan
    Write-Host "  -----------------------------------------" -ForegroundColor DarkGray
    Write-Host "  gb             listar ramas"
    Write-Host "  gsw  <nombre>  cambiar de rama  (git switch)"
    Write-Host "  gswc <nombre>  crear rama nueva (git switch -c)"
    Write-Host "  gbd  <nombre>  eliminar rama (safe)"
    Write-Host "  gbD  <nombre>  eliminar rama (forzado)"
    Write-Host ""
    Write-Host "  Archivos / Stash / Merge" -ForegroundColor Cyan
    Write-Host "  -----------------------------------------" -ForegroundColor DarkGray
    Write-Host "  grs  <file>   descartar cambios (git restore)"
    Write-Host "  gm  <branch>  git merge"
    Write-Host "  gst           git stash"
    Write-Host "  gstp          git stash pop"
    Write-Host ""
}

# â”€â”€â”€ NavegaciÃ³n â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
function d {
    Set-Location -Path "C:\Users\$user\Documents\Proyects"
}

function w {
    Invoke-Item ./;
}
function pr {
    Set-Location -Path "C:\Users\$user\Documents\Proyects\React"
}
function fr {
    Set-Location -Path "C:\Users\$user\Documents\Proyects\React\frontEndMentor"
}
function en {
    Set-Location -Path "C:\Users\$user\Documents\Proyects\en"
}
function n {
    Set-Location -Path "C:\Users\$user\Documents\Proyects\Node"
}
function mono {
    Set-Location -Path "C:\Users\$user\Documents\Proyects\MonoRepo"
}
function as {
    Set-Location -Path "C:\Users\$user\Documents\Proyects\astro"
}
function l {
    Set-Location -Path "C:\Users\$user\Documents\Proyects\Laravel"
}
function p {
    Set-Location -Path "C:\Users\$user\Documents\Proyects\PHP"
}
function ne {
    Set-Location -Path "C:\Users\$user\Documents\Proyects\Nextjs"
}
function js {
    Set-Location -Path "C:\Users\$user\Documents\Proyects\javascript"
}
function nes {
    Set-Location -Path "C:\Users\$user\Documents\Proyects\nestjs"
}
function power {
    Set-Location -Path "C:\Users\$user\Documents\PowerShell\";
    code .;
}

function tg {
    Start-Process "G:\Juegos\Suzumiya Haruhi\asd\Telegram\Telegram.exe"
}
function telegram {
    Set-Location -Path "G:\Juegos\Suzumiya Haruhi\asd\Telegram"
}


function vite {
   pnpm create vite@latest $args[0];
   Set-Location $args[0];
   pnpm i;   
   code .;
   pnpm run dev;
}
function next {
   pnpx create-next-app@latest $args[0];
   Set-Location $args[0];
   code .;
   pnpm run dev;
}

function vitet {
   pnpm create vite@latest $args[0];
   Set-Location $args[0];
   pnpm install tailwindcss @tailwindcss/vite;   
   pnpm i;   
   code .;
   pnpm run dev;
}


function dev {
    pnpm run dev;
}


function txt{ }

$route = "C:\Users\$user\Documents\Proyects\rmj"
function cdrm { Set-Location -Path $route }
function rmj {
   param([string]$n = "creado")
   & "$PSScriptRoot\Scripts\rmj.ps1" -n $n
}

function cf {
    param (
        [Parameter(Mandatory = $true)]
        [string]$path,

        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$files
    )

    if (-not (Test-Path $path)) {
        Write-Host "Creando carpeta: $path"
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }

    foreach ($file in $files) {
        if ($file -match "\.") {
            $filename = Join-Path $path $file
        } else {
            $filename = Join-Path $path "$file.ts"
        }

        New-Item -ItemType File -Path $filename -Force | Out-Null
        Write-Host "Creado: $filename"
    }
}




function astro {
   pnpm create astro@latest $args[0];
   Set-Location $args[0];
   code .;
   pnpm run dev;
}
# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

function post {
    node "C:\Users\$user\Documents\Proyects\node\post-facebook\index.js"
}

# Fix: VSCode integrated terminal a veces no carga el User PATH (solo el del sistema).
# Esto asegura que la carpeta de npm globals (pnpm, etc.) este disponible.
$npmGlobals = "C:\Users\$user\AppData\Roaming\npm"
if ((Test-Path $npmGlobals) -and (($env:PATH -split ';') -notcontains $npmGlobals)) {
    $env:PATH = "$npmGlobals;$env:PATH"
}

# --- TOOLS BLOCK (zoxide / starship / bat / eza / rg / fd) -------------------
# Para desinstalar: ejecuta Scripts\uninstall_tools.ps1 y borra este bloque.

# Starship prompt — solo fuera de Zellij (Zellij tiene su propio prompt para CWD tracking)
if (-not $env:ZELLIJ) {
    if (Get-Command starship -ErrorAction SilentlyContinue) {
        Invoke-Expression (&starship init powershell)
    }
}

# Zoxide (smart cd: usa 'z' en lugar de 'cd')
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# eza — listado con iconos y colores
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function ls { eza --icons $args }
    function ll { eza --icons -l $args }
    function la { eza --icons -la $args }
    function lt { eza --icons --tree --level=2 $args }
}

# bat — cat con syntax highlighting
if (Get-Command bat -ErrorAction SilentlyContinue) {
    function cat { bat $args }
}

# --- END TOOLS BLOCK ----------------------------------------------------------
