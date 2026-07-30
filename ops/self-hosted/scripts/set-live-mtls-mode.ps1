param(
  [ValidateSet('enable', 'rollback')]
  [string]$Mode = 'enable',
  [string]$CoreEnvFile = "D:\FYNIX\ORBI\Orbi Infrastructures\ORBI CORE\Core Backend\ORBI-Insitutional-Core-V2.0.4-Preview Stable\ops\self-hosted\.env.production",
  [string]$GatewayEnvFile = "D:\FYNIX\ORBI\SECREATES\ORBI PAY GATEWAY LIVE ENV.txt",
  [string]$GatewayRepoPath = "D:\FYNIX\ORBI\Orbi Infrastructures\ORBI GATEWAY\Pay Gateway Backend",
  [switch]$Apply,
  [switch]$RestartGateway,
  [switch]$RestartCore
)

$ErrorActionPreference = "Stop"

function Read-EnvFile([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Env file not found: $Path"
  }
  Get-Content -LiteralPath $Path
}

function Set-EnvValue([string[]]$Lines, [string]$Key, [string]$Value) {
  $pattern = "^\s*$([Regex]::Escape($Key))\s*="
  $updated = $false
  $next = foreach ($line in $Lines) {
    if ($line -match $pattern) {
      $updated = $true
      "$Key=$Value"
    } else {
      $line
    }
  }
  if (-not $updated) {
    $next += "$Key=$Value"
  }
  $next
}

function Write-EnvFile([string]$Path, [hashtable]$Values) {
  $lines = Read-EnvFile $Path
  foreach ($key in $Values.Keys) {
    $lines = Set-EnvValue $lines $key $Values[$key]
  }
  $stamp = Get-Date -Format "yyyyMMddHHmmss"
  $backup = "$Path.backup.$stamp"
  Copy-Item -LiteralPath $Path -Destination $backup
  Set-Content -LiteralPath $Path -Value $lines -Encoding utf8
  Write-Output "Updated $Path"
  Write-Output "Backup: $backup"
}

$enableCore = @{
  "ORBI_CORE_TLS_ENABLED" = "true"
  "ORBI_TLS_CERT_PATH" = "/etc/orbi/tls/fullchain.pem"
  "ORBI_TLS_KEY_PATH" = "/etc/orbi/tls/privkey.pem"
  "ORBI_TLS_CA_PATH" = "/etc/orbi/tls/orbi-internal-ca.crt"
  "ORBI_TLS_REJECT_UNAUTHORIZED" = "true"
  "ORBI_CORE_INTERNAL_MTLS_SOURCE" = "direct"
  "ORBI_INTERNAL_MTLS_SOURCE" = "direct"
  "ORBI_INTERNAL_MTLS_MODE" = "required"
  "ORBI_INTERNAL_MTLS_CA_PATH" = "/etc/orbi/tls/orbi-internal-ca.crt"
  "ORBI_ALLOW_HMAC_ONLY_INTERNAL_REQUESTS" = "false"
  "ORBI_ALLOW_PRIVATE_HTTP_INTERNAL_REQUESTS" = "false"
}

$rollbackCore = @{
  "ORBI_CORE_TLS_ENABLED" = "false"
  "ORBI_INTERNAL_MTLS_SOURCE" = "proxy"
  "ORBI_CORE_INTERNAL_MTLS_SOURCE" = "proxy"
  "ORBI_INTERNAL_MTLS_MODE" = "required"
  "ORBI_ALLOW_HMAC_ONLY_INTERNAL_REQUESTS" = "false"
  "ORBI_ALLOW_PRIVATE_HTTP_INTERNAL_REQUESTS" = "false"
}

$enableGateway = @{
  "ORBI_CORE_INTERNAL_BASE_URL" = "https://core:3000"
  "PAYMENT_GATEWAY_ALLOW_PRIVATE_HTTP_CORE" = "false"
  "PAYMENT_GATEWAY_INTERNAL_MTLS_ENABLED" = "true"
  "PAYMENT_GATEWAY_INTERNAL_MTLS_CERT_PATH" = "/opt/orbi/mtls/pay-gateway-client.crt"
  "PAYMENT_GATEWAY_INTERNAL_MTLS_KEY_PATH" = "/opt/orbi/mtls/pay-gateway-client.key"
  "PAYMENT_GATEWAY_INTERNAL_MTLS_CA_PATH" = "/opt/orbi/mtls/orbi-internal-ca.crt"
  "PAYMENT_GATEWAY_INTERNAL_MTLS_REJECT_UNAUTHORIZED" = "true"
}

$rollbackGateway = @{
  "ORBI_CORE_INTERNAL_BASE_URL" = "http://core:3000"
  "PAYMENT_GATEWAY_ALLOW_PRIVATE_HTTP_CORE" = "true"
  "PAYMENT_GATEWAY_INTERNAL_MTLS_ENABLED" = "false"
}

$coreValues = if ($Mode -eq "enable") { $enableCore } else { $rollbackCore }
$gatewayValues = if ($Mode -eq "enable") { $enableGateway } else { $rollbackGateway }

Write-Output "ORBI live mTLS mode: $Mode"
Write-Output "Core env keys to change: $($coreValues.Keys -join ', ')"
Write-Output "Gateway env keys to change: $($gatewayValues.Keys -join ', ')"

if (-not $Apply) {
  Write-Output "Dry run only. Re-run with -Apply to update env files."
  exit 0
}

Write-EnvFile $CoreEnvFile $coreValues
Write-EnvFile $GatewayEnvFile $gatewayValues

if ($Mode -eq "enable") {
  Push-Location $GatewayRepoPath
  try {
    npm run mtls:readiness
    if ($LASTEXITCODE -ne 0) {
      throw "Gateway mTLS readiness failed after env update."
    }
  } finally {
    Pop-Location
  }
}

if ($RestartCore) {
  Write-Output "RestartCore requested, but automatic Core restart is intentionally not embedded here."
  Write-Output "Use the approved Core deployment command for this host, then verify Core HTTPS health before restarting Gateway."
}

if ($RestartGateway) {
  Write-Output "RestartGateway requested, but automatic Gateway restart is intentionally not embedded here."
  Write-Output "Use the approved Pay Gateway compose command after Core HTTPS health is verified."
}
