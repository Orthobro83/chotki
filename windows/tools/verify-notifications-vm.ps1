param([ValidateSet('debug','release')][string]$Configuration='debug')
. $PSScriptRoot\windows-env.ps1
. $PSScriptRoot\review-retention-vm.ps1
Remove-OldChotkiReviews
& $PSScriptRoot\build-vm.ps1 -Configuration $Configuration
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$exe=Get-ChotkiExecutable $Configuration
Write-Output 'Notification executable PE machine: 0x8664; matching x64 runtime bundled.'
$name='ChotkiNotificationReview-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
$principal=New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value) -LogonType Interactive -RunLevel Limited
$action=New-ScheduledTaskAction -Execute 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -File C:\workspace-build\tools\notification-review-vm.ps1 -Configuration ' + $Configuration)
Register-ScheduledTask -TaskName $name -Action $action -Principal $principal | Out-Null
$pidFile='C:\workspace-build\notification-review.pid'
Remove-Item $pidFile -ErrorAction SilentlyContinue
try {
    Start-ScheduledTask $name
    $complete=$false
    for ($attempt=0; $attempt -lt 35; $attempt++) {
        Start-Sleep -Seconds 1
        $info=Get-ScheduledTaskInfo $name
        if ($info.LastRunTime.Year -gt 2000 -and (Get-ScheduledTask $name).State -eq 'Ready') { $info=Get-ScheduledTaskInfo $name; if ($info.LastTaskResult -ne 267009) { $complete=$true; break } }
    }
    Get-Content 'C:\workspace-build\notification-review.log'
    if (!$complete) { throw 'Native notification review timed out.' }
    if ($info.LastTaskResult -ne 0) { throw "Native notification review failed: $($info.LastTaskResult)" }
} finally {
    Stop-ScheduledTask $name -ErrorAction SilentlyContinue
    if (Test-Path $pidFile) {
        $reviewPID=[int](Get-Content $pidFile -Raw)
        $child=Get-CimInstance Win32_Process -Filter "ProcessId=$reviewPID"
        if ($child -and $child.ExecutablePath -eq $exe.FullName -and $child.CommandLine -like '*--notification-smoke*') { Stop-Process $reviewPID -Force -ErrorAction SilentlyContinue }
        Remove-Item $pidFile -ErrorAction SilentlyContinue
    }
    Unregister-ScheduledTask $name -Confirm:$false
    # Recover only this fixture's identity if a terminated process missed cleanup.
    $key='HKCU:\Software\Classes\CLSID\{F5B98871-0C8C-451E-9BCD-CA54B93B6530}'
    if (Test-Path "$key\LocalServer32") {
        $server=(Get-Item "$key\LocalServer32").GetValue('')
        if ($server -eq ('"'+$exe.FullName+'" -ToastActivated')) { Remove-Item $key -Recurse -Force }
    }
    $shortcut=Join-Path ([Environment]::GetFolderPath('Programs')) 'Chotki notification review.lnk'
    if (Test-Path $shortcut) {
        $link=(New-Object -ComObject WScript.Shell).CreateShortcut($shortcut)
        if ($link.TargetPath -eq $exe.FullName) { Remove-Item $shortcut -Force }
    }
}
exit 0
