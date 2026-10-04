param([ValidateSet('debug','release')][string]$Configuration='debug')
. $PSScriptRoot\windows-env.ps1
$exe=Get-ChotkiExecutable $Configuration
$OutputDir=$exe.DirectoryName
$env:PATH="$OutputDir;C:\Windows\system32;C:\Windows"
Set-Location $OutputDir
$app=Start-Process -FilePath $exe.FullName -ArgumentList '--notification-smoke' -NoNewWindow -PassThru -RedirectStandardOutput 'C:\workspace-build\notification-review.log' -RedirectStandardError 'C:\workspace-build\notification-review-error.log'
$null=$app.Handle
$app.Id | Set-Content 'C:\workspace-build\notification-review.pid'
$app.WaitForExit()
$code=$app.ExitCode
Get-Content 'C:\workspace-build\notification-review-error.log' | Add-Content 'C:\workspace-build\notification-review.log'
Add-Content 'C:\workspace-build\notification-review.log' "Native notification review exit: $code"
exit $code
