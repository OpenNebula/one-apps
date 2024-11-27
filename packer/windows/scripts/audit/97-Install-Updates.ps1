Write-Host "Installing Windows updates"
$DriveLetter = Get-WmiObject Win32_CDRomDrive | Where-Object VolumeName -eq "PSWindowsUpdate" | Select-Object -ExpandProperty Drive
Write-Host "CD-ROM drive letter: $DriveLetter"
$ModulePath = Join-Path -Path $DriveLetter -ChildPath "PSWindowsUpdate"
Write-Host "Importing module from $ModulePath"
Import-Module -Name $ModulePath -ErrorAction Stop
Write-Host "Checking for Windows Updates"
Get-WindowsUpdate -MicrosoftUpdate -Install -AcceptAll -IgnoreReboot -NotTitle preview
Write-Host "Checking for pending reboot"
if ((Get-WURebootStatus -Silent) -eq $true) {
    Write-Host "Reboot required"
    exit 2
}
else {
    Write-Host "Update process finished, no reboot required"
    exit 0
}