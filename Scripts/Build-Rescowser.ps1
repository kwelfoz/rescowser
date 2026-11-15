[CmdletBinding()]
param(
    [Parameter()]
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+esr$')]
    [string]$FirefoxVersion = '153.7.0esr',

    [Parameter()]
    [ValidatePattern('^[a-z]{2}-[A-Z]{2}$')]
    [string]$Locale = 'pt-PT'
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repoRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $repoRoot '.build'
$downloadRoot = Join-Path $buildRoot 'downloads'
$extractRoot = Join-Path $buildRoot 'extract'
$appRoot = Join-Path $repoRoot 'App'
$distRoot = Join-Path $repoRoot 'dist'

$osVersion = [Environment]::OSVersion.Version
if ($osVersion.Major -lt 10) {
    throw 'The build script requires Windows 10 or Windows 11.'
}

New-Item -ItemType Directory -Force -Path $downloadRoot, $extractRoot, $appRoot, $distRoot | Out-Null

$architectures = @(
    [pscustomobject]@{ Name = 'x64'; MozillaFolder = 'win64' },
    [pscustomobject]@{ Name = 'x86'; MozillaFolder = 'win32' }
)

foreach ($architecture in $architectures) {
    Write-Host "[RESCOWSER] Downloading Firefox ESR $FirefoxVersion ($($architecture.Name), $Locale)..." -ForegroundColor Cyan

    $msiName = "Firefox Setup $FirefoxVersion.msi"
    $msiPath = Join-Path $downloadRoot "$($architecture.Name)-$msiName"
    $encodedName = [Uri]::EscapeDataString($msiName)
    $url = "https://ftp.mozilla.org/pub/firefox/releases/$FirefoxVersion/$($architecture.MozillaFolder)/$Locale/$encodedName"

    Invoke-WebRequest -Uri $url -OutFile $msiPath
    if (-not (Test-Path -LiteralPath $msiPath) -or (Get-Item -LiteralPath $msiPath).Length -lt 1MB) {
        throw "The downloaded MSI for $($architecture.Name) is missing or unexpectedly small. Check version/locale availability: $url"
    }

    $signature = Get-AuthenticodeSignature -FilePath $msiPath
    if ($signature.Status -ne 'Valid') {
        throw "Mozilla MSI signature is not valid for $($architecture.Name). Status: $($signature.Status)"
    }
    if (-not ($signature.SignerCertificate.Subject -match 'Mozilla Corporation')) {
        throw "Unexpected MSI signer for $($architecture.Name): $($signature.SignerCertificate.Subject)"
    }

    $extractDir = Join-Path $extractRoot $architecture.Name
    $destinationDir = Join-Path $appRoot $architecture.Name
    Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $destinationDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $extractDir, $destinationDir | Out-Null

    # Mozilla documents EXTRACT_DIR as an extraction-only MSI option.
    $msiexec = Join-Path $env:WINDIR 'System32\msiexec.exe'
    $arguments = '/i "{0}" EXTRACT_DIR="{1}" /quiet /norestart' -f $msiPath, $extractDir
    $process = Start-Process -FilePath $msiexec -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Mozilla MSI extraction failed for $($architecture.Name). msiexec exit code: $($process.ExitCode)"
    }

    $firefoxExe = Get-ChildItem -Path $extractDir -Filter 'firefox.exe' -File -Recurse | Select-Object -First 1
    if (-not $firefoxExe) {
        throw "Could not find firefox.exe in the extracted $($architecture.Name) files."
    }

    Copy-Item -Path (Join-Path $firefoxExe.Directory.FullName '*') -Destination $destinationDir -Recurse -Force
    New-Item -ItemType Directory -Force -Path (Join-Path $destinationDir 'distribution') | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot 'Config\policies.json') -Destination (Join-Path $destinationDir 'distribution\policies.json') -Force

    $installedVersion = (Get-Item -LiteralPath (Join-Path $destinationDir 'firefox.exe')).VersionInfo.ProductVersion
    $expectedVersion = $FirefoxVersion -replace 'esr$', ''
    if ($installedVersion -notlike "$expectedVersion*") {
        throw "Unexpected Firefox version in $($architecture.Name) package. Expected $expectedVersion; found $installedVersion."
    }
    Write-Host "[RESCOWSER] $($architecture.Name) Firefox $installedVersion extracted and verified." -ForegroundColor Green
}

$packageRoot = Join-Path $buildRoot 'package'
Remove-Item -LiteralPath $packageRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null

foreach ($item in @('App', 'Config', 'Data', 'StartPage', 'Scripts', 'Rescowser.cmd', 'README.md', 'NOTICE.md', 'LICENSE')) {
    $source = Join-Path $repoRoot $item
    if (Test-Path -LiteralPath $source) {
        $destination = Join-Path $packageRoot $item
        $parent = Split-Path -Parent $destination
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
    }
}

$versionInfo = @(
    'Rescowser portable package',
    "Firefox ESR: $FirefoxVersion",
    "Locale: $Locale",
    "Built: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')",
    'Architectures: x86, x64',
    'Operating systems: Windows 10 and Windows 11'
) -join [Environment]::NewLine
Set-Content -LiteralPath (Join-Path $packageRoot 'BUILD-INFO.txt') -Value $versionInfo -Encoding UTF8

$zipPath = Join-Path $distRoot 'Rescowser-Portable.zip'
Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $packageRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal
Write-Host "[RESCOWSER] Portable package created: $zipPath" -ForegroundColor Green
