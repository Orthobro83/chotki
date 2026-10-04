# Current-user installation; practice records under LOCALAPPDATA\Chotki are untouched.
param([string]$Destination=(Join-Path $env:LOCALAPPDATA 'Programs\Chotki'))
$ErrorActionPreference='Stop'
$source=$PSScriptRoot
$manifest=Get-Content (Join-Path $source 'payload.json') -Raw | ConvertFrom-Json
if ($manifest.architecture -ne 'x86_64') { throw 'This installer requires the x86_64 payload.' }
foreach ($entry in $manifest.files) {
    if ([IO.Path]::IsPathRooted($entry.path) -or $entry.path.Split('/') -contains '..') { throw 'Invalid payload path.' }
    $file=Join-Path $source $entry.path
    if (!(Test-Path $file -PathType Leaf) -or (Get-FileHash $file -Algorithm SHA256).Hash -ne $entry.sha256) { throw "Damaged payload: $($entry.path)" }
}
if (Get-Process ChotkiWindows -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq (Join-Path $Destination 'ChotkiWindows.exe') }) { throw 'Quit Chotki from its tray menu before updating it.' }
# An existing installation must have our manifest. Never replace an unrelated folder.
if ((Test-Path $Destination) -and !(Test-Path (Join-Path $Destination 'payload.json'))) { throw 'Destination is not a managed Chotki installation.' }
$parent=Split-Path $Destination -Parent
New-Item -ItemType Directory -Force $parent | Out-Null
$incoming=Join-Path $parent ('Chotki-incoming-'+[Guid]::NewGuid().ToString('N'))
$previous=Join-Path $parent ('Chotki-previous-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $incoming | Out-Null
try {
    foreach ($entry in $manifest.files) {
        $target=Join-Path $incoming $entry.path
        New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
        Copy-Item (Join-Path $source $entry.path) $target
    }
    Copy-Item (Join-Path $source 'payload.json') $incoming
    if (Test-Path $Destination) { Move-Item $Destination $previous }
    try { Move-Item $incoming $Destination } catch { if (Test-Path $previous) { Move-Item $previous $Destination }; throw }
    $shell=New-Object -ComObject WScript.Shell
    foreach ($folder in @([Environment]::GetFolderPath('Desktop'),(Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs'))) {
        New-Item -ItemType Directory -Force $folder | Out-Null
        $shortcut=$shell.CreateShortcut((Join-Path $folder 'Chotki.lnk'))
        $shortcut.TargetPath='C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
        $shortcut.Arguments='-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+(Join-Path $Destination 'launch-windows.ps1')+'"'
        $shortcut.WorkingDirectory=$Destination
        $shortcut.IconLocation=(Join-Path $Destination 'Chotki.ico')+',0'
        $shortcut.Description='Chotki'
        $shortcut.Save()
    }
    if (Test-Path $previous) { Remove-Item $previous -Recurse -Force }
    Write-Output "Installed Chotki x86_64 at $Destination. Desktop and Start menu shortcuts are ready."
} finally {
    if (Test-Path $incoming) { Remove-Item $incoming -Recurse -Force }
}
