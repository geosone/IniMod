#Requires -Version 7.4
# Build a native Windows executable using an explicit Lazarus/FPC installation.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$LazarusDirectory,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateSet('x86', 'x64')][string]$Architecture = 'x64'
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'powershell/windows/all/Build-Windows.ps1') @PSBoundParameters
