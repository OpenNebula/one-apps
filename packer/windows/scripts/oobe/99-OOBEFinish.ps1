# Delete unattend files and scripts
Remove-Item -Recurse -Force (Join-Path -Path $env:systemdrive -ChildPath "scripts")
Remove-Item -Recurse -Force (Join-Path -Path $env:systemdrive -ChildPath "Unattend.xml")
Remove-Item -Recurse -Force (Join-Path -Path $env:windir -ChildPath "Panther\Unattend.xml")
Remove-Item -Recurse -Force (Join-Path -Path $env:systemdrive -ChildPath "Run-Scripts.ps1")
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
$SecurityDBPath = Join-Path -Path $env:systemdrive -ChildPath "windows\security\local.sdb"
$LogFile = Join-Path -Path $env:systemdrive -ChildPath "security.log"
$SecurityCfg = Join-Path -Path $env:systemdrive -ChildPath "security.cfg"
$SecurityCfgModified = Join-Path -Path $env:systemdrive -ChildPath "security_no_pw_complexity.cfg"
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
# Reenable and start OpenNebula contextualization service
Write-Host "Enabling and starting contextualization service"
Set-Service -Name "onecontext" -StartupType Automatic
Start-Service -Name "onecontext"
# logoff user 5 seconds after OOBE finishes
Start-Sleep 5
shutdown.exe /l
# exit script withour restart
exit 0