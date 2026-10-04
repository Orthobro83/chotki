# All desktop assertions against the optimized GUI-subsystem executable.
& $PSScriptRoot\verify-ui-desktop-vm.ps1 -Configuration release
exit $LASTEXITCODE
