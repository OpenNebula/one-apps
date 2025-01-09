Write-Host "Checking if OpenSSH Server is available for this Windows version"
$FeatureName = "OpenSSH.Server~~~~0.0.1.0"

# Check if the feature is available for this Windows version
$oldErrorActionPreference = $ErrorActionPreference
# The -ErrorAction parameter produced error messages, so we change the preference
$ErrorActionPreference = "SilentlyContinue"
$Capability = Get-WindowsCapability -Online -Name $FeatureName
$ErrorActionPreference = $oldErrorActionPreference

# Check if installation is possible
if ($Capability.Name) {
     Write-Host "Feature $FeatureName is supported."
    
    # Check if the feauture is installed
    if ($Capability.State -eq "Installed") {
        Write-Host "Feature $FeatureName is already installed"
        exit 0
    }

    # Install the feauture
    Write-Host "Installing $FeatureName"
    Add-WindowsCapability -Online -Name $FeatureName
    exit 0
}

# Feature is not supported
Write-Host "Feature $FeatureName is not supported on this Windows version"
exit 0