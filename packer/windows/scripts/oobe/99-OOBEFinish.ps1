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
# Export security policy
$SecurityDBPath = "$env:systemdrive\windows\security\local.sdb"
$LogFile = "$env:systemdrive\security.log"
$SecurityCfg = "$env:systemdrive\security.cfg"
$SecurityCfgModified = "$env:systemdrive\security_no_pw_complexity.cfg"
secedit /export /cfg $SecurityCfg
# Disable pasword complexity
(Get-Content $SecurityCfg).replace("PasswordComplexity = 1", "PasswordComplexity = 0") | Set-Content $SecurityCfgModified
# Apply new security policy
secedit /configure /db $SecurityDBPath /cfg $SecurityCfgModified /areas SECURITYPOLICY
# Remove Administrator password
cmd.exe /c 'net user Administrator ""'
# Force password change on next logon
cmd.exe /c 'net user Administrator /logonpasswordchg:yes'
# Restore security policy
secedit /configure /db $SecurityDBPath /cfg $SecurityCfg /areas SECURITYPOLICY
# Remove temporary files
Remove-Item -Force $SecurityCfg, $SecurityCfgModified
# logoff user 5 seconds after OOBE finishes
Start-Sleep 5
Disable-LocalUser -Name Administrator
shutdown.exe /l
# exit script withour restart
exit 0