<#
  Assign drive letters to context ISO and additional disks.
  Reads environment variables set by OpenNebula context:
    CONTEXT_DRIVE_LETTER  - letter for context ISO (e.g., "Z")
    DISK<index>_DRIVE_LETTER - letter for additional disk (e.g., DISK1_DRIVE_LETTER="D")
  Indexing: DISK0 is assumed to be the OS disk (ignored).
  Requires administrative privileges.
  Logs to C:\Windows\Temp\context-drive-letter.log
#>

$logFile = "C:\Windows\Temp\context-drive-letter.log"
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] $Message"
    Add-Content -Path $logFile -Value $entry
}

Write-Log "Starting drive letter assignment script."

# Wait for disk subsystem to be ready (up to 120 seconds)
$timeout = 120
$elapsed = 0
$ready = $false
while (-not $ready -and $elapsed -lt $timeout) {
    try {
        $disks = Get-Disk -ErrorAction Stop
        if ($disks.Count -gt 0) {
            $ready = $true
        }
    } catch {
        # Disk cmdlets may not be available initially
    }
    if (-not $ready) {
        Start-Sleep -Seconds 5
        $elapsed += 5
    }
}
if (-not $ready) {
    Write-Log "ERROR: Disks did not become available within $timeout seconds."
    exit 1
}
Write-Log "Disk subsystem is ready ($($disks.Count) disks found)."

# --- Helper function to change drive letter for a partition ---
function Set-DriveLetter {
    param(
        [Parameter(Mandatory)]
        [string]$TargetLetter,
        [Parameter(Mandatory)]
        [uint32]$DiskNumber,
        [Parameter(Mandatory)]
        [uint32]$PartitionNumber
    )
    try {
        $partition = Get-Partition -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -ErrorAction Stop
        if ($partition.DriveLetter) {
            Write-Log "Partition ${DiskNumber}:${PartitionNumber} currently has letter $($partition.DriveLetter). Changing to $TargetLetter."
            # Remove existing letter first
            Remove-PartitionAccessPath -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -AccessPath "$($partition.DriveLetter):" -ErrorAction Stop
        }
        # Check if target letter is free (no drive currently using it)
        $existingDrive = Get-Partition -DriveLetter $TargetLetter -ErrorAction SilentlyContinue
        if ($existingDrive) {
            Write-Log "WARNING: Drive letter $TargetLetter is already in use by Disk $($existingDrive.DiskNumber) Partition $($existingDrive.PartitionNumber). Skipping."
            return
        }
        Add-PartitionAccessPath -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -AccessPath "$TargetLetter": -ErrorAction Stop
        Write-Log "Successfully set drive letter $TargetLetter for Disk $DiskNumber Partition $PartitionNumber."
    } catch {
        Write-Log "ERROR: Failed to set drive letter $TargetLetter for Disk $DiskNumber Partition $PartitionNumber : $_"
    }
}

# --- Process CONTEXT_DRIVE_LETTER ---
$contextLetter = [Environment]::GetEnvironmentVariable("CONTEXT_DRIVE_LETTER")
if ($contextLetter) {
    Write-Log "Context drive letter requested: $contextLetter."
    # Find context ISO: a CD/DVD drive containing context.sh (or context.iso marker?)
    $cdroms = Get-CDDrive -ErrorAction SilentlyContinue | Where-Object { $_.Drive -and $_.MediaLoaded }
    # Simpler: iterate over all CD/DVD drives (Get-Volume with DriveType CD-ROM)
    $contextDrive = $null
    $volumes = Get-Volume | Where-Object { $_.DriveType -eq "CD-ROM" -and $_.DriveLetter }
    foreach ($vol in $volumes) {
        $drivePath = $vol.DriveLetter + ":"
        if (Test-Path "$drivePath\context.sh") {
            $contextDrive = $vol
            break
        }
    }
    if (-not $contextDrive) {
        Write-Log "WARNING: Could not find context ISO drive (no CD-ROM with context.sh). Skipping CONTEXT_DRIVE_LETTER."
    } else {
        $diskNumber = (Get-Disk | Where-Object { $_.Number -eq (Get-Partition -DriveLetter $contextDrive.DriveLetter).DiskNumber }).Number
        $partitionNumber = (Get-Partition -DriveLetter $contextDrive.DriveLetter).PartitionNumber
        Set-DriveLetter -TargetLetter $contextLetter -DiskNumber $diskNumber -PartitionNumber $partitionNumber
    }
} else {
    Write-Log "No CONTEXT_DRIVE_LETTER set."
}

# --- Process DISK<index>_DRIVE_LETTER for additional disks ---
try {
    # Get system disk number (disk containing C:\)
    $systemDiskNumber = (Get-Partition -DriveLetter C).DiskNumber
    Write-Log "System disk is Number $systemDiskNumber."
} catch {
    Write-Log "WARNING: Could not get system disk number (C: not found). Skipping additional disk processing."
    $systemDiskNumber = -1
}

if ($systemDiskNumber -ge 0) {
    # Get all non-CD-ROM, non-system disks
    $additionalDisks = Get-Disk | Where-Object {
        $_.Number -ne $systemDiskNumber -and
        $_.MediaType -ne "DVD/CD-ROM" -and
        $_.OperationalStatus -eq "Online"
    } | Sort-Object Number
    Write-Log "Found $($additionalDisks.Count) additional disk(s)."
    for ($i = 0; $i -lt $additionalDisks.Count; $i++) {
        $varName = "DISK$($i + 1)_DRIVE_LETTER"  # DISK1, DISK2, ...
        $letter = [Environment]::GetEnvironmentVariable($varName)
        if ($letter) {
            Write-Log "Variable $varName = $letter. Applying to disk index $i (Disk Number $($additionalDisks[$i].Number))."
            # Get the first partition that can accept a drive letter (usually first partition)
            $partitions = Get-Partition -DiskNumber $additionalDisks[$i].Number | Where-Object { $_.Type -ne 'Reserved' -and -not $_.DriveLetter } | Sort-Object PartitionNumber
            if ($partitions.Count -eq 0) {
                $partitions = Get-Partition -DiskNumber $additionalDisks[$i].Number | Where-Object { $_.Type -ne 'Reserved' } | Sort-Object PartitionNumber
            }
            if ($partitions.Count -gt 0) {
                Set-DriveLetter -TargetLetter $letter -DiskNumber $additionalDisks[$i].Number -PartitionNumber $partitions[0].PartitionNumber
            } else {
                Write-Log "WARNING: No eligible partition on Disk $($additionalDisks[$i].Number) to assign letter $letter."
            }
        } else {
            Write-Log "No $varName set."
        }
    }
}

Write-Log "Drive letter assignment completed."