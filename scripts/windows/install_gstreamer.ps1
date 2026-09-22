param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("x86_64", "arm64")]
    [string]$Architecture
)

$ErrorActionPreference = "Stop"

$GStreamerVersion = "1.28.7"
$GStreamerInstallDir = "C:\gstreamer"
$GStreamerRoot = Join-Path $GStreamerInstallDir "1.0"

$PackageName = "gstreamer-1.0-msvc-$Architecture-$GStreamerVersion.exe"
$BaseUrl = "https://gstreamer.freedesktop.org/data/pkg/windows/$GStreamerVersion/msvc"
$DevelUrl = "$BaseUrl/$PackageName"
$Installer = Join-Path $env:RUNNER_TEMP $PackageName

Write-Host "GStreamer version: $GStreamerVersion"
Write-Host "GStreamer architecture: $Architecture"
Write-Host "GStreamer installer: $PackageName"

Write-Host ""
Write-Host "Downloading GStreamer development installer..."
Write-Host "  $DevelUrl"

Invoke-WebRequest `
    -Uri $DevelUrl `
    -OutFile $Installer

if (-not (Test-Path $Installer)) {
    throw "GStreamer installer was not downloaded: $Installer"
}

Write-Host ""
Write-Host "Installer downloaded:"
Write-Host "  $Installer"
Write-Host "  $((Get-Item $Installer).Length) bytes"

Write-Host ""
Write-Host "Installing GStreamer..."

$Arguments = @(
    "/TYPE=devel"
    "/DIR=$GStreamerInstallDir"
    "/VERYSILENT"
    "/SUPPRESSMSGBOXES"
    "/NORESTART"
    "/CLOSEAPPLICATIONS"
    "/RESTARTAPPLICATIONS"
)

$Process = Start-Process `
    -FilePath $Installer `
    -ArgumentList $Arguments `
    -PassThru

$TimeoutSeconds = 600

if (-not $Process.WaitForExit($TimeoutSeconds * 1000)) {
    Write-Host "GStreamer installer exceeded $TimeoutSeconds seconds."

    try {
        $Process.Kill()
    }
    catch {
        Write-Host "Could not terminate installer process: $($_.Exception.Message)"
    }

    throw "GStreamer installation timed out after $TimeoutSeconds seconds."
}

if ($Process.ExitCode -ne 0) {
    throw "GStreamer installation failed with exit code $($Process.ExitCode)."
}

Write-Host ""
Write-Host "GStreamer installation completed."

Write-Host ""
Write-Host "Locating GStreamer installation..."

$GStreamerDll = Get-ChildItem `
    -Path $GStreamerInstallDir `
    -Filter "gstreamer-1.0-0.dll" `
    -File `
    -Recurse `
    -ErrorAction SilentlyContinue |
    Select-Object -First 1

if (-not $GStreamerDll) {
    Write-Host ""
    Write-Host "Contents of ${GStreamerInstallDir}:"
    
    if (Test-Path $GStreamerInstallDir) {
        Get-ChildItem `
            -Path $GStreamerInstallDir `
            -Recurse `
            -File |
            Select-Object -First 100 FullName |
            ForEach-Object {
                Write-Host "  $($_.FullName)"
            }
    }
    
    throw "Could not locate gstreamer-1.0-0.dll under $GStreamerInstallDir"
}

$GStreamerRoot = Split-Path `
    (Split-Path $GStreamerDll.FullName -Parent) `
    -Parent

$GStreamerBin = Join-Path $GStreamerRoot "bin"
$GStreamerLib = Join-Path $GStreamerRoot "lib"

Write-Host ""
Write-Host "GStreamer root:"
Write-Host "  $GStreamerRoot"

Write-Host ""
Write-Host "GStreamer bin:"
Write-Host "  $GStreamerBin"

Write-Host ""
Write-Host "GStreamer lib:"
Write-Host "  $GStreamerLib"

"GSTREAMER_ROOT=$GStreamerRoot" |
    Out-File -FilePath $env:GITHUB_ENV -Encoding utf8

"GSTREAMER_BIN=$GStreamerBin" |
    Out-File -FilePath $env:GITHUB_ENV -Encoding utf8

"GSTREAMER_LIB=$GStreamerLib" |
    Out-File -FilePath $env:GITHUB_ENV -Encoding utf8

if (-not (Test-Path $GStreamerBin)) {
    throw "GStreamer bin directory was not found: $GStreamerBin"
}

if (-not (Test-Path $GStreamerLib)) {
    throw "GStreamer lib directory was not found: $GStreamerLib"
}

Write-Host ""
Write-Host "Adding GStreamer to PATH..."

$GStreamerBin |
    Out-File `
        -FilePath $env:GITHUB_PATH `
        -Encoding utf8

Write-Host ""
Write-Host "GStreamer installation complete."