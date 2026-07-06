# Context script for Windows
# [Original content truncated for brevity - assume existing file]
# ...
# At the end, after attaching all disks, apply drive letter mapping if specified

$driveLetterMapString = $one_context['DRIVE_LETTER_MAP']
if ($driveLetterMapString) {
    try {
        $driveLetterMap = $driveLetterMapString | ConvertFrom-Json -AsHashtable
        if ($driveLetterMap.Count -gt 0) {
            Write-Output "Applying drive letter mapping..."
            & $PSScriptRoot\drive_letter.ps1 -DriveLetterMap $driveLetterMap
        }
    } catch {
        Write-Warning "Invalid DRIVE_LETTER_MAP format. Expected JSON hashtable: { 'D:': 'diskIdentifier', ... }"
    }
}
