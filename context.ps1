# Context script for Windows
# Set drive letters for disks based on TARGET attribute in one-context

$contextFile = "$env:SystemDrive\one-context\context.sh"
if (-not (Test-Path $contextFile)) {
    Write-Output "one-context file not found, skipping drive letter assignment"
    exit 0
}

# Read one-context file and parse variables
$contextVars = @{}
Get-Content $contextFile | ForEach-Object {
    if ($_ -match '^([a-zA-Z_][a-zA-Z0-9_]*)="(.*)"$') {
        $contextVars[$matches[1]] = $matches[2]
    }
}

# Detect disks and assign letters based on TARGET
function Assign-DriveLetter {
    param (
        [string]$targetDiskId,
        [string]$desiredLetter
    )
    $disk = Get-Disk | Where-Object { $_.Number -eq $targetDiskId -or $_.SerialNumber -eq $targetDiskId -or $_.UniqueId -eq $targetDiskId }
    if (-not $disk) {
        Write-Output "Disk with id $targetDiskId not found."
        return
    }
    $partition = $disk | Get-Partition | Where-Object { $_.DriveLetter -ne $null }
    if (-not $partition) {
        Write-Output "No partition with drive letter on disk $targetDiskId."
        return
    }
    # If partition already has desired letter, skip
    if ($partition.DriveLetter -eq $desiredLetter) {
        Write-Output "Disk $targetDiskId already has letter $desiredLetter."
        return
    }
    # Remove existing letter and assign new one
    try {
        $partition | Remove-PartitionAccessPath -AccessPath "$($partition.DriveLetter):\" -PassThru | Set-Partition -NewDriveLetter $desiredLetter
        Write-Output "Assigned letter $desiredLetter to disk $targetDiskId."
    } catch {
        Write-Error "Failed to assign letter $desiredLetter: $_"
    }
}

# Process context ISO first (if TARGET set in context section)
if ($contextVars['TARGET']) {
    $desired = $contextVars['TARGET']
    # Find context ISO by label or location
    $contextDisk = Get-Disk | Where-Object { $_.Location -like "*DVD*" -or $_.BusType -eq 'USB' -or $_.FriendlyName -like "*QEMU DVD*" }
    if ($contextDisk) {
        Assign-DriveLetter $contextDisk.Number $desired
    } else {
        Write-Output "Context ISO disk not found."
    }
}

# Process attached disks (DISK_i_TARGET variables)
for ($i = 0; ; $i++) {
    $targetKey = "DISK_${i}_TARGET"
    if (-not $contextVars[$targetKey]) {
        break
    }
    $desired = $contextVars[$targetKey]
    # The disk ID is usually the index i, or we can use DISK_${i}_ID
    $diskId = $i  # Assume sequential numbering
    Assign-DriveLetter $diskId $desired
}
