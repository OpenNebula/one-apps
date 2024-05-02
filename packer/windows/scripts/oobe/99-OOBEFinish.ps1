Remove-Item -Recurse -Force $env:systemdrive\scripts %$env:systemdrive\Unattend.xml $env:windir\Panther\Unattend.xml
Remove-Item -Force $env:systemdrive\Run-Scripts.ps1
logoff.exe