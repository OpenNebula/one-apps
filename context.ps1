$ErrorActionPreference = "Stop"

# Function to assign a drive letter to a partition
function Assign-DriveLetter {
    param(
        [Parameter(Mandatory=$true)]
        [string]$DiskId,
        [Parameter(Mandatory=$true)]
        [string]$DriveLetter
    )
    $partition = Get-Partition -DiskNumber $DiskId -ErrorAction SilentlyContinue | Where-Object { $_.Type -eq 'Basic' -or $_.Type -eq 'Unknown' }
    if (-not $partition) {
        Write-Host "No partition found on disk $DiskId. Skipping drive letter assignment."
        return
    }

    # If partition already has a drive letter, remove it first
    if ($partition.DriveLetter) {
        $partition | Remove-PartitionAccessPath -AccessPath $($partition.DriveLetter + ":") -ErrorAction SilentlyContinue
    }

    # Assign new drive letter
    try {
        $partition | Set-Partition -NewDriveLetter $DriveLetter -ErrorAction Stop
        Write-Host "Assigned drive letter $DriveLetter to disk $DiskId"
    } catch {
        Write-Host "Failed to assign drive letter $DriveLetter to disk $DiskId: $_"
    }
}

# Process context disk assignments
# The context variables are assumed to be available (e.g., from context.sh or environment)
# For each disk, we check if TARGET is a single letter

# Example: iterate over context variables (simplified)
# In real scenario, these would come from the context ISO's variables.txt or context.sh
$ctxDisks = @(
    @{ID="0"; TARGET="Z"},  # Context ISO assigned to Z:
    @{ID="1"; TARGET="D"}   # Data disk assigned to D:
)

foreach ($disk in $ctxDisks) {
    $target = $disk.TARGET
    $diskId = $disk.ID

    # Check if TARGET is a single letter (A-Z or a-z)
    if ($target -match '^[A-Za-z]$') {
        $driveLetter = $target.ToUpper()
        Write-Host "Processing disk $diskId with target letter $driveLetter"
        
        # Get disk number (for simplicity, assume disk number matches ID; real implementation may need to map)
        $diskNumber = [int]$diskId
        
        # Ensure disk is online and initialized
        $diskObj = Get-Disk -Number $diskNumber -ErrorAction SilentlyContinue
        if (-not $diskObj) {
            Write-Host "Disk $diskNumber not found. Skipping."
            continue
        }
        if ($diskObj.OperationalStatus -ne 'Online') {
            Set-Disk -Number $diskNumber -IsOffline $false
        }
        if (-not $diskObj.IsReadOnly) {
            Set-Disk -Number $diskNumber -IsReadOnly $false
        }
        
        # Assign drive letter
        Assign-DriveLetter -DiskId $diskNumber -DriveLetter $driveLetter
    } else {
        # Default behavior: just let Windows assign automatically
        Write-Host "Disk $diskId target is not a letter ($target). Skipping custom assignment."
    }
}

# Note: This script assumes disks are already attached and visible to the OS.
# For production, ensure disk numbers are correctly mapped from the context.
