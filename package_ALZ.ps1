param(
    [string]$version,
    [string]$prerelease = ""
)

New-Item "AzureMigrate.ALZ" -ItemType Directory -Force
Copy-Item -Path "./src/Artifacts/*" -Destination "./AzureMigrate.ALZ" -Recurse -Exclude "ccReport", "testOutput"  -Force

Update-ModuleManifest -Path "./AzureMigrate.ALZ/AzureMigrate.ALZ.psd1" -ModuleVersion $version -Prerelease $prerelease