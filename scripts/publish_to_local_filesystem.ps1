<#
.SYNOPSIS
    Builds the ALZ module and publishes it to a local filesystem PowerShell repository.

.DESCRIPTION
    This script runs the build, sets the module version, and publishes the resulting
    module to a local folder registered as a PSRepository. Use this to test the
    packaged module locally before pushing it to an internal feed.

    After running this script you can install the module from the local feed with:
        Install-Module -Name ALZ -Repository ALZLocal -Scope CurrentUser -Force

.PARAMETER Version
    The module version to publish (e.g. '0.4.0').

.PARAMETER Prerelease
    Optional prerelease tag (e.g. 'beta1'). Leave empty for a stable release.

.PARAMETER LocalFeedPath
    The local filesystem folder to use as the repository (the .nupkg lands here).
    Defaults to '<repo>/local-feed'.

.PARAMETER SkipBuild
    Skip running Invoke-Build and publish whatever is already in src/Artifacts.

.EXAMPLE
    ./publish_to_local_filesystem.ps1 -Version '0.4.0'

.EXAMPLE
    ./publish_to_local_filesystem.ps1 -Version '0.4.0' -Prerelease 'beta1'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Version,

    [Parameter(Mandatory = $false)]
    [string] $Prerelease = "",

    [Parameter(Mandatory = $false)]
    [string] $LocalFeedPath = (Join-Path $PSScriptRoot ".." "local-feed"),

    [Parameter(Mandatory = $false)]
    [switch] $SkipBuild
)

$ErrorActionPreference = "Stop"

$repositoryName = "ALZLocal"
$moduleName = "ALZ"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$artifactsPath = Join-Path $repoRoot "src" "Artifacts"
$manifestPath = Join-Path $artifactsPath "$moduleName.psd1"

# 1. Build the module
if (-not $SkipBuild) {
    Write-Host "Building module..." -ForegroundColor Cyan
    Invoke-Build -File (Join-Path $repoRoot "src" "ALZ.build.ps1")
}

if (-not (Test-Path $manifestPath)) {
    throw "Module manifest not found at '$manifestPath'. Run the build first or remove -SkipBuild."
}

# 2. Stamp the version onto the built manifest
Write-Host "Setting module version to '$Version'$(if ($Prerelease) { " (prerelease: $Prerelease)" })..." -ForegroundColor Cyan
$updateParams = @{
    Path          = $manifestPath
    ModuleVersion = $Version
}
if (-not [string]::IsNullOrWhiteSpace($Prerelease)) {
    $updateParams["Prerelease"] = $Prerelease
}
Update-ModuleManifest @updateParams

# Stage the built module into a folder named after the module (Publish-Module
# requires the leaf folder name to match the module name).
$stagingPath = Join-Path ([System.IO.Path]::GetTempPath()) "ALZ-publish-$([guid]::NewGuid().ToString('N'))" $moduleName
$null = New-Item -Path $stagingPath -ItemType Directory -Force
Copy-Item -Path (Join-Path $artifactsPath '*') -Destination $stagingPath -Recurse -Exclude "ccReport", "testOutput" -Force

# 3. Ensure the local feed folder exists
if (-not (Test-Path $LocalFeedPath)) {
    $null = New-Item -Path $LocalFeedPath -ItemType Directory -Force
}
$LocalFeedPath = (Resolve-Path $LocalFeedPath).Path

# 4. Register (or re-register) the local repository
$existingRepo = Get-PSRepository -Name $repositoryName -ErrorAction SilentlyContinue
if ($existingRepo) {
    if ($existingRepo.SourceLocation -ne $LocalFeedPath) {
        Write-Host "Re-registering '$repositoryName' to point at '$LocalFeedPath'..." -ForegroundColor Yellow
        Unregister-PSRepository -Name $repositoryName
        Register-PSRepository -Name $repositoryName -SourceLocation $LocalFeedPath -PublishLocation $LocalFeedPath -InstallationPolicy Trusted
    }
} else {
    Write-Host "Registering local repository '$repositoryName' at '$LocalFeedPath'..." -ForegroundColor Cyan
    Register-PSRepository -Name $repositoryName -SourceLocation $LocalFeedPath -PublishLocation $LocalFeedPath -InstallationPolicy Trusted
}

# 5. Publish to the local feed
# Remove any existing package for this version so the local feed can be refreshed
# (filesystem repositories will not overwrite an existing version).
$existingPackage = Join-Path $LocalFeedPath "$moduleName.$Version.nupkg"
if (Test-Path $existingPackage) {
    Write-Host "Removing existing package '$moduleName.$Version.nupkg' from local feed..." -ForegroundColor Yellow
    Remove-Item -Path $existingPackage -Force
}

Write-Host "Publishing '$moduleName' $Version to '$repositoryName'..." -ForegroundColor Cyan
try {
    Publish-Module -Path $stagingPath -Repository $repositoryName -Force
} finally {
    Remove-Item -Path (Split-Path $stagingPath -Parent) -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Done. Module published to local feed: $LocalFeedPath" -ForegroundColor Green
Write-Host "Test the install with:" -ForegroundColor Green
Write-Host "    Install-Module -Name $moduleName -Repository $repositoryName -Scope CurrentUser -Force" -ForegroundColor Green
