# OpenNebula Windows Context Script
# Enhanced to allow assigning specific drive letters to disks via TARGET attribute.

param()

$ErrorActionPreference = "Stop"
$logFile = "C:\ProgramData\OneCloud\context.log"

function Write-Log {
    param([string]$Message)
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$time - $Message" | Out-File -FilePath $logFile -Encoding ASCII -Append
}

Write-Log "Starting context script"

# Context ISO is typically mounted as D: or E: - try common paths
$contextPaths = @("D:\context.sh", "E:\context.sh", "F:\context.sh")
$contextFile = $null
foreach ($path in $contextPaths) {
    if (Test-Path $path) {
        $contextFile = $path
        break
    }
}

if (-not $contextFile) {
    Write-Log "Context file not found"
    exit 1
}

Write-Log "Reading context from $contextFile"

# Parse context.sh (simple key=value lines)
$context = @{}
Get-Content $contextFile | ForEach-Object {
    if ($_ -match "^([A-Za-z_][A-Za-z0-9_]*)=(.*)$") {
        $key = $matches[1]
        $value = $matches[2].Trim('"')
        $context[$key] = $value
    }
}

# Check for TARGET overrides per disk
# Expects variables like TARGET_VDA="D" or similar. We'll iterate over all disks.
# Disks are defined as DISK_ID, but we need to associate TARGET with specific disk.
# Standard OpenNebula context provides DISK_ID and TARGET for each disk (e.g., TARGET for context ISO).
# We'll look for TARGET variables that are a single letter (Windows drive letter).

$driveLetterOverrides = @{}
foreach ($key in $context.Keys) {
    if ($key -match "^TARGET_(.+)$") {
        $diskId = $matches[1]
        $value = $context[$key]
        # If value is a single letter, it's a drive letter override
        if ($value -match "^[A-Za-z]$") {
            $driveLetterOverrides[$diskId] = $value.ToUpper()
        }
    }
}

Write-Log "Drive letter overrides: $($driveLetterOverrides | Out-String)"

# Now we need to apply these overrides using Get-Partition/Set-Partition.
# For simplicity, we assume that disks are already attached and have a drive letter.
# We'll wait a bit for disk initialization.
Start-Sleep -Seconds 5

# Get all disk partitions and their current drive letters
$partitions = Get-Partition -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -ne $null -and $_.DriveLetter -ne '' }

# We need to map disk ID to partition. Without additional info, we use heuristics.
# Option: Use disk number from OpenNebula context (DISK_ID -> disk index). 
# We'll assume each disk ID corresponds to a physical disk number (starting from 0).
# Context ISO is usually last disk. We'll trust user mapping.
foreach ($entry in $driveLetterOverrides.GetEnumerator()) {
    $diskId = $entry.Key
    $targetLetter = $entry.Value
    Write-Log "Processing override for disk ID $diskId to letter $targetLetter"

    # Try to find disk by number (disk ID as number)
    $diskNum = [int]::TryParse($diskId, [ref]0) ? [int]$diskId : -1
    if ($diskNum -ge 0) {
        $disk = Get-Disk -Number $diskNum -ErrorAction SilentlyContinue
        if ($disk) {
            $partition = $disk | Get-Partition -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -ne $null }
            if ($partition) {
                $currentLetter = $partition.DriveLetter
                if ($currentLetter -ne $targetLetter) {
                    Write-Log "Changing drive letter from $currentLetter to $targetLetter on disk $diskNum"
                    try {
                        # Remove current letter first
                        $partition | Set-Partition -NoDriveLetter
                        # Assign new letter (use mountvol to avoid issues with Set-Partition)
                        mountvol "$($targetLetter):\" "\\?\Volume{$($partition.Guid)}" /L
                        Write-Log "Successfully changed drive letter to $targetLetter"
                    } catch {
                        Write-Log "Failed to change drive letter: $_"
                    }
                } else {
                    Write-Log "Drive letter already $targetLetter, skipping"
                }
            } else {
                Write-Log "No partition with drive letter found on disk $diskNum"
            }
        } else {
            Write-Log "Disk number $diskNum not found"
        }
    } else {
        Write-Log "Invalid disk ID: $diskId"
    }
}

Write-Log "Context script completed"
