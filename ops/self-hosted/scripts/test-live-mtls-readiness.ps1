param(
  [string]$SecretsRoot = "D:\FYNIX\ORBI\SECREATES",
  [string]$GatewayRepoPath = "D:\FYNIX\ORBI\Orbi Infrastructures\ORBI GATEWAY\Pay Gateway Backend"
)

$ErrorActionPreference = "Stop"

function Assert-File([string]$Path, [string]$Label) {
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "$Label missing: $Path"
  }
}

$coreDir = Join-Path $SecretsRoot "ORBI_CORE_TLS"
$gatewayDir = Join-Path $SecretsRoot "ORBI_MTLS"
$gatewayPatch = Join-Path $SecretsRoot "ORBI PAY GATEWAY LIVE MTLS ACTIVATION PATCH.txt"
$corePatch = Join-Path $SecretsRoot "ORBI CORE LIVE MTLS ACTIVATION PATCH.txt"

Assert-File (Join-Path $coreDir "fullchain.pem") "Core server certificate"
Assert-File (Join-Path $coreDir "privkey.pem") "Core server private key"
Assert-File (Join-Path $coreDir "orbi-internal-ca.crt") "Core CA certificate"
Assert-File (Join-Path $gatewayDir "pay-gateway-client.crt") "Gateway client certificate"
Assert-File (Join-Path $gatewayDir "pay-gateway-client.key") "Gateway client private key"
Assert-File (Join-Path $gatewayDir "orbi-internal-ca.crt") "Gateway CA certificate"
Assert-File $gatewayPatch "Gateway activation patch"
Assert-File $corePatch "Core activation patch"

Push-Location $GatewayRepoPath
try {
  $env:PAYMENT_GATEWAY_INTERNAL_MTLS_ENABLED = "true"
  $env:PAYMENT_GATEWAY_INTERNAL_MTLS_CERT_PATH = Join-Path $gatewayDir "pay-gateway-client.crt"
  $env:PAYMENT_GATEWAY_INTERNAL_MTLS_KEY_PATH = Join-Path $gatewayDir "pay-gateway-client.key"
  $env:PAYMENT_GATEWAY_INTERNAL_MTLS_CA_PATH = Join-Path $gatewayDir "orbi-internal-ca.crt"
  $env:PAYMENT_GATEWAY_INTERNAL_MTLS_REJECT_UNAUTHORIZED = "true"
  $env:ORBI_CORE_INTERNAL_BASE_URL = "https://core:3000"
  npm run mtls:readiness
  if ($LASTEXITCODE -ne 0) {
    throw "Gateway mTLS readiness failed."
  }
} finally {
  Pop-Location
}

Write-Output "Live mTLS dry-run readiness passed. Do not cut over until Core TLS volume is mounted and a maintenance window is approved."
