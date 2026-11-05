#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BinaryDirectory,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedSHA256,
    [ValidateSet('x86', 'x64')][string]$Architecture = 'x64'
)
$ErrorActionPreference = 'Stop'
$exe = Join-Path $BinaryDirectory 'inimod.exe'
if ((Get-FileHash $exe).Hash -ine $ExpectedSHA256) {
    throw 'Executable checksum mismatch.'
}
$bytes = [IO.File]::ReadAllBytes($exe)
$header = [BitConverter]::ToInt32($bytes, 0x3c)
$machine = [BitConverter]::ToUInt16($bytes, $header + 4)
$expectedMachine = if ($Architecture -eq 'x64') {
    0x8664
} else {
    0x14c
}
if ($machine -ne $expectedMachine) {
    throw 'Executable architecture differs from the archive target.'
}
if (Test-Path $OutputDirectory) {
    throw 'Choose a fresh output directory.'
}
$output = [IO.Path]::GetFullPath($OutputDirectory)
$payload = Join-Path $output 'payload'
$null = New-Item -ItemType Directory $payload -Force
Copy-Item $exe $payload
# Include all applicable notices in the single README, not extra sidecar files.
$noticeFiles = @('README.md', 'COPYRIGHT.txt', 'JPLib-README.md')
$noticeFiles += @(Get-ChildItem $BinaryDirectory -File -Filter 'COPYING*' | Sort-Object Name | Select-Object -ExpandProperty Name)
if ($noticeFiles.Count -eq 3) {
    throw 'Compiler/runtime license notices are missing.'
}
$text = "IniMod 1.0.3 — portable Windows $Architecture`nExtract inimod.exe into the Mystic directory or another chosen location.`nNo installation, PATH update or service is required.`n`n"
foreach ($name in $noticeFiles) {
    $text += "`n=== $name ===`n" + [IO.File]::ReadAllText((Join-Path $BinaryDirectory $name)) + "`n"
}
[IO.File]::WriteAllText((Join-Path $payload 'README.txt'), $text)
$archive = Join-Path $output "inimod-1.0.3-windows-$Architecture.zip"
Compress-Archive -LiteralPath (Join-Path $payload 'inimod.exe'), (Join-Path $payload 'README.txt') -DestinationPath $archive
$hash = (Get-FileHash $archive).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $output 'SHA256SUMS'), "$hash  $([IO.Path]::GetFileName($archive))`n")
[pscustomobject]@{
    Archive = $archive
    SHA256  = $hash
}
