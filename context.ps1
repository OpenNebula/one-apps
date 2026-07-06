# Context script for Windows - Modified to support TARGET drive letter assignment
# This script runs at VM boot and applies contextualization.
# It reads context variables from the context ISO.
# New feature: If CONTEXT_TARGET variable is set, changes the context ISO drive letter.
# If DISK_TARGET_N variables are set (e.g., DISK_TARGET_0=D), changes corresponding data disk letters.

param(
    [string]$ContextPath = "Z:\context.ps1"
)

# Read context variables from the context ISO
$contextExists = Test-Path $ContextPath
if (-not $contextExists) {
    Write-Host "Context file not found at $ContextPath. Skipping context processing."
    exit 0
}

# Source the context variables (assumes file defines global variables)
. $ContextPath

# Helper function to safely change drive letter
function Set-DriveLetter {
    param(
        [string]$CurrentLetter,
        [string]$NewLetter
    )
    if (-not $NewLetter) {
        Write-Host "No new drive letter specified."
        return
    }
    if ($CurrentLetter -eq $NewLetter) {
        Write-Host "Drive already has desired letter $NewLetter. Skipping."
        return
    }
    Write-Host "Attempting to change drive $CurrentLetter to $NewLetter."
    try {
        # First, check if target letter is free
        $existingDrive = Get-Partition -DriveLetter $NewLetter -ErrorAction SilentlyContinue
        if ($existingDrive) {
            Write-Host "Target drive letter $NewLetter already in use. Removing it first."
            Remove-PartitionAccessPath -Partition $existingDrive -AccessPath "$NewLetter`:" -ErrorAction Stop
        }
        # Change letter
        $partition = Get-Partition -DriveLetter $CurrentLetter -ErrorAction Stop
        Set-Partition -Partition $partition -NewDriveLetter $NewLetter -ErrorAction Stop
        Write-Host "Successfully changed drive $CurrentLetter to $NewLetter."
    }
    catch {
        Write-Host "Failed to change drive letter: $_"
    }
}

# Identify the context ISO drive (likely a CDROM)
$contextDrive = Get-WmiObject Win32_CDROMDrive | Where-Object { $_.MediaLoaded -eq $true } | Select-Object -First 1
if (-not $contextDrive) {
    Write-Host "No context CDROM drive found. Skipping context drive letter assignment."
}
else {
    $contextLetter = $contextDrive.Drive
    Write-Host "Context ISO mounted at $contextLetter"
    
    # Apply CONTEXT_TARGET if defined
    if ($global:CONTEXT_TARGET) {
        Set-DriveLetter -CurrentLetter $contextLetter.TrimEnd(':') -NewLetter $global:CONTEXT_TARGET
    }
}

# Process additional data disks via DISK_TARGET_N variables
# Enumerate all fixed and removable disks (excluding the context ISO)
$allDisks = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -ne 5 -and $_.DeviceID -ne $contextLetter }
$diskIndex = 0
foreach ($disk in $allDisks) {
    $targetVar = "DISK_TARGET_$diskIndex"
    $targetLetter = (Get-Variable -Name $targetVar -ErrorAction SilentlyContinue).Value
    if ($targetLetter) {
        Write-Host "Applying DISK_TARGET_$diskIndex = $targetLetter to disk at $($disk.DeviceID)"
        Set-DriveLetter -CurrentLetter $disk.DeviceID.TrimEnd(':') -NewLetter $targetLetter
    }
    $diskIndex++
}

# Remaining contextualization tasks (networking, etc.) can follow here
Write-Host "Context script completed."
