# Extract the matching runtime without installing or changing the ARM64 compiler.
. $PSScriptRoot\windows-env.ps1
$base = 'C:\swift-x64-runtime\6.4.0'
$installer = Join-Path $base 'installer.exe'
$dark = 'C:\swift-x64-runtime\extraction-tools\wix\dark.exe'
if (!(Test-Path $dark)) { throw 'Portable WiX dark.exe extraction tool is missing.' }
New-Item -ItemType Directory -Force $base | Out-Null
if (!(Test-Path $installer)) {
    Invoke-WebRequest 'https://download.swift.org/swift-6.4.0-release/windows10/swift-6.4.0-RELEASE/swift-6.4.0-RELEASE-windows10.exe' -OutFile $installer
}
& $dark -x "$base\payloads" $installer
if ($LASTEXITCODE -ne 0) { throw 'Installer payload extraction failed.' }
[xml]$manifest = Get-Content "$base\payloads\UX\manifest.xml"
$payloads = $manifest.SelectNodes("//*[local-name()='Payload']")
foreach ($name in @('rtl.amd64.msi', 'rtl.amd64.cab')) {
    $payload = $payloads | Where-Object FilePath -EQ $name | Select-Object -First 1
    if (!$payload) { throw "Missing runtime payload: $name" }
    Copy-Item "$base\payloads\AttachedContainer\$($payload.SourcePath)" "$base\payloads\$name" -Force
}
$process = Start-Process msiexec.exe -ArgumentList "/a $base\payloads\rtl.amd64.msi /qn ALLUSERS=0 TARGETDIR=$base\extracted /l*v $base\extract.log" -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Administrative extraction failed: $($process.ExitCode)" }
if (!(Test-IsX64 "$base\extracted\swiftCore.dll")) { throw 'Extracted Swift runtime is not AMD64.' }
Write-Output "Swift 6.4 x64 runtime extracted to $base\extracted"
exit 0
