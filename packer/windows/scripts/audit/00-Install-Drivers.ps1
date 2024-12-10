# Get the drive letter for the CD-ROM drive with VirtIO drivers
Write-host "Installing VirtIO drivers"
$DriveLetter = Get-WmiObject Win32_CDRomDrive | Where-Object VolumeName -like virtio-win-* | Select-Object -ExpandProperty Drive
if (!$DriveLetter) {
    throw "VirtIO CD-ROM not found"
}
Write-Host "CD-ROM drive letter: $DriveLetter"
# Get the installer executable path
$InstallerExecutablePath = Join-Path -Path $DriveLetter -ChildPath "virtio-win-guest-tools.exe"
Write-Host "Installer executable path: $InstallerExecutablePath"
if (!(Test-Path -Path $InstallerExecutablePath)) {
    throw "VirtIO Installer not found"
}
# Run the installer
Write-Host "Running installer"
$Process = Start-Process -FilePath $InstallerExecutablePath -ArgumentList "/install", "/quiet" -Wait -PassThru
$ExitCode = $Process.ExitCode
$ExpectedExitCode = 0
if ($ExitCode -ne $ExpectedExitCode) {
    throw "VirtIO driver installation failed with exit code: $ExitCode"
}
Write-Host "Installer finished with exit code: $ExitCode"
exit 0