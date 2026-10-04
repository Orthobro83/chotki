# Run only after verify-candidate-vm.ps1 succeeds and visual review is complete.
. $PSScriptRoot\windows-env.ps1
$payload='C:\workspace-build\.build\package\Chotki-Windows-x64'
$destination=Join-Path $env:LOCALAPPDATA 'Programs\Chotki'
& "$payload\install-windows.ps1" -Destination $destination
$manifest=Get-Content "$destination\payload.json" -Raw | ConvertFrom-Json
foreach($file in $manifest.files) {
    if((Get-FileHash (Join-Path $destination $file.path) -Algorithm SHA256).Hash -ne $file.sha256){throw "Installed file mismatch: $($file.path)"}
}
$exe=Join-Path $destination 'ChotkiWindows.exe'
if(!(Test-IsX64 $exe)){throw 'Installed executable is not x86_64.'}
foreach($dll in Get-ChildItem $destination -Filter '*.dll'){if(!(Test-IsX64 $dll.FullName)){throw "Wrong installed architecture: $($dll.Name)"}}
$env:PATH="$destination;C:\Windows\system32;C:\Windows"
Set-Location $destination
$app=Start-Process $exe -ArgumentList '--self-test' -Wait -PassThru -RedirectStandardOutput 'C:\workspace-build\installed-check.log' -RedirectStandardError 'C:\workspace-build\installed-check-error.log'
Get-Content 'C:\workspace-build\installed-check.log'
if($app.ExitCode -ne 0){Get-Content 'C:\workspace-build\installed-check-error.log';throw "Installed bootstrap failed: $($app.ExitCode)"}
$shell=New-Object -ComObject WScript.Shell
$desktop=Join-Path ([Environment]::GetFolderPath('Desktop')) 'Chotki.lnk'
$link=$shell.CreateShortcut($desktop)
if($link.WorkingDirectory -ne $destination -or !$link.Arguments.Contains('launch-windows.ps1') -or !(Test-Path "$destination\Chotki.ico")){throw 'Desktop shortcut does not target this installation.'}
& "$PSScriptRoot\verify-lifecycle-vm.ps1" -Application $exe
if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
Write-Output "Installed candidate verified: $destination"
Write-Output "Desktop icon ready: $desktop"
Write-Output "Installed version: $((Get-Item $exe).VersionInfo.ProductVersion); executable and DLLs 0x8664; bootstrap/lifecycle exit 0."
exit 0
