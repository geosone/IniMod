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

# Read the executable's file version from its VS_FIXEDFILEINFO record, which
# starts with the signature 0xFEEF04BD (Microsoft VS_FIXEDFILEINFO): offset 8
# holds dwFileVersionMS (major << 16 | minor), offset 12 dwFileVersionLS
# (revision << 16 | build), both little-endian UInt32. wixl leaves File.Version
# empty; Windows Installer then treats the new file as unversioned, keeps an
# installed versioned inimod.exe and skips its component, including the PATH
# entry, during a major upgrade.
$signature = [byte[]](0xBD, 0x04, 0xEF, 0xFE)
$offset = -1
for ($i = 0; $i -le $bytes.Length - 16; $i++) {
    if ($bytes[$i] -eq $signature[0] -and $bytes[$i + 1] -eq $signature[1] -and
        $bytes[$i + 2] -eq $signature[2] -and $bytes[$i + 3] -eq $signature[3]) {
        $offset = $i
        break
    }
}
if ($offset -lt 0) {
    throw 'The executable has no version resource.'
}
$versionMS = [BitConverter]::ToUInt32($bytes, $offset + 8)
$versionLS = [BitConverter]::ToUInt32($bytes, $offset + 12)
$fileVersion = '{0}.{1}.{2}.{3}' -f ($versionMS -shr 16), ($versionMS -band 0xffff), ($versionLS -shr 16), ($versionLS -band 0xffff)
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

# The program, MSI and archives share one release version.
$productVersion = $document.SelectSingleNode('//w:Product', $namespace).GetAttribute('Version')
if (!$fileVersion.StartsWith($productVersion + '.')) {
    throw "Executable version $fileVersion does not match MSI version $productVersion."
}
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
    if ($files[$i] -eq 'inimod.exe') {
        $file.SetAttribute('DefaultVersion', $fileVersion)
    }
    $null = $component.AppendChild($file)
    $null = $directory.AppendChild($component)
    $reference = $document.CreateElement('ComponentRef', $document.DocumentElement.NamespaceURI)
    $reference.SetAttribute('Id', "Payload$i")
    $null = $feature.AppendChild($reference)
}
$wxs = Join-Path $output 'package.wxs'
$document.Save($wxs)
$msi = Join-Path $output "inimod-1.0.3-windows-$Architecture.msi"
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
