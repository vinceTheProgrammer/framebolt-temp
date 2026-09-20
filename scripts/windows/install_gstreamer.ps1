echo "Installing GStreamer dev..."
curl -L "https://gstreamer.freedesktop.org/data/pkg/windows/1.26.7/msvc/gstreamer-1.0-devel-msvc-x86_64-1.26.7.msi" -o gstreamer-devel.msi
$args = '/i', 'gstreamer-devel.msi', '/qn', 'INSTALLDIR=C:\gstreamer', '/L*v', 'C:\install.log'
$process = Start-Process msiexec -ArgumentList $args -Wait -PassThru
if ($process.ExitCode -ne 0) {
    Write-Host "❌ GStreamer install failed with exit code $($process.ExitCode)"
    Get-Content C:\install.log -Tail 20
    exit 1
}
Write-Host "✅ GStreamer dev installed successfully"
curl -L "https://gstreamer.freedesktop.org/data/pkg/windows/1.26.7/msvc/gstreamer-1.0-msvc-x86_64-1.26.7.msi" -o gstreamer-runtime.msi
$args = '/i', 'gstreamer-runtime.msi', '/qn', 'INSTALLDIR=C:\gstreamer', '/L*v', 'C:\install.log'
$process = Start-Process msiexec -ArgumentList $args -Wait -PassThru
if ($process.ExitCode -ne 0) {
    Write-Host "❌ GStreamer install failed with exit code $($process.ExitCode)"
    Get-Content C:\install.log -Tail 20
    exit 1
}
Write-Host "✅ GStreamer installed successfully"