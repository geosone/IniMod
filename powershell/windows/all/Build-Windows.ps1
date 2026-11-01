#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$LazarusDirectory,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateSet('x86', 'x64')][string]$Architecture = 'x64'
)
$ErrorActionPreference = 'Stop'
if (!$IsWindows) {
    throw 'Use a native Windows Lazarus/FPC installation.'
}
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$target = if ($Architecture -eq 'x64') {
    'x86_64-win64'
} else {
    'i386-win32'
}
$compiler = Join-Path $LazarusDirectory "fpc/3.2.2/bin/$target/fpc.exe"
if (!(Test-Path $compiler)) {
    throw "Missing native compiler for $target."
}
if (Test-Path $OutputDirectory) {
    throw 'Choose a fresh output directory.'
}
$output = [IO.Path]::GetFullPath($OutputDirectory)
$units = Join-Path $output 'units'
$null = New-Item -ItemType Directory $units -Force
$exe = Join-Path $output 'inimod.exe'
$arguments = @(
    '-MObjFPC', '-Scghi', '-O2', '-g-', '-dINI_NO_GRAPHICS',
    ('-Fi' + (Join-Path $root 'third_party/JPLib')),
    ('-Fu' + (Join-Path $root 'third_party/JPLib/Base')),
    ('-Fu' + (Join-Path $root 'third_party/JPLib/Logging')),
    ('-Fu' + (Join-Path $LazarusDirectory 'components/lazutils')),
    ('-FU' + $units), ('-o' + $exe), (Join-Path $root 'src/IniMod.lpr')
)
& $compiler @arguments
if ($LASTEXITCODE) {
    throw 'Free Pascal compilation failed.'
}
# Verify PE machine type so an incorrectly selected compiler cannot be mislabeled.
$bytes = [IO.File]::ReadAllBytes($exe)
$header = [BitConverter]::ToInt32($bytes, 0x3c)
$machine = [BitConverter]::ToUInt16($bytes, $header + 4)
$expectedMachine = if ($Architecture -eq 'x64') {
    0x8664
} else {
    0x14c
}
if ($machine -ne $expectedMachine) {
    throw 'Executable architecture does not match the package target.'
}
$noticeFiles = @(Get-ChildItem -LiteralPath $LazarusDirectory -File -Filter 'COPYING*')
if (!$noticeFiles.Count) {
    throw 'Compiler distribution license notices were not found.'
}
foreach ($notice in $noticeFiles) {
    Copy-Item $notice.FullName $output
}
Copy-Item (Join-Path $root 'Readme.md') (Join-Path $output 'README.md')
Copy-Item (Join-Path $root 'debian/copyright') (Join-Path $output 'COPYRIGHT.txt')
Copy-Item (Join-Path $root 'third_party/JPLib/Readme.md') (Join-Path $output 'JPLib-README.md')
$hash = (Get-FileHash $exe).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $output 'SHA256SUMS'), "$hash  inimod.exe`n")
[pscustomobject]@{
    Executable   = $exe
    Architecture = $Architecture
    SHA256       = $hash
}
