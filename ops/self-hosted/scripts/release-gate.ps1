param(
  [string]$GatewayRepoPath = "D:\FYNIX\ORBI\ORBI CORE\ORBI PAY GATEWAY",
  [string]$CoreImage = "self-hosted-core",
  [string]$GatewayBaseUrl = "http://127.0.0.1:3101",
  [string]$CoreHealthUrl = "http://127.0.0.1:3001/health",
  [switch]$InstallDependencies,
  [switch]$SkipBuild,
  [switch]$SkipSandboxGate,
  [switch]$SkipNegativeTests
)

$ErrorActionPreference = "Stop"

function Assert-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command '$Name' was not found in PATH."
  }
}

function Invoke-OrbiCommand([string]$Label, [string]$File, [string[]]$Arguments = @()) {
  Write-Output "==> $Label"
  & $File @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$Label failed with exit code $LASTEXITCODE."
  }
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
Set-Location $root

Assert-Command "npm"
Assert-Command "docker"
Assert-Command "node"

if ($InstallDependencies) {
  Invoke-OrbiCommand "Installing Core dependencies" "npm" @("ci")
}

if (-not $SkipBuild) {
  Invoke-OrbiCommand "Building Core TypeScript" "npm" @("run", "build")
  Invoke-OrbiCommand "Building Core Docker image $CoreImage" "docker" @("build", "-t", $CoreImage, ".")
}

if (-not $SkipSandboxGate) {
  $smokeArgs = @(
    "-GatewayRepoPath", $GatewayRepoPath,
    "-GatewayBaseUrl", $GatewayBaseUrl,
    "-CoreHealthUrl", $CoreHealthUrl,
    "-EnsureContainers",
    "-SeedFixtures",
    "-RotateSecrets"
  )
  if ($SkipNegativeTests) {
    $smokeArgs += "-SkipNegativeTests"
  }

  $powershellArgs = @(
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $PSScriptRoot "test-sandbox-pay-gateway.ps1")
  ) + $smokeArgs

  Invoke-OrbiCommand "Running ORBI Pay Gateway sandbox smoke gate" "powershell" $powershellArgs
}

Write-Output "CORE_RELEASE_GATE_PASS"
