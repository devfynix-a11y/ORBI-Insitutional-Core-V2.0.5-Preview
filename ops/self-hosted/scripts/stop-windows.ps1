$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
Set-Location $root

$compose = @(
    '--env-file', '.env',
    '-f', 'ops/self-hosted/docker-compose.dev.yml',
    '-f', 'ops/self-hosted/Auth_Security/docker-compose.yml',
    '-f', 'ops/self-hosted/Storage/docker-compose.yml'
)

docker compose @compose down
Write-Host 'ORBI development containers stopped. Persistent volumes were preserved.'
