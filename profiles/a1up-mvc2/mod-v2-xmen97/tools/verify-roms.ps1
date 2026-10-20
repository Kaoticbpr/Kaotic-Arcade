# Checks the ROM zips in ..\roms against ROM-MANIFEST.txt and reports exactly what is
# wrong with each one, rather than letting the cabinet fail later with "cannot load content".
#
# Reads each zip's central directory directly, so it gets the real CRC32 of every file
# inside without decompressing anything. .NET's ZipArchive does not expose entry CRCs.

[CmdletBinding()]
param(
    [string]$RomDir,
    [string]$Manifest
)

# Resolved here, not as param() defaults: parameter defaults are evaluated before the script
# scope exists, so $PSScriptRoot is still empty at that point and Join-Path throws.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($RomDir))   { $RomDir   = Join-Path $here '..\roms' }
if ([string]::IsNullOrEmpty($Manifest)) { $Manifest = Join-Path $here '..\roms\ROM-MANIFEST.txt' }

function Get-ZipEntries {
    param([string]$Path)
    $fs = [System.IO.File]::Open($Path, 'Open', 'Read')
    try {
        $len = $fs.Length
        if ($len -lt 22) { return $null }
        # End of central directory: scan the tail for signature 0x06054b50
        $tail = [Math]::Min(66560, $len)
        $fs.Position = $len - $tail
        $buf = New-Object byte[] $tail
        [void]$fs.Read($buf, 0, $tail)
        $eocd = -1
        for ($i = $tail - 22; $i -ge 0; $i--) {
            if ($buf[$i] -eq 0x50 -and $buf[$i+1] -eq 0x4B -and $buf[$i+2] -eq 0x05 -and $buf[$i+3] -eq 0x06) {
                $eocd = $i; break
            }
        }
        if ($eocd -lt 0) { return $null }
        $count  = [BitConverter]::ToUInt16($buf, $eocd + 10)
        $cdOff  = [BitConverter]::ToUInt32($buf, $eocd + 16)
        $cdSize = [BitConverter]::ToUInt32($buf, $eocd + 12)

        $fs.Position = $cdOff
        $cd = New-Object byte[] $cdSize
        [void]$fs.Read($cd, 0, $cdSize)

        $out = @{}
        $p = 0
        for ($n = 0; $n -lt $count -and $p + 46 -le $cd.Length; $n++) {
            if (-not ($cd[$p] -eq 0x50 -and $cd[$p+1] -eq 0x4B -and $cd[$p+2] -eq 0x01 -and $cd[$p+3] -eq 0x02)) { break }
            $crc     = [BitConverter]::ToUInt32($cd, $p + 16)
            $usize   = [BitConverter]::ToUInt32($cd, $p + 24)
            $nameLen = [BitConverter]::ToUInt16($cd, $p + 28)
            $extLen  = [BitConverter]::ToUInt16($cd, $p + 30)
            $cmtLen  = [BitConverter]::ToUInt16($cd, $p + 32)
            $name    = [System.Text.Encoding]::UTF8.GetString($cd, $p + 46, $nameLen)
            if (-not $name.EndsWith('/')) {
                $out[$name] = ('{0}|{1:x8}' -f $usize, $crc)
            }
            $p += 46 + $nameLen + $extLen + $cmtLen
        }
        return $out
    } finally { $fs.Close() }
}

if (-not (Test-Path $Manifest)) { Write-Host "  ROM-MANIFEST.txt missing - skipping check."; exit 0 }

# manifest -> @{ zip = @{ file = "size|crc" } }
$want = @{}
foreach ($line in Get-Content $Manifest) {
    if ($line -match '^\s*#' -or $line -notmatch '\|') { continue }
    $f = $line.Split('|')
    if ($f.Count -lt 4) { continue }
    if (-not $want.ContainsKey($f[0])) { $want[$f[0]] = @{} }
    $want[$f[0]][$f[1]] = ('{0}|{1}' -f $f[2], $f[3])
}

$present = 0; $good = 0; $bad = @()
foreach ($zipName in ($want.Keys | Sort-Object)) {
    $path = Join-Path $RomDir $zipName
    if (-not (Test-Path $path)) { continue }
    $present++
    $have = Get-ZipEntries -Path $path
    if ($null -eq $have) { $bad += "  $zipName  - not a readable zip file"; continue }

    $missing = @(); $wrong = @()
    foreach ($f in $want[$zipName].Keys) {
        if (-not $have.ContainsKey($f)) { $missing += $f }
        elseif ($have[$f] -ne $want[$zipName][$f]) { $wrong += $f }
    }
    if ($missing.Count -eq 0 -and $wrong.Count -eq 0) {
        Write-Host ("  OK       {0}" -f $zipName)
        $good++
    } else {
        Write-Host ("  MISMATCH {0}" -f $zipName) -ForegroundColor Yellow
        if ($missing.Count) {
            $eg = ($missing | Select-Object -First 3) -join ', '
            $bad += ("  {0}: {1} file(s) missing, e.g. {2}" -f $zipName, $missing.Count, $eg)
        }
        if ($wrong.Count) {
            $eg = ($wrong | Select-Object -First 3) -join ', '
            $bad += ("  {0}: {1} file(s) wrong version, e.g. {2}" -f $zipName, $wrong.Count, $eg)
        }
    }
}

Write-Host ""
if ($present -eq 0) {
    Write-Host "  No ROM zips found in the roms folder."
    Write-Host "  See roms\PUT-YOUR-ROMS-HERE.txt for the exact filenames needed."
    exit 2
}

Write-Host ("  {0} of {1} set(s) present matched the known-good versions." -f $good, $present)
if ($bad.Count) {
    Write-Host ""
    Write-Host "  Problems found:" -ForegroundColor Yellow
    $bad | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
    Write-Host ""
    Write-Host "  A mismatched set usually means a different region or a newer/older"
    Write-Host "  dump than the cores expect. The game may still work, or may refuse"
    Write-Host "  to load. Sets that say OK above are the ones tested on a cabinet."
    exit 1
}
exit 0
