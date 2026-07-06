<#
.SYNOPSIS
Assigns a drive letter to a partition.

.DESCRIPTION
This function changes the drive letter of a partition on a specified disk.
If the partition already has a drive letter, it will be removed and reassigned.
#>
function Set-DriveLetter {
    param(
        [Parameter(Mandatory=$true)]
        [int]$DiskNumber,

        [Parameter(Mandatory=$false)]
        [int]$PartitionNumber = 1,

        [Parameter(Mandatory=$true)]
        [ValidatePattern('^[A-Z]$')]
        [string]$NewDriveLetter
    )

    try {
        $partition = Get-Partition -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -ErrorAction Stop
        # Remove existing drive letter if present
        if ($partition.DriveLetter) {
            Remove-PartitionAccessPath -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -AccessPath "$($partition.DriveLetter):" -ErrorAction Stop
        }
        # Assign new drive letter
        Add-PartitionAccessPath -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -AccessPath "$($NewDriveLetter):" -ErrorAction Stop
        Write-Output "Successfully assigned drive letter $NewDriveLetter to disk $DiskNumber partition $PartitionNumber."
    }
    catch {
        Write-Error "Failed to assign drive letter: $($_.Exception.Message)"
    }
}