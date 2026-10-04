# Shared mandatory compiler and execution environment helpers.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$env:MIMALLOC_DISABLE_REDIRECT = '1'
$env:SWIFT_DRIVER_USE_FRONTEND = '0'

function Test-IsX64([string]$FilePath) {
    try {
        $bytes = [IO.File]::ReadAllBytes($FilePath)
        $pe = [BitConverter]::ToInt32($bytes, 0x3C)
        return [BitConverter]::ToUInt16($bytes, $pe + 4) -eq 0x8664
    } catch { return $false }
}

function Get-ChotkiExecutable {
    $exe = Get-ChildItem C:\workspace-build\.build -Recurse -Filter ChotkiWindows.exe |
        Where-Object FullName -NotMatch 'Intermediates' |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (!$exe) { throw 'ChotkiWindows.exe was not produced.' }
    if (!(Test-IsX64 $exe.FullName)) { throw 'Executable is not AMD64.' }
    return $exe
}

function Copy-X64Runtime([string]$OutputDir) {
    # Match the 6.4 SDK; never mix older extracted runtime DLLs.
    $cores = @(Get-ChildItem C:\swift-x64-runtime\6.4.0\extracted -Recurse -Filter swiftCore.dll |
        Where-Object { Test-IsX64 $_.FullName })
    if ($cores.Count -ne 1) { throw 'Expected one extracted x64 Swift 6.4 runtime.' }
    foreach ($core in $cores) {
        Get-ChildItem $core.DirectoryName -Filter '*.dll' |
            Where-Object { Test-IsX64 $_.FullName } |
            Copy-Item -Destination $OutputDir -Force
    }
    $sqlite = 'C:\vcpkg\installed\x64-windows\bin\sqlite3.dll'
    if (!(Test-IsX64 $sqlite)) { throw 'SQLite DLL is not AMD64.' }
    Copy-Item $sqlite -Destination $OutputDir -Force
    foreach ($required in @('swiftCore.dll', 'sqlite3.dll')) {
        if (!(Test-IsX64 (Join-Path $OutputDir $required))) {
            throw "Missing or incompatible runtime: $required"
        }
    }
    foreach ($dll in Get-ChildItem $OutputDir -Filter '*.dll') {
        if (!(Test-IsX64 $dll.FullName)) { throw "Incompatible output DLL: $($dll.Name)" }
    }
}
