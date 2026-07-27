# MVision Build Script (Windows)
# Usage: .\build.ps1 [-Platform windows] [-Mode release|debug|profile]
#
# Requires: Flutter 3.44.8+ (Dart 3.12.2+), Visual Studio 2022 with
# "Desktop development with C++" workload.

param(
    [ValidateSet('windows')]
    [string]$Platform = 'windows',

    [ValidateSet('release', 'debug', 'profile')]
    [string]$Mode = 'release'
)

$ErrorActionPreference = 'Stop'

function Info($msg)  { Write-Host "[INFO] $msg" -ForegroundColor Green }
function Warn($msg)  { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Fail($msg)  { Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }

# --- Environment ---
# Set MVISION_FLUTTER_HOME when the required SDK is installed elsewhere.
# Flutter 3.44.8+ (Dart 3.12.2+) is required by this project; older SDKs
# cannot resolve the client's Dart constraints.
$RequiredFlutterHome = 'E:\Web\Flutter\flutter_windows_3.44.8-stable\flutter'
$LegacyFlutterHome = 'E:\Web\Flutter\flutter_windows_3.27.1-stable\flutter'
$FlutterHome = if ($env:MVISION_FLUTTER_HOME) {
    $env:MVISION_FLUTTER_HOME
} else {
    $RequiredFlutterHome
}

if (Test-Path "$FlutterHome\bin\flutter.bat") {
    $env:Path = "$FlutterHome\bin;$env:Path"
} elseif (-not $env:MVISION_FLUTTER_HOME -and (Test-Path "$LegacyFlutterHome\bin\flutter.bat")) {
    Fail "Flutter 3.44.8+ is required but only the legacy SDK was found at $LegacyFlutterHome. Install the required SDK or set MVISION_FLUTTER_HOME to it."
}
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'

# --- Config ---
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClientDir = Join-Path $ProjectDir 'apps\client'

# --- Pre-checks ---
$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) { Fail "Flutter 3.44.8+ not found. Install it at $RequiredFlutterHome or set MVISION_FLUTTER_HOME." }

Info "Flutter: $((flutter --version | Select-Object -First 1) -replace '\s+', ' ')"
Info "Platform: $Platform | Mode: $Mode"
Info "Project: $ClientDir"
Write-Host ''

# --- Pub Get ---
Info 'Resolving dependencies...'
Push-Location $ClientDir
try {
    flutter pub get | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail 'pub get failed' }

    # --- Build ---
    Info "Building Windows ($Mode)..."
    flutter build windows --$Mode
    if ($LASTEXITCODE -ne 0) { Fail 'Windows build failed' }

    $modeCap = (Get-Culture).TextInfo.ToTitleCase($Mode)
    $exe = Join-Path $ClientDir "build\windows\x64\runner\$modeCap\mvision_client.exe"
    if (Test-Path $exe) {
        $size = '{0:N1} MB' -f ((Get-Item $exe).Length / 1MB)
        Info "Windows build complete: $exe ($size)"
    } else {
        Warn "Build output not found at expected path: $exe"
    }
} finally {
    Pop-Location
}

Write-Host ''
Info 'Done!'
