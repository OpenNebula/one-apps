$scriptsRoot = $Args[0]


# exit if no script root provided
if ($null -eq $scriptsRoot) {
    Write-Warning "No script root provided, exiting"
    exit 0;
}
# exit if script root does not exist
if (-Not (Test-Path -Path $scriptsRoot)) {
    Write-Warning "Provided script root does not exist, exiting"
    exit 0;
}

$progressFilePath = Join-Path -Path $scriptsRoot -ChildPath "progress.json"

# get script files
if (Test-Path -Path $progressFilePath) {
    # load progress file after reboot
    $scriptFiles = [string[]](ConvertFrom-Json -InputObject (Get-Content $progressFilePath -Raw))
}
else {
    # get scripts from scripts folder
    $scriptFiles = [String[]]@(Get-ChildItem -Path $scriptsRoot -Recurse -Include *.ps1 | Select-Object -ExpandProperty FullName | Sort-Object)
}


# add scripts to Queue
$scriptFileQueue = [System.Collections.Generic.Queue[String]]::new($scriptFiles)

# run scripts
while ($scriptFileQueue.Count -gt 0) {
    # run script
    $scriptFile = $scriptFileQueue.Peek()
    & $scriptFile
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