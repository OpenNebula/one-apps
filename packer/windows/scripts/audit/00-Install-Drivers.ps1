# Get the drive letter for the CD-ROM drive with VirtIO drivers
Write-host "Installing VirtIO drivers"
$DriveLetter = Get-WmiObject Win32_CDRomDrive | Where-Object VolumeName -like virtio-win-* | Select-Object -ExpandProperty Drive
Write-Host "CD-ROM drive letter: $DriveLetter"
# Get the installer executable path
$InstallerExecutablePath = Join-Path -Path $DriveLetter -ChildPath "virtio-win-guest-tools.exe"
Write-Host "Installer executable path: $InstallerExecutablePath"
# Run the installer
Write-Host "Running installer"
Start-Process -FilePath $InstallerExecutablePath -ArgumentList "/install", "/quiet" -Wait
Write-Host "Installer finished"
exit 0