# Get the drive letter for the CD-ROM drive with VirtIO drivers
$DriveLetter = Get-WmiObject Win32_CDRomDrive | Where-Object VolumeName -like virtio-win-* | Select-Object -ExpandProperty Drive
# Get the installer executable path
$InstallerExecutablePath = "$DriveLetter\virtio-win-guest-tools.exe"
# Run the installer
& $InstallerExecutablePath /install /quiet
exit 0