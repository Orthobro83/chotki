# Verify the actual logged-in desktop, since SSH runs in noninteractive session 0.
. $PSScriptRoot\windows-env.ps1
& $PSScriptRoot\build-vm.ps1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$exe = Get-ChotkiExecutable
Write-Output 'ChotkiWindows PE machine: 0x8664'
$OutputDir = $exe.DirectoryName
$env:PATH = "$OutputDir;C:\Windows\system32;C:\Windows"
Set-Location $OutputDir
& $exe.FullName --self-test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Output 'Bootstrap exit: 0'
$name = 'ChotkiReview-' + [Guid]::NewGuid().ToString('N').Substring(0,8)
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-ScheduledTaskPrincipal -UserId $identity.User.Value -LogonType Interactive -RunLevel Limited
$action = New-ScheduledTaskAction -Execute 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\workspace-build\tools\review-vm.ps1'
Register-ScheduledTask -TaskName $name -Action $action -Principal $principal | Out-Null
try {
    Start-ScheduledTask $name
    $complete = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        Start-Sleep -Seconds 1
        $info = Get-ScheduledTaskInfo $name
        if ($info.LastRunTime.Year -gt 2000 -and (Get-ScheduledTask $name).State -eq 'Ready') {
            $complete = $true; break
        }
    }
    if (!$complete) { Stop-ScheduledTask $name; throw 'Interactive review timed out.' }
    Get-Content C:\workspace-build\review.log
    if ($info.LastTaskResult -ne 0) { throw "Interactive review failed: $($info.LastTaskResult)" }
    # Shared-drive readers can lock an existing capture. Every run gets new paths.
    $captures = Join-Path 'Z:\windows\.build\reviews' $name
    New-Item -ItemType Directory -Force $captures | Out-Null
    Copy-Item C:\workspace-build\review.bmp (Join-Path $captures 'review.bmp')
    foreach ($surface in @('editor', 'library', 'settings', 'calendar-settings', 'record', 'reading', 'home', 'month', 'narrow')) {
        $capture = "C:\workspace-build\review-$surface.bmp"
        if (Test-Path $capture) { Copy-Item $capture (Join-Path $captures "review-$surface.bmp") }
    }
    Write-Output "Synthetic captures: $captures"
} finally { Unregister-ScheduledTask $name -Confirm:$false }
exit 0
