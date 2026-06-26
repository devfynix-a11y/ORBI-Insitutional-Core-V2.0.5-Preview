$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
Set-Location $root

function Get-EnvValue([string]$key, [string]$fallback = '') {
    $line = Get-Content '.env' |
        Where-Object { $_ -match "^\s*$([Regex]::Escape($key))\s*=" } |
        Select-Object -Last 1
    if (-not $line) { return $fallback }
    $value = ($line -split '=', 2)[1].Trim().Trim('"').Trim("'")
    if ($value) { return $value }
    return $fallback
}

if (-not (docker ps --format '{{.Names}}' | Select-String -SimpleMatch 'orbi-postgres')) {
    throw 'orbi-postgres is not running.'
}

$database = Get-EnvValue 'ORBI_POSTGRES_DB' 'orbi'
$user = Get-EnvValue 'ORBI_POSTGRES_USER' 'orbi'
$password = Get-EnvValue 'ORBI_POSTGRES_PASSWORD'
if (-not $password) { throw 'ORBI_POSTGRES_PASSWORD is missing from .env.' }

$backupDirectory = Join-Path $root 'backups\local'
New-Item -ItemType Directory -Force -Path $backupDirectory | Out-Null

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$fileName = "orbi-$stamp.dump"
$containerPath = "/tmp/$fileName"
$hostPath = Join-Path $backupDirectory $fileName

docker exec -e "PGPASSWORD=$password" orbi-postgres `
    pg_dump --format=custom --no-owner --no-privileges `
    --username $user --dbname $database --file $containerPath
if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL backup failed.' }

try {
    docker cp "orbi-postgres:$containerPath" $hostPath
    if ($LASTEXITCODE -ne 0) { throw 'Failed to copy PostgreSQL backup to the host.' }
}
finally {
    docker exec orbi-postgres rm -f $containerPath | Out-Null
}

$backup = Get-Item -LiteralPath $hostPath
if ($backup.Length -le 0) { throw 'PostgreSQL backup file is empty.' }

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $hostPath).Hash.ToLowerInvariant()
[IO.File]::WriteAllText(
    "$hostPath.sha256",
    "$hash  $fileName`n",
    [Text.UTF8Encoding]::new($false)
)

Write-Host "Backup created: $hostPath"
Write-Host "Backup size: $($backup.Length) bytes"
Write-Host "Checksum: $hostPath.sha256"
