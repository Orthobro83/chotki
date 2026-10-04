. $PSScriptRoot\windows-env.ps1
& $PSScriptRoot\build-vm.ps1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$exe = Get-ChotkiExecutable
Write-Output 'ChotkiWindows PE machine: 0x8664'
$OutputDir = $exe.DirectoryName
$env:PATH = "$OutputDir;C:\Windows\system32;C:\Windows"
Set-Location $OutputDir
& $exe.FullName --self-test
$runExit = $LASTEXITCODE
Write-Output "Execution exit: $runExit"
if ($runExit -ne 0) { exit $runExit }

if ($runExit -eq 0) {
    & $exe.FullName --ui-smoke
    Write-Output "UI smoke exit: $LASTEXITCODE"
    exit $LASTEXITCODE
}
