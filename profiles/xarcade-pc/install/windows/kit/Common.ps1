# VPX Cabinet Kit - shared engine (dot-sourced by the Table Installer, Display Mode and Setup).
# Windows port of the KaoticBPR Arcade vpx-add.py / vpx-layout.py: sorts a table's downloads into the
# Visual Pinball X layout, applies the known script fixes for VPX 10.8.1's PinMAME plugin, places the
# backglass / DMD for the current display mode and adds the ES-DE entry + artwork.

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Web.Extensions
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Latin1 = [System.Text.Encoding]::GetEncoding(28591)
$Utf8   = New-Object System.Text.UTF8Encoding($false)

# ---------- config ----------
$ConfigPath = if ($env:PINBALL_KIT_CONFIG) { $env:PINBALL_KIT_CONFIG } else { 'C:\Pinball\Kit\kit.json' }

function New-KitConfig([string]$root) {
    $esde = Join-Path $root 'ES-DE'
    [ordered]@{
        Root              = $root
        EsdeDir           = $esde
        EsdeData          = Join-Path $esde 'ES-DE'
        Tables            = Join-Path $esde 'ROMs\vpinball'
        VpxDir            = Join-Path $esde 'Emulators\VPinballX'
        VpxExe            = ''
        VpxIni            = Join-Path $env:APPDATA 'VPinballX\10.8\VPinballX.ini'
        NativeW           = 1920
        NativeH           = 1080
        Mode              = 'landscape'
        PortraitTurn      = 90
        PortraitBackglass = $false
    }
}
function Get-KitConfig {
    if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Kit config not found at $ConfigPath - run Setup first." }
    $j = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    $h = [ordered]@{}; foreach ($p in $j.PSObject.Properties) { $h[$p.Name] = $p.Value }
    return $h
}
function Save-KitConfig($cfg) {
    $dir = Split-Path $ConfigPath; if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    [IO.File]::WriteAllText($ConfigPath, ($cfg | ConvertTo-Json), $Utf8)
}
function Get-MediaDir($cfg)  { Join-Path $cfg.EsdeData 'downloaded_media\vpinball' }
function Get-Gamelist($cfg)  { Join-Path $cfg.EsdeData 'gamelists\vpinball\gamelist.xml' }

# ---------- reading the table script straight out of the .vpx (an OLE compound file) ----------
if (-not ('VpxScript' -as [type])) {
Add-Type -TypeDefinition @'
using System; using System.IO; using System.Text; using System.Collections.Generic;
public static class VpxScript {
    static byte[] Sec(FileStream fs, int s, int ss) { var b = new byte[ss]; fs.Seek((long)(s + 1) * ss, SeekOrigin.Begin); int n = 0; while (n < ss) { int r = fs.Read(b, n, ss - n); if (r <= 0) break; n += r; } return b; }
    static byte[] Chain(FileStream fs, int[] fat, int start, int ss, long size) {
        var ms = new MemoryStream(); int s = start, guard = 0;
        while (s >= 0 && s < fat.Length && guard++ < 10000000) { var b = Sec(fs, s, ss); ms.Write(b, 0, b.Length); if (size >= 0 && ms.Length >= size) break; s = fat[s]; }
        var r = ms.ToArray(); if (size >= 0 && r.Length > size) Array.Resize(ref r, (int)size); return r;
    }
    static int[] Ints(byte[] b) { var r = new int[b.Length / 4]; for (int i = 0; i < r.Length; i++) r[i] = BitConverter.ToInt32(b, i * 4); return r; }
    public static string Read(string path) {
        using (var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite)) {
            var h = new byte[512]; fs.Read(h, 0, 512);
            if (BitConverter.ToUInt64(h, 0) != 0xE11AB1A1E011CFD0UL) return null;
            int ss = 1 << BitConverter.ToUInt16(h, 0x1E), mss = 1 << BitConverter.ToUInt16(h, 0x20);
            int nFat = BitConverter.ToInt32(h, 0x2C), dirStart = BitConverter.ToInt32(h, 0x30);
            uint cutoff = BitConverter.ToUInt32(h, 0x38);
            int miniFatStart = BitConverter.ToInt32(h, 0x3C), difat = BitConverter.ToInt32(h, 0x44), nDifat = BitConverter.ToInt32(h, 0x48);
            var fatSecs = new List<int>();
            for (int i = 0; i < 109 && fatSecs.Count < nFat; i++) { int s = BitConverter.ToInt32(h, 0x4C + i * 4); if (s >= 0) fatSecs.Add(s); }
            while (fatSecs.Count < nFat && difat >= 0 && nDifat-- > 0) {
                var b = Sec(fs, difat, ss); int per = ss / 4 - 1;
                for (int i = 0; i < per && fatSecs.Count < nFat; i++) { int s = BitConverter.ToInt32(b, i * 4); if (s >= 0) fatSecs.Add(s); }
                difat = BitConverter.ToInt32(b, per * 4);
            }
            var fat = new int[fatSecs.Count * ss / 4]; int k = 0;
            foreach (int s in fatSecs) { var b = Sec(fs, s, ss); for (int i = 0; i < ss / 4; i++) fat[k++] = BitConverter.ToInt32(b, i * 4); }
            var dir = Chain(fs, fat, dirStart, ss, -1);
            int rootStart = BitConverter.ToInt32(dir, 0x74); long rootSize = BitConverter.ToUInt32(dir, 0x78);
            for (int off = 0; off + 128 <= dir.Length; off += 128) {
                int nl = BitConverter.ToUInt16(dir, off + 0x40); if (nl < 2 || nl > 64) continue;
                if (Encoding.Unicode.GetString(dir, off, nl - 2) != "GameData" || dir[off + 0x42] != 2) continue;
                int start = BitConverter.ToInt32(dir, off + 0x74); long size = BitConverter.ToUInt32(dir, off + 0x78);
                byte[] data;
                if (size < cutoff) {
                    var mini = Chain(fs, fat, rootStart, ss, rootSize);
                    var minifat = Ints(Chain(fs, fat, miniFatStart, ss, -1));
                    var ms = new MemoryStream(); int s = start, guard = 0;
                    while (s >= 0 && s < minifat.Length && ms.Length < size && guard++ < 1000000) { ms.Write(mini, s * mss, Math.Min(mss, mini.Length - s * mss)); s = minifat[s]; }
                    data = ms.ToArray(); if (data.Length > size) Array.Resize(ref data, (int)size);
                } else data = Chain(fs, fat, start, ss, size);
                return Script(data);
            }
            return null;
        }
    }
    static string Script(byte[] d) {   // BIFF records: [int32 len][4-char tag][len-4 bytes]; CODE is [int32 n][n chars]
        int p = 0;
        while (p + 8 <= d.Length) {
            int len = BitConverter.ToInt32(d, p); string tag = Encoding.ASCII.GetString(d, p + 4, 4); p += 8;
            if (tag == "CODE") { int n = BitConverter.ToInt32(d, p); p += 4; if (n < 0 || p + n > d.Length) return null; return Encoding.GetEncoding(28591).GetString(d, p, n); }
            if (tag == "ENDB" || len < 4) break;
            p += len - 4;
        }
        return null;
    }
}
'@
}

