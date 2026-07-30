param(
  [ValidateSet('live', 'sandbox')]
  [string]$Environment = 'sandbox',
  [string]$SecretsRoot = 'D:\FYNIX\ORBI\SECREATES',
  [string[]]$CoreDnsNames = @('core', 'core-sandbox', 'core.internal.orbifinancial.com', 'api.orbifinancial.com', 'localhost'),
  [string[]]$GatewayDnsNames = @('pay-gateway', 'pay.orbifinancial.com', 'sandbox-pay.orbifinancial.com', 'localhost'),
  [int]$Days = 825,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Require-OpenSsl {
  $openssl = Get-Command openssl -ErrorAction SilentlyContinue
  if (-not $openssl) {
    throw 'OpenSSL is required. Install OpenSSL and ensure openssl.exe is available in PATH.'
  }
  return $openssl.Source
}

function New-SanConfig {
  param(
    [string]$Path,
    [string[]]$DnsNames
  )

  $lines = @(
    'basicConstraints=CA:FALSE',
    'keyUsage=digitalSignature,keyEncipherment',
    'extendedKeyUsage=serverAuth,clientAuth',
    'subjectAltName=@alt_names',
    '',
    '[alt_names]'
  )

  $index = 1
  foreach ($dns in $DnsNames) {
    $trimmed = $dns.Trim()
    if (-not $trimmed) { continue }
    $lines += "DNS.$index=$trimmed"
    $index += 1
  }

  Set-Content -LiteralPath $Path -Value ($lines -join [Environment]::NewLine) -Encoding ascii
}

function Invoke-OpenSsl {
  param([string[]]$Arguments)

  & openssl @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "OpenSSL failed: openssl $($Arguments -join ' ')"
  }
}

$opensslPath = Require-OpenSsl
$suffix = if ($Environment -eq 'live') { '' } else { '_SANDBOX' }
$coreDir = Join-Path $SecretsRoot "ORBI_CORE_TLS$suffix"
$gatewayDir = Join-Path $SecretsRoot "ORBI_MTLS$suffix"
$workDir = Join-Path $SecretsRoot "ORBI_MTLS_WORK$suffix"

New-Item -ItemType Directory -Force -Path $coreDir, $gatewayDir, $workDir | Out-Null

$caKey = Join-Path $workDir 'orbi-internal-ca.key'
$caCert = Join-Path $workDir 'orbi-internal-ca.crt'
$coreKey = Join-Path $coreDir 'privkey.pem'
$coreCsr = Join-Path $workDir 'core-server.csr'
$coreCert = Join-Path $coreDir 'fullchain.pem'
$coreExt = Join-Path $workDir 'core-server.ext'
$gatewayKey = Join-Path $gatewayDir 'pay-gateway-client.key'
$gatewayCsr = Join-Path $workDir 'pay-gateway-client.csr'
$gatewayCert = Join-Path $gatewayDir 'pay-gateway-client.crt'
$gatewayExt = Join-Path $workDir 'pay-gateway-client.ext'

if (Test-Path -LiteralPath $caKey) {
  if (-not $Force) {
    throw "CA key already exists at $caKey. Refusing to overwrite certificate authority material. Use -Force to archive and rotate this environment bundle."
  }

  $stamp = Get-Date -Format 'yyyyMMddHHmmss'
  foreach ($dir in @($coreDir, $gatewayDir, $workDir)) {
    if (Test-Path -LiteralPath $dir) {
      $archive = "$dir.archive.$stamp"
      Move-Item -LiteralPath $dir -Destination $archive
      Write-Host "Archived existing bundle: $archive"
    }
  }

  New-Item -ItemType Directory -Force -Path $coreDir, $gatewayDir, $workDir | Out-Null
}

Write-Host "Using OpenSSL: $opensslPath"
Write-Host "Generating $Environment internal CA and service certificates..."

Invoke-OpenSsl @('genrsa', '-out', $caKey, '4096')
Invoke-OpenSsl @('req', '-x509', '-new', '-nodes', '-key', $caKey, '-sha256', '-days', "$Days", '-out', $caCert, '-subj', "/CN=ORBI Internal $Environment CA")

Invoke-OpenSsl @('genrsa', '-out', $coreKey, '4096')
Invoke-OpenSsl @('req', '-new', '-key', $coreKey, '-out', $coreCsr, '-subj', "/CN=orbi-core-$Environment")
New-SanConfig -Path $coreExt -DnsNames $CoreDnsNames
Invoke-OpenSsl @('x509', '-req', '-in', $coreCsr, '-CA', $caCert, '-CAkey', $caKey, '-CAcreateserial', '-out', $coreCert, '-days', "$Days", '-sha256', '-extfile', $coreExt)

Invoke-OpenSsl @('genrsa', '-out', $gatewayKey, '4096')
Invoke-OpenSsl @('req', '-new', '-key', $gatewayKey, '-out', $gatewayCsr, '-subj', "/CN=orbi-pay-gateway-$Environment")
New-SanConfig -Path $gatewayExt -DnsNames $GatewayDnsNames
Invoke-OpenSsl @('x509', '-req', '-in', $gatewayCsr, '-CA', $caCert, '-CAkey', $caKey, '-CAcreateserial', '-out', $gatewayCert, '-days', "$Days", '-sha256', '-extfile', $gatewayExt)

Copy-Item -LiteralPath $caCert -Destination (Join-Path $coreDir 'orbi-internal-ca.crt') -Force
Copy-Item -LiteralPath $caCert -Destination (Join-Path $gatewayDir 'orbi-internal-ca.crt') -Force

Write-Host "Created Core TLS files: $coreDir"
Write-Host "Created Gateway mTLS files: $gatewayDir"
Write-Host "CA private key is stored in: $caKey"
Write-Host 'Keep CA and private keys outside Git. Rotate by generating a new bundle and deploying both sides together.'
