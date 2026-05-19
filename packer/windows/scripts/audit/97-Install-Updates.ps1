powershell.exe -ExecutionPolicy Bypass -NonInteractive -NoProfile -WindowStyle Maximized -File "A:\scripts\windows-update.ps1"
if ((New-Object -ComObject 'Microsoft.Update.SystemInfo').RebootRequired) {exit 2}
