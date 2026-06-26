param(
    [switch]$AllowWrites
)

$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
Set-Location $root

Get-Content '.env' | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
    $key, $value = $_ -split '=', 2
    $key = $key.Trim()
    $value = $value.Trim().Trim('"').Trim("'")
    if ($key) {
        [Environment]::SetEnvironmentVariable($key, $value, 'Process')
    }
}

$database = if ($env:ORBI_POSTGRES_DB) { $env:ORBI_POSTGRES_DB } else { 'orbi' }
$user = if ($env:ORBI_POSTGRES_USER) { $env:ORBI_POSTGRES_USER } else { 'orbi' }
if (-not $env:ORBI_POSTGRES_PASSWORD) { throw 'ORBI_POSTGRES_PASSWORD is missing.' }

$env:ORBI_RUN_DB_INTEGRATION = 'true'
$env:ORBI_DB_INTEGRATION_PROVIDER = 'local'
$env:ORBI_DATA_PROVIDER = 'local'
$env:ORBI_DB_INTEGRATION_DATABASE_URL = "postgresql://${user}:$($env:ORBI_POSTGRES_PASSWORD)@127.0.0.1:5432/${database}"
$env:DATABASE_URL = $env:ORBI_DB_INTEGRATION_DATABASE_URL
$env:VALKEY_URL = "redis://:$($env:ORBI_VALKEY_PASSWORD)@127.0.0.1:6379/0"

if (-not $AllowWrites) {
    npm run test:db:financial
    exit $LASTEXITCODE
}

docker exec -e "PGPASSWORD=$($env:ORBI_POSTGRES_PASSWORD)" orbi-postgres `
    psql --set=ON_ERROR_STOP=1 --username $user --dbname $database `
    --file /demo/20260622_local_integration_fixtures.sql
if ($LASTEXITCODE -ne 0) {
    throw 'Failed to apply local financial integration fixtures.'
}

$env:ORBI_DB_INTEGRATION_ALLOW_WRITES = 'true'
$env:ORBI_DB_TEST_USER_ID = '11111111-1111-4111-8111-111111111111'
$env:ORBI_DB_TEST_SOURCE_WALLET_ID = '22222222-2222-4222-8222-222222222201'
$env:ORBI_DB_TEST_TARGET_WALLET_ID = '22222222-2222-4222-8222-222222222202'
$env:ORBI_DB_TEST_LOW_BALANCE_WALLET_ID = '22222222-2222-4222-8222-222222222203'
$env:ORBI_DB_TEST_LOCKED_WALLET_ID = '22222222-2222-4222-8222-222222222204'
$env:ORBI_DB_TEST_DRIFT_WALLET_ID = '22222222-2222-4222-8222-222222222205'
$env:ORBI_DB_TEST_INTERNAL_TRANSFER_VAULT_ID = '33333333-3333-4333-8333-333333333301'
$env:ORBI_DB_TEST_OPERATING_VAULT_ID = '33333333-3333-4333-8333-333333333302'
$env:ORBI_DB_TEST_ESCROW_VAULT_ID = '33333333-3333-4333-8333-333333333303'
$env:ORBI_DB_TEST_REVIEW_ACTOR_ID = '11111111-1111-4111-8111-111111111111'
$env:ORBI_DB_TEST_WEBHOOK_PARTNER_ID = '44444444-4444-4444-8444-444444444401'
$env:ORBI_DB_TEST_WITHDRAWAL_PROVIDER_ID = '44444444-4444-4444-8444-444444444402'
$env:ORBI_DB_TEST_BUDGET_CATEGORY_ID = '55555555-5555-4555-8555-555555555501'
$env:ORBI_DB_TEST_BUDGET_TRIGGER_AMOUNT = '10'

npm run test:db:financial:write
exit $LASTEXITCODE
