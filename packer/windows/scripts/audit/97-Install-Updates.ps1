$ModuleName = "PSWindowsUpdate"
Write-Host "Finding $ModuleName CD-ROM"
$DriveLetter = Get-WmiObject Win32_CDRomDrive | Where-Object VolumeName -eq $ModuleName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Drive
if (!$DriveLetter) {
    throw "CD-ROM labeled $ModuleName not found"
}
Write-Host "CD-ROM drive letter: $DriveLetter"
$ModulePath = Join-Path -Path $DriveLetter -ChildPath "PSWindowsUpdate"
Write-Host "Importing module from $ModulePath"
if (!(Test-Path -Path $ModulePath)) {
    throw "Module not found"
}
try {
    Import-Module -Name $ModulePath -ErrorAction Stop
    Write-Host "Module imported successfully"
}
catch {
    throw "Failed to import module: $_"
}
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