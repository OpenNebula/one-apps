Write-Host "Installing OneContext"
# Get the path to the MSI installer
$InstallerPath = Get-ChildItem -Path "A:\one-context-*.msi" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
if (!$InstallerPath) {
    throw "OneContext MSI installer not found"
}
# Run msiexec
Write-Host "Running MSI exec"
$Process = Start-Process -FilePath msiexec.exe -ArgumentList "/i", $InstallerPath, "/qn" -Wait -PassThru
$ExpectedExitCode = 0
$ExitCode = $Process.ExitCode
if ($ExitCode -ne $ExpectedExitCode) {
    throw "MSI exec failed with exit code: $ExitCode"
}
Write-Host "MSI finished successfully"
# Disable OpenNebula coontext service during image creation
Write-Host "Disabling contextualization service"
Set-Service -Name "onecontext" -StartupType Disabled
exit 0