# ---------- display rotation (portrait / landscape) ----------
if (-not ('KitDisplay' -as [type])) {
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public static class KitDisplay {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
        public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra; public int dmFields;
        public int dmPositionX, dmPositionY, dmDisplayOrientation, dmDisplayFixedOutput;
        public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
        public short dmLogPixels; public int dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency;
        public int dmICMMethod, dmICMIntent, dmMediaType, dmDitherType, dmReserved1, dmReserved2, dmPanningWidth, dmPanningHeight;
    }
    [DllImport("user32.dll", CharSet = CharSet.Ansi)] static extern bool EnumDisplaySettings(string dev, int mode, ref DEVMODE dm);
    [DllImport("user32.dll", CharSet = CharSet.Ansi)] static extern int ChangeDisplaySettings(ref DEVMODE dm, int flags);
    public static int[] Current() { var dm = new DEVMODE(); dm.dmSize = (short)Marshal.SizeOf(dm); EnumDisplaySettings(null, -1, ref dm); return new[] { dm.dmPelsWidth, dm.dmPelsHeight, dm.dmDisplayOrientation }; }
    // orientation: 0 = landscape, 1 = 90, 2 = 180, 3 = 270. Returns 0 on success.
    public static int Rotate(int orientation) {
        var dm = new DEVMODE(); dm.dmSize = (short)Marshal.SizeOf(dm);
        if (!EnumDisplaySettings(null, -1, ref dm)) return -99;
        bool nowPortrait = (dm.dmDisplayOrientation & 1) == 1, wantPortrait = (orientation & 1) == 1;
        if (nowPortrait != wantPortrait) { int t = dm.dmPelsWidth; dm.dmPelsWidth = dm.dmPelsHeight; dm.dmPelsHeight = t; }
        dm.dmDisplayOrientation = orientation;
        dm.dmFields = 0x80 | 0x80000 | 0x100000;   // DM_DISPLAYORIENTATION | DM_PELSWIDTH | DM_PELSHEIGHT
        return ChangeDisplaySettings(ref dm, 1);    // CDS_UPDATEREGISTRY
    }
}
'@
}

# ---------- ini files (VPinballX.ini and the per-table "<table>.ini") ----------
function Set-IniKeys([string]$path, [string]$section, $values) {
    $lines = New-Object System.Collections.Generic.List[string]
    if (Test-Path -LiteralPath $path) { foreach ($l in ([IO.File]::ReadAllText($path) -split "`r?`n")) { $lines.Add($l) } }
    while ($lines.Count -gt 0 -and -not $lines[$lines.Count - 1].Trim()) { $lines.RemoveAt($lines.Count - 1) }
    $start = -1; for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -eq "[$section]") { $start = $i; break } }
    if ($start -lt 0) { if ($lines.Count) { $lines.Add('') }; $lines.Add("[$section]"); $start = $lines.Count - 1 }
    $end = $lines.Count; for ($i = $start + 1; $i -lt $lines.Count; $i++) { if ($lines[$i].StartsWith('[')) { $end = $i; break } }
    while ($end -gt $start + 1 -and -not $lines[$end - 1].Trim()) { $end-- }
    foreach ($key in $values.Keys) {
        $line = "$key = $($values[$key])"; $found = $false
        for ($i = $start + 1; $i -lt $end; $i++) { if ($lines[$i] -match ('^' + [regex]::Escape($key) + '\s*=')) { $lines[$i] = $line; $found = $true; break } }
        if (-not $found) { $lines.Insert($end, $line); $end++ }
    }
    $dir = Split-Path $path; if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    [IO.File]::WriteAllText($path, (($lines -join "`r`n").TrimEnd() + "`r`n"), $Utf8)
}
function Get-IniText([string]$path) { if (Test-Path -LiteralPath $path) { [IO.File]::ReadAllText($path) } else { '' } }

# ---------- backglass + DMD placement (vpx-layout.py, for any resolution and both orientations) ----------
# Landscape: like the KaoticBPR arcade - backglass in the top-left corner, DMD/score box in the top-right corner (or
#            under the backglass on tables that are wide at the top), desktop view. The top corners are where every
#            table is narrowest, so the boxes stay clear of the cabinet rails.
# Portrait:  cabinet view; DMD centered at the top of the screen, backglass above it only if turned on.
# Layouts checked on screen on the arcade (1920x1080, each table's own default camera), keyed by the table's title
# (letters/digits only, so "Star Trek: The Next Generation" and "Star Trek The Next Generation" both match):
#   backglass width, height | score box x, y, width, height | 'nobg' = the table's background art already shows it
$KnownLayouts = @{
    'apollo13' = @(580, 425, 1280, 0, 640, 160); 'attackfrommars' = @(513, 305, 1315, 0, 605, 151)
    'bigtroubleinlittlechina' = @(560, 315, 0, 315, 560, 315); 'blackrose' = @(580, 384, 1290, 0, 630, 158)
    'cactuscanyon' = @(511, 351, 1333, 0, 587, 146); 'creaturefromtheblacklagoon' = @(494, 344, 1347, 0, 573, 143)
    'diner' = @(550, 323, 0, 323, 550, 138); 'elviraandthepartymonsters' = @(386, 336, 0, 336, 386, 97)
    'fathom' = @(552, 444, 1304, 0, 616, 155); 'firepower' = @(490, 437, 1340, 0, 580, 145)
    'funhouse' = @(494, 337, 1464, 12, 368, 92); 'godzilla' = @(528, 399, 1307, 0, 613, 153)
    'gorgar' = @(497, 443, 1317, 0, 603, 151); 'independenceday' = @(493, 428, 1328, 0, 592, 149)
    'indianajonesthepinballadventure' = @(574, 399, 1311, 0, 609, 152); 'judgedredd' = @(548, 378, 1329, 0, 591, 147)
    'jurassicpark' = @(505, 437, 1312, 0, 608, 151); 'medievalmadness' = @(553, 384, 1294, 0, 626, 157)
    'metallicaremastered' = @(540, 432, 1320, 0, 580, 145, 'nobg'); 'monsterbash' = @(610, 361, 0, 361, 610, 152)
    'nogoodgofers' = @(539, 378, 1311, 0, 609, 152); 'piratesofthecaribbean' = @(525, 384, 0, 384, 525, 131)
    'primus' = @(420, 420, 0, 420, 420, 236); 'scaredstiff' = @(538, 372, 1312, 0, 608, 152)
    'startrekthenextgeneration' = @(536, 372, 1335, 0, 585, 146); 'starwars' = @(583, 489, 1280, 0, 640, 160)
    'talesfromthecrypt' = @(583, 495, 1386, 0, 534, 134); 'terminator2' = @(472, 378, 1356, 0, 564, 141)
    'theatreofmagic' = @(484, 387, 1335, 0, 585, 146); 'thegetawayhighspeedii' = @(589, 400, 1296, 0, 624, 155)
    'thelordoftherings' = @(552, 408, 1292, 0, 628, 156); 'themachinebrideofpinbot' = @(620, 434, 1280, 0, 640, 161)
    'thewalkingdead' = @(515, 412, 42, 32, 576, 143, 'nobg'); 'tomandjerry' = @(567, 320, 1289, 0, 631, 157)
    'totalnuclearannihilation' = @(505, 345, 1389, 0, 531, 298); 'twilightzone' = @(556, 383, 1314, 0, 606, 152)
    'twister' = @(550, 460, 1289, 0, 631, 158); 'whitewater' = @(550, 379, 0, 379, 550, 137)
    'wwfroyalrumble' = @(520, 449, 1300, 0, 620, 155)
}
function Get-KnownLayout([string]$name) {
    # Longest title key that the table's title starts with ("The Walking Dead LE Premium" -> 'thewalkingdead').
    $t = $name; $p = $t.LastIndexOf(' ('); if ($p -gt 0) { $t = $t.Substring(0, $p) }
    $t = ($t.ToLower() -replace '[^a-z0-9]', ''); $best = $null
    foreach ($k in $KnownLayouts.Keys) { if ($t.StartsWith($k) -and (-not $best -or $k.Length -gt $best.Length)) { $best = $k } }
    if ($best) { return $KnownLayouts[$best] }; return $null
}

