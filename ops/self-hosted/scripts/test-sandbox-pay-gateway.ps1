param(
  [string]$GatewayRepoPath = "D:\FYNIX\ORBI\ORBI CORE\ORBI PAY GATEWAY",
  [string]$GatewayBaseUrl = "http://127.0.0.1:3101",
  [string]$CoreHealthUrl = "http://127.0.0.1:3001/health",
  [string]$FixturePath = ".sandbox\orbi-sandbox-fixtures.json",
  [decimal]$Amount = 1500,
  [switch]$EnsureContainers,
  [switch]$SeedFixtures,
  [switch]$RotateSecrets,
  [switch]$SkipLogScan
)

$ErrorActionPreference = "Stop"

function Resolve-RepoPath([string]$Path) {
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return $Path
  }
  return (Join-Path $PWD $Path)
}

function Assert-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command '$Name' was not found in PATH."
  }
}

function Invoke-JsonHealth([string]$Name, [string]$Url) {
  try {
    Invoke-RestMethod -Method GET -Uri $Url -TimeoutSec 12 | Out-Null
    Write-Output "$Name health OK"
  } catch {
    throw "$Name health check failed at $Url. $($_.Exception.Message)"
  }
}

function Get-ValkeyPassword {
  $cmd = docker inspect orbi-valkey --format '{{json .Config.Cmd}}' | ConvertFrom-Json
  for ($index = 0; $index -lt $cmd.Count; $index++) {
    if ($cmd[$index] -eq "--requirepass" -and ($index + 1) -lt $cmd.Count) {
      return $cmd[$index + 1]
    }
  }
  throw "Could not read Valkey password from orbi-valkey container command."
}

function Get-OtcFromValkey([string]$RequestId) {
  $redisPassword = Get-ValkeyPassword
  try {
    $raw = docker exec -e REDISCLI_AUTH=$redisPassword orbi-valkey redis-cli GET "otp:$RequestId"
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($raw)) {
      throw "OTC request '$RequestId' was not found in Valkey."
    }
    $payload = $raw | ConvertFrom-Json
    if (-not $payload.code) {
      throw "OTC payload for '$RequestId' did not include a code."
    }
    return [string]$payload.code
  } finally {
    Remove-Variable redisPassword -ErrorAction SilentlyContinue
  }
}

function Invoke-NoRedirectForm([string]$Uri, [hashtable]$Body) {
  $headersFile = [System.IO.Path]::GetTempFileName()
  $bodyFile = [System.IO.Path]::GetTempFileName()
  try {
    $curlArgs = @(
      "-sS",
      "-D", $headersFile,
      "-o", $bodyFile,
      "-w", "%{http_code}",
      "-X", "POST",
      $Uri,
      "-H", "Content-Type: application/x-www-form-urlencoded",
      "--max-redirs", "0"
    )
    foreach ($key in $Body.Keys) {
      $curlArgs += "--data-urlencode"
      $curlArgs += "$key=$($Body[$key])"
    }
    $statusCodeText = & curl.exe @curlArgs
    if ($LASTEXITCODE -ne 0) {
      throw "curl challenge request failed."
    }
    $headers = @{}
    foreach ($line in Get-Content -LiteralPath $headersFile) {
      if ($line -match "^([^:]+):\s*(.*)$") {
        $headers[$Matches[1]] = $Matches[2].Trim()
      }
    }
    [pscustomobject]@{
      StatusCode = [int]$statusCodeText
      Headers = $headers
      Body = Get-Content -LiteralPath $bodyFile -Raw -ErrorAction SilentlyContinue
    }
  } finally {
    Remove-Item -LiteralPath $headersFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $bodyFile -Force -ErrorAction SilentlyContinue
  }
}

function Get-HeaderValue($Headers, [string]$Name) {
  if ($Headers.ContainsKey($Name)) {
    $value = $Headers[$Name]
    if ($value -is [array]) {
      return [string]$value[0]
    }
    return [string]$value
  }
  return $null
}

function Invoke-NodeJson([string]$Script, [string]$WorkingDirectory) {
  Push-Location $WorkingDirectory
  try {
    $output = $Script | node --input-type=module
    if ($LASTEXITCODE -ne 0) {
      throw "Node smoke step failed."
    }
    $jsonLine = ($output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Last 1)
    if (-not $jsonLine) {
      throw "Node smoke step returned no JSON output."
    }
    return $jsonLine | ConvertFrom-Json
  } finally {
    Pop-Location
  }
}

