param(
    [string]$port
)

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
"@ | Set-Content -Path $path

    Write-Host "Archivo creado en: $path"
}

docker compose up -d
$connectionString = "DATABASE_URL=postgresql://dusk:dusk@localhost:$($port)/dusk"
$connectionString | Set-Clipboard
Write-Host "Conexión: $connectionString (copiada al portapapeles)"
