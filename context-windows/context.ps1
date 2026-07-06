# OpenNebula Windows Context Script

# ... existing preamble and functions ...

function Set-DriveLetter {
    param(
        [string]$DeviceID,  # e.g., \\.\PHYSICALDRIVE1 or CDROM ID
        [string]$Letter
    )
    try {
        $Letter = $Letter.ToUpper().Trim(':') + ":"
        # Check if it's a CD/DVD drive
        $cdDrive = Get-WmiObject -Class Win32_CDROMDrive | Where-Object { $_.DeviceID -eq $DeviceID }
        if ($cdDrive) {
            $cdDrive.Drive = $Letter
            [void]$cdDrive.Put()
            Write-Output "Changed CD drive letter to $Letter"
            return
        }
        # Else treat as disk partition
        $partition = Get-Partition | Where-Object { $_.DiskNumber -eq (Get-Disk -DeviceId $DeviceID).Number } | Select-Object -First 1
        if ($partition) {
            if ($partition.DriveLetter) {
                Set-Partition -InputObject $partition -NewDriveLetter $Letter.Trim(':') -ErrorAction Stop
                Write-Output "Changed disk partition letter to $Letter"
            } else {
                Write-Warning "Partition has no drive letter to change."
            }
        } else {
            Write-Warning "No partition found for device $DeviceID"
        }
    } catch {
        Write-Error "Failed to set drive letter: $_"
    }
}

# Process each context disk
$contextDisks = Get-ContextDisks  # hypothetical function to list attached context disks
foreach ($disk in $contextDisks) {
    $target = $disk.TARGET
    if ($target -match '^[A-Za-z]$') {
        $desiredLetter = $target.ToUpper()
        # Wait for the volume to appear
        Start-Sleep -Seconds 2
        $drive = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 5 -or $_.DriveType -eq 3 } | Where-Object { $_.DeviceID -eq "$desiredLetter:" }
        if (-not $drive) {
            # Assume it's a new disk, need to identify its device
            $device = Get-WmiObject -Class Win32_DiskDrive | Where-Object { $_.SCSIBus -eq $disk.Bus -and $_.SCSILogicalUnit -eq $disk.LUN } | Select-Object -First 1
            if ($device) {
                Set-DriveLetter -DeviceID $device.DeviceID -Letter $desiredLetter
            }
        } else {
            Write-Output "Drive $desiredLetter: already exists."
        }
    }
}

# ... remaining context processing ...
