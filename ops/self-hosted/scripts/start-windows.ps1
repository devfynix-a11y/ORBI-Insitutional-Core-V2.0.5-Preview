$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
Set-Location $root

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker is not installed. Install Docker Desktop with the WSL2 backend first.'
}

docker version | Out-Null
docker compose version | Out-Null

if (-not (Test-Path '.env')) {
    & (Join-Path $PSScriptRoot 'generate-dev-env.ps1')
}

function Get-EnvValue([string]$key, [string]$fallback) {
    $line = Get-Content '.env' |
        Where-Object { $_ -match "^\s*$([Regex]::Escape($key))\s*=" } |
        Select-Object -Last 1
    if (-not $line) {
        return $fallback
    }

    $value = ($line -split '=', 2)[1].Trim().Trim('"').Trim("'")
    if ($value) { return $value }
    return $fallback
}

function Pull-ImageWithRetry([string]$image, [int]$attempts = 5) {
    for ($attempt = 1; $attempt -le $attempts; $attempt++) {
        Write-Host "Pulling $image (attempt $attempt/$attempts)..."
        docker pull $image
        if ($LASTEXITCODE -eq 0) {
            return
        }
        if ($attempt -lt $attempts) {
            Start-Sleep -Seconds (10 * $attempt)
        }
    }
    throw "Failed to pull $image after $attempts attempts."
}

$images = @(
    (Get-EnvValue 'ORBI_POSTGRES_IMAGE' 'postgres:16-bookworm'),
    (Get-EnvValue 'ORBI_VALKEY_IMAGE' 'valkey/valkey:8.0-bookworm'),
    (Get-EnvValue 'ORBI_KEYCLOAK_IMAGE' 'quay.io/keycloak/keycloak:26.5.0'),
    (Get-EnvValue 'ORBI_STORAGE_IMAGE' 'minio/minio:latest'),
    (Get-EnvValue 'ORBI_STORAGE_CLIENT_IMAGE' 'minio/mc:latest')
) | Select-Object -Unique

foreach ($image in $images) {
    Pull-ImageWithRetry $image
}

$compose = @(
    '--env-file', '.env',
    '-f', 'ops/self-hosted/docker-compose.dev.yml',
    '-f', 'ops/self-hosted/Auth_Security/docker-compose.yml',
    '-f', 'ops/self-hosted/Storage/docker-compose.yml'
)

$env:COMPOSE_PARALLEL_LIMIT = '1'
docker compose @compose up --build --pull never -d
if ($LASTEXITCODE -ne 0) { throw 'ORBI development stack failed to start.' }

docker compose @compose ps
Write-Host ''
Write-Host 'Core API:  http://localhost:3000'
Write-Host 'Keycloak:  http://localhost:8081'
Write-Host 'Realm:     http://localhost:8081/realms/orbi'
