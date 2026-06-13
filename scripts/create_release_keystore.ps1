# Creates a release keystore and android/key.properties for signed APK builds.
# Run from repo root: .\scripts\create_release_keystore.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$AndroidDir = Join-Path $Root "android"
$Keystore = Join-Path $AndroidDir "app\mediavault-release.jks"
$KeyProps = Join-Path $AndroidDir "key.properties"

if (Test-Path $Keystore) {
    Write-Host "Keystore already exists: $Keystore"
} else {
    $dname = "CN=MediaVault, OU=Personal, O=MediaVault, L=Local, ST=Local, C=US"
    keytool -genkeypair -v `
        -keystore $Keystore `
        -alias mediavault `
        -keyalg RSA `
        -keysize 2048 `
        -validity 10000 `
        -storepass mediavault_release `
        -keypass mediavault_release `
        -dname $dname
    Write-Host "Created keystore: $Keystore"
}

if (-not (Test-Path $KeyProps)) {
    @"
storePassword=mediavault_release
keyPassword=mediavault_release
keyAlias=mediavault
storeFile=app/mediavault-release.jks
"@
    [System.IO.File]::WriteAllText($KeyProps, $content + "`n", (New-Object System.Text.UTF8Encoding $false))
    Write-Host "Created key.properties: $KeyProps"
} else {
    Write-Host "key.properties already exists: $KeyProps"
}

Write-Host ""
Write-Host "Next: flutter build apk --release"
Write-Host "Output: build/app/outputs/flutter-apk/app-release.apk"
