param([switch]$Startup)
# Keep the x64 runtime search path isolated from the ARM64 compiler installation.
$env:PATH="$PSScriptRoot;C:\Windows\system32;C:\Windows"
Set-Location $PSScriptRoot
$launch=@{FilePath=(Join-Path $PSScriptRoot 'ChotkiWindows.exe'); WorkingDirectory=$PSScriptRoot}
if ($Startup) { $launch.ArgumentList='--startup' }
Start-Process @launch
