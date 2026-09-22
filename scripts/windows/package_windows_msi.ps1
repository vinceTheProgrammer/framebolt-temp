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
$InstallerDir = Join-Path $Root "dist/windows-installer"

$WixFile = Join-Path `
    $InstallerDir `
    "framebolt-$Architecture.wxs"

$Output = Join-Path `
    $Dist `
    "${PackageName}-${Version}-windows-${Architecture}-setup.msi"

if (-not (Test-Path $Stage)) {
    throw "Windows staging directory does not exist: $Stage"
}

$Executable = Join-Path $Stage "framebolt.exe"

if (-not (Test-Path $Executable)) {
    throw "Framebolt executable not found: $Executable"
}

New-Item `
    -ItemType Directory `
    -Force `
    -Path $InstallerDir |
    Out-Null

New-Item `
    -ItemType Directory `
    -Force `
    -Path $Dist |
    Out-Null

if (Test-Path $Output) {
    Remove-Item -Force $Output
}

# ------------------------------------------------------------
# WiX architecture
# ------------------------------------------------------------

switch ($Architecture) {
    "x86_64" {
        $WixPlatform = "x64"

        # Architecture-specific UpgradeCode.
        # Keep this value unchanged for all future x64 releases.
        $UpgradeCode = "{A9A8A2D8-2C74-4B83-B7E5-9D4F6C2D9D31}"
    }

    "arm64" {
        $WixPlatform = "arm64"

        # Architecture-specific UpgradeCode.
        # Keep this value unchanged for all future ARM64 releases.
        $UpgradeCode = "{D4D5A4D5-9F4B-4D9D-9E4D-6B6C6E8E8A42}"
    }

    default {
        throw "Unsupported architecture: $Architecture"
    }
}

# ------------------------------------------------------------
# WiX compiler
# ------------------------------------------------------------

$Wix = Get-Command wix -ErrorAction SilentlyContinue

if (-not $Wix) {
    throw @"
WiX Toolset was not found.

Install WiX 6 before running this script, for example:

    dotnet tool install --global wix --version 6.0.2

Then make sure 'wix' is available on PATH.
"@
}

Write-Host "Using WiX:"
Write-Host "  $($Wix.Source)"

# ------------------------------------------------------------
# Optional application icon
# ------------------------------------------------------------

$IconFile = Join-Path $Root "framebolt.ico"

$IconXml = ""

if (Test-Path $IconFile) {
    Copy-Item `
        $IconFile `
        (Join-Path $InstallerDir "framebolt.ico") `
        -Force

    $IconXml = @"
        <Icon Id="FrameboltIcon" SourceFile="$IconFile" />

        <Property
            Id="ARPPRODUCTICON"
            Value="FrameboltIcon" />
"@
}

# ------------------------------------------------------------
# WiX source
# ------------------------------------------------------------
#
# ProductCode is intentionally omitted.
# WiX generates the ProductCode from the package identity.
#
# UpgradeCode is architecture-specific and MUST remain unchanged
# for all future releases of that architecture.
#
# The architecture itself is selected by:
#
#     wix build ... -arch x64
#     wix build ... -arch arm64
#
# Do not add Platform to the Package element.
# ------------------------------------------------------------

@"
<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs">

    <Package
        Name="Framebolt"
        Manufacturer="Framebolt"
        Version="$Version"
        UpgradeCode="$UpgradeCode"
        Language="1033"
        InstallerVersion="500"
        Scope="perMachine">

        <SummaryInformation
            Description="Framebolt media application"
            Manufacturer="Framebolt"
            Keywords="Framebolt,media,GStreamer" />

        <MajorUpgrade
            DowngradeErrorMessage="A newer version of Framebolt is already installed."
            AllowSameVersionUpgrades="no" />

        <MediaTemplate EmbedCab="yes" />

$IconXml

        <StandardDirectory Id="ProgramFilesFolder">
            <Directory
                Id="APPLICATIONFOLDER"
                Name="Framebolt" />
        </StandardDirectory>

        <StandardDirectory Id="ProgramMenuFolder">
            <Directory
                Id="APPLICATIONPROGRAMSFOLDER"
                Name="Framebolt" />
        </StandardDirectory>

        <Feature
            Id="MainFeature"
            Title="Framebolt"
            Level="1"
            AllowAdvertise="no"
            Display="expand">

            <ComponentGroupRef Id="ApplicationFiles" />

            <ComponentRef Id="ApplicationShortcuts" />

        </Feature>

    </Package>

    <Fragment>

        <ComponentGroup
            Id="ApplicationFiles"
            Directory="APPLICATIONFOLDER">

            <Files Include="$Stage\**" />

        </ComponentGroup>

    </Fragment>

    <Fragment>

        <Component
            Id="ApplicationShortcuts"
            Directory="APPLICATIONFOLDER">

            <Shortcut
                Id="StartMenuShortcut"
                Directory="APPLICATIONPROGRAMSFOLDER"
                Name="Framebolt"
                Description="Launch Framebolt"
                Target="[APPLICATIONFOLDER]framebolt.exe"
                WorkingDirectory="APPLICATIONFOLDER"
                Advertise="no"$(
                if ($IconXml) {
                    ', Icon="FrameboltIcon"'
                }
            ) />

            <RegistryValue
                Root="HKLM"
                Key="Software\Framebolt"
                Name="Installed"
                Type="integer"
                Value="1"
                KeyPath="yes" />

        </Component>

    </Fragment>

</Wix>
"@ | Set-Content `
    -Path $WixFile `
    -Encoding UTF8

Write-Host ""
Write-Host "Building Windows MSI..."
Write-Host "  Version:      $Version"
Write-Host "  Architecture: $Architecture"
Write-Host "  WiX platform: $WixPlatform"
Write-Host "  Input:        $Stage"
Write-Host "  Output:       $Output"

& wix build `
    $WixFile `
    -arch $WixPlatform `
    -o $Output

if ($LASTEXITCODE -ne 0) {
    throw "WiX failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path $Output)) {
    throw "Expected MSI was not created: $Output"
}

Write-Host ""
Write-Host "Created:"
Write-Host "  $Output"

Write-Host ""
Write-Host "MSI information:"

Get-Item $Output |
    Format-List Name, Length, FullName