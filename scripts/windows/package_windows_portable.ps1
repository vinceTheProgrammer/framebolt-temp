param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("x86_64", "arm64")]
    [string]$Architecture
)

$ErrorActionPreference = "Stop"

$Version = $env:FRAMEBOLT_VERSION

if ([string]::IsNullOrWhiteSpace($Version)) {
    throw "FRAMEBOLT_VERSION environment variable is required."
}

$PackageName = "framebolt"

$Root = Resolve-Path (Join-Path $PSScriptRoot "../..")
$Stage = Join-Path $Root "dist/windows-staging"
$Dist = Join-Path $Root "dist"

$Output = Join-Path `
    $Dist `
    "${PackageName}-${Version}-windows-${Architecture}-portable.zip"

Write-Host "Packaging Framebolt $Version portable Windows release..."
Write-Host "Architecture: $Architecture"

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

$CheckDir = Join-Path `
    $env:TEMP `
    "framebolt-portable-check-$Architecture"

if (Test-Path $CheckDir) {
    Remove-Item -Recurse -Force $CheckDir
}

Expand-Archive `
    -Path $Output `
    -DestinationPath $CheckDir `
    -Force

Get-ChildItem `
    $CheckDir `
    -Recurse |
    Select-Object FullName
