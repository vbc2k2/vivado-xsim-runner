param(
    [string]$InstallDir = (Join-Path ([Environment]::GetFolderPath("UserProfile")) ".xsim-runner")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceScript = Join-Path $repoRoot "scripts\run_xsim.ps1"

if (-not (Test-Path $sourceScript)) {
    throw "Could not find '$sourceScript'. Run this installer from the repository root."
}

[void](New-Item -ItemType Directory -Path $InstallDir -Force)

$destinationScript = Join-Path $InstallDir "run_xsim.ps1"
Copy-Item -LiteralPath $sourceScript -Destination $destinationScript -Force

Write-Host "Installed Vivado XSIM runner to:"
Write-Host "  $destinationScript"
Write-Host ""
Write-Host "VS Code tasks can reference it as:"
Write-Host '  ${userHome}\.xsim-runner\run_xsim.ps1'
Write-Host ""
Write-Host "Code Runner settings can reference it as:"
Write-Host '  $env:USERPROFILE\.xsim-runner\run_xsim.ps1'
