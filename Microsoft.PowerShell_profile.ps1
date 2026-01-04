$user = $env:USERNAME

Set-PsReadLineOption -PredictionViewStyle ListView


function newdb {
    $port = $args[0]

    if (-not $port) {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $listener.Start()
        $port = $listener.LocalEndpoint.Port
        $listener.Stop()
        Write-Host "No se especificó puerto. Usando el disponible: $port"
    }

    $path = "$PWD\docker-compose.yml"

    if (-Not (Test-Path $path)) {
        
@"
services:
  postgres:
    image: postgres:14.1-alpine
    restart: always
    ports:
      - $($port):5432
    environment:
      POSTGRES_USER: dusk
      POSTGRES_PASSWORD: dusk
      POSTGRES_DB: dusk
"@ 
|   Set-Content -Path $path

    Write-Host "Archivo creado en: $path"
    } 
    docker compose up -d;
    $connectionString = "DATABASE_URL=postgresql://dusk:dusk@localhost:$($port)/dusk"
    $connectionString | Set-Clipboard;
    Write-Host "Conexión: $connectionString (copiada al portapapeles ✅)";
}


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

# function cf {
#     param (
#         [string]$path = ".",      # Ruta por defecto es el directorio actual
#         [string]$extension = ".txt"  # Extensión por defecto es .txt
#     )

#     if (-not (Test-Path $path)) {
#         Write-Host "La ruta $path no existe"
#             New-Item -Path ".\$path$extension" -ItemType File -Force

#         foreach ($item in $args) {
#         #  Verificar si la ruta existe
#             New-Item -Path ".\$item$extension" -ItemType File -Force
#         }
#     }
#     else{
#         foreach ($item in $args) {
#             # Concatenar la ruta y la extensión
#             $filename = "$path\$item$extension"
#             New-Item -Path $filename -ItemType File -Force
#         }
#     }
# }

function cf {
    param (
        [Parameter(Mandatory = $true)]
        [string]$path,

        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$files
    )

    if (-not (Test-Path $path)) {
        Write-Host "📁 Creando carpeta: $path"
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }

    foreach ($file in $files) {
        if ($file -match "\.") {
            $filename = Join-Path $path $file
        } else {
            $filename = Join-Path $path "$file.ts"
        }

        New-Item -ItemType File -Path $filename -Force | Out-Null
        Write-Host "📄 Creado: $filename"
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
