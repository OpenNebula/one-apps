exit 0
Install-PackageProvider -Name NuGet -Force
Install-Module -Name PSWindowsUpdate -Force
Import-Module PSWindowsUpdate
Get-WindowsUpdate -MicrosoftUpdate -Install -AcceptAll -IgnoreReboot -NotTitle preview
if ((Get-WURebootStatus -Silent) -eq $true) {
    exit 2
}
else {
    exit 0 
}