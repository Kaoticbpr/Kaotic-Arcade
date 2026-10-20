<#
  Packs a release folder into a zip that macOS can actually open.

  WHY THIS EXISTS
  ---------------
  MVC2-Cabinet-Mod-v2.zip was built with a writer that streams -- Java's ZipOutputStream, which
  is what both `jar` and most Java-based packers use. A streaming writer does not know an
  entry's size or CRC until it has finished deflating it, so it writes zeros into the local file
  header, sets general-purpose bit 3, and appends the real values in a "data descriptor" after
  the compressed bytes.

  Info-ZIP and Windows Explorer read the central directory, where the real sizes always are, so
  the archive tests clean on Windows. macOS Archive Utility reads the stream front-to-back off
  the local headers, hits an entry that claims to be zero bytes long, and gives up with
  "unsupported format" -- which is exactly what X-Men '97 owners reported, and exactly why the
  older 3-in-1 zip (63 fewer such entries: it had none) opened for them without complaint.

  .NET's ZipArchive writes to a seekable file and goes back to patch the real CRC and sizes into
  each local header, so nothing here sets bit 3. The script asserts that before it exits.

  usage: powershell -ExecutionPolicy Bypass -File make-zip.ps1 -SourceDir <folder> -OutZip <zip>
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SourceDir,
    [Parameter(Mandatory = $true)][string]$OutZip
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$src = (Resolve-Path $SourceDir).Path.TrimEnd('\')
$top = Split-Path $src -Leaf

# Already-deflated payloads: the ROM sets are zips of zips and give back nothing for the time
# spent. APKs are deliberately NOT in this list -- they still shed a few percent, and at three
# of them that is worth the half-minute.
$storeExt = @('.zip', '.png', '.jpg', '.jpeg', '.mp3', '.gz', '.7z')

# Files that have to keep their executable bit. A zip written on Windows records a DOS-style
# attribute set, so macOS will still land these mode 644 and the mac docs tell people to run
# the installer with `bash` -- but recording the mode costs nothing and any unzip that honours
# it (Info-ZIP with -X, most Linux tooling) gets it right.
function Is-Executable([string]$rel) {
    return ($rel -match '\.(command|sh)$') -or ($rel -match '(^|/)platform-tools/(adb|fastboot|etc1tool|hprof-conv|make_f2fs\w*|mke2fs|sqlite3)$')
}

$outFull = if ([System.IO.Path]::IsPathRooted($OutZip)) { $OutZip }
           else { Join-Path (Get-Location).ProviderPath $OutZip }
$outFull = [System.IO.Path]::GetFullPath($outFull)
if (Test-Path -LiteralPath $outFull) { Remove-Item -LiteralPath $outFull -Force }

$fs = [System.IO.File]::Open($outFull, [System.IO.FileMode]::CreateNew,
                             [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
$zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create, $true)

$nFiles = 0
$nDirs  = 0
try {
    # Directories first, in path order, so the archive reads the way the folder does. The top
    # level gets its own entry too -- some extractors use it to name the folder they create.
    $dirs = @(Get-Item -LiteralPath $src) +
            @(Get-ChildItem -LiteralPath $src -Recurse -Directory | Sort-Object FullName)
    foreach ($d in $dirs) {
        $rel = if ($d.FullName -eq $src) { '' }
               else { $d.FullName.Substring($src.Length + 1).Replace('\', '/') + '/' }
        $e = $zip.CreateEntry("$top/$rel", [System.IO.Compression.CompressionLevel]::NoCompression)
        $e.LastWriteTime = $d.LastWriteTime
        try { $e.ExternalAttributes = (0x41ED -shl 16) -bor 0x10 } catch { }   # drwxr-xr-x + DOS DIRECTORY
        $nDirs++
    }

    foreach ($f in (Get-ChildItem -LiteralPath $src -Recurse -File | Sort-Object FullName)) {
        $rel = $f.FullName.Substring($src.Length + 1).Replace('\', '/')
        $level = if ($storeExt -contains $f.Extension.ToLower()) {
            [System.IO.Compression.CompressionLevel]::NoCompression
        } else {
            [System.IO.Compression.CompressionLevel]::Optimal
        }
        $e = $zip.CreateEntry("$top/$rel", $level)
        $e.LastWriteTime = $f.LastWriteTime
        $mode = if (Is-Executable $rel) { 0x81ED } else { 0x81A4 }             # -rwxr-xr-x / -rw-r--r--
        try { $e.ExternalAttributes = ($mode -shl 16) } catch { }

        $in  = [System.IO.File]::OpenRead($f.FullName)
        $out = $e.Open()
        try { $in.CopyTo($out, 1MB) } finally { $out.Dispose(); $in.Dispose() }
        $nFiles++
    }
} finally {
    $zip.Dispose()
    $fs.Dispose()
}

Write-Output ("packed {0} files and {1} directories into {2}" -f $nFiles, $nDirs, $outFull)
Write-Output ("size: {0:N0} bytes" -f (Get-Item -LiteralPath $outFull).Length)

# --- verify: every local file header must carry real sizes, not bit 3 -------------------------
$check = [System.IO.File]::OpenRead($outFull)
$br = New-Object System.IO.BinaryReader($check)
try {
    $len = $check.Length
    $scan = [Math]::Min(66000L, $len)
    $check.Position = $len - $scan
    $buf = $br.ReadBytes([int]$scan)
    $eocd = -1
    for ($i = $buf.Length - 22; $i -ge 0; $i--) {
        if ($buf[$i] -eq 0x50 -and $buf[$i + 1] -eq 0x4b -and $buf[$i + 2] -eq 0x05 -and $buf[$i + 3] -eq 0x06) { $eocd = $i; break }
    }
    if ($eocd -lt 0) { throw "no end-of-central-directory record" }
    $count = [BitConverter]::ToUInt16($buf, $eocd + 10)
    $check.Position = [BitConverter]::ToUInt32($buf, $eocd + 16)

    $streaming = 0
    for ($e = 0; $e -lt $count; $e++) {
        if ($br.ReadUInt32() -ne 0x02014b50) { throw "corrupt central directory at entry $e" }
        $null = $br.ReadBytes(24)
        $nlen = $br.ReadUInt16(); $elen = $br.ReadUInt16(); $clen = $br.ReadUInt16()
        $null = $br.ReadBytes(8)
        $lho = $br.ReadUInt32()
        $null = $br.ReadBytes($nlen + $elen + $clen)
        $save = $check.Position
        $check.Position = $lho + 6
        if ($br.ReadUInt16() -band 0x8) { $streaming++ }
        $check.Position = $save
    }
    if ($streaming -gt 0) { throw "$streaming of $count entries still use data descriptors -- macOS will refuse this zip" }
    Write-Output "verified: $count entries, none using data descriptors"
} finally {
    $br.Close(); $check.Close()
}