function Assert-NoBadLogs([datetime]$StartedAtUtc) {
  $sinceSeconds = [Math]::Max(30, [int]([datetime]::UtcNow - $StartedAtUtc).TotalSeconds + 15)
  $badPatterns = @(
    "core_service_payment_event_failed",
    "PAY_SERVICE_NOT_REGISTERED",
    "INVALID_WORKER_SIGNATURE",
    "MERCHANT_CONTEXT_REQUIRED",
    "PLATFORM_FEE_CONFIG_REQUIRED",
    "ORBI_CORE_CALLBACK_TIMEOUT"
  )
  $containers = @("orbi-pay-gateway-sandbox", "orbi-core-sandbox")
  foreach ($container in $containers) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
      $logs = & docker logs --since "${sinceSeconds}s" $container 2>&1 | Out-String
    } finally {
      $ErrorActionPreference = $previousErrorActionPreference
    }
    foreach ($pattern in $badPatterns) {
      if ($logs -match [regex]::Escape($pattern)) {
        throw "Sandbox log scan found '$pattern' in $container logs."
      }
    }
  }
  Write-Output "Sandbox log scan OK"
}

Assert-Command "docker"
Assert-Command "node"
Assert-Command "curl.exe"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$gatewayRepoFull = Resolve-RepoPath $GatewayRepoPath
$fixtureFull = Resolve-RepoPath $FixturePath
$sandboxDirectory = Join-Path $repoRoot ".sandbox"
$intentOutputPath = Join-Path $sandboxDirectory "last-sandbox-smoke-intent.json"
$finalOutputPath = Join-Path $sandboxDirectory "last-sandbox-smoke-final.json"

$startedAtUtc = [datetime]::UtcNow

if ($EnsureContainers) {
  & (Join-Path $PSScriptRoot "start-core-sandbox.ps1")
  & (Join-Path $PSScriptRoot "start-pay-gateway-sandbox.ps1")
  Start-Sleep -Seconds 5
}

if ($SeedFixtures) {
  $seedArgs = @{}
  if ($RotateSecrets) {
    $seedArgs["RotateSecrets"] = $true
  }
  & (Join-Path $PSScriptRoot "seed-sandbox-fixtures.ps1") @seedArgs | Out-Host
}

Invoke-JsonHealth "Core sandbox" $CoreHealthUrl
Invoke-JsonHealth "Pay Gateway sandbox" "$GatewayBaseUrl/health"

if (-not (Test-Path -LiteralPath $fixtureFull)) {
  throw "Fixture file not found at $fixtureFull. Run this script with -SeedFixtures -RotateSecrets."
}

$sdkEntry = Join-Path $gatewayRepoFull "sdk\node\dist\index.js"
if (-not (Test-Path -LiteralPath $sdkEntry)) {
  throw "Node SDK build was not found at $sdkEntry. Build the Pay Gateway Node SDK before running the smoke test."
}

New-Item -ItemType Directory -Path $sandboxDirectory -Force | Out-Null

$env:ORBI_SMOKE_FIXTURE_PATH = [string](Resolve-Path $fixtureFull)
$env:ORBI_SMOKE_INTENT_PATH = $intentOutputPath
$env:ORBI_SMOKE_GATEWAY_BASE_URL = $GatewayBaseUrl
$env:ORBI_SMOKE_AMOUNT = [string]$Amount

$createScript = @'
import { createOrbi } from './sdk/node/dist/index.js';
import { readFileSync, writeFileSync } from 'node:fs';

const fixture = JSON.parse(readFileSync(process.env.ORBI_SMOKE_FIXTURE_PATH, 'utf8').replace(/^\uFEFF/, ''));
if (!fixture.apiKey) {
  throw new Error('SANDBOX_API_KEY_MISSING: run seed-sandbox-fixtures.ps1 with -RotateSecrets');
}

const orbi = createOrbi({
  baseUrl: process.env.ORBI_SMOKE_GATEWAY_BASE_URL,
  serviceKey: fixture.apiKey,
  environment: 'Demo',
});

const reference = `SANDBOX-SMOKE-${Date.now()}`;
const amount = Number(process.env.ORBI_SMOKE_AMOUNT || 1500);
const response = await orbi.payments.checkout({
  operation: 'collection',
  paymentCategory: 'orbi',
  paymentRail: 'orbi_wallet',
  reference,
  amount,
  currency: 'TZS',
  description: 'Sandbox PaySafe smoke checkout',
  returnUrl: 'https://shop.orbifinancial.com/checkout/orbi/return',
  customer: {
    type: 'user',
    name: fixture.demoUsers?.[0]?.name || 'Daniel Zakaria Sandbox',
    phone: fixture.demoUsers?.[0]?.phone || '+255700000101',
  },
  metadata: {
    sandbox: true,
    smokeTest: true,
    merchantId: fixture.merchantId,
    serviceCode: fixture.serviceCode,
  },
}, {
  environment: 'Demo',
  idempotencyKey: `sandbox-smoke:${reference}`,
  requestId: `sandbox-smoke-${reference}`,
});

