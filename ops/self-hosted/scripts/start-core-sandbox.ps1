param(
  [string]$CoreImage = "self-hosted-core",
  [string]$SandboxDatabase = "orbi_core_sandbox",
  [switch]$RebuildSchema
)

$ErrorActionPreference = "Stop"

function New-OrbiSecret([int]$Length) {
  $chars = 48..57 + 65..90 + 97..122
  -join ($chars | Get-Random -Count $Length | ForEach-Object { [char]$_ })
}

function Get-ContainerEnvMap([string]$ContainerName) {
  $rows = docker inspect $ContainerName --format '{{json .Config.Env}}' | ConvertFrom-Json
  $map = [ordered]@{}
  foreach ($row in $rows) {
    $parts = $row -split '=', 2
    if ($parts.Length -eq 2) {
      $map[$parts[0]] = $parts[1]
    }
  }
  $map
}

function Invoke-Postgres([string]$Database, [string]$Sql) {
  docker exec orbi-postgres psql -U orbi -d $Database -v ON_ERROR_STOP=1 -c $Sql | Out-Null
}

$liveCoreEnv = Get-ContainerEnvMap "orbi-core"
$sandboxGatewayEnv = Get-ContainerEnvMap "orbi-pay-gateway-sandbox"

if (-not $liveCoreEnv.Contains("DATABASE_URL")) {
  throw "DATABASE_URL not found on orbi-core."
}
if (-not $sandboxGatewayEnv.Contains("WORKER_SIGNING_SECRET")) {
  throw "WORKER_SIGNING_SECRET not found on orbi-pay-gateway-sandbox."
}

$sandboxDatabaseUrl = $liveCoreEnv["DATABASE_URL"] -replace "/orbi(\?.*)?$", "/$SandboxDatabase`$1"
if ($sandboxDatabaseUrl -eq $liveCoreEnv["DATABASE_URL"]) {
  throw "Could not derive sandbox Core database URL safely."
}

$databaseExists = docker exec orbi-postgres psql -U orbi -d orbi -tAc "select 1 from pg_database where datname = '$SandboxDatabase';"
if ($databaseExists -and $RebuildSchema) {
  $activeConnectionsSql = "select pg_terminate_backend(pid) from pg_stat_activity where datname = '$SandboxDatabase';"
  Invoke-Postgres "orbi" $activeConnectionsSql
  Invoke-Postgres "orbi" "drop database $SandboxDatabase;"
  $databaseExists = $null
}
if (-not $databaseExists) {
  Invoke-Postgres "orbi" "create database $SandboxDatabase owner orbi;"
}

$hasCoreSchemas = docker exec orbi-postgres psql -U orbi -d $SandboxDatabase -tAc "select count(*) from information_schema.schemata where schema_name in ('public', 'orbi_auth');"
if ([int]$hasCoreSchemas -lt 2) {
  docker exec orbi-postgres pg_dump -U orbi -d orbi --schema-only |
    docker exec -i orbi-postgres psql -U orbi -d $SandboxDatabase -v ON_ERROR_STOP=1 | Out-Null
}

$existing = docker ps -a --filter "name=^orbi-core-sandbox$" --format "{{.Names}}"
if ($existing) {
  docker rm -f orbi-core-sandbox | Out-Null
}

$envArgs = New-Object System.Collections.Generic.List[string]
foreach ($key in $liveCoreEnv.Keys) {
  if ($key -in @("PATH", "NODE_VERSION", "YARN_VERSION")) {
    continue
  }
  $value = $liveCoreEnv[$key]
  switch ($key) {
    "NODE_ENV" { $value = "sandbox" }
    "PORT" { $value = "3000" }
    "DATABASE_URL" { $value = $sandboxDatabaseUrl }
    "BACKEND_URL" { $value = "https://sandbox-api.orbifinancial.com" }
    "ORBI_PRIMARY_CORE_BASE_URL" { $value = "https://sandbox-api.orbifinancial.com" }
    "ORBI_WEB_ORIGIN" { $value = "https://sandbox-api.orbifinancial.com" }
    "ORBI_ALLOWED_ORIGINS" { $value = "https://sandbox-api.orbifinancial.com,https://sandbox-pay.orbifinancial.com" }
    "ORBI_ENFORCE_HTTPS" { $value = "false" }
    "ORBI_TLS_ENABLED" { $value = "false" }
    "ORBI_PAY_GATEWAY_BASE_URL" { $value = "https://sandbox-pay.orbifinancial.com" }
    "ORBI_PAY_GATEWAY_INTERNAL_BASE_URL" { $value = "http://pay-gateway-sandbox:3101" }
    "PAYMENT_GATEWAY_PUBLIC_BASE_URL" { $value = "https://sandbox-pay.orbifinancial.com" }
    "PAYMENT_GATEWAY_PROVIDER_MODE" { $value = "sandbox" }
    "PAYMENT_GATEWAY_WORKER_ID" { $value = "orbi-payment-gateway-sandbox" }
    "WORKER_SIGNING_SECRET" { $value = $sandboxGatewayEnv["WORKER_SIGNING_SECRET"] }
    "WORKER_SECRET" { $value = New-OrbiSecret 96 }
    "JWT_SECRET" { $value = New-OrbiSecret 96 }
    "SESSION_SECRET" { $value = New-OrbiSecret 96 }
    "KMS_MASTER_KEY" { $value = New-OrbiSecret 96 }
    "KMS_MASTER_SALT" { $value = New-OrbiSecret 64 }
    "ORBI_BOOTSTRAP_ADMIN_SECRET" { $value = New-OrbiSecret 64 }
    "ORBI_MONITOR_API_KEY" { $value = New-OrbiSecret 64 }
    "ORBI_ENABLE_SANDBOX_ROUTES" { $value = "true" }
    "ORBI_ENABLE_GATEWAY_BACKGROUND_JOBS" { $value = "false" }
    "ORBI_ENABLE_INTERNAL_BACKGROUND_JOBS" { $value = "false" }
    "ORBI_API_GATEWAY_ENABLED" { $value = "true" }
    "ORBI_API_GATEWAY_FAIL_CLOSED" { $value = "true" }
  }
  $envArgs.Add("-e")
  $envArgs.Add("$key=$value")
}

docker create `
  --name orbi-core-sandbox `
  --restart unless-stopped `
  --network orbi-private `
  --network-alias core-sandbox `
  @envArgs `
  -p 127.0.0.1:3001:3000 `
  $CoreImage | Out-Null

docker network connect --alias core-sandbox orbi-edge orbi-core-sandbox
docker start orbi-core-sandbox | Out-Null

Write-Output "Sandbox Core started on 127.0.0.1:3001 with isolated database '$SandboxDatabase'."
