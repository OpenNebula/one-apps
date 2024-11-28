Write-Host "Installing OneContext"
# Get the path to the MSI installer
$InstallerPath = Get-ChildItem -Path "A:\one-context-*.msi" | Select-Object -ExpandProperty FullName
# Run msiexec
Write-Host "Running MSI exec"
Start-Process -FilePath msiexec.exe -ArgumentList "/i", $InstallerPath, "/qn" -Wait
Write-Host "MSI finished"
# Disable OpenNebula coontext service during image creation
Write-Host "Disabling contextualization service"
Set-Service -Name "onecontext" -StartupType Disabled
exit 0