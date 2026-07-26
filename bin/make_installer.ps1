param(
    [ValidateSet("major", "minor", "patch")]
    [string]$bump = "patch"
)

# Set paths
$nsisExe = "F:\NSIS\makensis.exe"
$scriptPath = "F:\Projects\ktracer_center\bin\KTracerCenterInstaller.nsi"
$outputExe = "F:\Projects\ktracer_center\bin\KTracerCenterSetup.exe"
$pubspec = "F:\Projects\ktracer_center\pubspec.yaml"

# Kill running app if open
Stop-Process -Name "ktracer_center" -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 1000

# Bump version in pubspec.yaml
$pubspecContent = Get-Content $pubspec -Raw
if ($pubspecContent -match "version:\s*(\d+)\.(\d+)\.(\d+)") {
    $major = [int]$matches[1]
    $minor = [int]$matches[2]
    $patch = [int]$matches[3]
    switch ($bump) {
        "major" { $major++; $minor = 0; $patch = 0 }
        "minor" { $minor++; $patch = 0 }
        "patch" { $patch++ }
    }
    $newVersion = "$major.$minor.$patch"
    $pubspecContent = $pubspecContent -replace "version:\s*\d+\.\d+\.\d+", "version: $newVersion"
    Set-Content $pubspec $pubspecContent
    Write-Host "Bumped version to $newVersion"
}
else {
    Write-Host "Could not find version in pubspec.yaml"
}

flutter build windows --release

if (Test-Path $outputExe) { Remove-Item $outputExe -Force }

# Run NSIS compiler
& "$nsisExe" "$scriptPath"

# Create GitHub release (requires gh CLI and authentication)
$releaseName = "v$newVersion"
$releaseNotes = "Automated release for $releaseName"
$exePath = $outputExe
if (Test-Path $exePath) {
    gh release create $releaseName $exePath --title $releaseName --notes $releaseNotes --latest
    Write-Host "Created GitHub release $releaseName"
}
else {
    Write-Host "Installer not found, skipping GitHub release."
}