param(
  [string]$Src = "C:\path\to\mvc2-cabinet\MVC2-Cabinet-3in1",
  [string]$Dst = "C:\path\to\mvc2-cabinet\MVC2-Cabinet-3in1.zip"
)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$ErrorActionPreference = "Stop"

# files that must be executable on macOS/Linux
$EXEC = @('mac/INSTALL.command','mac/UNINSTALL.command','mac/platform-tools/adb')

$tmp = "$Dst.tmp"
if (Test-Path $tmp) { Remove-Item $tmp -Force }

$root = (Resolve-Path $Src).Path
$base = Split-Path $root -Leaf

$fs  = [System.IO.File]::Open($tmp, [System.IO.FileMode]::CreateNew)
$zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)

$n = 0; $execSet = 0
foreach ($f in Get-ChildItem -Path $root -Recurse -File) {
    $rel = $f.FullName.Substring($root.Length).TrimStart('\','/')
    $rel = $rel -replace '\\','/'                       # ZIP spec: forward slashes only
    $entryName = "$base/$rel"

    $entry = $zip.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)

    # stamp unix mode in the high 16 bits so macOS keeps the exec bit
    $mode = if ($EXEC -contains $rel) { 0x81ED } else { 0x81A4 }   # 100755 : 100644
    try { $entry.ExternalAttributes = $mode -shl 16; if ($EXEC -contains $rel) { $execSet++ } } catch { }

    $es = $entry.Open()
    $ifs = [System.IO.File]::OpenRead($f.FullName)
    $ifs.CopyTo($es)
    $ifs.Dispose(); $es.Dispose()
    $n++
}
$zip.Dispose(); $fs.Dispose()

if (Test-Path $Dst) { Remove-Item $Dst -Force }
Move-Item $tmp $Dst

$mb = (Get-Item $Dst).Length / 1MB
Write-Output ("packed {0} files, {1} marked executable -> {2:N1} MB" -f $n, $execSet, $mb)
