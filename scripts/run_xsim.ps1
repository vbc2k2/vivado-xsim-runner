<# 
SPDX-License-Identifier: MIT

Run a Verilog/SystemVerilog source file with Xilinx Vivado XSIM.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,

    [string]$Top,

    [string]$WorkspaceRoot,

    [switch]$Gui
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-RequiredTool {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Could not find '$Name' on PATH. Start VS Code from a shell where Vivado is set up, or add Vivado's bin directory to PATH."
    }

    return $command.Source
}

function Get-DirectiveValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $match = [regex]::Match($Content, "(?im)xsim-$Name\s*:\s*([A-Za-z0-9_.$-]+)")
    if ($match.Success) {
        return $match.Groups[1].Value
    }

    return $null
}

function Get-TopModule {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $modules = [regex]::Matches($Content, "(?im)^\s*module\s+([A-Za-z_][A-Za-z0-9_$]*)\b")
    if ($modules.Count -gt 0) {
        return $modules[$modules.Count - 1].Groups[1].Value
    }

    return $null
}

function Test-UvmUsage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PrimaryContent,

        [string]$FileListPath
    )

    $directive = Get-DirectiveValue -Content $PrimaryContent -Name "uvm"
    if ($directive) {
        return $directive -match "^(1|on|true|yes)$"
    }

    if ($PrimaryContent -match "(?im)uvm_pkg|`uvm_|run_test\s*\(") {
        return $true
    }

    if ($FileListPath -and (Test-Path $FileListPath)) {
        $fileListContent = Get-Content -Raw $FileListPath
        if ($fileListContent -match "(?im)uvm") {
            return $true
        }
    }

    return $false
}

function Get-UvmSupport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VivadoRoot
    )

    $includeDir = Join-Path $VivadoRoot "data\system_verilog\uvm_1.2"
    $packageFile = Join-Path $includeDir "xlnx_uvm_package.sv"

    if (-not (Test-Path $includeDir) -or -not (Test-Path $packageFile)) {
        throw "Vivado UVM support files were not found under '$includeDir'."
    }

    return @{
        IncludeDir = $includeDir
        PackageFile = $packageFile
        Defines = @("UVM_NO_DPI")
    }
}

function Get-PathHash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $md5 = [System.Security.Cryptography.MD5]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value.ToLowerInvariant())
        $hashBytes = $md5.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hashBytes)).Replace("-", "").Substring(0, 8).ToLowerInvariant()
    }
    finally {
        $md5.Dispose()
    }
}

$resolvedFile = (Resolve-Path $FilePath).Path
$sourceDir = Split-Path -Parent $resolvedFile
$fileName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedFile)
$fileListPath = Join-Path $sourceDir "xsim.f"
$batchTclPath = Join-Path $sourceDir "xsim.tcl"

$buildRoot = $sourceDir
if ($WorkspaceRoot -and (Test-Path $WorkspaceRoot)) {
    $buildRoot = (Resolve-Path $WorkspaceRoot).Path
}

$buildId = "{0}_{1}" -f $fileName, (Get-PathHash -Value $resolvedFile)
$buildDir = Join-Path $buildRoot (Join-Path ".xsim" $buildId)

$xvlogTool = Resolve-RequiredTool -Name "xvlog"
[void](Resolve-RequiredTool -Name "xelab")
[void](Resolve-RequiredTool -Name "xsim")

$vivadoBinDir = Split-Path -Parent $xvlogTool
$vivadoRoot = Split-Path -Parent $vivadoBinDir

$primaryContent = Get-Content -Raw $resolvedFile
$useUvm = Test-UvmUsage -PrimaryContent $primaryContent -FileListPath $fileListPath

if (-not $Top) {
    $Top = Get-DirectiveValue -Content $primaryContent -Name "top"
}

if (-not $Top) {
    $Top = Get-TopModule -Content $primaryContent
}

if (-not $Top) {
    $Top = "tb"
}

if (Test-Path $buildDir) {
    Remove-Item -Recurse -Force $buildDir
}

[void](New-Item -ItemType Directory -Path $buildDir -Force)

$xvlogArgs = @("--sv", "--include", $sourceDir)
$compileMode = "current file"

if ($useUvm) {
    $uvm = Get-UvmSupport -VivadoRoot $vivadoRoot
    $xvlogArgs += @("--include", $uvm.IncludeDir)
    foreach ($define in $uvm.Defines) {
        $xvlogArgs += @("-d", $define)
    }
    $xvlogArgs += $uvm.PackageFile
}

if (Test-Path $fileListPath) {
    $compileMode = "xsim.f"
    $xvlogArgs += @("-f", $fileListPath)
}
else {
    $xvlogArgs += $resolvedFile
}

$xelabArgs = @($Top, "-debug", "typical", "--relax")

$xsimArgs = @($Top)
if ($Gui) {
    $xsimArgs += "-gui"
}
elseif (Test-Path $batchTclPath) {
    $xsimArgs += @("-tclbatch", $batchTclPath)
}
else {
    $xsimArgs += "-runall"
}

Write-Host "xsim target : $resolvedFile"
Write-Host "top module  : $Top"
Write-Host "compile mode: $compileMode"
Write-Host "uvm support : $useUvm"
Write-Host "build dir   : $buildDir"

Push-Location $buildDir
try {
    & xvlog @xvlogArgs
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    & xelab @xelabArgs
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    & xsim @xsimArgs
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
