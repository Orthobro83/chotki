# The SSH helper already verified and expanded the source archive onto C:.
# Delete only obsolete compiler inputs in generated workspace source directories.
$root = 'C:\workspace-build'
$manifest = Get-Content "$root\source-manifest.json" -Raw | ConvertFrom-Json
$present = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($path in $manifest) { [void]$present.Add($path.Replace('/', '\')) }
foreach ($folder in @('Sources', 'shared-core\Sources', 'shared-core\Tests', 'tools', 'Branding')) {
    $directory = Join-Path $root $folder
    if (!(Test-Path $directory)) { continue }
    Get-ChildItem $directory -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring($root.Length + 1)
        if ($relative.StartsWith('Sources\ChotkiWindows\Assets\')) { return }
        if ($_.Extension -in @('.swift', '.c', '.cpp', '.h', '.modulemap', '.json', '.ps1', '.py', '.rc', '.manifest', '.ico') -and !$present.Contains($relative)) {
            Remove-Item -LiteralPath $_.FullName -Force
        }
    }
}
