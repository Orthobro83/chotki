param([ValidateSet('debug','release')][string]$Configuration='debug',[switch]$VisualOnly)
# Verify the actual logged-in desktop, since SSH runs in noninteractive session 0.
. $PSScriptRoot\windows-env.ps1
. $PSScriptRoot\review-retention-vm.ps1
Remove-OldChotkiReviews -Keep 1
& $PSScriptRoot\build-vm.ps1 -Configuration $Configuration
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$exe = Get-ChotkiExecutable $Configuration
Write-Output 'ChotkiWindows PE machine: 0x8664'
$OutputDir = $exe.DirectoryName
$env:PATH = "$OutputDir;C:\Windows\system32;C:\Windows"
Set-Location $OutputDir
$bootstrap=Start-Process $exe.FullName -ArgumentList '--self-test' -Wait -PassThru -RedirectStandardOutput 'C:\workspace-build\bootstrap.log' -RedirectStandardError 'C:\workspace-build\bootstrap-error.log'
Get-Content 'C:\workspace-build\bootstrap.log'
if ($bootstrap.ExitCode -ne 0) { Get-Content 'C:\workspace-build\bootstrap-error.log'; exit $bootstrap.ExitCode }
Write-Output 'Bootstrap exit: 0'
$name = 'ChotkiReview-' + [Guid]::NewGuid().ToString('N').Substring(0,8)
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-ScheduledTaskPrincipal -UserId $identity.User.Value -LogonType Interactive -RunLevel Limited
$action = New-ScheduledTaskAction -Execute 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -File C:\workspace-build\tools\review-vm.ps1 -Configuration '+$Configuration+$(if($VisualOnly){' -VisualOnly'}else{''}))
Register-ScheduledTask -TaskName $name -Action $action -Principal $principal | Out-Null
$pidFile = 'C:\workspace-build\review.pid'
Remove-Item $pidFile -ErrorAction SilentlyContinue
try {
    Start-ScheduledTask $name
    $complete = $false
    for ($attempt = 0; $attempt -lt 120; $attempt++) {
        Start-Sleep -Seconds 1
        $info = Get-ScheduledTaskInfo $name
        if ($info.LastRunTime.Year -gt 2000 -and (Get-ScheduledTask $name).State -eq 'Ready') {
            $info = Get-ScheduledTaskInfo $name
            if ($info.LastTaskResult -ne 267009) { $complete = $true; break }
        }
    }
    if (!$complete) { Stop-ScheduledTask $name; throw 'Interactive review timed out.' }
    Get-Content C:\workspace-build\review.log
    if ($info.LastTaskResult -ne 0) { throw "Interactive review failed: $($info.LastTaskResult)" }
    # Capture and archive on native storage; retrieve through SSH afterward.
    # Shared-drive transfers can fail even after the native UI test succeeds.
    $captures = Join-Path 'C:\workspace-build\reviews' $name
    New-Item -ItemType Directory -Force $captures | Out-Null
    if(!$VisualOnly){Move-Item C:\workspace-build\review.bmp (Join-Path $captures 'review.bmp')}
    # review-vm.ps1 removes prior captures before this synthetic run. Collect
    # its complete surface set, including newly added parity checks.
    Get-ChildItem 'C:\workspace-build' -Filter 'review-*.bmp' -File | Move-Item -Destination $captures
    $archive = "$captures.zip"
    Compress-Archive -Path "$captures\*.bmp" -DestinationPath $archive -Force
    Write-Output "Synthetic captures: $captures"
    Write-Output "Capture archive: $archive"
} finally {
    # Stopping PowerShell's scheduled task does not reliably stop its child.
    # Verify the recorded PID, executable and synthetic flag before termination.
    if (Test-Path $pidFile) {
        $reviewPID = [int](Get-Content $pidFile -Raw)
        $child = Get-CimInstance Win32_Process -Filter "ProcessId=$reviewPID"
        if ($child -and $child.ExecutablePath -eq $exe.FullName -and $child.CommandLine -like '*--ui-smoke*') {
            Stop-Process -Id $reviewPID -Force -ErrorAction SilentlyContinue
        }
        Remove-Item $pidFile -ErrorAction SilentlyContinue
    }
    Unregister-ScheduledTask $name -Confirm:$false
}
exit 0
