# Extract only x64 testing DLLs from the SDK cabinet; do not install the SDK.
. $PSScriptRoot\windows-env.ps1
$base = 'C:\swift-x64-runtime\6.4.0'
[xml]$manifest = Get-Content "$base\payloads\UX\manifest.xml"
$payloads = $manifest.SelectNodes("//*[local-name()='Payload']")
$msi = $payloads | Where-Object FilePath -EQ 'windows.msi' | Select-Object -First 1
$cab = $payloads | Where-Object FilePath -EQ 'sdk.windows.x64.cab' | Select-Object -First 1
if (!$msi -or !$cab) { throw 'Extract the Swift 6.4 installer payloads first.' }
Copy-Item "$base\payloads\AttachedContainer\$($msi.SourcePath)" "$base\payloads\windows.msi" -Force
$cabinet = "$base\payloads\AttachedContainer\$($cab.SourcePath)"
$entries = (& expand.exe -D $cabinet) -join "`n"
$temporary = "$base\test-payloads"
$output = "$base\test-runtime"
New-Item -ItemType Directory -Force $temporary,$output | Out-Null
$installer = New-Object -ComObject WindowsInstaller.Installer
$database = $installer.OpenDatabase("$base\payloads\windows.msi",0)
$view = $database.OpenView('SELECT `File`, `FileName` FROM `File`')
$view.Execute()
while ($record = $view.Fetch()) {
    $id = $record.StringData(1)
    $name = $record.StringData(2).Split('|')[-1]
    if ($name -notmatch '\.dll$' -or $entries -notmatch [Regex]::Escape($id)) { continue }
    & expand.exe "-F:$id" $cabinet $temporary | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to extract $name" }
    $file = Join-Path $temporary $id
    if (!(Test-IsX64 $file)) { throw "SDK DLL is not AMD64: $name" }
    Copy-Item $file (Join-Path $output $name) -Force
    Write-Output "Extracted x64 test runtime: $name"
}
$view.Close()
exit 0
