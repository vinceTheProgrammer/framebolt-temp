# === Configuration ===
$exePath = "windows_release\framebolt.exe"
$gstBin  = "C:\gstreamer\1.0\msvc_x86_64\bin"
$outDir  = "windows_release"

# Find dumpbin.exe (auto-detect on GitHub runners or VS installs)
$dumpbin = (Get-ChildItem "C:\Program Files\Microsoft Visual Studio" -Recurse -Filter dumpbin.exe -ErrorAction SilentlyContinue |
             Where-Object { $_.FullName -match "Hostx64\\x64" } |
             Select-Object -First 1).FullName

if (-not $dumpbin) {
    Write-Error "❌ dumpbin.exe not found. Make sure Visual Studio Build Tools are installed."
    exit 1
}

# === Helper: get dependencies from a given file ===
function Get-Dependencies($file) {
    & $dumpbin /DEPENDENTS $file 2>$null |
        Select-String -Pattern "\.dll" |
        ForEach-Object { ($_ -split '\s+')[-1].Trim() } |
        Sort-Object -Unique
}

# === Recursive copy ===
$processed = @{}
$queue = New-Object System.Collections.Queue
$queue.Enqueue($exePath)
$copiedCount = 0

while ($queue.Count -gt 0) {
    $current = $queue.Dequeue()

    if ($processed.ContainsKey($current)) {
        continue
    }
    $processed[$current] = $true

    $deps = Get-Dependencies $current

    foreach ($dll in $deps) {
        $src = Join-Path $gstBin $dll
        $dst = Join-Path $outDir $dll

        if ((Test-Path $src) -and (-not (Test-Path $dst))) {
            Copy-Item $src -Destination $outDir -Force
            Write-Host "Copied: $dll"
            $copiedCount++
            # Queue this DLL for deeper dependency inspection
            $queue.Enqueue($dst)
        }
    }
}

# === Final sanity check ===
if ($copiedCount -eq 0) {
    Write-Error "❌ No GStreamer DLLs were copied! Check if GStreamer is installed in $gstBin"
    exit 1
}

Write-Host "`n✅ Recursive GStreamer dependency copy complete."
Write-Host "📦 $copiedCount DLLs copied to: $out
Dir"
exit 0