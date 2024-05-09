Copy-Item -Recurse -Force A:\scripts\oobe $env:systemdrive\scripts
Copy-Item -Force A:\Run-Scripts.ps1 $env:systemdrive\Run-Scripts.ps1
Copy-Item -Force A:\OOBEunattend.xml $env:systemdrive\Unattend.xml