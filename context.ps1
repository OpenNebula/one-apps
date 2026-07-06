<#
.SYNOPSIS
    OpenNebula Windows context initialization script.
.DESCRIPTION
    This script is executed at VM startup to configure the VM based on context
    variables. It includes support for assigning drive letters to disks based
    on the TARGET attribute (single letter).
.NOTES
    The script assumes that the context ISO is mounted at a known location
    (e.g., D: or a fixed path). It reads context variables from a file
    'context.sh' or 'context.ps1' on the ISO.
#>

# Set strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Helper functions ---

function Get-ContextVariable {
    param (
        [string]$VariableName
    )
    $path = Join-Path $contextPath "context.sh"
    if (Test-Path $path) {
        $content = Get-Content $path -Raw
        $pattern = "$VariableName=['\"`"'](.*?)['\"`"']"
        if ($content -match $pattern) {
            return $matches[1]
        }
    }
    return $null
}

function Assign-DriveLetter {
    param (
        [int]$DiskNumber,
        [char]$DesiredLetter
    )
    Write-Host "Assigning drive letter $DesiredLetter to disk $DiskNumber"
    try {
        $disk = Get-Disk -Number $DiskNumber -ErrorAction Stop
        $partition = $disk | Get-Partition -ErrorAction Stop
        
        # Check if desired letter is already in use
        $existing = Get-Partition -DriveLetter $DesiredLetter -ErrorAction SilentlyContinue
        if ($existing -and $existing.DiskNumber -ne $DiskNumber) {
            # Remove existing letter from conflicting disk
            Write-Host "Drive letter $DesiredLetter already in use on disk $($existing.DiskNumber). Removing it."
            $existing | Set-Partition -NoDriveLetter -ErrorAction Stop
        }
        
        # Set new drive letter
        $partition | Set-Partition -NewDriveLetter $DesiredLetter -ErrorAction Stop
        Write-Host "Successfully assigned drive letter $DesiredLetter to disk $DiskNumber"
    }
    catch {
        Write-Warning "Failed to assign drive letter $DesiredLetter to disk $DiskNumber: $_"
    }
}

function Process-DiskTargets {
    <#
        Reads context variables for each disk (besides the context ISO) and
        assigns the desired drive letter based on the TARGET attribute.
        TARGET is expected to be a single uppercase letter (e.g., 'Z' or 'D').
    #>
    # Determine the number of disks (excluding context ISO).
    # The context variable VM_DISK_COUNT may contain the total number of disks.
    $diskCount = Get-ContextVariable "VM_DISK_COUNT"
    if (-not $diskCount) {
        Write-Host "VM_DISK_COUNT not found. Assuming 1 disk (context only)."
        return
    }
    $diskCount = [int]$diskCount

    # Disk 0 is usually the context ISO, so we start from disk 1.
    for ($i = 1; $i -lt $diskCount; $i++) {
        # The context variable for disk i's target is DISK_i_TARGET (0-indexed?)
        # Usually OpenNebula uses DISK_X_TARGET where X is the disk ID (1-based).
        # We'll try common patterns.
        $targetVar = "DISK_${i}_TARGET"
        $target = Get-ContextVariable $targetVar
        if (-not $target) {
            $targetVar = "DISK_$($i-1)_TARGET"
            $target = Get-ContextVariable $targetVar
        }
        if ($target -and $target -match '^[A-Z]$') {
            $letter = $target[0]
            Assign-DriveLetter -DiskNumber $i -DesiredLetter $letter
        }
        else {
            Write-Host "Disk $i: No valid TARGET (value: '$target'). Skipping."
        }
    }
}

# --- Main script ---

Write-Host "Starting Windows context initialization..."

# Determine the context ISO mount point.
# Typically the context ISO is mounted as the first CD-ROM drive (drive D:).
$contextPath = $null
$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -eq 0 -and $_.Free -eq 0 }
foreach ($drive in $drives) {
    $root = $drive.Root
    if (Test-Path (Join-Path $root "context.sh")) {
        $contextPath = $root
        break
    }
}

if (-not $contextPath) {
    Write-Warning "Context ISO not found. Proceeding without context configuration."
    exit 0
}

Write-Host "Context ISO found at $contextPath"

# Read and execute context variables if present (optional)
$contextScript = Join-Path $contextPath "context.ps1"
if (Test-Path $contextScript) {
    . $contextScript
}

# Process disk target assignments
Process-DiskTargets

Write-Host "Context initialization completed."
