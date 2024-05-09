# Get the path to the MSI installer
$InstallerPath = Get-ChildItem -Path "A:\one-context-*.msi" | Select-Object -ExpandProperty FullName
# Run msiexec
& msiexec.exe /i $InstallerPath /qn
exit 0