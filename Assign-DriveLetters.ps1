<#
.SYNOPSIS
Reads context metadata and assigns drive letters to disks as specified.

.DESCRIPTION
This script reads a JSON file from the context drive containing disk definitions.
For each disk where the 'target' attribute is a single letter (e.g., 'D'),
it maps the Linux device name (e.g., 'sda', 'hdc') to a Windows disk number
and assigns the drive letter using Set-DriveLetter function.

The script assumes the context drive is known (e.g., from environment variable $CONTEXT_DRIVE).
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ContextFilePath
)

# Load Set-DriveLetter function
. .\Set-DriveLetter.ps1

function Get-WindowsDiskNumberFromLinuxDevice {
    param([string]$LinuxDevice)
    # Map Linux device names to Windows disk numbers.
    # Assumes order of attachment matches bus enumeration.
    # SCSI disks: sda=0, sdb=1, ... ; IDE disks: hda=0, hdb=1, ... ; CDROM: sr0, hdc
    # Heuristic: Get all disks, filter by bus type based on device name prefix.
    $disks = Get-Disk
    if ($LinuxDevice -match '^sd([a-z])$') {
        $index = $Matches[1].ToUpper()[0] - [char]'A'
        $scsiDisks = $disks | Where-Object BusType -eq 'SCSI' | Sort-Object Number
        if ($index -lt $scsiDisks.Count) {
            return $scsiDisks[$index].Number
        }
    }
    elseif ($LinuxDevice -match '^hd([a-z])$') {
        $index = $Matches[1].ToUpper()[0] - [char]'A'
        $ideDisks = $disks | Where-Object BusType -eq 'IDE' | Sort-Object Number
        if ($index -lt $ideDisks.Count) {
            return $ideDisks[$index].Number
        }
    }
    elseif ($LinuxDevice -match '^sr[0-9]+$') {
        $index = [int]($LinuxDevice -replace '^sr', '')
        $cdromDisks = $disks | Where-Object BusType -eq 'SCSI' -and MediaType -eq 'DVD' | Sort-Object Number
        if ($index -lt $cdromDisks.Count) {
            return $cdromDisks[$index].Number
        }
    }
    Write-Warning "Unable to map Linux device '$LinuxDevice' to a Windows disk number."
    return $null
}

# Read context JSON
if (-not (Test-Path $ContextFilePath)) {
    Write-Error "Context file not found: $ContextFilePath"
    exit 1
}

$context = Get-Content $ContextFilePath -Raw | ConvertFrom-Json

# Process each disk in the context
$disks = $context.disks
if (-not $disks) {
    Write-Output "No disks defined in context."
    exit 0
}

foreach ($disk in $disks) {
    $target = $disk.target
    if ($target -and $target -match '^[A-Z]$') {
        $linuxDevice = $disk.device  # e.g., 'sda', 'hdc'
        if (-not $linuxDevice) {
            Write-Warning "Disk has target '$target' but missing device name."
            continue
        }
        $diskNumber = Get-WindowsDiskNumberFromLinuxDevice -LinuxDevice $linuxDevice
        if ($diskNumber -ne $null) {
            # Assume partition number 1 for simplicity; could be refined.
            Set-DriveLetter -DiskNumber $diskNumber -PartitionNumber 1 -NewDriveLetter $target
        }
    }
}
