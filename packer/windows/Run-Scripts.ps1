﻿$scriptsRoot = $Args[0]

# exit if no script root provided
if ($null -eq $scriptsRoot ) {
    Write-Warning "No script root provided, exiting"
    exit 0;
}
# exit if script root does not exist
if (-Not (Test-Path -Path $scriptsRoot)) {
    Write-Warning "Provided script root does not exist, exiting"
    exit 0;
}
# prepare script list
if (Test-Path -Path $scriptsRoot\progress.json) {
    # load progress file after reboot
    [System.Collections.ArrayList]$scripts = Get-Content -Path $scriptsRoot\progress.json | ConvertFrom-Json
} else {
    # create progress file
    [System.Collections.ArrayList]$scripts = Get-ChildItem -Path $scriptsRoot -Recurse -Include *.ps1 -ErrorAction SilentlyContinue | Sort-Object $_.FullName | Select-Object -ExpandProperty FullName
    # exit if there aren't any scripts
    if ($scripts.count -eq 0) {
        exit 0;
    }
    $scripts | ConvertTo-Json | Set-Content -Path $scriptsRoot\progress.json
}

# run scripts
foreach ($scriptPath in $scripts.Clone()) {
    # run script
    & $scriptPath
    # decide if reboot is needed
    switch ($LASTEXITCODE) {
        0 {
            # script finished, no reboot required
            $scripts.Remove($scriptPath);
        }
        1 {
            # script finished, reboot required
            $scripts.Remove($scriptPath);
            $scripts | ConvertTo-Json | Set-Content -Path $scriptsRoot\progress.json            
            exit 1;
        }
        2 {
            # script not finished, reboot required, same script will run after reboot
            $scripts | ConvertTo-Json | Set-Content -Path $scriptsRoot\progress.json            
            exit 1;
        }
        default {
            # script returned unsupported value, continue
            $scripts.Remove($scriptPath)
        }
    }
}

# cleanup
Remove-Item -Path $scriptsRoot\progress.json -Force
exit 0