# Get the drive letter for the CD-ROM drive with VirtIO drivers
$DriveLetter = Get-WmiObject Win32_CDRomDrive | Where-Object VolumeName -like virtio-win-* | Select-Object -ExpandProperty Drive
# Prepare arguments for Start-Process
$ProcessOptions = @{
    "FilePath"      = "$DriveLetter\virtio-win-guest-tools.exe";
    "ArgumentList" = @("/install", "/quiet");
    "Wait"          = $true
}
# Run te installer
Start-Process @ProcessOptions