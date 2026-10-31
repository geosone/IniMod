#Requires -Version 7.4
# Package a previously built and tested native executable; compile in Build-Windows.ps1.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BinaryDirectory,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedSHA256,
    [ValidateSet('x86', 'x64')][string]$Architecture = 'x64'
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'powershell/linux/all/New-WindowsMsi.ps1') @PSBoundParameters
