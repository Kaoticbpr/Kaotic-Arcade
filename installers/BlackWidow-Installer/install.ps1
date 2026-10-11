param([ValidateSet('Install','Uninstall')][string]$Action = 'Install')

# Black Widow installer for Buy Stuff WrestleFest (Batocera) cabinets.
# Uses the OpenSSH client built into Windows 10/11. Only adds Black Widow; never updates the cabinet.

$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

# Save a log next to the installer so problems can be diagnosed (no passwords are recorded).
$log = Join-Path $here 'install-log.txt'
try { Start-Transcript -Path $log -Force | Out-Null } catch { }

# Any unexpected error: show it, keep the window open.
trap {
    Write-Host ""
    Write-Host "  UNEXPECTED ERROR: $_" -ForegroundColor Red
    Write-Host "  A log was saved to: $log" -ForegroundColor Yellow
    Read-Host "Press Enter to close"
    exit 1
}

function Fail($msg) {
    Write-Host ""; Write-Host "  ERROR: $msg" -ForegroundColor Red
    Write-Host "  (A log was saved to: $log)" -ForegroundColor Yellow; Write-Host ""
    Read-Host "Press Enter to close"; exit 1
}

Write-Host "  PowerShell $($PSVersionTable.PSVersion) on Windows $([Environment]::OSVersion.Version)"

Write-Host ""
Write-Host "  ===== Black Widow $Action  -  WrestleFest cabinet =====" -ForegroundColor Cyan
Write-Host "  This only ADDS Black Widow (or removes it again). It does NOT update or"
Write-Host "  change anything else on your cabinet, and it backs up every file it edits."
Write-Host ""

foreach ($tool in 'ssh', 'scp', 'tar') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Fail "'$tool' was not found. Windows 10/11 includes it: Settings > Apps > Optional features > add 'OpenSSH Client'."
    }
}

# --- ROM (not needed to uninstall)
$rom = $null
if ($Action -eq 'Install') {
    foreach ($p in @((Join-Path $here 'bwidow.zip'), (Join-Path $here 'rom\bwidow.zip'))) {
        if (Test-Path $p) { $rom = $p; break }
    }
    if (-not $rom) {
        Write-Host ""
        Write-Host "  STOP: the Black Widow ROM file (bwidow.zip) was not found." -ForegroundColor Red
        Write-Host "  It is NOT included in this installer. Put your own copy of bwidow.zip in this" -ForegroundColor Yellow
        Write-Host "  folder (right next to Install-BlackWidow.bat), then run the installer again." -ForegroundColor Yellow
        Write-Host "  (If the cabinet already has bwidow.zip you can type SKIP below.)"
        Write-Host ""
        $ans = Read-Host "  Type SKIP to continue without it, or just press Enter to quit"
        if ($ans -ne 'SKIP') { Fail "Installer stopped: bwidow.zip is missing. Nothing was changed on the cabinet." }
    } else {
        $len = (Get-Item $rom).Length
        $head = [System.IO.File]::ReadAllBytes($rom)[0..1]
        if ($len -lt 1000 -or $head[0] -ne 0x50 -or $head[1] -ne 0x4B) { Fail "bwidow.zip doesn't look like a valid zip file." }
        Write-Host "  Found ROM: $rom ($len bytes)"
    }
}

# --- Cabinet address
Write-Host ""
Write-Host "  Find the cabinet's IP address on your router's connected-devices list"
Write-Host "  (its hostname is usually 'Buystuff'). Your PC must be on the same WiFi."
$defaultIp = '192.168.1.77'
$ip = ("" + (Read-Host "  Cabinet IP address - just press Enter to use $defaultIp")).Trim()
if ($ip -eq '') { $ip = $defaultIp }
if ($ip -notmatch '^[A-Za-z0-9.\-]+$') { Fail "That doesn't look like an IP address." }

$tcp = New-Object System.Net.Sockets.TcpClient
$iar = $tcp.BeginConnect($ip, 22, $null, $null)
if (-not $iar.AsyncWaitHandle.WaitOne(5000) -or -not $tcp.Connected) { $tcp.Close(); Fail "Can't reach $ip on SSH port 22. Check the IP and that the cabinet is on." }
$tcp.Close()

$reboot = 'noreboot'
$r = Read-Host "  Restart the cabinet automatically when finished? Recommended - y/N"
if ($r -match '^[Yy]') { $reboot = 'reboot' }

# --- Stage payload
$stage = Join-Path $env:TEMP ("bwi-stage-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $stage | Out-Null
Copy-Item (Join-Path $here 'payload\*') $stage -Recurse
if ($rom) { New-Item -ItemType Directory -Path (Join-Path $stage 'rom') | Out-Null; Copy-Item $rom (Join-Path $stage 'rom\bwidow.zip') }

# the cabinet needs Unix line endings in text files
foreach ($f in 'remote-install.sh', 'bwidow.cfg', 'gamelist-entry.xml') {
    $path = Join-Path $stage $f
    $txt = [System.IO.File]::ReadAllText($path) -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($path, $txt, (New-Object System.Text.UTF8Encoding($false)))
}

$tgz = Join-Path $env:TEMP 'bwidow-installer.tgz'
if (Test-Path $tgz) { Remove-Item $tgz -Force }
tar --format ustar -czf $tgz -C $stage .
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $tgz)) { Fail "Could not build the install package." }

$sshOpts = @('-o', 'StrictHostKeyChecking=accept-new', '-o', 'ConnectTimeout=10')

Write-Host ""
Write-Host "  Copying to the cabinet. When asked for a password, type:  linux" -ForegroundColor Yellow
Write-Host "  (you won't see it as you type - that's normal). It is asked twice." -ForegroundColor Yellow
Write-Host ""
& scp @sshOpts $tgz "root@${ip}:/tmp/bwidow-installer.tgz"
if ($LASTEXITCODE -ne 0) { Remove-Item $stage, $tgz -Recurse -Force -ErrorAction SilentlyContinue; Fail "Copy failed (wrong password or IP?). Nothing was changed on the cabinet." }

$remote = "rm -rf /tmp/bwi && mkdir -p /tmp/bwi && tar -xzf /tmp/bwidow-installer.tgz -C /tmp/bwi && sh /tmp/bwi/remote-install.sh $($Action.ToLower()) $reboot"
& ssh @sshOpts "root@$ip" $remote
$rc = $LASTEXITCODE

Remove-Item $stage, $tgz -Recurse -Force -ErrorAction SilentlyContinue
if ($rc -ne 0) { Fail "The installer reported a problem (see messages above)." }

Write-Host ""
Write-Host "  All done." -ForegroundColor Green
if ($reboot -eq 'noreboot') { Write-Host "  Restart the cabinet from its menu BEFORE playing any game so the list reloads." -ForegroundColor Yellow }
Write-Host ""
try { Stop-Transcript | Out-Null } catch { }
Read-Host "Press Enter to close"
