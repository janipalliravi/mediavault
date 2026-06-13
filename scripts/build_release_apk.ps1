# Builds a single signed universal release APK for Android 16 (API 36).
# Run from repo root: .\scripts\build_release_apk.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$KeyProps = Join-Path $Root "android\key.properties"

if (-not (Test-Path $KeyProps)) {
    Write-Host "Missing android/key.properties — run scripts/create_release_keystore.ps1 first."
    exit 1
}

Set-Location $Root
flutter clean
flutter pub get
flutter build apk --release

Write-Host ""
Write-Host "Signed universal APK:"
Write-Host "  build/app/outputs/flutter-apk/app-release.apk"
