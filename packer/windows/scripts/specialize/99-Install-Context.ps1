# Get the path to the MSI installer
$InstallerPath = Get-ChildItem -Path "A:\one-context-*.msi" | Select-Object -ExpandProperty FullName
# Prepare arguments for Start-Process
$ProcessOptions = @{
    "FilePath"      = "msiexec.exe";
    "ArgumentList" = @("/i",$InstallerPath, "/qn");
    "Wait"          = $true
}
# Run msiexec
Start-Process @ProcessOptions   