$scriptsRoot = $Args[0]

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
    [System.Collections.ArrayList]$scripts = @(Get-Content -Path $scriptsRoot\progress.json | ConvertFrom-Json)
} else {
    # create progress file
    [System.Collections.ArrayList]$scripts = @(Get-ChildItem -Path $scriptsRoot -Recurse -Include *.ps1 -ErrorAction SilentlyContinue | Sort-Object $_.FullName | Select-Object FullName)
    # exit if there aren't any scripts
    if ($scripts.count -eq 0) {
        exit 0;
    }
}

# run scripts
foreach ($script in $scripts.Clone()) {
    # run script
    & $script.FullName
    # decide if reboot is needed
    switch ($LASTEXITCODE) {
        0 {
            # script finished, no reboot required
            $scripts.Remove($script);
        }
        1 {
            # script finished, reboot required
            $scripts.Remove($script);
            ConvertTo-Json -InputObject $scripts | Set-Content -Path $scriptsRoot\progress.json            
            exit 1;
        }
        2 {
            # script not finished, reboot required, same script will run after reboot
            ConvertTo-Json -InputObject $scripts | Set-Content -Path $scriptsRoot\progress.json            
            exit 1;
        }
        default {
            # script returned unsupported value, continue
            $scripts.Remove($script)
        }
    }
}

# cleanup
Remove-Item -ErrorAction SilentlyContinue -Path $scriptsRoot\progress.json -Force
exit 0