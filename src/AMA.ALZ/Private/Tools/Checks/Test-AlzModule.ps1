function Test-AlzModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$CheckVersion = $true,
        [Parameter(Mandatory = $false)]
        [switch]$AllowContinueOnFailure
    )

    $results = @()
    $hasFailure = $false
    $currentScope = "CurrentUser"

    $importedModule = Get-Module -Name AMA.ALZ
    $isDevelopmentModule = ($null -ne $importedModule -and $importedModule.Version -eq "0.1.0")

    if ((-not $CheckVersion) -or $isDevelopmentModule) {
        Write-Verbose "Skipping AMA.ALZ module version check"

        if($isDevelopmentModule) {
            $results += @{
                message = "AMA.ALZ module version is 0.1.0. Skipping version check as this is a development module."
                result  = "Warning"
            }
        } elseif (-not $CheckVersion) {
            $results += @{
                message = "AMA.ALZ module version check was skipped as 'AmaAlzModuleVersion' was not included in Checks."
                result  = "Warning"
            }
        }
    } else {
        # Check if latest AMA.ALZ module is installed
        Write-Verbose "Checking AMA.ALZ module version"
        $alzModuleCurrentVersion = Get-InstalledPSResource -Name AMA.ALZ 2>$null | Select-Object -Property Name, Version | Sort-Object Version -Descending | Select-Object -First 1
        if($null -eq $alzModuleCurrentVersion) {
            Write-Verbose "AMA.ALZ module not found in CurrentUser scope, checking AllUsers scope"
            $alzModuleCurrentVersion = Get-InstalledPSResource -Name AMA.ALZ -Scope AllUsers 2>$null | Select-Object -Property Name, Version | Sort-Object Version -Descending | Select-Object -First 1
            if($null -ne $alzModuleCurrentVersion) {
                Write-Verbose "AMA.ALZ module found in AllUsers scope"
                $currentScope = "AllUsers"
            }
        }

        if($null -eq $alzModuleCurrentVersion) {
            if($AllowContinueOnFailure.IsPresent) {
                $results += @{
                    message = "AMA.ALZ module is not correctly installed. Please install the latest version using 'Install-PSResource -Name AMA.ALZ'. Continuing as -destroy flag is set."
                    result  = "Warning"
                }
            } else {
                $results += @{
                    message = "AMA.ALZ module is not correctly installed. Please install the latest version using 'Install-PSResource -Name AMA.ALZ'."
                    result  = "Failure"
                }
                $hasFailure = $true
            }
        }

        $alzModuleLatestVersion = Find-PSResource -Name AMA.ALZ
        if ($null -ne $alzModuleCurrentVersion) {
            if ($alzModuleCurrentVersion.Version -lt $alzModuleLatestVersion.Version) {
                if($AllowContinueOnFailure.IsPresent) {
                    $results += @{
                        message = "AMA.ALZ module is not the latest version. Your version: $($alzModuleCurrentVersion.Version), Latest version: $($alzModuleLatestVersion.Version). Please update to the latest version using 'Update-PSResource -Name AMA.ALZ'. Continuing as -destroy flag is set."
                        result  = "Warning"
                    }
                } else {
                    $results += @{
                        message = "AMA.ALZ module is not the latest version. Your version: $($alzModuleCurrentVersion.Version), Latest version: $($alzModuleLatestVersion.Version). Please update to the latest version using 'Update-PSResource -Name AMA.ALZ'."
                        result  = "Failure"
                    }
                    $hasFailure = $true
                }
            } else {
                if($importedModule.Version -lt $alzModuleLatestVersion.Version) {
                    Write-Verbose "Imported AMA.ALZ module version ($($importedModule.Version)) is older than the latest installed version ($($alzModuleLatestVersion.Version)), re-importing module"

                    if($AllowContinueOnFailure.IsPresent) {
                        $results += @{
                            message = "AMA.ALZ module has the latest version installed, but not imported. Imported version: ($($importedModule.Version)). Please re-import the module using 'Remove-Module -Name AMA.ALZ; Import-Module -Name AMA.ALZ -Global' to use the latest version. Continuing as -destroy flag is set."
                            result  = "Warning"
                        }
                    } else {
                        $results += @{
                            message = "AMA.ALZ module has the latest version installed, but not imported. Imported version: ($($importedModule.Version)). Please re-import the module using 'Remove-Module -Name AMA.ALZ; Import-Module -Name AMA.ALZ -Global' to use the latest version."
                            result  = "Failure"
                        }
                        $hasFailure = $true
                    }
                } else {
                    $results += @{
                        message = "AMA.ALZ module is the latest version ($($alzModuleCurrentVersion.Version))."
                        result  = "Success"
                    }
                }
            }
        }
    }

    return @{
        Results      = $results
        HasFailure   = $hasFailure
        CurrentScope = $currentScope
    }
}
