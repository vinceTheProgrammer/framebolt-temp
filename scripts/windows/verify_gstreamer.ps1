Write-Host "Checking GStreamer installation..."
          
if (-not (Test-Path $env:GSTREAMER_ROOT)) {
throw "GStreamer installation directory was not found: $env:GSTREAMER_ROOT"
}

if (-not (Test-Path "$env:GSTREAMER_ROOT\bin")) {
throw "GStreamer bin directory was not found: $env:GSTREAMER_ROOT\bin"
}

if (-not (Test-Path "$env:GSTREAMER_ROOT\lib\gstreamer-1.0")) {
throw "GStreamer plugin directory was not found: $env:GSTREAMER_ROOT\lib\gstreamer-1.0"
}

Write-Host "GStreamer installation found at:"
Write-Host "  $env:GSTREAMER_ROOT"

Write-Host ""
Write-Host "GStreamer version:"
& "$env:GSTREAMER_ROOT\bin\gst-launch-1.0.exe" --version

if ($LASTEXITCODE -ne 0) {
throw "gst-launch-1.0 failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Checking GStreamer plugins..."

$PluginCount = @(Get-ChildItem "$env:GSTREAMER_ROOT\lib\gstreamer-1.0" -Filter "*.dll").Count

if ($PluginCount -eq 0) {
throw "No GStreamer plugins were found."
}

Write-Host "Found $PluginCount GStreamer plugin DLL(s)."

Write-Host ""
Write-Host "GStreamer verification successful."