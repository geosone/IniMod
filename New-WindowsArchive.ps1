#Requires -Version 7.4
# Create the portable download, with exactly the executable and one README.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BinaryDirectory,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedSHA256,
    [ValidateSet('x86', 'x64')][string]$Architecture = 'x64'
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'powershell/all/New-WindowsArchive.ps1') @PSBoundParameters
