# VPX Cabinet Kit - one-time setup (run Setup.cmd). Safe to run again: it repairs/updates and keeps tables + settings.
#   - Visual Pinball X 10.8.1 (BGFX, Windows x64) with its built-in PinMAME, B2S backglass, Serum, PuP and AltSound plugins
#   - Microsoft Visual C++ runtime (VPX needs it)
#   - ES-DE (portable) as the game menu, with a Visual Pinball system pointing at VPX
#   - Desktop shortcuts: Start Pinball, Pinball Table Installer, Pinball Display Mode
# Everything goes in C:\Pinball (tables live in C:\Pinball\ES-DE\ROMs\vpinball).
param([string]$Root = 'C:\Pinball')

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Host.UI.RawUI.WindowTitle = 'VPX Cabinet Kit - Setup'
$env:PINBALL_KIT_CONFIG = Join-Path $Root 'Kit\kit.json'
. (Join-Path $PSScriptRoot 'Common.ps1')

# The VPX build the KaoticBPR arcade runs; its script fixes were verified on this revision.
$VpxTag     = 'v10.8.1-5436-af26b2d93'
$VpxAsset   = '^VPinballX_BGFX-.*-windows-x64-Release\.zip$'
$EsdeApi    = 'https://gitlab.com/api/v4/projects/es-de%2Femulationstation-de/releases/permalink/latest'
$EsdeBackup = 'https://gitlab.com/es-de/emulationstation-de/-/package_files/357718057/download'   # 3.5.0 portable
$VcRedist   = 'https://aka.ms/vs/17/release/vc_redist.x64.exe'

