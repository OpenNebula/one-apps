param(
    [String]$ScriptsRoot
)

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

$progressFilePath = Join-Path -Path $ScriptsRoot -ChildPath "progress.json"

# get script files
if (Test-Path -Path $progressFilePath) {
    # load progress file after reboot
    $scriptFiles = [string[]](ConvertFrom-Json -InputObject (Get-Content $progressFilePath -Raw))
}
else {
    # get scripts from scripts folder
    $scriptFiles = [String[]]@(Get-ChildItem -Path $ScriptsRoot -Recurse -Include *.ps1 | Select-Object -ExpandProperty FullName | Sort-Object)
}


# add scripts to Queue
$scriptFileQueue = [System.Collections.Generic.Queue[String]]::new($scriptFiles)

# run scripts
while ($scriptFileQueue.Count -gt 0) {
    # run script
    $scriptFile = $scriptFileQueue.Peek()
    try {
    & $scriptFile
    }
    catch {
        Write-Warning "Skipping script $($scriptFile) because of error: $_"
        # override exit code to prevent system reboot
        $LASTEXITCODE = 0;
    }
    $exitCode = $LASTEXITCODE
    # save and exit if script requests reboot
    if ($exitCode -in 1, 2) {
        # Remove from the queue if script has finished and does not need to run again
        if ($exitCode -eq 1) {
            $scriptFileQueue.Dequeue() | Out-Null
        }
        # Write progress file
        ConvertTo-Json -InputObject $scriptFileQueue | Set-Content -Path $progressFilePath
        exit $exitCode
    }
    # Remove finished script from queue
    $scriptFileQueue.Dequeue() | Out-Null
}

# cleanup progress file
if (Test-Path -Path $progressFilePath) {
    Remove-Item -Path $progressFilePath -Force
}

exit 0