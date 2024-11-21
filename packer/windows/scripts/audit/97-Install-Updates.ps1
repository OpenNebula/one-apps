$DriveLetter = Get-WmiObject Win32_CDRomDrive | Where-Object VolumeName -eq "PSWindowsUpdate" | Select-Object -ExpandProperty Drive
$ModulePath = Join-Path -Path $DriveLetter -ChildPath "PSWindowsUpdate"
Import-Module -Name $ModulePath -ErrorAction Stop
Get-WindowsUpdate -MicrosoftUpdate -Install -AcceptAll -IgnoreReboot -NotTitle preview
if ((Get-WURebootStatus -Silent) -eq $true) {
    exit 2
}
else {
    exit 0
}