# Context.ps1 - Windows context script with drive letter assignment
# This script runs at VM boot to apply OpenNebula context configuration
# and optionally assign specific drive letters to disks based on the TARGET attribute.

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

# ----- Helper functions -----

function Parse-ContextFile {
    param([string]$FilePath)
    $vars = @{}
    if (Test-Path $FilePath) {
        Get-Content $FilePath | ForEach-Object {
            if ($_ -match '^export\s+(\w+)=(.*)$') {
                $name = $matches[1]
                $value = $matches[2] -replace '^"|"$', '' -replace "^'|'$", ''
                $vars[$name] = $value
            }
        }
    }
    return $vars
}

function Get-DriveLetterForTarget {
    param([string]$Target)
    if ($Target -match '^[A-Za-z]$') {
        return $Target.ToUpper()
    }
    return $null
}

function Assign-DriveLetter {
    param(
        [string]$CurrentDriveLetter,
        [string]$NewDriveLetter,
        [string]$DiskSerial = $null
    )
    # Helper function to get partition by drive letter or serial
    function Get-PartitionForLetterOrSerial {
        param([string]$Letter, [string]$Serial)
        $partitions = Get-Partition -ErrorAction SilentlyContinue
        if ($Letter) {
            $partitions = $partitions | Where-Object { $_.DriveLetter -eq $Letter }
        }
        if ($Serial) {
            $disk = Get-Disk -ErrorAction SilentlyContinue | Where-Object { $_.SerialNumber -eq $Serial }
            if ($disk) {
                $partitions = $disk | Get-Partition -ErrorAction SilentlyContinue
            } else {
                $partitions = $null
            }
        }
        return $partitions | Select-Object -First 1
    }

    try {
        $partition = Get-PartitionForLetterOrSerial -Letter $CurrentDriveLetter -Serial $DiskSerial
        if (-not $partition) {
            Write-Warning "Cannot find partition for current letter '$CurrentDriveLetter' or serial '$DiskSerial'"
            return
        }
        # Check if new letter is already in use; if so, move it away first
        $existing = Get-Partition -DriveLetter $NewDriveLetter -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Host "Drive letter $NewDriveLetter is already in use. Will reassign after setting new letter."
            # Temporarily move existing letter to a free letter
            $free = (65..90 | ForEach-Object { [char]$_ }) -notin (Get-Partition).DriveLetter
            if ($free.Count -eq 0) {
                Write-Error "No free drive letters available"
                return
            }
            Set-Partition -DriveLetter $NewDriveLetter -NewDriveLetter $free[0]
        }
        Set-Partition -InputObject $partition -NewDriveLetter $NewDriveLetter
        Write-Host "Assigned drive letter $NewDriveLetter to partition (serial $DiskSerial)"
    } catch {
        Write-Warning "Failed to set drive letter: $_"
    }
}

# ----- Main script -----

Write-Host "OpenNebula Context Script (Windows) - Starting"

# Determine context ISO drive letter (the drive this script is running from)
$contextDrive = (Get-Location).Drive.Root.TrimEnd('\\')
Write-Host "Context ISO mounted at drive: $contextDrive"

# Parse context.sh from context ISO
$contextFilePath = "${contextDrive}\\context.sh"
$contextVars = Parse-ContextFile -FilePath $contextFilePath
Write-Host "Context variables loaded"

# Drive letter assignment for context ISO (DISK0) based on TARGET
$ctxTarget = $null
if ($contextVars.ContainsKey('ONE_DISK0_TARGET')) {
    $ctxTarget = $contextVars['ONE_DISK0_TARGET']
} elseif ($contextVars.ContainsKey('DISK0_TARGET')) {
    $ctxTarget = $contextVars['DISK0_TARGET']
}
if ($ctxTarget) {
    $letter = Get-DriveLetterForTarget -Target $ctxTarget
    if ($letter -and ($letter -ne $contextDrive)) {
        Write-Host "Assigning drive letter $letter to context ISO (currently $contextDrive)"
        Assign-DriveLetter -CurrentDriveLetter $contextDrive -NewDriveLetter $letter
        $contextDrive = $letter  # update for further use
    }
}

# Iterate over all disks (DISK1, DISK2, ...) and assign letters
$diskIndex = 1
while ($true) {
    $targetVar = "ONE_DISK${diskIndex}_TARGET"
    $serialVar = "ONE_DISK${diskIndex}_SERIAL"
    $target = $null
    $serial = $null
    if ($contextVars.ContainsKey($targetVar)) {
        $target = $contextVars[$targetVar]
    }
    if ($contextVars.ContainsKey($serialVar)) {
        $serial = $contextVars[$serialVar]
    }
    if (-not $target -and -not $serial) {
        # Also try without ONE_ prefix
        $targetVar = "DISK${diskIndex}_TARGET"
        $serialVar = "DISK${diskIndex}_SERIAL"
        if ($contextVars.ContainsKey($targetVar)) {
            $target = $contextVars[$targetVar]
        }
        if ($contextVars.ContainsKey($serialVar)) {
            $serial = $contextVars[$serialVar]
        }
    }
    if (-not $target -and -not $serial) {
        break  # no more disks
    }
    $letter = Get-DriveLetterForTarget -Target $target
    if ($letter) {
        Write-Host "Attempting to assign drive letter $letter to disk $diskIndex (serial: $serial)"
        Assign-DriveLetter -CurrentDriveLetter $null -NewDriveLetter $letter -DiskSerial $serial
    }
    $diskIndex++
}

# ----- Continue with other context configuration (hostname, keys, etc.) -----
# Below is a placeholder for the rest of the context script.
# In a real deployment, include standard actions like setting hostname, adding SSH keys, etc.

Write-Host "Context script completed."