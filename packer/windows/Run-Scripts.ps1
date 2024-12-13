param(
    [String]$ScriptsRoot
)
$log = $true
if ($log) {
    $TranscriptFolder = Join-Path -Path $env:SYSTEMDRIVE -ChildPath "PSLogs"
    $TranscriptName = "Transcript-$($env:USERNAME)-$(hostname)-$(Get-Date -Format 'MM-dd-yyyy-HH-mm').txt"
    Start-Transcript  -Path (Join-Path -Path $TranscriptFolder -ChildPath $TranscriptName) -Append -Force
}

# exit if no script root provided
if (!$ScriptsRoot) {
    Write-Warning "No script root provided, exiting"
    exit 0;
}
# exit if script root does not exist
if (!(Test-Path -Path $ScriptsRoot)) {
    Write-Warning "Provided script root does not exist, exiting"
    exit 0;
}

Write-host "Running scripts from: $ScriptsRoot"

$progressFilePath = Join-Path -Path $ScriptsRoot -ChildPath "progress.json"

# get script files
if (Test-Path -Path $progressFilePath) {
    # load progress file after reboot
    Write-Host "Resuming from progress file: $progressFilePath"
    $scriptFiles = [string[]](ConvertFrom-Json -InputObject (Get-Content $progressFilePath -Raw))
}
else {
    # get scripts from scripts folder
    $scriptFiles = [String[]]@(Get-ChildItem -Path $ScriptsRoot -Recurse -Include *.ps1 | Select-Object -ExpandProperty FullName | Sort-Object)
}


# add scripts to Queue
$scriptFileQueue = [System.Collections.Generic.Queue[String]]::new($scriptFiles)

Write-Host "Scripts to run:"
$scriptFileQueue | ForEach-Object { Write-Host $_ }
# run scripts
while ($scriptFileQueue.Count -gt 0) {
    # run script
    $scriptFile = $scriptFileQueue.Peek()
    try {
        Write-Host "Running script: $scriptFile"
        & $scriptFile
    }
    catch {
        Write-Warning "Skipping script $($scriptFile) because of error: $_"
        # override exit code to prevent system reboot
        $LASTEXITCODE = 0;
    }
    $exitCode = $LASTEXITCODE
    Write-Host "Script finished with exit code: $exitCode"
    # save and exit if script requests reboot
    if ($exitCode -in 1, 2) {
        # Remove from the queue if script has finished and does not need to run again
        if ($exitCode -eq 1) {
            $scriptFileQueue.Dequeue() | Out-Null
        }
        # Write progress file
        ConvertTo-Json -InputObject $scriptFileQueue | Set-Content -Path $progressFilePath
        Write-Host "Creating progress file: $progressFilePath"
        Write-Host "Exiting script runner with code: $exitCode"
        exit $exitCode
    }
    # Remove finished script from queue
    $scriptFileQueue.Dequeue() | Out-Null
}

# cleanup progress file
if (Test-Path -Path $progressFilePath) {
    Write-Host "Removing progress file: $progressFilePath"
    Remove-Item -Path $progressFilePath -Force
}

Write-Host "Running scripts done, exit code: 0"
exit 0