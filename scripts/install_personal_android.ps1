# Installs release APK via adb (bypasses some on-device Play Protect UI blocks).
# Run from repo root: .\scripts\install_personal_android.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Apk = Join-Path $Root "build\app\outputs\flutter-apk\app-release.apk"
$Adb = Join-Path $env:LOCALAPPDATA "Android\sdk\platform-tools\adb.exe"

if (-not (Test-Path $Apk)) {
    Write-Host "APK not found. Building release first..."
    Set-Location $Root
    & "$Root\scripts\build_release_apk.ps1"
}

if (-not (Test-Path $Adb)) {
    Write-Host "adb not found at $Adb"
    exit 1
}

$devices = & $Adb devices | Select-String "device$"
if (-not $devices) {
    Write-Host "No device connected. Enable USB debugging and connect phone, or start emulator."
    exit 1
}

Write-Host "Installing $Apk ..."
& $Adb install -r $Apk
if ($LASTEXITCODE -eq 0) {
    Write-Host "Installed com.mediavault.personal"
    Write-Host "On Android 15/16: Apps -> MediaVault -> Allow restricted settings (if backup/picker needs it)."
} else {
    Write-Host "Install failed. See SIDELOAD_INSTALL.md"
    exit $LASTEXITCODE
}
