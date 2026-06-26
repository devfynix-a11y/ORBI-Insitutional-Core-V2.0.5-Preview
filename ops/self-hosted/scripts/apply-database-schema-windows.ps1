param(
    [switch]$SkipBackup
)

$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
Set-Location $root

if (-not $SkipBackup) {
    & (Join-Path $PSScriptRoot 'backup-windows.ps1')
}

$compose = @(
    '--env-file', '.env',
    '-f', 'ops/self-hosted/docker-compose.dev.yml',
    '-f', 'ops/self-hosted/Auth_Security/docker-compose.yml',
    '-f', 'ops/self-hosted/Storage/docker-compose.yml'
)

docker compose @compose run --rm database-init
if ($LASTEXITCODE -ne 0) { throw 'Database schema application failed.' }

function Get-EnvValue([string]$key, [string]$fallback = '') {
    $line = Get-Content '.env' |
        Where-Object { $_ -match "^\s*$([Regex]::Escape($key))\s*=" } |
        Select-Object -Last 1
    if (-not $line) { return $fallback }
    $value = ($line -split '=', 2)[1].Trim().Trim('"').Trim("'")
    if ($value) { return $value }
    return $fallback
}

$database = Get-EnvValue 'ORBI_POSTGRES_DB' 'orbi'
$user = Get-EnvValue 'ORBI_POSTGRES_USER' 'orbi'
$password = Get-EnvValue 'ORBI_POSTGRES_PASSWORD'

$verification = @'
SELECT 'public_tables=' || COUNT(*) FROM pg_tables WHERE schemaname = 'public';
SELECT 'rls_policies=' || COUNT(*) FROM pg_policies;
SELECT 'migration=' || version
FROM public.schema_migrations
WHERE version = '20260622_native_postgres_runtime';
SELECT 'roles=' || string_agg(rolname, ',' ORDER BY rolname)
FROM pg_roles
WHERE rolname IN ('anon', 'authenticated', 'service_role');
'@

docker exec -e "PGPASSWORD=$password" orbi-postgres `
    psql --tuples-only --no-align --username $user --dbname $database `
    --command $verification
if ($LASTEXITCODE -ne 0) { throw 'Database schema verification failed.' }

Write-Host 'Database schema application and verification completed.'
