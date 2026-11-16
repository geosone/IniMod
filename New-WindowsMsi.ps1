#Requires -Version 7.4
<#
.SYNOPSIS
Packages a checksum-verified native Windows binary as an MSI using Linux wixl.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BinaryDirectory,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [Parameter(Mandatory)][string]$ExpectedSHA256,
    [ValidateSet('x86', 'x64')][string]$Architecture = 'x64'
)
& (Join-Path $PSScriptRoot 'powershell/linux/all/New-WindowsMsi.ps1') @PSBoundParameters
