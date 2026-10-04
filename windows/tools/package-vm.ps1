# Assemble a reviewable x64 payload. This does not install, tag or publish it.
. $PSScriptRoot\windows-env.ps1
& $PSScriptRoot\packaging-space-vm.ps1
& $PSScriptRoot\build-vm.ps1 -Configuration release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$exe=Get-ChotkiExecutable 'release'
$OutputDir=$exe.DirectoryName
$env:PATH="$OutputDir;C:\Windows\system32;C:\Windows"
Set-Location $OutputDir
$check=Start-Process $exe.FullName -ArgumentList '--self-test' -Wait -PassThru -RedirectStandardOutput 'C:\workspace-build\package-check.log' -RedirectStandardError 'C:\workspace-build\package-check-error.log'
Get-Content 'C:\workspace-build\package-check.log'
if ($check.ExitCode -ne 0) { Get-Content 'C:\workspace-build\package-check-error.log'; throw "Release bootstrap failed: $($check.ExitCode)" }
$stage='C:\workspace-build\.build\package\Chotki-Windows-x64'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null
Copy-Item $exe.FullName $stage
Get-ChildItem $OutputDir -Filter '*.dll' -File | ForEach-Object {
    if (!(Test-IsX64 $_.FullName)) { throw "Non-x64 DLL in payload: $($_.Name)" }
    Copy-Item $_.FullName $stage
}
Get-ChildItem $OutputDir -Directory | Where-Object { $_.Name -like '*.resources' -or $_.Name -like '*.bundle' } | Copy-Item -Destination $stage -Recurse
Copy-Item 'C:\workspace-build\Branding\Chotki.ico' $stage
Copy-Item 'C:\workspace-build\Branding\LICENSE.txt' $stage
Copy-Item "$PSScriptRoot\install-windows.ps1" $stage
Copy-Item "$PSScriptRoot\launch-windows.ps1" $stage
New-Item -ItemType Directory -Force "$stage\Notices" | Out-Null
Copy-Item 'C:\workspace-build\Sources\WindowsUI\Notifications\LICENSE.txt' "$stage\Notices\WindowsNotifications-MIT.txt"
Copy-Item 'C:\workspace-build\Fonts\LICENSE.txt' "$stage\Notices\XCharter.txt"
Copy-Item 'C:\workspace-build\Branding\Swift-LICENSE.txt' "$stage\Notices\Swift-Apache-Runtime.txt"
# Verify the assembled payload itself, not just the compiler output directory.
$env:PATH="$stage;C:\Windows\system32;C:\Windows"
Set-Location $stage
$payloadCheck=Start-Process (Join-Path $stage 'ChotkiWindows.exe') -ArgumentList '--self-test' -Wait -PassThru -RedirectStandardOutput 'C:\workspace-build\payload-check.log' -RedirectStandardError 'C:\workspace-build\payload-check-error.log'
Get-Content 'C:\workspace-build\payload-check.log'
if($payloadCheck.ExitCode -ne 0){Get-Content 'C:\workspace-build\payload-check-error.log';throw "Assembled payload failed: $($payloadCheck.ExitCode)"}
$files=Get-ChildItem $stage -Recurse -File | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path=$_.FullName.Substring($stage.Length+1).Replace('\','/'); bytes=$_.Length; sha256=(Get-FileHash $_.FullName -Algorithm SHA256).Hash }
}
[ordered]@{architecture='x86_64'; version=$exe.VersionInfo.ProductVersion; files=@($files)} | ConvertTo-Json -Depth 5 | Set-Content "$stage\payload.json" -Encoding UTF8
$archive="$stage.zip"
Compress-Archive "$stage\*" $archive -Force
Write-Output "Draft payload: $stage"
Write-Output "Draft archive: $archive"
exit 0
