
function New-ModuleSetup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$targetDirectory,
        [Parameter(Mandatory = $false)]
        [string]$targetFolder,
        [Parameter(Mandatory = $false)]
        [string]$sourceFolder,
        [Parameter(Mandatory = $false)]
        [string]$url,
        [Parameter(Mandatory = $false)]
        [string]$release,
        [Parameter(Mandatory = $false)]
        [string]$releaseArtifactName = "",
        [Parameter(Mandatory = $false)]
        [string]$moduleOverrideFolderPath,
        [Parameter(Mandatory = $false)]
        [bool]$skipInternetChecks,
        [Parameter(Mandatory = $false)]
        [switch]$replaceFiles,
        [Parameter(Mandatory = $false)]
        [switch]$upgrade,
        [Parameter(Mandatory = $false)]
        [switch]$autoApprove,
        [Parameter(Mandatory = $false)]
        [string]$githubToken
    )

    if ($PSCmdlet.ShouldProcess("Check and get module", "modify")) {
        Write-ToConsoleLog -Message "Starting New-ModuleSetup for module type: $targetFolder and version: $release" -Level Verbose
        $versionAndPath = New-FolderStructure `
            -targetDirectory $targetDirectory `
            -url $url `
            -release $release `
            -releaseArtifactName $releaseArtifactName `
            -targetFolder $targetFolder `
            -sourceFolder $sourceFolder `
            -overrideSourceDirectoryPath $moduleOverrideFolderPath `
            -replaceFiles:$replaceFiles.IsPresent `
            -githubToken $githubToken

        Write-Verbose "New version: $($versionAndPath.releaseTag) at path: $($versionAndPath.path)"

        # Update version data
        Set-ModuleVersionData -targetDirectory $targetDirectory -moduleType $targetFolder -version $versionAndPath.releaseTag | Out-Null

        return $versionAndPath
    }
}