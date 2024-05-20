& dism.exe /online /Quiet /NoRestart /Cleanup-Image /StartComponentCleanup /ResetBase
Get-Volume | Optimize-Volume -ReTrim -SlabConsolidate -ErrorAction SilentlyContinue
exit 0