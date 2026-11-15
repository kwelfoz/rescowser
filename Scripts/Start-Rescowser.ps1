[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$BrowserArguments
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

try {
    $os = [Environment]::OSVersion.Version
    if ($os.Major -lt 10) {
        throw 'Rescowser requires Windows 10 or Windows 11.'
    }

    $arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
    $browser = Join-Path $root "App\$arch\firefox.exe"
    if (-not (Test-Path -LiteralPath $browser -PathType Leaf)) {
        throw "The $arch browser build is missing. Download a Rescowser package or run Scripts\Build-Rescowser.ps1."
    }

    $profile = Join-Path $root "Data\Profiles\$arch"
    $downloads = Join-Path $root 'Data\Downloads'
    New-Item -ItemType Directory -Force -Path $profile, $downloads | Out-Null

    # Refresh this setting on every launch so it follows the USB drive letter.
    $basePrefs = Join-Path $root 'Config\user.js'
    $prefs = if (Test-Path -LiteralPath $basePrefs) { Get-Content -LiteralPath $basePrefs -Raw } else { '' }
    $downloadsForJs = $downloads.Replace('\', '\\').Replace('"', '\"')
    $managedPrefs = @"

// Rescowser-managed portable download location.
user_pref("browser.download.folderList", 2);
user_pref("browser.download.useDownloadDir", true);
user_pref("browser.download.dir", "$downloadsForJs");
"@
    [IO.File]::WriteAllText((Join-Path $profile 'user.js'), $prefs + $managedPrefs, [Text.UTF8Encoding]::new($false))

    if ($BrowserArguments -and $BrowserArguments.Count -gt 0) {
        $target = $BrowserArguments -join ' '
    } else {
        $startPage = [IO.Path]::GetFullPath((Join-Path $root 'StartPage\index.html'))
        $target = ([Uri]::new($startPage)).AbsoluteUri
    }

    # A separate Firefox instance and an explicit profile keep user data on USB.
    $argumentLine = '-no-remote -profile "{0}" "{1}"' -f $profile, $target
    Write-Host "[RESCOWSER] Starting Firefox ($arch) with a USB-local profile..." -ForegroundColor Cyan
    $process = Start-Process -FilePath $browser -ArgumentList $argumentLine -PassThru
    $process.WaitForExit()
    exit $process.ExitCode
}
catch {
    Write-Host "[RESCOWSER] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
