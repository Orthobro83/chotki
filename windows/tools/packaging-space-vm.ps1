# Remove only disposable captures and the obsolete framework staging output.
. $PSScriptRoot\review-retention-vm.ps1
Remove-OldChotkiReviews -Keep 1
$review=Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith('C:\workspace-build\',[StringComparison]::OrdinalIgnoreCase) -and $_.CommandLine -like '*--ui-smoke*' }
if($review){throw 'A synthetic capture is still running; do not remove its artifacts.'}
Get-ChildItem 'C:\workspace-build' -Filter 'review*.bmp' -File | Remove-Item -Force
$legacy='C:\workspace-build\.build\out'
if (Test-Path $legacy) {
    $running=Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($legacy+'\',[StringComparison]::OrdinalIgnoreCase) }
    if ($running) { throw 'Obsolete staging output is still running.' }
    Remove-Item $legacy -Recurse -Force
}
Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" | Select-Object Size,FreeSpace
