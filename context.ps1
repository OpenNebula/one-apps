# OpenNebula Windows Context Script with Drive Letter Assignment
# Modified to support setting drive letters via environment variables DISK{X}_TARGET

param(
    [string]$ContextIsoPath = "C:\Context.iso"
)

# Ensure script runs as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator."
    exit 1
}

# Mount context ISO and read variables (simplified - adapt to your OpenNebula agent)
if (Test-Path $ContextIsoPath) {
    $mountDrive = (Mount-DiskImage -ImagePath $ContextIsoPath -PassThru | Get-Volume).DriveLetter + ":"
    $contextFile = "$mountDrive\context.sh"
    if (Test-Path $contextFile) {
        # Parse key=value lines and set as environment variables for this session
        Get-Content $contextFile | ForEach-Object {
            if ($_ -match "^([^=]+)=(.*)$") {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                Set-Item -Path "Env:$key" -Value $value
            }
        }
    }
    Dismount-DiskImage -ImagePath $ContextIsoPath
}

# Function to assign drive letters based on target environment variables
function Set-DriveLettersFromTargets {
    # Get all physical disks and their partitions with drive letters
    $disks = Get-Disk | Where-Object { $_.OperationalStatus -eq "Online" }
    
    foreach ($disk in $disks) {
        $diskNumber = $disk.Number
        $envVar = "DISK${diskNumber}_TARGET"
        $targetLetter = [Environment]::GetEnvironmentVariable($envVar, "Process")
        
        if (-not [string]::IsNullOrEmpty($targetLetter)) {
            # Validate target letter: single uppercase letter
            if ($targetLetter -match '^[A-Z]$') {
                # Get the current partition with a drive letter
                $partition = Get-Partition -DiskNumber $diskNumber | Where-Object { $_.DriveLetter -ne $null }
                if ($partition -ne $null) {
                    $currentLetter = $partition.DriveLetter
                    if ($currentLetter -ne $targetLetter) {
                        try {
                            # Check if target letter is already in use
                            $existingDrive = Get-Partition -DriveLetter $targetLetter -ErrorAction SilentlyContinue
                            if ($existingDrive -ne $null) {
                                # Swap letters by moving existing to a temporary letter
                                $tempLetter = [char]('Z' -le [int][char]$currentLetter ? 'Y' : 'Z')
                                Write-Warning "Drive letter $targetLetter is in use. Swapping with $currentLetter via temp $tempLetter."
                                Set-Partition -DriveLetter $targetLetter -NewDriveLetter $tempLetter
                                Set-Partition -DriveLetter $currentLetter -NewDriveLetter $targetLetter
                                Set-Partition -DriveLetter $tempLetter -NewDriveLetter $currentLetter
                            } else {
                                Set-Partition -DriveLetter $currentLetter -NewDriveLetter $targetLetter
                            }
                            Write-Output "Disk $diskNumber: Changed drive letter from $currentLetter to $targetLetter."
                        } catch {
                            Write-Error "Failed to change drive letter for disk $diskNumber: $_"
                        }
                    }
                } else {
                    Write-Warning "Disk $diskNumber has no partition with a drive letter."
                }
            } else {
                Write-Warning "Invalid TARGET value for disk $diskNumber: '$targetLetter'. Must be a single uppercase letter (A-Z)."
            }
        }
    }
}

# Execute drive letter assignment
Set-DriveLettersFromTargets

# Continue with other context initialization tasks...
Write-Output "Context initialization completed."