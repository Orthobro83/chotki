# Compile immutable, content-addressed Win32 icon/version/manifest resources.
function New-ChotkiResources {
    $branding='C:\workspace-build\Branding'
    $parts=Get-ChildItem $branding -File | Sort-Object Name | ForEach-Object { (Get-FileHash $_.FullName -Algorithm SHA256).Hash }
    $algorithm=[Security.Cryptography.SHA256]::Create()
    try { $digest=$algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes(($parts -join ''))) } finally { $algorithm.Dispose() }
    $hash=($digest | ForEach-Object { $_.ToString('x2') }) -join ''
    $folder='C:\workspace-build\.build\Branding'
    New-Item -ItemType Directory -Force $folder | Out-Null
    $resource=Join-Path $folder ("chotki-"+$hash.Substring(0,16)+'.res')
    if (Test-Path $resource) { return $resource }
    $kits=(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots').KitsRoot10
    $versions=Get-ChildItem (Join-Path $kits 'bin') -Directory | Where-Object Name -Match '^\d+\.\d+\.\d+\.\d+$' | Sort-Object { [version]$_.Name } -Descending
    $compiler=$null
    foreach ($version in $versions) {
        foreach ($hostArchitecture in @('arm64','x64')) {
            $candidate=Join-Path $version.FullName "$hostArchitecture\rc.exe"
            if (Test-Path $candidate) { $compiler=$candidate; $sdkVersion=$version.Name; break }
        }
        if ($compiler) { break }
    }
    if (!$compiler) { throw 'Windows SDK resource compiler was not found.' }
    Push-Location $branding
    try {
        & $compiler /nologo "/fo$resource" "/I$(Join-Path $kits "Include\$sdkVersion\um")" "/I$(Join-Path $kits "Include\$sdkVersion\shared")" Chotki.rc
        if ($LASTEXITCODE -ne 0) { throw "Windows branding resource compilation failed: $LASTEXITCODE" }
    } finally { Pop-Location }
    if (!(Test-Path $resource)) { throw 'Windows branding resource file was not produced.' }
    return $resource
}
