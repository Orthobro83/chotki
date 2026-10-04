# Run on the logged-in VM desktop, using only synthetic data.
. $PSScriptRoot\windows-env.ps1
$exe = Get-ChotkiExecutable
$OutputDir = $exe.DirectoryName
$env:PATH = "$OutputDir;C:\Windows\system32;C:\Windows"
$env:CHOTKI_REVIEW_CAPTURE = 'C:\workspace-build\review.bmp'
Set-Location $OutputDir
& $exe.FullName --ui-smoke *> C:\workspace-build\review.log
$code = $LASTEXITCODE
Add-Content C:\workspace-build\review.log "UI review exit: $code"
exit $code
