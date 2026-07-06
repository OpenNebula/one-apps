<#
.SYNOPSIS
Windows context initialization script with drive letter assignment support.
.DESCRIPTION
This script extends the standard OpenNebula context initialization to allow
assigning specific drive letters to the context ISO (via CONTEXT_TARGET)
and to data disks (via DISK_<id>_DRIVE_LETTER).
The driver letters are set using PowerShell cmdlets.
Assumes script is run with administrative privileges.
#>

#Requires -RunAsAdministrator

# Function: Set-VolumeDriveLetter
# Changes drive letter for a volume (e.g., CD-ROM)
function Set-VolumeDriveLetter {
    param(
        [string]$VolumeId,
        [string]$DesiredLetter
    )
    try {
        $volume = Get-Volume | Where-Object { $_.DriveLetter -eq $VolumeId -or $_.Path -eq $VolumeId } | Select-Object -First 1
        if (-not $volume) {
            Write-Warning "Volume not found with identifier '$VolumeId'"
            return
        }
        $currentLetter = $volume.DriveLetter
        if (-not $currentLetter) {
            Write-Warning "Volume does not have a drive letter assigned"
            return
        }
        if ($currentLetter -eq $DesiredLetter) {
            Write-Host "Volume already has drive letter $DesiredLetter"
            return
        }
        Set-Volume -DriveLetter $currentLetter -NewDriveLetter $DesiredLetter -ErrorAction Stop
        Write-Host "Changed drive letter of volume from $currentLetter to $DesiredLetter"
    } catch {
        Write-Error "Failed to set drive letter for volume: $_"
    }
}

# Function: Set-DiskDriveLetter
# Changes drive letter for a partition on a specific disk identified by serial number.
function Set-DiskDriveLetter {
    param(
        [int]$DiskId,
        [string]$DesiredLetter
    )
    try {
        $disk = Get-Disk | Where-Object { $_.SerialNumber -eq $DiskId.ToString() } | Select-Object -First 1
        if (-not $disk) {
            Write-Warning "Disk with serial $DiskId not found"
            return
        }
        $partition = $disk | Get-Partition | Where-Object { $_.DriveLetter } | Select-Object -First 1
        if (-not $partition) {
            Write-Warning "No partition with drive letter found on disk $DiskId"
            return
        }
        $currentLetter = $partition.DriveLetter
        if ($currentLetter -eq $DesiredLetter) {
            Write-Host "Disk $DiskId already has drive letter $DesiredLetter"
            return
        }
        Set-Partition -DriveLetter $currentLetter -NewDriveLetter $DesiredLetter -ErrorAction Stop
        Write-Host "Changed drive letter of disk $DiskId from $currentLetter to $DesiredLetter"
    } catch {
        Write-Error "Failed to set drive letter for disk $DiskId : $_"
    }
}

# --- Main logic ---
# This section should be placed after the context ISO is mounted and context variables are loaded
# Context variables are expected to be available as environment variables (e.g., $env:CONTEXT_TARGET)

# 1. Handle context ISO drive letter (attribute CONTEXT_TARGET)
$contextTarget = $env:CONTEXT_TARGET
if ($contextTarget -and ($contextTarget -match '^[A-Za-z]$')) {
    $desiredLetter = $contextTarget.ToUpper()
    # Find the CD-ROM drive (context ISO is typically attached as CD-ROM)
    $cdrom = Get-Volume | Where-Object { $_.DriveType -eq 'CD-ROM' } | Select-Object -First 1
    if ($cdrom) {
        Set-VolumeDriveLetter -VolumeId $cdrom.DriveLetter -DesiredLetter $desiredLetter
    } else {
        Write-Warning "No CD-ROM drive found for context ISO"
    }
} else {
    Write-Host "CONTEXT_TARGET not set or invalid (single letter expected)"
}

# 2. Handle data disk drive letters (attribute DISK_<id>_DRIVE_LETTER)
$diskEnv = Get-ChildItem Env: | Where-Object { $_.Name -match '^DISK_(\d+)_DRIVE_LETTER$' }
foreach ($entry in $diskEnv) {
    $match = [regex]::Match($entry.Name, '^DISK_(\d+)_DRIVE_LETTER$')
    if ($match.Success) {
        $diskId = [int]$match.Groups[1].Value
        $desiredLetter = $entry.Value
        if ($desiredLetter -match '^[A-Za-z]$') {
            $desiredLetter = $desiredLetter.ToUpper()
            Set-DiskDriveLetter -DiskId $diskId -DesiredLetter $desiredLetter
        } else {
            Write-Warning "Invalid drive letter value for disk $diskId : $desiredLetter (single letter expected)"
        }
    }
}

<#
NOTES:
- This script assumes that the disk serial numbers match the OpenNebula disk IDs (e.g., disk 0 -> serial "0").
- The script should be run after all disks are attached and the context ISO is mounted.
- Requires PowerShell 5.0+ for Set-Volume and Set-Partition cmdlets.
#>