function Step([string]$s) { Write-Host ''; Write-Host "== $s" -ForegroundColor Magenta }
function Info([string]$s) { Write-Host "   $s" -ForegroundColor Cyan }
function Warn([string]$s) { Write-Host "   $s" -ForegroundColor Yellow }
function Get-File([string]$url, [string]$out) {
    & curl.exe -L --fail --retry 3 --progress-bar -o $out $url
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $out)) { throw "Download failed: $url" }
}
function Expand-Flat([string]$zip, [string]$dest, [string]$marker) {
    # Unzips, then moves the folder that holds $marker (the zip may or may not have a top folder) into $dest.
    $tmp = Join-Path $env:TEMP ('vpxkit-unz-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $tmp)
    $hit = Get-ChildItem -LiteralPath $tmp -Recurse -File -Filter $marker | Sort-Object { $_.FullName.Length } | Select-Object -First 1
    if (-not $hit) { throw "$marker not found in $zip" }
    New-Item -ItemType Directory -Force $dest | Out-Null
    Get-ChildItem -LiteralPath $hit.DirectoryName -Force | ForEach-Object { Copy-Item -LiteralPath $_.FullName $dest -Recurse -Force }
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
function New-Shortcut([string]$lnk, [string]$target, [string]$arguments, [string]$icon, [string]$workDir) {
    $sh = New-Object -ComObject WScript.Shell; $s = $sh.CreateShortcut($lnk)
    $s.TargetPath = $target; $s.Arguments = $arguments; if ($workDir) { $s.WorkingDirectory = $workDir }
    if ($icon) { $s.IconLocation = $icon }; $s.Save()
}
function Ask([string]$q, [bool]$default) {
    $d = if ($default) { 'Y/n' } else { 'y/N' }
    $a = Read-Host "   $q [$d]"; if (-not $a) { return $default }; return $a -match '^[yY]'
}

try {
    Write-Host ''
    Write-Host '  VPX CABINET KIT - SETUP' -ForegroundColor Magenta
    Write-Host '  Installs Visual Pinball X + ES-DE into' $Root -ForegroundColor Cyan
    Write-Host '  Downloads about 400 MB. Takes 5-10 minutes.' -ForegroundColor Cyan

    if (-not [Environment]::Is64BitOperatingSystem) { throw 'This kit needs 64-bit Windows.' }
    if (Get-VpxProcess) { throw 'Visual Pinball is running - close it and run Setup again.' }
    $dl = Join-Path $env:TEMP 'vpxkit-downloads'; New-Item -ItemType Directory -Force $dl | Out-Null

    $cfg = if (Test-Path $ConfigPath) { Get-KitConfig } else { New-KitConfig $Root }
    foreach ($k in (New-KitConfig $Root).Keys) { if (-not $cfg.Contains($k)) { $cfg[$k] = (New-KitConfig $Root)[$k] } }

    # ---------- screen ----------
    Step 'Screen'
    $cur = [KitDisplay]::Current()
    if ($cur[2] % 2 -eq 1) { $cfg.NativeW = $cur[1]; $cfg.NativeH = $cur[0]; $cfg.Mode = 'portrait' }
    else { $cfg.NativeW = $cur[0]; $cfg.NativeH = $cur[1] }
    Info "TV resolution: $($cfg.NativeW) x $($cfg.NativeH) (landscape). Current mode: $($cfg.Mode)."
    if ($cfg.NativeW -lt 1920) { Warn 'Windows is running the TV below 1080p. Set it to its native resolution (Settings > Display) for the best picture.' }

    # ---------- Visual C++ runtime ----------
    Step 'Microsoft Visual C++ runtime'
    $vc = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64' -ErrorAction SilentlyContinue
    if ($vc -and $vc.Installed -eq 1 -and [int]$vc.Major -ge 14 -and [int]$vc.Minor -ge 40) { Info "Already installed ($($vc.Version))." }
    else {
        Info 'Downloading...'; Get-File $VcRedist "$dl\vc_redist.x64.exe"
        Info 'Installing - click YES on the Windows prompt.'
        $p = Start-Process "$dl\vc_redist.x64.exe" -ArgumentList '/install', '/quiet', '/norestart' -Verb RunAs -Wait -PassThru
        if ($p.ExitCode -notin 0, 1638, 3010) { Warn "The installer returned $($p.ExitCode). If VPX will not start later, run vc_redist.x64.exe from $dl yourself." } else { Info 'Done.' }
    }

    # ---------- Visual Pinball X ----------
    Step 'Visual Pinball X 10.8.1'
    $vpxExe = if ($cfg.VpxExe -and (Test-Path -LiteralPath $cfg.VpxExe)) { $cfg.VpxExe } else { $null }
    if ($vpxExe -and -not (Ask 'VPX is already installed. Download it again (repair)?' $false)) { Info "Keeping $vpxExe" }
    else {
        $rel = try { Invoke-RestMethod "https://api.github.com/repos/vpinball/vpinball/releases/tags/$VpxTag" -Headers @{ 'User-Agent' = 'vpx-cabinet-kit' } } catch { $null }
        if (-not $rel) { Warn 'Pinned build not found - using the newest release.'; $rel = (Invoke-RestMethod 'https://api.github.com/repos/vpinball/vpinball/releases?per_page=5' -Headers @{ 'User-Agent' = 'vpx-cabinet-kit' }) | Where-Object { $_.assets.name -match $VpxAsset } | Select-Object -First 1 }
        $asset = $rel.assets | Where-Object { $_.name -match $VpxAsset } | Select-Object -First 1
        if (-not $asset) { throw 'Could not find the Windows VPX download on GitHub.' }
        Info "Downloading $($asset.name) ($([int]($asset.size / 1MB)) MB)..."
        Get-File $asset.browser_download_url "$dl\vpx.zip"
        Info 'Unpacking...'
        Expand-Flat "$dl\vpx.zip" $cfg.VpxDir 'VPinballX*.exe'
        $vpxExe = (Get-ChildItem -LiteralPath $cfg.VpxDir -Filter 'VPinballX*.exe' -File | Sort-Object @{ e = { $_.Name -notmatch 'BGFX' } }, @{ e = { $_.Name -notmatch '64' } }, Name | Select-Object -First 1).FullName
        if (-not $vpxExe) { throw 'VPinballX exe missing after unpacking.' }
        Get-ChildItem -LiteralPath $cfg.VpxDir -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
        Info "Installed: $vpxExe"
    }
    $cfg.VpxExe = $vpxExe

    # ---------- table folders + VPX settings ----------
    Step 'Visual Pinball settings'
    $T = $cfg.Tables
    foreach ($d in $T, "$T\pinmame\roms", "$T\pinmame\altcolor", "$T\pinmame\altsound", "$T\pinmame\nvram", "$T\music", "$T\pupvideos") { New-Item -ItemType Directory -Force $d | Out-Null }
    $ini = $cfg.VpxIni
    Set-IniKeys $ini 'Player' ([ordered]@{ PlayfieldFullScreen = 1; ShowFPS = 0; SSRefl = 1; AAFactor = '1.0'; MSAASamples = 0; FXAA = 6; Sharpen = 1; CacheMode = 1 })   # SMAA + reflections (tested on a Radeon 780M at 60 fps)
    $dmd = [ordered]@{}; foreach ($n in 1..7) { $dmd["Profile${n}UnlitDotColor"] = '0X00000000' }
    Set-IniKeys $ini 'DMD' $dmd   # black DMD background (unlit dots off)
    Get-ChildItem -LiteralPath (Join-Path $cfg.VpxDir 'plugins\scoreview\layouts') -Filter 'lay4x1-dmd*.scv' -ErrorAction SilentlyContinue | ForEach-Object {
        (Get-Content -LiteralPath $_.FullName -Raw) -replace 'Ambient:(\s*)\[0\.4,0\.4,0\.4\]', 'Ambient:$1[0.0,0.0,0.0]' | Set-Content -LiteralPath $_.FullName -NoNewline }   # black DMD glass
    Set-IniKeys $ini 'Controller' ([ordered]@{ ForceDisableB2S = 0 })
    Set-IniKeys $ini 'Plugin.PinMAME' ([ordered]@{ Enable = 1; PinMAMEPath = "$T\pinmame\" })
    Set-IniKeys $ini 'Plugin.B2SLegacy' ([ordered]@{ Enable = 1; B2SHideGrill = 1 })
    foreach ($p in 'Serum', 'VNI', 'ScoreView', 'PUP', 'AltSound', 'FlexDMD') { Set-IniKeys $ini "Plugin.$p" ([ordered]@{ Enable = 1 }) }
    Set-GlobalVpxMode $cfg
    Info "Settings: $ini"
    Info "Tables:   $T"

    # ---------- ES-DE ----------
    Step 'ES-DE (game menu)'
    $esdeExe = Join-Path $cfg.EsdeDir 'ES-DE.exe'
    if ((Test-Path $esdeExe) -and -not (Ask 'ES-DE is already installed. Download the newest version (keeps your settings)?' $false)) { Info 'Keeping the installed ES-DE.' }
    else {
        if (Get-EsdeProcess) { [void](Stop-Esde) }
        $url = $EsdeBackup; $nm = 'ES-DE portable'
        try {
            $r = Invoke-RestMethod $EsdeApi
            $l = $r.assets.links | Where-Object { $_.name -match '_Portable\.zip$' } | Select-Object -First 1
            if ($l) { $url = $l.url; $nm = $l.name }
        } catch { Warn 'Could not ask GitLab for the newest ES-DE - using 3.5.0.' }
        Info "Downloading $nm..."
        Get-File $url "$dl\esde.zip"
        Info 'Unpacking...'
        Expand-Flat "$dl\esde.zip" $cfg.EsdeDir 'ES-DE.exe'
        Get-ChildItem -LiteralPath $cfg.EsdeDir -Recurse -File -Filter *.exe | Unblock-File -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path (Join-Path $cfg.EsdeDir 'portable.txt'))) { [IO.File]::WriteAllText((Join-Path $cfg.EsdeDir 'portable.txt'), '') }
    $data = $cfg.EsdeData
    foreach ($d in 'custom_systems', 'settings', 'gamelists\vpinball', 'downloaded_media\vpinball\screenshots', 'downloaded_media\vpinball\marquees', 'downloaded_media\vpinball\covers') { New-Item -ItemType Directory -Force (Join-Path $data $d) | Out-Null }
    $rel = $cfg.VpxExe.Substring($cfg.EsdeDir.Length).TrimStart('\')
    $sys = @"
<?xml version="1.0"?>
<!-- VPX Cabinet Kit: Visual Pinball runs the VPX build in Emulators\VPinballX -->
<systemList>
    <system>
        <name>vpinball</name>
        <fullname>Visual Pinball</fullname>
        <path>%ROMPATH%\vpinball</path>
        <extension>.vpx .VPX</extension>
        <command label="Visual Pinball X">%ESPATH%\$rel -play %ROM%</command>
        <platform>vpinball</platform>
        <theme>vpinball</theme>
    </system>
</systemList>
"@
    [IO.File]::WriteAllText((Join-Path $data 'custom_systems\es_systems.xml'), $sys, $Utf8)
    $set = Join-Path $data 'settings\es_settings.xml'
    if (-not (Test-Path $set)) {
        [IO.File]::WriteAllText($set, "<?xml version=`"1.0`"?>`n<string name=`"StartupSystem`" value=`"vpinball`" />`n<bool name=`"ShowQuitMenu`" value=`"true`" />`n", $Utf8)
    }
    Info "ES-DE: $($cfg.EsdeDir)"

    # ---------- kit files + shortcuts ----------
    Step 'Shortcuts'
    $kit = Join-Path $Root 'Kit'; New-Item -ItemType Directory -Force $kit | Out-Null
    if ((Resolve-Path $PSScriptRoot).Path -ne (Resolve-Path $kit).Path) {
        Get-ChildItem -LiteralPath $PSScriptRoot -File | Copy-Item -Destination $kit -Force
        $readme = Join-Path (Split-Path $PSScriptRoot) 'README.txt'; if (Test-Path $readme) { Copy-Item $readme $Root -Force }
    }
    Get-ChildItem -LiteralPath $kit -File | Unblock-File -ErrorAction SilentlyContinue
    Save-KitConfig $cfg
    $desk = [Environment]::GetFolderPath('Desktop')
    $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $hidden = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File'
    New-Shortcut "$desk\Start Pinball.lnk" $esdeExe '' "$esdeExe,0" $cfg.EsdeDir
    New-Shortcut "$desk\Pinball Table Installer.lnk" $ps "$hidden `"$kit\Table-Installer.ps1`"" "$($cfg.VpxExe),0" $kit
    New-Shortcut "$desk\Pinball Display Mode.lnk" $ps "$hidden `"$kit\Display-Mode.ps1`"" "$env:SystemRoot\System32\DisplaySwitch.exe,0" $kit
    Info 'Desktop: Start Pinball, Pinball Table Installer, Pinball Display Mode'
    $startup = Join-Path ([Environment]::GetFolderPath('Startup')) 'Start Pinball.lnk'
    if (Ask 'Start the pinball menu automatically when Windows starts (for a cabinet)?' $true) { New-Shortcut $startup $esdeExe '' "$esdeExe,0" $cfg.EsdeDir; Info 'ES-DE will start with Windows.' }
    elseif (Test-Path $startup) { Remove-Item $startup }

    Remove-Item -LiteralPath $dl -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host ''
    Write-Host '  ALL SET!' -ForegroundColor Magenta
    Write-Host '  1. Open "Pinball Table Installer" on the desktop and drag in a table you downloaded.' -ForegroundColor Cyan
    Write-Host '  2. Open "Start Pinball" to play. Esc in a table brings up the menu to quit back.' -ForegroundColor Cyan
    Write-Host '  3. Turning the TV upright? Run "Pinball Display Mode" and press PORTRAIT.' -ForegroundColor Cyan
    Write-Host ''
    if (Ask 'Open the Table Installer now?' $true) { Start-Process $ps -ArgumentList "$hidden `"$kit\Table-Installer.ps1`"" }
} catch {
    Write-Host ''
    Write-Host "  SETUP STOPPED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host '  Fix the problem above and run Setup.cmd again - it picks up where it left off.' -ForegroundColor Yellow
    Write-Host ''
    Read-Host '  Press Enter to close'
    exit 1
}
