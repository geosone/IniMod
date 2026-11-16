#Requires -Version 7.4
# Native installation test for an explicitly selected disposable Windows VM.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PackagePath,
    [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedSHA256,
    [Parameter(Mandatory)][string]$TestDirectory,
    [Parameter(Mandatory)][ValidateSet('x86', 'x64')][string]$Architecture
)
$ErrorActionPreference = 'Stop'
if (!$IsWindows -or (Get-FileHash $PackagePath).Hash -ine $ExpectedSHA256) {
    throw 'A Windows test VM and a matching MSI checksum are required.'
}
. (Join-Path $PSScriptRoot 'packaging/test_windows_path.ps1')
$beforePath = Get-TestMachinePath
$programs = if ($Architecture -eq 'x64') {
    $env:ProgramW6432
} elseif ($env:ProgramW6432) {
    ${env:ProgramFiles(x86)}
} else {
    $env:ProgramFiles
}
if (!$programs) {
    throw 'Unsupported package architecture.'
}
$installed = Join-Path $programs 'IniMod'
if ((Test-Path $installed) -or (Test-Path $TestDirectory)) {
    throw 'Refusing an existing installation or test directory.'
}
$null = New-Item -ItemType Directory $TestDirectory
$msi = [IO.Path]::GetFullPath($PackagePath)
function Invoke-Msi(
    [string]$Mode,
    [string]$LogName
) {
    $arguments = @($Mode, ('"' + $msi + '"'), '/qn', '/norestart', '/L*v', ('"' + (Join-Path $TestDirectory $LogName) + '"'))
    $process = Start-Process msiexec.exe -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Windows Installer failed ($($process.ExitCode)); inspect $LogName."
    }
}
$active = $false
try {
    Invoke-Msi '/i' 'install.log'
    $active = $true
    $exe = Join-Path $installed 'inimod.exe'
    Assert-TestToolPath -Directory $installed -Before $beforePath
    Assert-TestToolDiscovery -Executable $exe -WorkingDirectory $TestDirectory
    $hash = (Get-FileHash $exe).Hash
    Remove-Item $exe
    Invoke-Msi '/fa' 'repair.log'
    if ((Get-FileHash $exe).Hash -ne $hash) {
        throw 'Repair failed to restore the executable.'
    }
    Assert-TestToolPath -Directory $installed -Before $beforePath
    $config = Join-Path $TestDirectory 'settings.ini'
    [IO.File]::WriteAllText($config, "; preserved comment`n[General]`nKeep=yes`n")
    & $exe w $config -s General -k Name -v 'Native test' --silent
    if ($LASTEXITCODE) {
        throw 'Installed CLI write failed.'
    }
    $value = & $exe r $config -s General -k Name --silent
    if ($LASTEXITCODE -or $value.Trim() -ne 'Native test') {
        throw 'Installed CLI read failed.'
    }
    $original = [IO.File]::ReadAllText($config)
    if (!$original.Contains('preserved comment') -or !$original.Contains('Keep=yes')) {
        throw 'CLI damaged unrelated settings.'
    }
    Invoke-Msi '/x' 'uninstall.log'
    $active = $false
    Assert-TestToolPath -Directory $installed -Before $beforePath -Removed
    if ((Test-Path $exe) -or [IO.File]::ReadAllText($config) -ne $original) {
        throw 'Uninstall left a runtime file or changed external configuration.'
    }
    "PASS $Architecture MSI install, repair, real INI write/read, preserved unrelated settings and uninstall."
} finally {
    if ($active) {
        Invoke-Msi '/x' 'cleanup-uninstall.log'
    }
}
