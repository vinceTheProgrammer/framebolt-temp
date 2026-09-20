$ErrorActionPreference = "Stop"

$Version = $env:FRAMEBOLT_VERSION

if ([string]::IsNullOrWhiteSpace($Version)) {
    throw "FRAMEBOLT_VERSION environment variable is required."
}

$PackageName = "framebolt"

$Root = Resolve-Path (Join-Path $PSScriptRoot "../..")
$Stage = Join-Path $Root "dist/windows-staging"
$Dist = Join-Path $Root "dist"
$InstallerDir = Join-Path $Root "dist/windows-installer"

$IssFile = Join-Path $InstallerDir "framebolt.iss"
$Output = Join-Path $Dist "${PackageName}-${Version}-windows-x86_64-setup.exe"

if (-not (Test-Path $Stage)) {
    throw "Windows staging directory does not exist: $Stage"
}

$Executable = Join-Path $Stage "framebolt.exe"

if (-not (Test-Path $Executable)) {
    throw "Framebolt executable not found: $Executable"
}

New-Item -ItemType Directory -Force -Path $InstallerDir | Out-Null
New-Item -ItemType Directory -Force -Path $Dist | Out-Null

if (Test-Path $Output) {
    Remove-Item -Force $Output
}

$IconDirective = ""

$IconFile = Join-Path $Root "framebolt.ico"

if (Test-Path $IconFile) {
    Copy-Item $IconFile (Join-Path $InstallerDir "framebolt.ico") -Force
    $IconDirective = 'SetupIconFile=framebolt.ico'
}

@"
#define MyAppName "Framebolt"
#define MyAppVersion "$Version"
#define MyAppPublisher "Framebolt"
#define MyAppExeName "framebolt.exe"

[Setup]
AppId={{A9A8A2D8-2C74-4B83-B7E5-9D4F6C2D9D31}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Framebolt
DefaultGroupName=Framebolt
DisableProgramGroupPage=yes
OutputDir="$Dist"
OutputBaseFilename="framebolt-$Version-windows-x86_64-setup"
Compression=lzma
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
$IconDirective

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; \
    Description: "Create a desktop shortcut"; \
    GroupDescription: "Additional icons:"; \
    Flags: unchecked

[Files]
Source: "$Stage\*"; \
    DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Framebolt"; \
    Filename: "{app}\{#MyAppExeName}"

Name: "{autodesktop}\Framebolt"; \
    Filename: "{app}\{#MyAppExeName}"; \
    Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; \
    Description: "Launch Framebolt"; \
    Flags: nowait postinstall skipifsilent
"@ | Set-Content -Path $IssFile -Encoding UTF8

$Candidates = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
)

$ISCC = $Candidates |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1

if (-not $ISCC) {
    throw "Inno Setup compiler (ISCC.exe) was not found."
}

Write-Host "Building installer with:"
Write-Host "  $ISCC"

& $ISCC $IssFile

if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path $Output)) {
    throw "Expected installer was not created: $Output"
}

Write-Host ""
Write-Host "Created:"
Write-Host "  $Output"
