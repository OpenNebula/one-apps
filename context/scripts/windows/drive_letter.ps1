Param(
    [Parameter(Mandatory=$true)]
    [hashtable]$DriveLetterMap
)

# Function to set drive letter based on disk serial number or system address
function Set-DriveLetterMapping {
    param([hashtable]$mapping)

    $partitions = Get-Partition | Where-Object {$_.DriveLetter -ne $null}
    foreach ($entry in $mapping.GetEnumerator()) {
        $targetLetter = $entry.Key
        $diskIdentifier = $entry.Value

        # Resolve disk identifier to a partition object
        # Supports: 'DeviceNumber', 'SerialNumber', 'DiskNumber', 'UniqueId'
        $partition = $null
        if ($diskIdentifier -match '^[0-9]+$') {
            # Assume DiskNumber
            $partition = Get-Partition -DiskNumber $diskIdentifier | Where-Object {$_.DriveLetter -ne $null} | Select-Object -First 1
        } else {
            # Search by serial or unique id
            $disk = Get-Disk | Where-Object {$_.SerialNumber -eq $diskIdentifier -or $_.UniqueId -eq $diskIdentifier} | Select-Object -First 1
            if ($disk) {
                $partition = Get-Partition -DiskNumber $disk.Number | Where-Object {$_.DriveLetter -ne $null} | Select-Object -First 1
            }
        }

        if (-not $partition) {
            Write-Warning "No partition found for disk identifier: $diskIdentifier"
            continue
        }

        # Check if target letter is already in use
        $existingPartition = Get-Partition -DriveLetter $targetLetter -ErrorAction SilentlyContinue
        if ($existingPartition) {
            # If it's the same partition, skip; otherwise reassign existing to a free letter
            if ($existingPartition.PartitionNumber -ne $partition.PartitionNumber) {
                # Find a free letter (skip A,B,C)
                $freeLetter = [char]'D'..[char]'Z' | Where-Object { -not (Get-Partition -DriveLetter $_ -ErrorAction SilentlyContinue) } | Select-Object -First 1
                if ($freeLetter) {
                    $existingPartition | Set-Partition -NewDriveLetter ([string]$freeLetter) -ErrorAction SilentlyContinue
                    Write-Output "Reassigned existing drive $($targetLetter): to $($freeLetter):"
                } else {
                    Write-Warning "No free drive letters available to reassign $($targetLetter):"
                    continue
                }
            } else {
                # Already the correct letter
                continue
            }
        }

        # Set the partition to the target letter
        $partition | Set-Partition -NewDriveLetter $targetLetter -ErrorAction SilentlyContinue
        if ($?) {
            Write-Output "Set drive letter $($targetLetter): for partition on disk $($diskIdentifier)"
        } else {
            Write-Warning "Failed to set drive letter $($targetLetter): for disk $($diskIdentifier)"
        }
    }
}

Set-DriveLetterMapping -mapping $DriveLetterMap
