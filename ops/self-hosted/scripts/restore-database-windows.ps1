param(
    [Parameter(Mandatory = $true)]
    [string]$BackupPath,

    [switch]$ConfirmRestore
)

$ErrorActionPreference = 'Stop'

if (-not $ConfirmRestore) {
    throw 'Restore is destructive. Re-run with -ConfirmRestore after verifying the backup path.'
}

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
Set-Location $root
$resolvedBackup = (Resolve-Path -LiteralPath $BackupPath).Path

function Get-EnvValue([string]$key, [string]$fallback = '') {
    $line = Get-Content '.env' |
        Where-Object { $_ -match "^\s*$([Regex]::Escape($key))\s*=" } |
        Select-Object -Last 1
    if (-not $line) { return $fallback }
    $value = ($line -split '=', 2)[1].Trim().Trim('"').Trim("'")
    if ($value) { return $value }
    return $fallback
}

$checksumPath = "$resolvedBackup.sha256"
if (Test-Path -LiteralPath $checksumPath) {
    $expected = ((Get-Content -LiteralPath $checksumPath -Raw).Trim() -split '\s+')[0].ToLowerInvariant()
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedBackup).Hash.ToLowerInvariant()
    if ($expected -ne $actual) {
        throw 'Backup checksum verification failed.'
    }
}

$database = Get-EnvValue 'ORBI_POSTGRES_DB' 'orbi'
$user = Get-EnvValue 'ORBI_POSTGRES_USER' 'orbi'
$password = Get-EnvValue 'ORBI_POSTGRES_PASSWORD'
if (-not $password) { throw 'ORBI_POSTGRES_PASSWORD is missing from .env.' }

$compose = @(
    '--env-file', '.env',
    '-f', 'ops/self-hosted/docker-compose.dev.yml',
    '-f', 'ops/self-hosted/Auth_Security/docker-compose.yml',
    '-f', 'ops/self-hosted/Storage/docker-compose.yml'
)

$containerPath = "/tmp/orbi-restore-$([guid]::NewGuid().ToString('N')).dump"
docker compose @compose stop core
if ($LASTEXITCODE -ne 0) { throw 'Failed to stop Core before restore.' }

$restored = $false
try {
    docker cp $resolvedBackup "orbi-postgres:$containerPath"
    if ($LASTEXITCODE -ne 0) { throw 'Failed to copy backup into PostgreSQL container.' }

    docker exec -e "PGPASSWORD=$password" orbi-postgres `
        pg_restore --clean --if-exists --no-owner --no-privileges `
        --username $user --dbname $database $containerPath
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL restore failed. Core remains stopped.' }
    $restored = $true
}
finally {
    docker exec orbi-postgres rm -f $containerPath | Out-Null
}

if ($restored) {
    docker compose @compose start core
    if ($LASTEXITCODE -ne 0) { throw 'Restore succeeded, but Core failed to restart.' }
    Write-Host 'Restore completed. Run read/write DB tests and reconciliation before reopening financial traffic.'
}
