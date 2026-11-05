#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BinaryDirectory,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedSHA256,
    [ValidateSet('x86', 'x64')][string]$Architecture = 'x64'
)
$ErrorActionPreference = 'Stop'
if (!$IsLinux) {
    throw 'This packaging recipe requires Linux wixl.'
}
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$exe = Join-Path $BinaryDirectory 'inimod.exe'
if ((Get-FileHash $exe).Hash -ine $ExpectedSHA256) {
    throw 'Native executable checksum mismatch.'
}
$bytes = [IO.File]::ReadAllBytes($exe)
$header = [BitConverter]::ToInt32($bytes, 0x3c)
$machine = [BitConverter]::ToUInt16($bytes, $header + 4)
if (($Architecture -eq 'x64' -and $machine -ne 0x8664) -or ($Architecture -eq 'x86' -and $machine -ne 0x14c)) {
    throw 'PE machine type differs from the MSI target.'
}
if (Test-Path $OutputDirectory) {
    throw 'Choose a fresh output directory.'
}
$output = [IO.Path]::GetFullPath($OutputDirectory)
$payload = Join-Path $output 'payload'
$null = New-Item -ItemType Directory $payload -Force
# Explicit payload allowlist: compiler intermediates must not enter the MSI.
$files = @('inimod.exe', 'README.md', 'COPYRIGHT.txt', 'JPLib-README.md')
$files += @(Get-ChildItem $BinaryDirectory -File -Filter 'COPYING*' | Select-Object -ExpandProperty Name)
if ($files.Count -eq 4) {
    throw 'Missing compiler/runtime license notices.'
}
foreach ($name in $files) {
    Copy-Item (Join-Path $BinaryDirectory $name) $payload
}
$template = Join-Path $root "packaging/windows/$Architecture/inimod.wxs"
$document = [xml][IO.File]::ReadAllText($template)
$namespace = [Xml.XmlNamespaceManager]::new($document.NameTable)
$namespace.AddNamespace('w', $document.DocumentElement.NamespaceURI)
$directory = $document.SelectSingleNode('//w:Directory[@Id="INSTALLFOLDER"]', $namespace)
$feature = $document.SelectSingleNode('//w:Feature', $namespace)
for ($i = 0; $i -lt $files.Count; $i++) {
    $component = $document.CreateElement('Component', $document.DocumentElement.NamespaceURI)
    $component.SetAttribute('Id', "Payload$i")
    # Major upgrades retain the stable upgrade code and file component identity.
    $component.SetAttribute('Guid', '*')
    $component.SetAttribute('Win64', $(if ($Architecture -eq 'x64') {
                'yes'
            } else {
                'no'
            }))
    $file = $document.CreateElement('File', $document.DocumentElement.NamespaceURI)
    $file.SetAttribute('Id', "File$i")
    $file.SetAttribute('Source', (Join-Path $payload $files[$i]))
    $file.SetAttribute('KeyPath', 'yes')
    $null = $component.AppendChild($file)
    $null = $directory.AppendChild($component)
    $reference = $document.CreateElement('ComponentRef', $document.DocumentElement.NamespaceURI)
    $reference.SetAttribute('Id', "Payload$i")
    $null = $feature.AppendChild($reference)
}
$wxs = Join-Path $output 'package.wxs'
$document.Save($wxs)
$msi = Join-Path $output "inimod-1.0.2-windows-$Architecture.msi"
& wixl -a $Architecture -o $msi $wxs
if ($LASTEXITCODE) {
    throw 'MSI packaging failed.'
}
& (Join-Path $root 'packaging/finalize_msi_path.ps1') -Package $msi -Component Payload0
$hash = (Get-FileHash $msi).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $output 'SHA256SUMS'), "$hash  $([IO.Path]::GetFileName($msi))`n")
[pscustomobject]@{
    Package      = $msi
    Architecture = $Architecture
    SHA256       = $hash
}
