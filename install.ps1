# Run: irm https://raw.githubusercontent.com/SyntraChat/SyntraChat-Installer/v0.2.0/install.ps1 | iex
[CmdletBinding()]
param(
    [string]$Version = '0.2.0',
    [switch]$Gui,
    [switch]$DryRun,
    [string]$DownloadDirectory
)
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Use a release version such as 0.2.0.' }
if ($env:OS -ne 'Windows_NT') { throw 'Use install.sh on Linux or macOS.' }
$architecture = $env:PROCESSOR_ARCHITEW6432
if (-not $architecture) { $architecture = $env:PROCESSOR_ARCHITECTURE }
if ($architecture -ne 'AMD64') { throw 'This release requires 64-bit x86 Windows.' }
$asset = "SyntraChat-$Version-windows-x86_64-setup.exe"
$base = "https://github.com/SyntraChat/SyntraChat-Installer/releases/download/v$Version"
if ($DryRun) { Write-Output "$base/$asset"; return }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$stage = Join-Path ([IO.Path]::GetTempPath()) ('syntrachat-' + [guid]::NewGuid())
[void][IO.Directory]::CreateDirectory($stage)
try {
    $checksums = Invoke-RestMethod -Uri "$base/SHA256SUMS" -UseBasicParsing
    if ($checksums.Length -gt 65536) { throw 'Checksum list exceeds size limit.' }
    $pattern = '(?m)^([a-fA-F0-9]{64})  ' + [regex]::Escape($asset) + '\r?$'
    $entries = [regex]::Matches([string]$checksums, $pattern)
    if ($entries.Count -ne 1) { throw 'Release has no unique checksum for this package.' }
    $package = Join-Path $stage $asset
    Invoke-WebRequest -Uri "$base/$asset" -OutFile $package -UseBasicParsing
    if ((Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash -ine $entries[0].Groups[1].Value) {
        throw 'Package checksum mismatch. Nothing was installed.'
    }
    if ($DownloadDirectory) {
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetFullPath($DownloadDirectory))
        Copy-Item -LiteralPath $package -Destination (Join-Path $DownloadDirectory $asset)
        Write-Output "Verified package saved to $DownloadDirectory"
        return
    }
    Write-Output "Installing SyntraChat $Version for the current user..."
    if ($Gui) { $process = Start-Process -FilePath $package -Wait -PassThru }
    else { $process = Start-Process -FilePath $package -ArgumentList '/S' -Wait -PassThru }
    if ($process.ExitCode -ne 0) { throw "Setup failed with exit code $($process.ExitCode)." }
    Write-Output 'SyntraChat setup completed. Open it from the Start menu.'
}
finally {
    # Only remove this invocation's fresh, unpredictable temporary directory.
    if ([IO.Path]::GetDirectoryName($stage) -eq [IO.Path]::GetTempPath().TrimEnd('\')) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}
