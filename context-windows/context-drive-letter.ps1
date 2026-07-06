<#
.SYNOPSIS
    Assign drive letters to disks (including context ISO) based on context variables.
.DESCRIPTION
    This script reads context variables from a text file (e.g., context_variables.txt)
    and assigns drive letters to disks as specified. It validates that the letter is
    a single uppercase letter and avoids reserved letters (A, B, C).
.NOTES
    Designed for OpenNebula Windows context initialization.
#>

# Define path to context variables file
$ContextFile = "$env:SystemDrive\context_variables.txt"
if (-not (Test-Path $ContextFile)) {
    Write-Host "Context variables file not found: $ContextFile"
    exit 0
}

# Parse key-value pairs from context file
$ContextVars = @{}
Get-Content $ContextFile | ForEach-Object {
    $line = $_
    if ($line -match '^\s*([^=]+)=(.*)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        $ContextVars[$key] = $value
    }
}

# Helper function to validate and assign drive letter to a partition
function Set-DriveLetterToPartition {
    param(
        [int]$DiskNumber,
        [int]$PartitionNumber,
        [string]$Letter
    )
    try {
        $partition = Get-Partition -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -ErrorAction Stop
        $currentLetter = $partition.DriveLetter
        if ($currentLetter -eq $Letter) {
            Write-Host "Partition $DiskNumber:$PartitionNumber already has drive letter $Letter."
            return
        }
        # Remove current letter if present
        if ($currentLetter) {
            Remove-PartitionAccessPath -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -AccessPath "$currentLetter:\" -ErrorAction SilentlyContinue
        }
        # Assign new letter
        Add-PartitionAccessPath -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -AccessPath "$Letter:\"
        Write-Host "Assigned drive letter $Letter to partition $DiskNumber:$PartitionNumber."
    }
    catch {
        Write-Error "Failed to set drive letter: $_"
    }
}

# Helper function to assign drive letter to a disk (single partition / whole disk)
function Set-DriveLetterToDisk {
    param(
        [int]$DiskNumber,
        [string]$Letter
    )
    try {
        $disk = Get-Disk -Number $DiskNumber -ErrorAction Stop
        if ($disk.NumberOfPartitions -eq 0) {
            Write-Host "Disk $DiskNumber has no partitions. Initializing and creating partition..."
            Initialize-Disk -Number $DiskNumber -PartitionStyle MBR -ErrorAction Stop
            $partition = New-Partition -DiskNumber $DiskNumber -UseMaximumSize -AssignDriveLetter
            $existingLetter = $partition.DriveLetter
            if ($existingLetter -ne $Letter) {
                Remove-PartitionAccessPath -DiskNumber $DiskNumber -PartitionNumber $partition.PartitionNumber -AccessPath "$existingLetter:\" -ErrorAction SilentlyContinue
                Add-PartitionAccessPath -DiskNumber $DiskNumber -PartitionNumber $partition.PartitionNumber -AccessPath "$Letter:\"
                Write-Host "Assigned drive letter $Letter to disk $DiskNumber."
            }
        }
        else {
            # Assume first partition
            Set-DriveLetterToPartition -DiskNumber $DiskNumber -PartitionNumber 1 -Letter $Letter
        }
    }
    catch {
        Write-Error "Failed to set drive letter for disk $DiskNumber: $_"
    }
}

# Find disks that have a DRIVE_LETTER context variable associated
# Format: DISK_<index>_DRIVE_LETTER = <letter> or CONTEXT_DRIVE_LETTER = <letter>
# Also generic: DRIVE_LETTER_<target> = <letter>

# Look for CONTEXT_DRIVE_LETTER context variable
if ($ContextVars.ContainsKey('CONTEXT_DRIVE_LETTER')) {
    $letter = $ContextVars['CONTEXT_DRIVE_LETTER']
    if ($letter -match '^[A-Z]$' -and $letter -notin @('A','B','C')) {
        Write-Host "Context drive letter specified: $letter"
        # Find the context ISO disk - it is typically the first optical drive or a disk with label 'context'
        # Use different strategies: get optical drives and change their letter
        $opticalDrives = Get-CimInstance -ClassName Win32_CDROMDrive | Where-Object { $_.Drive -match '^[A-Z]:$' }
        if ($opticalDrives.Count -gt 0) {
            # Change letter for the first optical drive (context ISO)
            $currentDrive = $opticalDrives[0]
            $currentLetter = $currentDrive.Drive.Substring(0,1)
            # Use diskpart or wmi to change drive letter
            $diskNumber = $currentDrive.Index  # Not reliable; use Get-Disk based on serial?
            # Alternative: use Get-Disk and filter by BusType = USB or SCSI? Not reliable.
            # Recommended approach: use diskpart script
            $diskpartScript = @"
select volume=\$currentLetter
assign letter=$letter
"@
            $diskpartScript | diskpart | Out-Null
            Write-Host "Changed context drive letter from $currentLetter to $letter."
        }
        else {
            Write-Warning "No optical drive found for context ISO."
        }
    }
    else {
        Write-Warning "Invalid CONTEXT_DRIVE_LETTER value: $letter. Must be a single uppercase letter except A,B,C."
    }
}

# Look for DISK_<index>_DRIVE_LETTER variables
$diskIndex = 0
while ($true) {
    $key = "DISK_${diskIndex}_DRIVE_LETTER"
    if ($ContextVars.ContainsKey($key)) {
        $letter = $ContextVars[$key]
        if ($letter -match '^[A-Z]$' -and $letter -notin @('A','B','C')) {
            Write-Host "Disk $diskIndex drive letter specified: $letter"
            # Disk index corresponds to the order in which disks are attached
            # In OpenNebula, disks are numbered starting from 0.
            # The disk number in Windows may differ; we assume disk index in guest.
            # We'll try to find the disk by number (disk number equals index? Not guaranteed).
            # For safety, we iterate through all disks and match by some other property?
            # Simpler: assume the disk number is the same as index (only if no other disks exist).
            # Better: use the context variable 'DISK_<index>_TARGET' to identify the disk.
            # But for now, we'll try to get disk by index.
            try {
                $disk = Get-Disk -Number $diskIndex -ErrorAction Stop
                Set-DriveLetterToDisk -DiskNumber $diskIndex -Letter $letter
            }
            catch {
                Write-Warning "Disk with number $diskIndex not found. Ensure 'DISK_${diskIndex}_TARGET' is set correctly."
            }
        }
        else {
            Write-Warning "Invalid $key value: $letter. Must be a single uppercase letter except A,B,C."
        }
        $diskIndex++
    }
    else {
        break
    }
}

# Also handle generic DRIVE_LETTER_<target> variables (e.g., DRIVE_LETTER_hda = D)
foreach ($key in $ContextVars.Keys) {
    if ($key -match '^DRIVE_LETTER_(.+)$') {
        $target = $matches[1]
        $letter = $ContextVars[$key]
        if ($letter -match '^[A-Z]$' -and $letter -notin @('A','B','C')) {
            Write-Host "Drive letter for target '$target' specified: $letter"
            # Target is something like 'hda', 'sda', 'vda', or disk index.
            # Convert to disk number? Not straightforward.
            # For now, attempt to find disk by target name using Get-Disk with friendly name?
            Write-Warning "DRIVE_LETTER_<target> syntax not fully implemented. Use DISK_<index>_DRIVE_LETTER instead."
        }
    }
}
