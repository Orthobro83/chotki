# Retain only task-generated visual-review artifacts; never app records or sources.
function Remove-OldChotkiReviews([int]$Keep=3) {
    $root='C:\workspace-build\reviews'
    if (!(Test-Path $root)) { return }
    $directories=@(Get-ChildItem $root -Directory | Where-Object Name -Match '^ChotkiReview-[0-9a-f]{8}$' | Sort-Object LastWriteTime -Descending)
    foreach ($directory in ($directories | Select-Object -Skip $Keep)) {
        Remove-Item $directory.FullName -Recurse -Force
        $archive=$directory.FullName+'.zip'
        if (Test-Path $archive) { Remove-Item $archive -Force }
    }
}
