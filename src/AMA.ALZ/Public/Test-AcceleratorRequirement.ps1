function Test-AcceleratorRequirement {
    <#
    .SYNOPSIS
        Test that the Accelerator software requirements are met
    .DESCRIPTION
        This will check for the pre-requisite software
    .EXAMPLE
        C:\PS> Test-AcceleratorRequirement
    .EXAMPLE
        C:\PS> Test-AcceleratorRequirement -Verbose
    .EXAMPLE
        C:\PS> Test-AcceleratorRequirement -Checks @("GitHubCli")
    .OUTPUTS
        Boolean - True if all requirements are met, false if not.
    .NOTES
        This function is used by the Deploy-Accelerator function to ensure that the software requirements are met before attempting run the Accelerator.
    .COMPONENT
        AMA.ALZ
    #>
    param (
        [Parameter(
            Mandatory = $false,
            HelpMessage = "[OPTIONAL] Specifies which checks to run. Valid values: PowerShell, Git, AzureCli, AzureEnvVars, AzureCliOrEnvVars, AzureLogin, AmaAlzModule, AmaAlzModuleVersion, YamlModule, YamlModuleAutoInstall, GitHubCli, AzureDevOpsCli"
        )]
        [ValidateSet("PowerShell", "Git", "AzureCli", "AzureEnvVars", "AzureCliOrEnvVars", "AzureLogin", "AmaAlzModule", "AmaAlzModuleVersion", "YamlModule", "YamlModuleAutoInstall", "GitHubCli", "AzureDevOpsCli")]
        [string[]]$Checks = @("PowerShell", "Git", "AzureCliOrEnvVars", "AzureLogin", "AmaAlzModule", "AmaAlzModuleVersion")
    )
    Test-Tooling -Checks $Checks
}
