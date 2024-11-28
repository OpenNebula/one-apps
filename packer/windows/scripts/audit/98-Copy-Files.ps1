Copy-Item -Recurse -Force "A:\scripts\oobe" (Join-Path -Path $env:systemdrive -ChildPath "scripts")
Copy-Item -Force "A:\Run-Scripts.ps1" (Join-Path -Path $env:systemdrive -ChildPath "Run-Scripts.ps1")
Copy-Item -Force "A:\OOBEunattend.xml" (Join-Path -Path $env:systemdrive -ChildPath "Unattend.xml")