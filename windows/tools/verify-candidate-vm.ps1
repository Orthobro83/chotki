# Declare no candidate unless every sequential acceptance step succeeds.
& $PSScriptRoot\verify-release-vm.ps1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $PSScriptRoot\verify-input-vm.ps1 -Configuration release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $PSScriptRoot\package-vm.ps1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $PSScriptRoot\verify-lifecycle-vm.ps1
exit $LASTEXITCODE
