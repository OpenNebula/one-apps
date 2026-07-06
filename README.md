# Windows Drive Letter Assignment via TARGET Attribute

This enhancement allows Windows virtual machines to assign specific drive letters to context disks and additional data disks using the `TARGET` attribute in OpenNebula VM templates.

## Usage

### Context ISO

Set `CONTEXT = [ TARGET="Z" ]` to assign drive letter Z: to the context ISO.

### Data Disks

Set `DISK = [ IMAGE_ID=<id>, TARGET="D" ]` in the VM template. The script will assign drive letters in the order the disks are attached.

> **Note:** For data disks, the script currently assigns letters sequentially to fixed disks (excluding the system disk and optical drives). Ensure the order of `TARGET` attributes matches the order of attached disks.

## Implementation Details

- The context script (`context.ps1`) reads a context file containing key-value pairs.
- If `CONTEXT_TARGET` is specified, the script finds the CD/DVD drive with volume label `CONTEXT` and remaps its drive letter.
- For data disks, `DISK_TARGET_<N>` variables (e.g., `DISK_TARGET_0`, `DISK_TARGET_1`) are processed in index order. The script assigns each target letter to the first available non-system, non-optical partition.
- The script uses PowerShell cmdlets `Get-Partition` and `Set-Partition`.

## Requirements

- Windows PowerShell 5.0 or later.
- The context ISO must be attached and readable.
- The virtual machine must have the `OpenNebula` guest tools (context package) installed to run the script at boot.

## Limitations

- The script does not handle dynamic disk reordering; it assumes disks are ordered by attachment.
- If a target drive letter is already in use, the script will fail and log an error.
- Only drives with existing partitions (with or without letters) are reassigned; raw disks without partitions are ignored.

## Future Improvements

- Support disk identifiers (like serial number) for precise mapping.
- Automatic conflict resolution (e.g., free the target letter before assigning).
- Integration with OneGate for real-time updates.