# Windows Drive Letter Assignment for OpenNebula Context

This utility enables assigning specific drive letters to disks attached to Windows VMs in OpenNebula.

## Usage

1. Place `Set-DriveLetter.ps1` and `Assign-DriveLetters.ps1` in your context scripts directory (e.g., `C:\Program Files\OpenNebula\`).
2. Ensure the context ISO contains a `context.json` file with a `disks` array. Each disk object may include:
   - `device`: Linux device name (e.g., `sda`, `hdc`).
   - `target`: Desired Windows drive letter (single uppercase letter, e.g., `D`, `Z`).
3. Call `Assign-DriveLetters.ps1 -ContextFilePath <path-to-context.json>` from your context initialization script.

## Example `context.json`
```json
{
  "disks": [
    {
      "device": "sdb",
      "target": "D"
    },
    {
      "device": "hdc",
      "target": "Z"
    }
  ]
}
```

## Notes
- The script maps Linux device names to Windows disk numbers using bus type (SCSI/IDE) and order of attachment. Adjust the mapping function if needed.
- If a partition already has a drive letter, it will be removed before assigning the new one.
- Requires administrative privileges.