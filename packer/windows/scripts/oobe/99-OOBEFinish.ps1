# Delete unattend files and scripts
Remove-Item -Recurse -Force $env:systemdrive\scripts, $env:systemdrive\Unattend.xml, $env:windir\Panther\Unattend.xml, $env:systemdrive\Run-Scripts.ps1
# Wait for OOBE to finish provisioning apps (finished when user desktop shows up)
$RegistryKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE\Stats"
$RegistryKeyName = "OOBEUserSignedIn"
$AnimationProcessName = "FirstLogonAnim"
$OOBEFinished = $false
while ($OOBEFinished -eq $false) {
    try {
        Get-ItemProperty -Path $RegistryKeyPath -Name $RegistryKeyName -ErrorAction Stop | Out-Null
        $FirstLogonAnimationProcess = Get-Process -Name $AnimationProcessName -ErrorAction SilentlyContinue
        if ($null -eq $FirstLogonAnimationProcess) {
            $OOBEFinished = $true
        }
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