writeFileSync(process.env.ORBI_SMOKE_INTENT_PATH, JSON.stringify({ reference, response }, null, 2));

const data = response.data || {};
const challenge = data.coreResult?.challenge || {};
console.log(JSON.stringify({
  success: response.success,
  reference,
  intentId: data.id,
  status: data.status,
  challengeMode: data.challengeMode,
  otcRequestId: challenge.metadata?.otcRequestId || null,
  challengeId: challenge.challengeId || null,
  coreStatus: data.coreStatus || null,
  error: response.error || null,
  message: response.message || null,
}));
'@

$created = Invoke-NodeJson $createScript $gatewayRepoFull
if (-not $created.success) {
  throw "Checkout create failed. $($created.error) $($created.message)"
}
if (-not $created.intentId -or -not $created.otcRequestId -or -not $created.challengeId) {
  throw "Checkout did not return a hosted OTC challenge. Intent=$($created.intentId) Status=$($created.status)"
}
Write-Output "Checkout intent created: $($created.intentId) status=$($created.status)"

$otc = Get-OtcFromValkey $created.otcRequestId
$challengeUri = "$GatewayBaseUrl/v1/challenges/$($created.intentId)/respond"
$challengeResponse = Invoke-NoRedirectForm $challengeUri @{
  challengeId = $created.challengeId
  decision = "approve"
  otcCode = $otc
}

$statusCode = [int]$challengeResponse.StatusCode
$location = Get-HeaderValue $challengeResponse.Headers "Location"
if ($statusCode -lt 300 -or $statusCode -ge 400) {
  throw "Hosted challenge did not redirect after approval. HTTP $statusCode"
}
if (-not $location -or ($location -notmatch "orbi_payment_status=approved")) {
  throw "Hosted challenge redirect did not report approved status."
}
Write-Output "Hosted challenge approved and redirected"

$env:ORBI_SMOKE_INTENT_ID = [string]$created.intentId
$env:ORBI_SMOKE_FINAL_PATH = $finalOutputPath

$finalScript = @'
import { createOrbi } from './sdk/node/dist/index.js';
import { readFileSync, writeFileSync } from 'node:fs';

const fixture = JSON.parse(readFileSync(process.env.ORBI_SMOKE_FIXTURE_PATH, 'utf8').replace(/^\uFEFF/, ''));
const orbi = createOrbi({
  baseUrl: process.env.ORBI_SMOKE_GATEWAY_BASE_URL,
  serviceKey: fixture.apiKey,
  environment: 'Demo',
});

let finalResponse = null;
for (let attempt = 0; attempt < 12; attempt += 1) {
  finalResponse = await orbi.payments.getIntent(process.env.ORBI_SMOKE_INTENT_ID);
  if (finalResponse.success && ['completed', 'failed', 'cancelled'].includes(finalResponse.data.status)) {
    break;
  }
  await new Promise((resolve) => setTimeout(resolve, 1000));
}

writeFileSync(process.env.ORBI_SMOKE_FINAL_PATH, JSON.stringify(finalResponse, null, 2));
const data = finalResponse?.data || {};
console.log(JSON.stringify({
  success: Boolean(finalResponse?.success),
  status: data.status || null,
  coreStatus: data.coreStatus || null,
  coreMessage: data.coreMessage || null,
  escrowId: data.coreResult?.escrow?.id || data.coreResult?.escrowId || null,
  error: finalResponse?.error || null,
  message: finalResponse?.message || null,
}));
'@

$final = Invoke-NodeJson $finalScript $gatewayRepoFull
if (-not $final.success -or $final.status -ne "completed") {
  throw "Payment intent did not complete. status=$($final.status) coreStatus=$($final.coreStatus) error=$($final.error) message=$($final.message)"
}

if (-not $SkipLogScan) {
  Assert-NoBadLogs $startedAtUtc
}

Write-Output "SANDBOX_SMOKE_PASS"
Write-Output "reference=$($created.reference)"
Write-Output "intentId=$($created.intentId)"
Write-Output "status=$($final.status)"
Write-Output "coreStatus=$($final.coreStatus)"
Write-Output "coreMessage=$($final.coreMessage)"
