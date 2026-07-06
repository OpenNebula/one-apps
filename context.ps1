<#
.SYNOPSIS
  OpenNebula Windows context script.
.DESCRIPTION
  Processes context variables and assigns drive letters as specified by TARGET attributes.
  Supports:
    - CONTEXT_TARGET: Drive letter for the context ISO.
    - DISK_TARGET_<N>: Drive letter for additional data disks (by order of attachment).
  The script reads a context file (context.txt) from the context ISO or a local path.
#>

param(
    [string]$ContextFile = "C:\Program Files\OpenNebula\context.txt"
)

# Error handling
$ErrorActionPreference = "Stop"

function Read-ContextFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Warning "Context file not found: $Path"
        return @{}
    }
    $context = @{}
    Get-Content $Path | ForEach-Object {
        if ($_ -match "^\s*([^=]+)\s*=\s*(.+)\s*$") {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            $context[$key] = $value
        }
    }
    return $context
}

function Set-DriveLetter {
    param(
        [string]$PartitionId,
        [string]$NewLetter
    )
    $newLetter = $NewLetter.ToUpper()
    if ($newLetter -notmatch '^[A-Z]$') {
        Write-Warning "Invalid drive letter: $NewLetter. Must be a single letter A-Z."
        return
    }
    try {
        $partition = Get-Partition -PartitionNumber $PartitionId -ErrorAction Stop
        $currentLetter = $partition.DriveLetter
        if ($currentLetter -eq $newLetter) {
            Write-Output "Partition already has drive letter $newLetter, skipping."
            return
        }
        if ($currentLetter) {
            # Remove current letter first
            $partition | Set-Partition -NoDefaultDriveLetter -ErrorAction Stop
        }
        # Assign new letter
        $partition | Set-Partition -NewDriveLetter $newLetter -ErrorAction Stop
        Write-Output "Successfully set drive letter $newLetter for partition $PartitionId."
    } catch {
        Write-Error "Failed to set drive letter for partition $PartitionId : $_"
    }
}

function Get-OpticalDriveByLabel {
    param([string]$Label)
    $drives = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=5"
    foreach ($drive in $drives) {
        if ($drive.VolumeName -eq $Label) {
            return $drive.DeviceID -replace ':', ''
        }
    }
    return $null
}

function Get-DataDiskPartitions {
    # Return partitions of fixed drives, excluding system disk and optical drives
    $systemDrive = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
    $systemDiskIndex = $systemDrive.Index
    $opticalDriveLetters = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=5" | ForEach-Object { $_.DeviceID -replace ':', '' }
    $partitions = Get-Partition | Where-Object {
        $disk = Get-Disk -Number $_.DiskNumber -ErrorAction SilentlyContinue
        if (-not $disk) { return $false }
        # Exclude system disk (by index? better by partitioning style)
        $diskIsSystem = $disk.Number -eq $systemDiskIndex -or $disk.IsSystem -or $disk.IsBoot
        if ($diskIsSystem) { return $false }
        # Exclude optical drives
        if ($_.DriveLetter -and $opticalDriveLetters -contains $_.DriveLetter) { return $false }
        # Exclude reserved partitions (no drive letter usually)
        if (-not $_.DriveLetter -and -not $_.IsDataPartition) { return $false }
        return $true
    } | Sort-Object DiskNumber, PartitionNumber
    return $partitions
}

# Main script
$context = Read-ContextFile -Path $ContextFile
if ($context.Count -eq 0) {
    Write-Warning "No context variables found. Exiting."
    exit 0
}

# Process context ISO target
if ($context.ContainsKey('CONTEXT_TARGET')) {
    $targetLetter = $context['CONTEXT_TARGET'].ToUpper()
    Write-Output "Processing CONTEXT_TARGET=$targetLetter"
    $cdLetter = Get-OpticalDriveByLabel -Label 'CONTEXT'
    if ($cdLetter) {
        $cdPartition = Get-Partition -DriveLetter $cdLetter -ErrorAction SilentlyContinue
        if ($cdPartition) {
            Set-DriveLetter -PartitionId $cdPartition.PartitionNumber -NewLetter $targetLetter
        } else {
            Write-Warning "Could not find partition for CD drive letter $cdLetter."
        }
    } else {
        Write-Warning "No optical drive with label 'CONTEXT' found."
    }
}

# Process data disk targets
$diskTargets = @()
$context.Keys | Where-Object { $_ -match '^DISK_TARGET_(\d+)$' } | ForEach-Object {
    $index = [int]$matches[1]
    $letter = $context[$_].ToUpper()
    $diskTargets += @{ Index = $index; Letter = $letter }
}
# Sort by index
$diskTargets = $diskTargets | Sort-Object Index

if ($diskTargets.Count -gt 0) {
    $partitions = Get-DataDiskPartitions
    $partitionIndex = 0
    foreach ($target in $diskTargets) {
        if ($partitionIndex -lt $partitions.Count) {
            $partition = $partitions[$partitionIndex]
            Set-DriveLetter -PartitionId $partition.PartitionNumber -NewLetter $target.Letter
            $partitionIndex++
        } else {
            Write-Warning "Not enough data partitions for DISK_TARGET_$($target.Index). Need more disks attached."
        }
    }
}

Write-Output "Context script completed."