function Get-B2SInfo([string]$b2s) {
    # Returns @{ W; H; Grill } of the backglass art without decoding the whole image.
    try {
        $t = $Latin1.GetString([IO.File]::ReadAllBytes($b2s))     # the image usually sits after the bulb/illumination data
        $g = [regex]::Match($t, '<GrillHeight Value="(\d+)"'); $grill = if ($g.Success) { [int]$g.Groups[1].Value } else { 0 }
        $m = [regex]::Match($t, '<BackglassImage[^>]*Value="'); if (-not $m.Success) { return $null }
        $head = $t.Substring($m.Index + $m.Length, [Math]::Min(600, $t.Length - $m.Index - $m.Length))
        $head = ($head -replace '&#x?[0-9A-Fa-f]+;|\s', ''); $head = $head.Substring(0, 32)
        $img = [Convert]::FromBase64String($head)
        if ($img[0] -ne 0x89 -or $img[1] -ne 0x50) { return @{ W = 0; H = 0; Grill = $grill } }
        $w = ([int]$img[16] -shl 24) -bor ([int]$img[17] -shl 16) -bor ([int]$img[18] -shl 8) -bor $img[19]
        $h = ([int]$img[20] -shl 24) -bor ([int]$img[21] -shl 16) -bor ([int]$img[22] -shl 8) -bor $img[23]
        return @{ W = $w; H = $h; Grill = $grill }
    } catch { return $null }
}
function Get-ArtHeight([string]$b2s, [bool]$keepGrill, [int]$boxW, [int]$default) {
    $i = Get-B2SInfo $b2s
    if (-not $i -or $i.W -le 0) { return $default }
    $h = $i.H; if (-not $keepGrill) { $h -= $i.Grill }
    return [int][Math]::Max([Math]::Round($boxW * 120 / 560), [Math]::Min($boxW, [Math]::Round($boxW * $h / $i.W)))
}
function Get-Screen($cfg) {
    if ($cfg.Mode -eq 'portrait') { return @{ W = [int]$cfg.NativeH; H = [int]$cfg.NativeW } }
    return @{ W = [int]$cfg.NativeW; H = [int]$cfg.NativeH }
}
function Set-TableLayout($cfg, [string]$vpx) {
    $base = $vpx.Substring(0, $vpx.Length - 4); $ini = "$base.ini"; $b2s = "$base.directb2s"
    $scr = Get-Screen $cfg; $txt = Get-IniText $ini
    $hasScore = $txt -match '(?m)^ScoreViewOutput\s*=\s*2'
    $dmdInBg = $txt -match '(?m)^BackglassDMDOverlay\s*=\s*1'
    if ($cfg.Mode -eq 'portrait') {
        $gap = [int]($scr.H * 0.004); $y = [int]($scr.H * 0.008); $h = $null
        if ((Test-Path -LiteralPath $b2s) -and $cfg.PortraitBackglass) {
            $w = [int]($scr.W * 0.56); $x = [int](($scr.W - $w) / 2)
            $h = Get-ArtHeight $b2s ([bool]$dmdInBg) $w ([int]($w * 316 / 560))
            Set-IniKeys $ini 'Backglass' ([ordered]@{ BackglassOutput = 2; BackglassWndX = $x; BackglassWndY = $y; BackglassWidth = $w; BackglassHeight = $h })
            $y += $h + $gap
        } elseif (Test-Path -LiteralPath $b2s) {
            Set-IniKeys $ini 'Backglass' ([ordered]@{ BackglassOutput = 0 })
        }
        if ($hasScore) {
            $dw = [int]($scr.W * 0.46); $dx = [int](($scr.W - $dw) / 2)
            Set-IniKeys $ini 'ScoreView' ([ordered]@{ ScoreViewWndX = $dx; ScoreViewWndY = $y; ScoreViewWidth = $dw; ScoreViewHeight = [int]($dw / 4) })
        }
        return $h
    }
    # landscape: the arcade's 1920x1080 layout scaled to this screen's height (the table is drawn to fill the height);
    # left boxes stay on the left edge and right boxes on the right edge, so wider screens just get more room between.
    $k = $scr.H / 1080.0
    $L = Get-KnownLayout ([IO.Path]::GetFileName($base))
    if ($L) {
        $bw = [int]($L[0] * $k); $h = [int]($L[1] * $k)
        $sx = if ($L[2] -ge 960) { $scr.W - [int]((1920 - $L[2]) * $k) } else { [int]($L[2] * $k) }
        $sy = [int]($L[3] * $k); $sw = [int]($L[4] * $k); $sh = [int]($L[5] * $k)
        $bgOut = if ($L.Count -gt 6 -and $L[6] -eq 'nobg') { 0 } else { 2 }
    } else {
        # unknown table: backglass top-left (its art's own shape, kept out of the table's way), DMD top-right
        $bw = [int](500 * $k); $h = $null; $bgOut = 2
        if (Test-Path -LiteralPath $b2s) {
            $h = Get-ArtHeight $b2s ([bool]$dmdInBg) $bw ([int](300 * $k))
            $cap = [int](440 * $k); if ($h -gt $cap) { $bw = [int]($bw * $cap / $h); $h = $cap }   # tall art: narrower, not taller
        }
        $sw = [int](600 * $k); $sh = [int]($sw / 4); $sx = $scr.W - $sw; $sy = 0
    }
    if (Test-Path -LiteralPath $b2s) {
        Set-IniKeys $ini 'Backglass' ([ordered]@{ BackglassOutput = $bgOut; BackglassWndX = 0; BackglassWndY = 0; BackglassWidth = $bw; BackglassHeight = $h })
    } else { $h = $null }
    if ($hasScore) { Set-IniKeys $ini 'ScoreView' ([ordered]@{ ScoreViewWndX = $sx; ScoreViewWndY = $sy; ScoreViewWidth = $sw; ScoreViewHeight = $sh }) }
    return $h
}
function Set-GlobalVpxMode($cfg) {
    $ini = $cfg.VpxIni; $scr = Get-Screen $cfg
    if ($cfg.Mode -eq 'portrait') {
        Set-IniKeys $ini 'Player' ([ordered]@{ BGSet = 1; PlayfieldFullScreen = 1 })
        Set-IniKeys $ini 'TableOverride' ([ordered]@{ ViewCabRotation = 0 })   # Windows itself is rotated, so the picture is not
    } else {
        Set-IniKeys $ini 'Player' ([ordered]@{ BGSet = 0; PlayfieldFullScreen = 1 })
    }
    $k = $scr.H / 1080.0
    Set-IniKeys $ini 'Backglass' ([ordered]@{ BackglassOutput = 2; BackglassWndX = 0; BackglassWndY = 0; BackglassWidth = [int](500 * $k); BackglassHeight = [int](375 * $k) })
}
function Update-AllLayouts($cfg, [scriptblock]$say) {
    Set-GlobalVpxMode $cfg
    foreach ($v in (Get-ChildItem -LiteralPath $cfg.Tables -Filter *.vpx -File -ErrorAction SilentlyContinue)) {
        $h = Set-TableLayout $cfg $v.FullName
        if ($say) { & $say ("{0,-48} {1}" -f $v.BaseName, $(if ($h) { "backglass height $h" } else { 'ok' })) }
    }
}

