# Delete unattend files and scripts
Remove-Item -Recurse -Force $env:systemdrive\scripts, $env:systemdrive\Unattend.xml, $env:windir\Panther\Unattend.xml, $env:systemdrive\Run-Scripts.ps1
# Wait for OOBE to finish provisioning apps (finished when user desktop shows up)
$RegistryKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE\Stats"
$RegistryKeyName = "OOBEUserSignedIn2"
$OOBEFinished = $false
while ($OOBEFinished -eq $false) {
    try {
        Get-ItemProperty -Path $RegistryKeyPath -Name $RegistryKeyName -ErrorAction Stop | Out-Null
        $OOBEFinished = $true
    }
    catch {
        Start-Sleep -Seconds 1
    }
}
# logoff user 5 seconds after OOBE finishes
Start-Sleep 5
logoff.exe
# exit script withour restart
exit 0