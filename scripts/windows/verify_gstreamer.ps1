Write-Host "Checking GStreamer installation..."
          
if (-not (Test-Path $GStreamerRoot)) {
throw "GStreamer installation directory was not found: $GStreamerRoot"
}

if (-not (Test-Path "$GStreamerRoot\bin")) {
throw "GStreamer bin directory was not found: $GStreamerRoot\bin"
}

if (-not (Test-Path "$GStreamerRoot\lib\gstreamer-1.0")) {
throw "GStreamer plugin directory was not found: $GStreamerRoot\lib\gstreamer-1.0"
}

Write-Host "GStreamer installation found at:"
Write-Host "  $GStreamerRoot"

Write-Host ""
Write-Host "GStreamer version:"
& "$GStreamerRoot\bin\gst-launch-1.0.exe" --version

if ($LASTEXITCODE -ne 0) {
throw "gst-launch-1.0 failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Checking GStreamer plugins..."

$PluginCount = @(Get-ChildItem "$GStreamerRoot\lib\gstreamer-1.0" -Filter "*.dll").Count

if ($PluginCount -eq 0) {
throw "No GStreamer plugins were found."
}

Write-Host "Found $PluginCount GStreamer plugin DLL(s)."

Write-Host ""
Write-Host "GStreamer verification successful."