# ---------- sorting what was dropped in ----------
$RomBad = '.vpx', '.directb2s', '.crz', '.cromc', '.crom', '.pal', '.vni', '.pac', '.mp3', '.ogg', '.wav', '.mp4', '.pdf',
          '.docx', '.png', '.jpg', '.csv', '.vbs', '.pup', '.zip'
function Test-RomZip([System.IO.Compression.ZipArchive]$z) {
    $names = @($z.Entries | Where-Object { -not $_.FullName.EndsWith('/') } | ForEach-Object { $_.FullName.ToLower() })
    $chips = @($names | Where-Object { -not $_.EndsWith('.txt') })      # official Williams ROM zips carry LICENSE/RELEASE.TXT
    if (-not $chips.Count) { return $false }
    foreach ($n in $names) { foreach ($b in $RomBad) { if ($n.EndsWith($b)) { return $false } } }
    return $true
}
function New-Item2([string]$path, [string]$name, [bool]$rom) {
    [pscustomobject]@{ Path = $path; Name = $name.Replace('\', '/'); Low = $name.Replace('\', '/').ToLower(); Base = [IO.Path]::GetFileName($name); Size = (Get-Item -LiteralPath $path).Length; Rom = $rom }
}
function Expand-Zip([string]$zip, [string]$dest) {
    $z = [IO.Compression.ZipFile]::OpenRead($zip)
    try {
        foreach ($e in $z.Entries) {
            if ($e.FullName.EndsWith('/') -or -not $e.Name) { continue }
            $rel = ($e.FullName -replace '[:*?"<>|]', '_').TrimStart('/', '\')
            $out = [IO.Path]::GetFullPath((Join-Path $dest $rel))
            if (-not $out.StartsWith([IO.Path]::GetFullPath($dest))) { continue }
            [IO.Directory]::CreateDirectory((Split-Path $out)) | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $out, $true)
        }
    } finally { $z.Dispose() }
}
function Add-FileItems($list, [string]$path, [string]$label, [int]$depth, [string]$work) {
    if ($path.ToLower().EndsWith('.zip') -and $depth -le 1) {
        $z = $null
        try { $z = [IO.Compression.ZipFile]::OpenRead($path) } catch { }
        if ($z) {
            $isRom = Test-RomZip $z; $z.Dispose()
            if ($isRom) { $list.Add((New-Item2 $path $label $true)); return }
            $dest = Join-Path $work ([guid]::NewGuid().ToString('N').Substring(0, 8)); Expand-Zip $path $dest
            foreach ($f in (Get-ChildItem -LiteralPath $dest -Recurse -File)) {
                Add-FileItems $list $f.FullName ($label + '/' + $f.FullName.Substring($dest.Length + 1)) ($depth + 1) $work
            }
            return
        }
    }
    $list.Add((New-Item2 $path $label $false))
}
function Get-DroppedItems([string[]]$paths, [string]$work) {
    $list = New-Object System.Collections.Generic.List[object]
    foreach ($p in $paths) {
        $p = $p.TrimEnd('\')
        if (Test-Path -LiteralPath $p -PathType Container) {
            $top = Split-Path $p -Leaf
            foreach ($f in (Get-ChildItem -LiteralPath $p -Recurse -File)) { Add-FileItems $list $f.FullName ($top + '/' + $f.FullName.Substring($p.Length + 1)) 0 $work }
        } elseif (Test-Path -LiteralPath $p) { Add-FileItems $list $p ([IO.Path]::GetFileName($p)) 0 $work }
    }
    return ,$list
}

# ---------- script fixes (same as the arcade: VPX 10.8.1's PinMAME plugin behaves the same on Windows) ----------
function Get-RomName([string]$text) {
    if (-not $text) { return $null }
    $code = (($text -split "`n") | Where-Object { -not $_.TrimStart().StartsWith("'") }) -join "`n"
    if ($code -notmatch '(?i)\bLoadVPM\b|VPinMAME\.Controller') { return $null }
    $m = [regex]::Match($code, '(?i)cGameName\s*=\s*"([^"]+)"'); if (-not $m.Success) { $m = [regex]::Match($code, '(?i)\.GameName\s*=\s*"([^"]+)"') }
    if ($m.Success) { return $m.Groups[1].Value } else { return $null }
}
$LampTrue = New-Object regex '(controller\.(?:lamp|switch|solenoid)\s*\(\s*[^)]*\))\s*=\s*(true|false)\b', 'IgnoreCase'
$Cond     = New-Object regex '^(\s*(?:else\s*if|elseif|if|while|do\s+while|do\s+until|loop\s+while|loop\s+until)\b)(.*?)(\bthen\b.*)?$', 'IgnoreCase'
function Repair-LampChecks([string]$text) {
    # ROM lamps/switches report 1/0 through the PinMAME plugin, so '= true' / '= false' never match. Only conditions are rewritten.
    $n = 0; $out = New-Object System.Collections.Generic.List[string]
    $ev = [System.Text.RegularExpressions.MatchEvaluator]{ param($m) if ($m.Groups[2].Value -ieq 'true') { "CBool($($m.Groups[1].Value))" } else { "(Not CBool($($m.Groups[1].Value)))" } }
    foreach ($line in ($text -split "`n")) {
        $m = $Cond.Match($line)
        if ($m.Success) {
            $c = $m.Groups[2].Value; $k = $LampTrue.Matches($c).Count
            if ($k) { $line = $m.Groups[1].Value + $LampTrue.Replace($c, $ev) + $m.Groups[3].Value; $n += $k }
        }
        $out.Add($line)
    }
    if (-not $n) { return @($null, 0) }
    $hdr = "' VPX Cabinet Kit fix: ROM lamps/switches report 1 instead of True through VPX's PinMAME plugin,`n' so controller.lamp(n)=true style checks were rewritten as CBool(...).`n"
    return @(($hdr + ($out -join "`n")), $n)
}
function Repair-EarlyWilliams([string]$text) {
    # Williams System 3-7 sound boards go silent except for speech when PinMAME is time-fenced to VPX physics (VPX 10.8.1 rev 5436).
    if ($text -notmatch '(?i)LoadVPM\s+"[^"]*"\s*,\s*"S[3-7]\.VBS"') { return @($text, $false) }
    $text = [regex]::Replace($text, '(?i)(\.dip\(0\)\s*=\s*&h)([0-9a-f]+)', { param($m) $m.Groups[1].Value + ([Convert]::ToInt32($m.Groups[2].Value, 16) -bor 3).ToString('x2') })
    if ($text.Contains('HasTimeFence = False')) { return @($text, $true) }
    $m = [regex]::Match($text, '(?im)^(\s*)vpmInit\s+Me\s*$'); if (-not $m.Success) { return @($text, $false) }
    $line = $m.Value + "`n" + $m.Groups[1].Value + "On Error Resume Next : HasTimeFence = False : Controller.TimeFence = 0 : On Error Goto 0   ' VPX Cabinet Kit: early Williams sound board needs PinMAME unsynced"
    return @(($text.Substring(0, $m.Index) + $line + $text.Substring($m.Index + $m.Length)), $true)
}
$DmdHideMark = "' VPX Cabinet Kit: DMD shown in its own box"
function Repair-Dmd([string]$text) {
    # ROM tables show their DMD in VPX's ScoreView box; the corner DMD the table draws itself is hidden: a text box named
    # ScoreText (DMD tables) or, on older segment-display tables like Gorgar, the LED lights in a Digits() array that
    # the script lights from Controller.ChangedLEDs.
    if ($text -notmatch '(?i)UseVPMDMD|\bScoreText\b') { return @($text, $false) }
    $text = [regex]::Replace($text, "(?im)(\bScoreText\.Visible[ \t]*=(?>[ \t]*))[^:'\r\n]+?(?=\s*(?:$|:|'|\belse\b|\bend\s+if\b))", '${1}0')
    if (-not $text.Contains($DmdHideMark)) {
        $text = $text.TrimEnd("`r", "`n") + "`n`n$DmdHideMark - the table's own corner DMD is hidden`nOn Error Resume Next : ScoreText.Visible = 0 : On Error Goto 0`n"
        if ($text -match '(?im)^\s*Dim\s+Digits\s*\(' -and $text -match '(?i)ChangedLEDs') {
            $text += "Dim KitDigit, KitLed : On Error Resume Next`nFor Each KitDigit In Digits`n`tIf IsArray(KitDigit) Then`n`t`tFor Each KitLed In KitDigit : KitLed.Visible = 0 : Next`n`tEnd If`nNext`nOn Error Goto 0`n"
        }
    }
    return @($text, $true)
}

# ---------- artwork ----------
function Save-Png([System.Drawing.Image]$im, [int]$maxW, [string]$out) {
    $w = $im.Width; $h = $im.Height
    if ($w -gt $maxW) { $h = [int][Math]::Round($h * $maxW / $w); $w = $maxW }
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'
    $g.DrawImage($im, 0, 0, $w, $h); $g.Dispose()
    [IO.Directory]::CreateDirectory((Split-Path $out)) | Out-Null
    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}
function Save-BackglassArt([string]$b2s, [string]$out) {
    $t = $Latin1.GetString([IO.File]::ReadAllBytes($b2s))
    $m = [regex]::Match($t, '<BackglassImage[^>]*Value="([^"]+)"'); if (-not $m.Success) { return $false }
    $raw = [Convert]::FromBase64String(($m.Groups[1].Value -replace '&#x?[0-9A-Fa-f]+;|\s', ''))
    $ms = New-Object IO.MemoryStream(, $raw); $im = [System.Drawing.Image]::FromStream($ms)
    try {
        # Some backglasses (Cirqus Voltaire) keep only a partial base image and draw the full art as an always-on
        # "bulb" layer on top; paint those full-size always-on layers over the base like B2S does.
        foreach ($b in [regex]::Matches($t, '<Bulb\s([^>]*)>')) {
            $a = $b.Groups[1].Value
            $at = { param($k) $v = [regex]::Match($a, "$k=""(-?\d+)"""); if ($v.Success) { [int]$v.Groups[1].Value } else { 0 } }
            $img = [regex]::Match($a, ' Image="([^"]+)"')
            if (-not $img.Success -or (& $at 'Visible') -ne 1 -or (& $at 'InitialState') -ne 1 -or (& $at 'RomID') -ne 0) { continue }
            $lw = & $at 'Width'; $lh = & $at 'Height'
            if ($lw * $lh -lt 0.8 * $im.Width * $im.Height) { continue }
            try {
                $lms = New-Object IO.MemoryStream(, [Convert]::FromBase64String(($img.Groups[1].Value -replace '&#x?[0-9A-Fa-f]+;|\s', '')))
                $layer = [System.Drawing.Image]::FromStream($lms)
                $c = New-Object System.Drawing.Bitmap($im.Width, $im.Height)
                $gr = [System.Drawing.Graphics]::FromImage($c)
                $gr.DrawImage($im, 0, 0, $im.Width, $im.Height); $gr.DrawImage($layer, (& $at 'LocX'), (& $at 'LocY'), $lw, $lh); $gr.Dispose()
                $layer.Dispose(); $lms.Dispose(); $im.Dispose(); $im = $c
            } catch { }
        }
        $g = [regex]::Match($t, '<GrillHeight Value="(\d+)"')      # ES-DE shows its own frame, so leave the grill strip off
        if ($g.Success -and [int]$g.Groups[1].Value -gt 0 -and [int]$g.Groups[1].Value -lt $im.Height / 2) {
            $c = New-Object System.Drawing.Bitmap($im.Width, ($im.Height - [int]$g.Groups[1].Value))
            $gr = [System.Drawing.Graphics]::FromImage($c); $gr.DrawImage($im, 0, 0, $im.Width, $im.Height); $gr.Dispose()
            $im.Dispose(); $im = $c
        }
        Save-Png $im 1280 $out
    } finally { $im.Dispose(); $ms.Dispose() }
    return $true
}
function ConvertTo-Norm([string]$s) { (($s.ToLower().Replace('&', ' and ')) -replace '[^a-z0-9]+', ' ').Trim() }
function Save-MatchedWheel($cfg, [string]$name, [string]$out) {
    # All wheels from one set (VPX Media Database, github.com/superhac/vpinmediadb) so the ES-DE carousel matches.
    $m = [regex]::Match($name, '^(.+?)\s*\(([^()]*?)\s+((?:19|20)\d\d)\)\s*$'); if (-not $m.Success) { return $false }
    $title = ConvertTo-Norm $m.Groups[1].Value; $maker = ConvertTo-Norm $m.Groups[2].Value; $year = [int]$m.Groups[3].Value
    $cache = Join-Path $cfg.Root 'Kit\cache'; [IO.Directory]::CreateDirectory($cache) | Out-Null
    $db = Join-Path $cache 'vpsdb.json'
    try {
        if (-not (Test-Path $db) -or ((Get-Date) - (Get-Item $db).LastWriteTime).TotalDays -gt 7) {
            Invoke-WebRequest 'https://virtualpinballspreadsheet.github.io/vps-db/db/vpsdb.json' -OutFile $db -UseBasicParsing -TimeoutSec 30
        }
        $js = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $js.MaxJsonLength = [int]::MaxValue
        $games = $js.DeserializeObject([IO.File]::ReadAllText($db))
        $hits = @($games | Where-Object {
            $n = ConvertTo-Norm ([string]$_['name']); $mk = ConvertTo-Norm ([string]$_['manufacturer']); $y = 0; [void][int]::TryParse([string]$_['year'], [ref]$y)
            $n -eq $title -and [Math]::Abs($y - $year) -le 1 -and $mk -and ($mk.Contains($maker) -or $maker.Contains($mk)) })
        if ($hits.Count -ne 1) { return $false }
        $tmp = Join-Path $cache 'wheel-dl.png'
        Invoke-WebRequest "https://raw.githubusercontent.com/superhac/vpinmediadb/main/$($hits[0]['id'])/wheel.png" -OutFile $tmp -UseBasicParsing -TimeoutSec 30
        $im = [System.Drawing.Image]::FromFile($tmp); try { Save-Png $im 500 $out } finally { $im.Dispose() }
        Remove-Item $tmp -ErrorAction SilentlyContinue
        return $true
    } catch { return $false }
}

# ---------- PuP packs ----------
function Get-PupFiles($items) {
    $roots = @{}
    foreach ($i in $items) { if ($i.Low.EndsWith('/screens.pup') -and $i.Low -notmatch 'pup-pack_options' -and $i.Low -notmatch 'pupvideos') { $roots[$i.Name.Substring(0, $i.Name.Length - 12)] = 1 } }
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($i in $items) {
        if ($i.Low -match '\.(bat|exe|dll)$') { continue }
        $ix = $i.Low.IndexOf('pupvideos')
        if ($ix -ge 0) { $out.Add(@($i, $i.Name.Substring($ix + 9).TrimStart('/'))); continue }
        $root = $roots.Keys | Where-Object { $i.Name.StartsWith($_ + '/') } | Select-Object -First 1
        if ($root) { $out.Add(@($i, ($root.Split('/')[-1] + '/' + $i.Name.Substring($root.Length + 1)))) }
    }
    return ,$out
}
function Set-PupOneScreen([string]$packDir) {
    # Use the pack's 'Full DMD' layout: PuP videos + scores in the DMD box, real backglass art in the backglass box.
    $od = Join-Path $packDir 'PuP-Pack_Options'; if (-not (Test-Path -LiteralPath $od)) { return $null }
    $pick = Get-ChildItem -LiteralPath $od -Directory | Sort-Object Name | Where-Object { $_.Name -match '(?i)full\s*_?dmd' -and $_.Name -notmatch '(?i)\bvr\b' } | Select-Object -First 1
    if (-not $pick) { return $null }
    Get-ChildItem -LiteralPath $pick.FullName -Filter *.pup -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName (Join-Path $packDir $_.Name) -Force }
    return $pick.Name
}

# ---------- ES-DE ----------
function ConvertTo-Xml([string]$s) { $s.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace("'", '&apos;').Replace('"', '&quot;') }
function Get-NameMeta([string]$name) {
    $m = [regex]::Match($name, '\(([^()]*?)\s+((?:19|20)\d\d)\)')
    $maker = ''; $year = ''; if ($m.Success) { $maker = $m.Groups[1].Value.Trim(); $year = $m.Groups[2].Value }
    if ($maker -in 'original', 'vpx original') { $maker = 'Original' }
    $short = ($name -replace '\s*\([^)]*\)\s*$', '').Trim(); if (-not $short) { $short = $name }
    return @{ Short = $short; Maker = $maker; Year = $year }
}
function New-GamelistEntry([string]$fname, [string]$name, $notes) {
    $md = Get-NameMeta $name
    $desc = "$($md.Short) - $(if ($md.Maker -and $md.Maker -ne 'Original') { $md.Maker + ' ' })$(if ($md.Year) { $md.Year + ' ' })pinball table for Visual Pinball X."
    if ($md.Maker -eq 'Original') { $desc = "$($md.Short) - original Visual Pinball table$(if ($md.Year) { ' (' + $md.Year + ')' })." }
    if ($notes) { $desc += ' ' + ($notes -join ' ') }
    $e = @("`t<game>", "`t`t<path>./$(ConvertTo-Xml $fname)</path>", "`t`t<name>$(ConvertTo-Xml $md.Short)</name>", "`t`t<desc>$(ConvertTo-Xml $desc)</desc>")
    if ($md.Year) { $e += "`t`t<releasedate>$($md.Year)0101T000000</releasedate>" }
    if ($md.Maker) { $e += "`t`t<developer>$(ConvertTo-Xml $md.Maker)</developer>", "`t`t<publisher>$(ConvertTo-Xml $md.Maker)</publisher>" }
    $e += "`t`t<genre>Pinball</genre>", "`t</game>"
    return @{ File = $fname; Block = (($e -join "`n") + "`n") }
}
function Write-Gamelist($cfg, $entry) {
    $gl = Get-Gamelist $cfg; [IO.Directory]::CreateDirectory((Split-Path $gl)) | Out-Null
    $t = if (Test-Path -LiteralPath $gl) { [IO.File]::ReadAllText($gl) -replace "`r`n", "`n" } else { "<?xml version=`"1.0`"?>`n<gameList>`n</gameList>`n" }
    $t = [regex]::Replace($t, "\t<game>\n\t\t<path>\./" + [regex]::Escape((ConvertTo-Xml $entry.File)) + "</path>.*?</game>\n", '', 'Singleline')
    $t = $t.Replace('</gameList>', $entry.Block + '</gameList>')
    [IO.File]::WriteAllText($gl, $t, $Utf8)
}
function Get-EsdeProcess { Get-Process -Name 'ES-DE' -ErrorAction SilentlyContinue }
function Get-VpxProcess  { Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'VPinballX*' } }
function Stop-Esde {
    $p = Get-EsdeProcess; if (-not $p) { return $false }
    foreach ($x in $p) { [void]$x.CloseMainWindow() }
    for ($i = 0; $i -lt 40 -and (Get-EsdeProcess); $i++) { Start-Sleep -Milliseconds 250 }
    Get-EsdeProcess | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    return $true
}
function Start-Esde($cfg) {
    $exe = Join-Path $cfg.EsdeDir 'ES-DE.exe'
    if (Test-Path -LiteralPath $exe) { Start-Process -FilePath $exe -WorkingDirectory $cfg.EsdeDir }
}

# ---------- the table install (vpx-add.py install()) ----------
$VbsSkip = 'core.vbs', 'controller.vbs', 'vpmkeys.vbs', 'b2s.vbs', 'wpc.vbs', 's11.vbs', 'de.vbs', 'sega.vbs', 'gts3.vbs', 'stern.vbs', 'bally.vbs', 'vpmballs.vbs', 'pinmame.vbs'
$Img = '.png', '.jpg', '.jpeg', '.apng', '.gif', '.bmp', '.webp'
$Skip = '.txt', '.pdf', '.docx', '.doc', '.rtf', '.url', '.nfo', '.md', '.ini', '.db', '.exe'

function Install-Table($cfg, [string[]]$paths, [string]$name, [bool]$refresh, [scriptblock]$say) {
    $name = ($name -replace '[\\/:*?"<>|]', '').Trim()
    $T = $cfg.Tables; $PM = Join-Path $T 'pinmame'; $MED = Get-MediaDir $cfg
    foreach ($d in $T, "$PM\roms", "$PM\altcolor", "$PM\altsound", "$T\music", "$T\pupvideos", "$MED\covers", "$MED\screenshots", "$MED\marquees") { [IO.Directory]::CreateDirectory($d) | Out-Null }
    $work = Join-Path $env:TEMP ('vpxkit-' + (Get-Date -Format 'yyyyMMddHHmmss')); [IO.Directory]::CreateDirectory($work) | Out-Null
    try {
        & $say 'Unpacking...'
        $items = Get-DroppedItems $paths $work
        $pick = { param($pred) @($items | Where-Object $pred | Sort-Object Size -Descending) }
        $tables = @(& $pick { $_.Low.EndsWith('.vpx') })
        if (-not $tables.Count) { & $say 'ERROR: no .vpx table file found in what was added.'; return 1 }
        $notes = New-Object System.Collections.Generic.List[string]; $warn = New-Object System.Collections.Generic.List[string]
        $fname = "$name.vpx"; $vpx = Join-Path $T $fname
        Copy-Item -LiteralPath $tables[0].Path $vpx -Force; & $say "Table      -> $fname"
        if ($tables.Count -gt 1) { $warn.Add("several .vpx files were added; used the biggest ($($tables[0].Base))") }

        $b2s = @(& $pick { $_.Low.EndsWith('.directb2s') })
        if ($b2s.Count) {
            Copy-Item -LiteralPath $b2s[0].Path (Join-Path $T "$name.directb2s") -Force; & $say "Backglass  -> $name.directb2s"
            try { if (Save-BackglassArt $b2s[0].Path "$MED\screenshots\$name.png") { & $say 'Artwork    -> ES-DE picture from the backglass' } } catch { }
        } else { $warn.Add('no backglass (.directb2s) was added - the table still plays') }

        $text = try { [VpxScript]::Read($vpx) } catch { $null }
        if ($null -eq $text) { $text = ''; $warn.Add('could not read the table script - ROM name unknown, no script fixes applied') }
        $rom = Get-RomName $text
        & $say "ROM name   -> $(if ($rom) { $rom } else { 'none (this table does not use a ROM)' })"

        $ini = Join-Path $T "$name.ini"
        $pups = Get-PupFiles $items
        if ($rom -or $pups.Count) {
            Set-IniKeys $ini 'ScoreView' ([ordered]@{ ScoreViewOutput = 2 }); & $say 'Scores     -> DMD / score display shown in its own box'
        } elseif ((Get-IniText $ini) -match 'ScoreViewOutput = 2') { Set-IniKeys $ini 'ScoreView' ([ordered]@{ ScoreViewOutput = 0 }) }
        $h = Set-TableLayout $cfg $vpx
        if ($h) { & $say "Backglass  -> placed for $($cfg.Mode) mode (height $h)" }

        $roms = @{}; foreach ($r in ($items | Where-Object { $_.Rom })) { $roms[$r.Base.ToLower()] = $r }
        foreach ($r in $roms.Values) { Copy-Item -LiteralPath $r.Path (Join-Path "$PM\roms" $r.Base) -Force; & $say "ROM        -> pinmame\roms\$($r.Base)" }
        if ($rom -and -not (Get-ChildItem -LiteralPath "$PM\roms" -File | Where-Object { $_.Name -ieq "$rom.zip" })) {
            $warn.Add("ROM $rom.zip is missing - the table will not start until it is added")
        }

        $serum = @(& $pick { $_.Low -match '\.(crz|cromc|crom)$' })
        if ($serum.Count) {
            $pref = @($serum | Where-Object { $_.Low -match 'gradient' }); if (-not $pref.Count) { $pref = $serum }
            $s = $pref[0]; $r = [IO.Path]::GetFileNameWithoutExtension($s.Base)
            [IO.Directory]::CreateDirectory("$PM\altcolor\$r") | Out-Null
            Copy-Item -LiteralPath $s.Path "$PM\altcolor\$r\$($s.Base)" -Force; & $say "Colors     -> pinmame\altcolor\$r\$($s.Base)"
            if (@($serum | Select-Object -ExpandProperty Name -Unique).Count -gt 1) { & $say "             ($($serum.Count) color versions were included; used $($s.Name))" }
            $notes.Add('Colorized display.')
        }
        if ($items | Where-Object { $_.Low.EndsWith('.pac') }) { $warn.Add('a .pac color pack was included - those only work on PIN2DMD display hardware, so it was skipped') }
        $vni = @{}; foreach ($i in ($items | Where-Object { $_.Low -match '\.(pal|vni)$' })) { $vni[[IO.Path]::GetExtension($i.Low)] = $i }
        if ($vni.Count -and $rom) {
            [IO.Directory]::CreateDirectory("$PM\altcolor\$rom") | Out-Null
            foreach ($k in $vni.Keys) { Copy-Item -LiteralPath $vni[$k].Path "$PM\altcolor\$rom\pin2dmd$k" -Force }
            & $say "Colors     -> pinmame\altcolor\$rom\pin2dmd.pal/.vni"; $notes.Add('Colorized display.')
        }

        $music = @($items | Where-Object { $_.Low -match '\.(mp3|ogg)$' -and $_.Low -notmatch 'altsound' -and $_.Low -notmatch 'pup' })
        foreach ($i in $music) {
            $parts = $i.Name.Split('/'); $low = @($parts | ForEach-Object { $_.ToLower() }); $mi = [array]::IndexOf($low, 'music')
            $sub = if ($mi -ge 0 -and $mi -lt $parts.Count - 2) { $parts[($mi + 1)..($parts.Count - 2)] -join '\' } else { '' }
            $dst = if ($sub) { Join-Path "$T\music" $sub } else { "$T\music" }
            [IO.Directory]::CreateDirectory($dst) | Out-Null; Copy-Item -LiteralPath $i.Path (Join-Path $dst $i.Base) -Force
        }
        if ($music.Count) { & $say "Music      -> music\ ($($music.Count) tracks)" }

        $alts = @($items | Where-Object { $_.Low -match 'altsound' -and $Skip -notcontains [IO.Path]::GetExtension($_.Low) })
        if ($alts.Count -and $rom) {
            foreach ($i in $alts) {
                $rel = $i.Name.Substring($i.Low.IndexOf('altsound') + 8).TrimStart('/')
                $sp = $rel.Split('/', 2); if ($sp.Count -eq 2 -and $sp[0] -ieq $rom) { $rel = $sp[1] }
                $dst = Join-Path "$PM\altsound\$rom" (Split-Path $rel.Replace('/', '\')); [IO.Directory]::CreateDirectory($dst) | Out-Null
                Copy-Item -LiteralPath $i.Path (Join-Path $dst ([IO.Path]::GetFileName($rel))) -Force
            }
            & $say "AltSound   -> pinmame\altsound\$rom\ ($($alts.Count) files)"
        }
        foreach ($pr in $pups) {
            $dst = Join-Path "$T\pupvideos" (Split-Path $pr[1].Replace('/', '\')); [IO.Directory]::CreateDirectory($dst) | Out-Null
            Copy-Item -LiteralPath $pr[0].Path (Join-Path $dst ([IO.Path]::GetFileName($pr[1]))) -Force
        }
        if ($pups.Count) {
            & $say "PuP pack   -> pupvideos\ ($($pups.Count) files)"
            foreach ($pack in ($pups | ForEach-Object { $_[1].Split('/')[0] } | Sort-Object -Unique)) {
                $opt = Set-PupOneScreen (Join-Path "$T\pupvideos" $pack); if ($opt) { & $say "PuP layout -> '$opt' (videos + scores in the DMD box)" }
            }
        }

        $userVbs = @(& $pick { $_.Low.EndsWith('.vbs') -and $_.Low -notmatch 'pupvideos' -and $VbsSkip -notcontains $_.Base.ToLower() })
        $sidecar = Join-Path $T "$name.vbs"
        $baseText = if ($userVbs.Count) { $Latin1.GetString([IO.File]::ReadAllBytes($userVbs[0].Path)) } else { $text }
        $fx = Repair-LampChecks $baseText; $out = if ($fx[0]) { $fx[0] } else { $baseText }
        if ($fx[1]) { & $say "Lamp fix   -> applied ($($fx[1]) ROM light/switch checks fixed)" }
        $ew = Repair-EarlyWilliams $out; $out = $ew[0]
        if ($ew[1]) { & $say 'Sound fix  -> early Williams sound board: PinMAME runs unsynced so its effects play' }
        $hid = $false; if ($rom) { $dm = Repair-Dmd $out; $out = $dm[0]; $hid = $dm[1] }
        if ($userVbs.Count) { & $say "Script     -> using the included $($userVbs[0].Base)" }
        if ($out -and ($userVbs.Count -or $fx[1] -or $ew[1] -or $hid)) { [IO.File]::WriteAllText($sidecar, $out, $Latin1) }
        elseif (Test-Path -LiteralPath $sidecar) { Remove-Item -LiteralPath $sidecar }

        $wheels = @($items | Where-Object { $Img -contains [IO.Path]::GetExtension($_.Low) -and $_.Low -notmatch 'pupvideos|altcolor|pup-pack' } |
                    Sort-Object @{ e = { -not ($_.Low -match 'wheel|logo') } }, @{ e = { -$_.Size } })
        $marquee = "$MED\marquees\$name.png"
        & $say 'Wheel      -> looking up the matching wheel...'
        if (Save-MatchedWheel $cfg $name $marquee) { & $say 'Wheel      -> ES-DE marquee (matching wheel from the VPX Media Database)' }
        elseif ($wheels.Count) {
            try { $im = [System.Drawing.Image]::FromFile($wheels[0].Path); try { Save-Png $im 500 $marquee } finally { $im.Dispose() }; & $say 'Wheel      -> ES-DE marquee' }
            catch { $warn.Add("the wheel image $($wheels[0].Base) could not be read (webp is not supported) - convert it to .png and add it again") }
        }

        $entry = New-GamelistEntry $fname $name ($notes | Sort-Object -Unique)
        if (-not (Get-EsdeProcess)) { Write-Gamelist $cfg $entry; & $say 'ES-DE      -> added to the Visual Pinball list' }
        elseif ($refresh) { & $say 'ES-DE      -> restarting ES-DE so the table shows up now...'; [void](Stop-Esde); Write-Gamelist $cfg $entry; Start-Esde $cfg }
        else { [void](Stop-Esde); Write-Gamelist $cfg $entry; & $say 'ES-DE      -> closed ES-DE to add the table; start it again from the desktop' }
        foreach ($w in $warn) { & $say "NOTE: $w" }
        & $say 'DONE'
        return 0
    } finally { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}

# ---------- display mode switch ----------
function Set-DisplayMode($cfg, [string]$mode, [scriptblock]$say) {
    if (Get-VpxProcess) { & $say 'A table is running - close it first.'; return $false }
    $wasRunning = Stop-Esde
    $orient = if ($mode -eq 'portrait') { [int]([int]$cfg.PortraitTurn / 90) } else { 0 }
    $cur = [KitDisplay]::Current()
    if ($cur[2] -ne $orient) {
        $r = [KitDisplay]::Rotate($orient)
        if ($r -ne 0) { & $say "Windows refused to rotate the screen (code $r). Rotate it in Settings > System > Display, then press the button again."; }
    }
    $cfg.Mode = $mode; Save-KitConfig $cfg
    & $say "VPX        -> $mode layout for every table"
    Update-AllLayouts $cfg $null
    if ($wasRunning) { Start-Esde $cfg }
    return $true
}
