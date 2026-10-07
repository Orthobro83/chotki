. $PSScriptRoot\windows-env.ps1
& $PSScriptRoot\build-vm.ps1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
# Prefer the archive uploaded from this checkout (run-vm.py --upload windows/test-fixtures.zip); the shared
# mount may belong to another checkout. Fall back to the mount only when nothing was uploaded.
if (!(Test-Path C:\workspace-build\test-fixtures.zip)) {
    Copy-Item Z:\windows\test-fixtures.zip C:\workspace-build\test-fixtures.zip -Force
}
Expand-Archive C:\workspace-build\test-fixtures.zip C:\workspace-build -Force
Set-Location C:\workspace-build\shared-core
swift build --triple x86_64-unknown-windows-msvc --build-system native --build-tests -Xcc -IC:\vcpkg\installed\x64-windows\include -Xlinker -LC:\vcpkg\installed\x64-windows\lib
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$runner = Get-ChildItem .build -Recurse -File | Where-Object {
    $_.Name -match 'PackageTests\.(exe|xctest)$'
} | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (!$runner) { throw 'Core test runner was not produced.' }
if (!(Test-IsX64 $runner.FullName)) { throw 'Core test runner is not AMD64.' }
Copy-X64Runtime $runner.DirectoryName
Get-ChildItem C:\swift-x64-runtime\6.4.0\test-runtime -Filter '*.dll' | ForEach-Object {
    if (!(Test-IsX64 $_.FullName)) { throw "Test DLL is not AMD64: $($_.Name)" }
    Copy-Item $_.FullName $runner.DirectoryName -Force
}
$env:PATH = "$($runner.DirectoryName);C:\Windows\system32;C:\Windows"
Set-Location $runner.DirectoryName
# SwiftPM emits a PE executable with .xctest extension; PowerShell requires .exe.
$testExe = Join-Path $runner.DirectoryName 'ChotkiCoreTests.exe'
Copy-Item $runner.FullName $testExe -Force
$process = Start-Process $testExe -ArgumentList '--testing-library swift-testing' -Wait -PassThru -RedirectStandardOutput C:\workspace-build\core-tests.stdout.log -RedirectStandardError C:\workspace-build\core-tests.stderr.log
$code = $process.ExitCode
Get-Content C:\workspace-build\core-tests.stdout.log,C:\workspace-build\core-tests.stderr.log
Write-Output "Core test exit: $code"
exit $code
