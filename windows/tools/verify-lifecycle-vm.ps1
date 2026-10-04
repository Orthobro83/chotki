param([string]$Application='C:\workspace-build\.build\package\Chotki-Windows-x64\ChotkiWindows.exe')
. $PSScriptRoot\windows-env.ps1
. $PSScriptRoot\review-retention-vm.ps1
Remove-OldChotkiReviews
$exe=Get-Item $Application
$name='ChotkiLifecycleReview-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
$principal=New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value) -LogonType Interactive -RunLevel Limited
$action=New-ScheduledTaskAction -Execute 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -File C:\workspace-build\tools\lifecycle-review-vm.ps1 -Application "'+$Application+'"')
Register-ScheduledTask -TaskName $name -Action $action -Principal $principal | Out-Null
$pidFile='C:\workspace-build\lifecycle-review.pid'
try {
    Start-ScheduledTask $name
    $complete=$false
    for ($attempt=0;$attempt -lt 60;$attempt++) {
        Start-Sleep -Seconds 1
        $info=Get-ScheduledTaskInfo $name
        if ($info.LastRunTime.Year -gt 2000 -and (Get-ScheduledTask $name).State -eq 'Ready') { $info=Get-ScheduledTaskInfo $name; if ($info.LastTaskResult -ne 267009) { $complete=$true; break } }
    }
    Get-Content 'C:\workspace-build\lifecycle-review.log'
    if (!$complete) { throw 'Lifecycle review timed out.' }
    if ($info.LastTaskResult -ne 0) { throw "Lifecycle review failed: $($info.LastTaskResult)" }
} finally {
    Stop-ScheduledTask $name -ErrorAction SilentlyContinue
    if (Test-Path $pidFile) {
        $reviewPID=[int](Get-Content $pidFile -Raw)
        $child=Get-CimInstance Win32_Process -Filter "ProcessId=$reviewPID"
        if ($child -and $child.ExecutablePath -eq $exe.FullName -and $child.CommandLine -like '*--lifecycle-smoke*') { Stop-Process $reviewPID -Force -ErrorAction SilentlyContinue }
        Remove-Item $pidFile -ErrorAction SilentlyContinue
    }
    Unregister-ScheduledTask $name -Confirm:$false
}
exit 0
