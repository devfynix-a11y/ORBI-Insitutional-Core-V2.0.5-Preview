$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$template = Join-Path $root '.env.example'
$target = Join-Path $root '.env'

if (Test-Path $target) {
    throw "$target already exists. Refusing to overwrite local secrets."
}

function New-HexSecret([int]$bytes) {
    $buffer = New-Object byte[] $bytes
    $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $generator.GetBytes($buffer)
    }
    finally {
        $generator.Dispose()
    }
    return -join ($buffer | ForEach-Object { $_.ToString('x2') })
}

function Set-EnvValue([string]$content, [string]$key, [string]$value) {
    $escaped = [Regex]::Escape($key)
    return [Regex]::Replace(
        $content,
        "(?m)^$escaped=.*$",
        "$key=$value"
    )
}

$content = Get-Content -Raw $template
$values = @{
    'NODE_ENV' = 'development'
    'ORBI_AUTH_PROVIDER' = 'keycloak'
    'ORBI_DATA_PROVIDER' = 'local'
    'ORBI_ENABLE_GATEWAY_BACKGROUND_JOBS' = 'false'
    'ORBI_ENABLE_INTERNAL_BACKGROUND_JOBS' = 'false'
    'ORBI_IMAGE_STORAGE_PROVIDER' = 'disabled'
    'ORBI_KEYCLOAK_INTERNAL_URL' = 'http://keycloak:8080'
    'ORBI_KEYCLOAK_PUBLIC_URL' = 'http://localhost:8081'
    'ORBI_KEYCLOAK_ISSUER' = 'http://localhost:8081/realms/orbi'
    'ORBI_KEYCLOAK_ADMIN_PASSWORD' = (New-HexSecret 32)
    'JWT_SECRET' = (New-HexSecret 64)
    'SESSION_SECRET' = (New-HexSecret 64)
    'KMS_MASTER_KEY' = (New-HexSecret 64)
    'WORKER_SECRET' = (New-HexSecret 32)
    'WORKER_SIGNING_SECRET' = (New-HexSecret 64)
    'ORBI_MONITOR_API_KEY' = (New-HexSecret 32)
    'ORBI_BOOTSTRAP_ADMIN_SECRET' = (New-HexSecret 32)
    'ORBI_INTERNAL_MTLS_MODE' = 'off'
    'ORBI_INTERNAL_MTLS_PROXY_SHARED_SECRET' = (New-HexSecret 64)
    'ORBI_POSTGRES_PASSWORD' = (New-HexSecret 32)
    'ORBI_VALKEY_PASSWORD' = (New-HexSecret 32)
    'ORBI_STORAGE_ROOT_PASSWORD' = (New-HexSecret 32)
    'ORBI_GRAFANA_ADMIN_PASSWORD' = (New-HexSecret 24)
    'ORBI_ENFORCE_HTTPS' = 'false'
    'ORBI_API_GATEWAY_REDIS_REQUIRED' = 'true'
}

foreach ($entry in $values.GetEnumerator()) {
    $content = Set-EnvValue $content $entry.Key $entry.Value
}

$postgresPassword = $values['ORBI_POSTGRES_PASSWORD']
$valkeyPassword = $values['ORBI_VALKEY_PASSWORD']
$content = Set-EnvValue $content 'DATABASE_URL' "postgresql://orbi:$postgresPassword@postgres:5432/orbi"
$content = Set-EnvValue $content 'VALKEY_URL' "redis://:$valkeyPassword@valkey:6379/0"

[IO.File]::WriteAllText($target, $content, [Text.UTF8Encoding]::new($false))
Write-Host "Created $target with development-only secrets."
Write-Host 'Do not reuse these values in staging or production.'
