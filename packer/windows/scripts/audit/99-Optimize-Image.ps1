# cleaning up components and optimizing the image
Write-Host "Optimizing the image"
& dism.exe /online /Quiet /NoRestart /Cleanup-Image /StartComponentCleanup /ResetBase
# Trim the disk
Write-Host "Trimming the disk"
Get-Volume | Optimize-Volume -ReTrim -SlabConsolidate -ErrorAction SilentlyContinue
exit 0