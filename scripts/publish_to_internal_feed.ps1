<#
.SYNOPSIS
    Publishes the built ALZ module to a private internal PowerShell feed.

.DESCRIPTION
    This script publishes the module from src/Artifacts to a private/internal
    NuGet-style PowerShell feed (e.g. Azure Artifacts, a private NuGet server, etc.).

    Run publish_to_local_filesystem.ps1 first to build and validate the module
    locally. Once you are happy with it, run this script to push to the internal feed.

    The script will register the feed as a PSRepository if it is not already present.

.PARAMETER FeedName
    The friendly name to register the internal feed under (PSRepository name).

.PARAMETER FeedUrl
    The source/publish URL of the internal feed (NuGet v2/v3 endpoint).

.PARAMETER ApiKey
    The API key / personal access token used to authenticate against the feed.
    For Azure Artifacts a PAT is typically used; any non-empty value works when a
    credential is supplied instead.

.PARAMETER Credential
    Optional PSCredential for feeds that require basic auth (e.g. Azure Artifacts
    with a PAT as the password). Provide either -ApiKey or -Credential as required
    by your feed.

.PARAMETER Version
    Optional. If supplied, validates that the built manifest matches this version
    before publishing (guards against pushing the wrong version).

.EXAMPLE
    ./publish_to_internal_feed.ps1 `
        -FeedName 'InternalFeed' `
        -FeedUrl 'https://pkgs.dev.azure.com/myorg/_packaging/myfeed/nuget/v2' `
        -ApiKey 'az' `
        -Credential (Get-Credential)

.EXAMPLE
    ./publish_to_internal_feed.ps1 `
        -FeedName 'InternalFeed' `
        -FeedUrl 'https://my-nuget-server/api/v2/package' `
        -ApiKey $env:NUGET_API_KEY
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $FeedName,

    [Parameter(Mandatory = $true)]
    [string] $FeedUrl,

    [Parameter(Mandatory = $false)]
    [string] $ApiKey,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential] $Credential,

    [Parameter(Mandatory = $false)]
    [string] $Version
)

$ErrorActionPreference = "Stop"

$moduleName = "ALZ"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$artifactsPath = Join-Path $repoRoot "src" "Artifacts"
$manifestPath = Join-Path $artifactsPath "$moduleName.psd1"

# 1. Validate the build output exists
if (-not (Test-Path $manifestPath)) {
    throw "Module manifest not found at '$manifestPath'. Build the module (or run publish_to_local_filesystem.ps1) first."
}

# 2. Optional version guard
if (-not [string]::IsNullOrWhiteSpace($Version)) {
    $builtVersion = (Import-PowerShellDataFile -Path $manifestPath).ModuleVersion
    if ($builtVersion -ne $Version) {
        throw "Built module version '$builtVersion' does not match expected version '$Version'. Aborting."
    }
    Write-Host "Verified built module version is '$Version'." -ForegroundColor Cyan
}

# Stage the built module into a folder named after the module (Publish-Module
# requires the leaf folder name to match the module name).
$stagingPath = Join-Path ([System.IO.Path]::GetTempPath()) "ALZ-publish-$([guid]::NewGuid().ToString('N'))" $moduleName
$null = New-Item -Path $stagingPath -ItemType Directory -Force
Copy-Item -Path (Join-Path $artifactsPath '*') -Destination $stagingPath -Recurse -Exclude "ccReport", "testOutput" -Force

# 3. Register (or re-register) the internal feed
$existingRepo = Get-PSRepository -Name $FeedName -ErrorAction SilentlyContinue
$registerParams = @{
    Name               = $FeedName
    SourceLocation     = $FeedUrl
    PublishLocation    = $FeedUrl
    InstallationPolicy = "Trusted"
}
if ($Credential) {
    $registerParams["Credential"] = $Credential
}

if ($existingRepo) {
    if ($existingRepo.SourceLocation -ne $FeedUrl) {
        Write-Host "Re-registering '$FeedName' to point at '$FeedUrl'..." -ForegroundColor Yellow
        Unregister-PSRepository -Name $FeedName
        Register-PSRepository @registerParams
    }
} else {
    Write-Host "Registering internal feed '$FeedName' at '$FeedUrl'..." -ForegroundColor Cyan
    Register-PSRepository @registerParams
}

# 4. Publish to the internal feed
Write-Host "Publishing '$moduleName' to '$FeedName'..." -ForegroundColor Cyan
$publishParams = @{
    Path       = $stagingPath
    Repository = $FeedName
    Force      = $true
}
if (-not [string]::IsNullOrWhiteSpace($ApiKey)) {
    $publishParams["NuGetApiKey"] = $ApiKey
}
if ($Credential) {
    $publishParams["Credential"] = $Credential
}
try {
    Publish-Module @publishParams
} finally {
    Remove-Item -Path (Split-Path $stagingPath -Parent) -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Done. Module published to internal feed '$FeedName' ($FeedUrl)." -ForegroundColor Green
