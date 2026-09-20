$ErrorActionPreference = "Stop"

$Version = $env:FRAMEBOLT_VERSION

if ([string]::IsNullOrWhiteSpace($Version)) {
    throw "FRAMEBOLT_VERSION environment variable is required."
}

$PackageName = "framebolt"
$Architecture = "x86_64"

$Root = Resolve-Path (Join-Path $PSScriptRoot "../..")
$Stage = Join-Path $Root "dist/windows-staging"
$Dist = Join-Path $Root "dist"

$Output = Join-Path $Dist "${PackageName}-${Version}-windows-${Architecture}-portable.zip"

Write-Host "Packaging Framebolt $Version portable Windows release..."

if (-not (Test-Path $Stage)) {
    throw "Windows staging directory does not exist: $Stage"
}

$Executable = Join-Path $Stage "framebolt.exe"

if (-not (Test-Path $Executable)) {
    throw "Framebolt executable not found: $Executable"
}

New-Item -ItemType Directory -Force -Path $Dist | Out-Null

if (Test-Path $Output) {
    Remove-Item -Force $Output
}

Compress-Archive `
    -Path (Join-Path $Stage "*") `
    -DestinationPath $Output `
    -CompressionLevel Optimal

Write-Host ""
Write-Host "Created:"
Write-Host "  $Output"

Write-Host ""
Write-Host "Contents:"
Expand-Archive -Path $Output -DestinationPath (Join-Path $env:TEMP "framebolt-portable-check") -Force

Get-ChildItem `
    (Join-Path $env:TEMP "framebolt-portable-check") `
    -Recurse |
    Select-Object FullName
