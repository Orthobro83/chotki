. $PSScriptRoot\windows-env.ps1
# Run prepare-core.py on the Mac first. Synchronize to native storage, then build.
# Shared-drive timestamps can be stale. Copy even files classified as same.
if ($env:CHOTKI_SYNCHRONIZED_ARCHIVE -ne '1') {
# Explicit source groups keep large uploaded archives and local credentials out of sync.
robocopy Z:\windows C:\workspace-build Package.swift README.md AGENTS.md BUILD-ENVIRONMENT.md PORT.md VERIFICATION.md /IS /IT /NFL /NDL /NJH /NJS /R:1 /W:1
if ($LASTEXITCODE -ge 8) { throw 'Project synchronization failed.' }
foreach ($folder in @('Sources','shared-core','Fonts','tools')) {
    robocopy "Z:\windows\$folder" "C:\workspace-build\$folder" /E /IS /IT /XD .build .swiftpm .git Assets /NFL /NDL /NJH /NJS /R:1 /W:1
    if ($LASTEXITCODE -ge 8) { throw "Source synchronization failed: $folder" }
}
}
$assetRoot = 'C:\workspace-build\Sources\ChotkiWindows\Assets'
$manifest = if ($env:CHOTKI_SYNCHRONIZED_ARCHIVE -eq '1') { 'C:\workspace-build\assets-required.sha256' } else { 'Z:\windows\Sources\ChotkiWindows\Assets\catalog.sha256' }
$expected = (Get-Content $manifest -Raw).Trim()
$current = if (Test-Path "$assetRoot\catalog.sha256") { (Get-Content "$assetRoot\catalog.sha256" -Raw).Trim() } else { '' }
if ($current -ne $expected) {
    if (!(Test-Path 'C:\workspace-build\assets.zip')) { throw 'Prepare assets on Mac and upload windows/assets.zip through run-vm.py --upload first.' }
    Expand-Archive 'C:\workspace-build\assets.zip' 'C:\workspace-build\Sources\ChotkiWindows' -Force
    if ((Get-Content "$assetRoot\catalog.sha256" -Raw).Trim() -ne $expected) { throw 'Uploaded artwork archive is out of date.' }
}
Set-Location C:\workspace-build
swift build --triple x86_64-unknown-windows-msvc --build-system native -Xcc -IC:\vcpkg\installed\x64-windows\include -Xlinker -LC:\vcpkg\installed\x64-windows\lib
$buildExit = $LASTEXITCODE
if ($buildExit -ne 0) { exit $buildExit }
$exe = Get-ChotkiExecutable
Copy-X64Runtime $exe.DirectoryName
exit 0
