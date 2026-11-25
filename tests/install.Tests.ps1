$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('syntrachat-test-' + [guid]::NewGuid())
[void][IO.Directory]::CreateDirectory($testRoot)
$asset = 'SyntraChat-0.1.0-windows-x86_64-setup.exe'
$installerTestFixture = @{ Payload = [Text.Encoding]::UTF8.GetBytes('test-only package; never executed'); Download = $null; Checksums = '' }
$hash = [Security.Cryptography.SHA256]::Create()
$digest = ([BitConverter]::ToString($hash.ComputeHash($installerTestFixture.Payload))).Replace('-', '').ToLowerInvariant()
$hash.Dispose()
function Invoke-RestMethod { param($Uri, [switch]$UseBasicParsing) return $installerTestFixture.Checksums }
function Invoke-WebRequest { param($Uri, $OutFile, [switch]$UseBasicParsing) [IO.File]::WriteAllBytes($OutFile, $installerTestFixture.Download) }
function Start-Process { throw 'Tests must never execute a package.' }
try {
    foreach ($case in 'valid', 'tampered', 'missing', 'duplicate') {
        $installerTestFixture.Download = $installerTestFixture.Payload
        $installerTestFixture.Checksums = "$digest  $asset`n"
        if ($case -eq 'tampered') { $installerTestFixture.Download = [Text.Encoding]::UTF8.GetBytes('tampered') }
        if ($case -eq 'missing') { $installerTestFixture.Checksums = "$digest  other.exe`n" }
        if ($case -eq 'duplicate') { $installerTestFixture.Checksums += $installerTestFixture.Checksums }
        $output = Join-Path $testRoot $case
        $failed = $false
        try { & "$PSScriptRoot/../install.ps1" -DownloadDirectory $output }
        catch { $failed = $true; if ($case -eq 'valid') { throw } }
        if ($case -eq 'valid') {
            if ($failed -or -not (Test-Path (Join-Path $output $asset))) { throw 'Valid download rejected.' }
        }
        elseif (-not $failed -or (Test-Path (Join-Path $output $asset))) { throw "Unsafe $case download accepted." }
    }
    Write-Output 'PowerShell installer integrity tests passed (4 cases, no packages executed).'
}
finally {
    if ([IO.Path]::GetDirectoryName($testRoot) -eq [IO.Path]::GetTempPath().TrimEnd('\')) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
