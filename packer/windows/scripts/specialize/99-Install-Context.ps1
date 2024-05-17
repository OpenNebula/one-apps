# Get the path to the MSI installer
$InstallerPath = Get-ChildItem -Path "A:\one-context-*.msi" | Select-Object -ExpandProperty FullName
# Run msiexec
Start-Process -FilePath msiexec.exe -ArgumentList "/i", $InstallerPath, "/qn" -Wait
exit 0