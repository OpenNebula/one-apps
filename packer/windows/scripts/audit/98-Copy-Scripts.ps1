Copy-Item -Recurse -Force A:\scripts\oobe $env:systemdrive\scripts
Copy-Item -Force A:\Run-Scripts.ps1 $env:systemdrive
exit 0