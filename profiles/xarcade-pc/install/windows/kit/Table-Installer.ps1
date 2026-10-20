# VPX Cabinet Kit - Pinball Table Installer
# Drag a table's downloads (zips, .vpx, .directb2s, ROM zip, wheel image, color files, or a whole folder) onto the
# window, check the name, press INSTALL. Everything is sorted into Visual Pinball X and added to ES-DE (see Common.ps1).
# Started from the "Pinball Table Installer" shortcut on the desktop.

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()
. (Join-Path $PSScriptRoot 'Common.ps1')
try { $cfg = Get-KitConfig } catch { [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Pinball Table Installer'); exit 1 }

$Pink = [System.Drawing.Color]::FromArgb(255, 62, 200)
$Cyan = [System.Drawing.Color]::FromArgb(33, 232, 255)
$Bg   = [System.Drawing.Color]::FromArgb(18, 12, 34)
$Panel= [System.Drawing.Color]::FromArgb(32, 22, 58)
$Text = [System.Drawing.Color]::FromArgb(235, 230, 255)

# ---------- file type detection (for the list and the checklist) ----------
function Get-ZipNames([string]$path) {
    try { $z = [System.IO.Compression.ZipFile]::OpenRead($path); $n = @($z.Entries | ForEach-Object { $_.FullName }); $z.Dispose(); return $n }
    catch { return @() }
}
function Get-Kind([string]$path) {
    if (Test-Path -LiteralPath $path -PathType Container) { return 'Folder' }
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    switch ($ext) {
        '.vpx'       { return 'Table' }
        '.directb2s' { return 'Backglass' }
        '.crz'       { return 'Colors (Serum)' }
        '.cromc'     { return 'Colors (Serum)' }
        '.crom'      { return 'Colors (Serum)' }
        '.pal'       { return 'Colors (VNI)' }
        '.vni'       { return 'Colors (VNI)' }
        '.vbs'       { return 'Script fix' }
        '.mp3'       { return 'Music' }
        '.ogg'       { return 'Music' }
        '.zip' {
            $low = @(Get-ZipNames $path | ForEach-Object { $_.ToLower() })
            if ($low | Where-Object { $_.EndsWith('.vpx') })       { return 'Table (zipped)' }
            if ($low | Where-Object { $_.EndsWith('.directb2s') }) { return 'Backglass (zipped)' }
            if ($low | Where-Object { $_.EndsWith('.crz') -or $_.EndsWith('.cromc') -or $_.EndsWith('.crom') }) { return 'Colors (zipped)' }
            if ($low | Where-Object { $_ -like '*altsound*' })      { return 'AltSound pack' }
            if ($low | Where-Object { $_ -like '*pupvideos*' -or $_.EndsWith('.pup') }) { return 'PuP pack' }
            $media = $low | Where-Object { $_ -match '\.(txt|pdf|docx|png|jpg|mp3|ogg|wav|mp4|csv|vbs|zip)$' }
            if ($low.Count -gt 0 -and -not $media) { return 'ROM' }
            return 'Zip (extras)'
        }
    }
    if ($ext -in '.png', '.jpg', '.jpeg', '.apng', '.webp', '.gif') { return 'Wheel image' }
    return 'Extra'
}
function Get-TableNameFrom([string]$raw) {
    $n = [System.IO.Path]::GetFileNameWithoutExtension($raw)
    $n = $n -replace '\.vpx$', ''
    if ($n -match '^(.*?\(\s*[^()]*?\s(?:19|20)\d\d\s*\))') { return $Matches[1].Trim() }
    $n = $n -replace '(?i)\b(vpw|vpx|g5k|full\s*dmd|mod|v?\d+(\.\d+)+[a-z]?)\b', ''
    return ($n -replace '\s{2,}', ' ').Trim(' ', '-', '_')
}
function Find-VpxName([string]$path) {
    if (Test-Path -LiteralPath $path -PathType Container) {
        $f = Get-ChildItem -LiteralPath $path -Recurse -File | Where-Object { $_.Extension -in '.vpx', '.zip' } | Sort-Object Length -Descending
        foreach ($x in $f) { $r = Find-VpxName $x.FullName; if ($r) { return $r } }
        return $null
    }
    if ($path.ToLower().EndsWith('.vpx')) { return [System.IO.Path]::GetFileName($path) }
    if ($path.ToLower().EndsWith('.zip')) { $v = Get-ZipNames $path | Where-Object { $_.ToLower().EndsWith('.vpx') } | Select-Object -First 1; if ($v) { return [System.IO.Path]::GetFileName($v) } }
    return $null
}

# ---------- window ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Pinball Table Installer'
$form.Size = New-Object System.Drawing.Size(860, 690)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $Bg; $form.ForeColor = $Text
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$form.AllowDrop = $true

$title = New-Object System.Windows.Forms.Label
$title.Text = 'PINBALL TABLE INSTALLER'; $title.ForeColor = $Pink
$title.Font = New-Object System.Drawing.Font('Segoe UI Black', 18)
$title.Location = New-Object System.Drawing.Point(18, 10); $title.AutoSize = $true
$form.Controls.Add($title)

$hint = New-Object System.Windows.Forms.Label
$hint.Text = 'Drag in everything you downloaded for ONE table: zips, .vpx, .directb2s, the ROM zip, the wheel image, color files - or the whole folder.'
$hint.ForeColor = $Cyan; $hint.Location = New-Object System.Drawing.Point(20, 52); $hint.Size = New-Object System.Drawing.Size(810, 40)
$form.Controls.Add($hint)

$list = New-Object System.Windows.Forms.ListView
$list.View = 'Details'; $list.FullRowSelect = $true; $list.AllowDrop = $true
$list.Location = New-Object System.Drawing.Point(20, 95); $list.Size = New-Object System.Drawing.Size(805, 190)
$list.BackColor = $Panel; $list.ForeColor = $Text; $list.BorderStyle = 'FixedSingle'
[void]$list.Columns.Add('File', 470); [void]$list.Columns.Add('What it is', 190); [void]$list.Columns.Add('Size', 110)
$form.Controls.Add($list)

$check = New-Object System.Windows.Forms.Label
$check.Location = New-Object System.Drawing.Point(20, 292); $check.Size = New-Object System.Drawing.Size(805, 24)
$check.ForeColor = $Cyan
$form.Controls.Add($check)

$nameLbl = New-Object System.Windows.Forms.Label
$nameLbl.Text = 'Table name - best as "Title (Maker Year)", e.g. "Medieval Madness (Williams 1997)":'
$nameLbl.Location = New-Object System.Drawing.Point(20, 322); $nameLbl.AutoSize = $true
$form.Controls.Add($nameLbl)
$name = New-Object System.Windows.Forms.TextBox
$name.Location = New-Object System.Drawing.Point(20, 345); $name.Size = New-Object System.Drawing.Size(805, 28)
$name.BackColor = $Panel; $name.ForeColor = $Text
$form.Controls.Add($name)

$refresh = New-Object System.Windows.Forms.CheckBox
$refresh.Text = 'Show it in ES-DE right away (restarts ES-DE if it is open)'
$refresh.Checked = $true; $refresh.Location = New-Object System.Drawing.Point(20, 380); $refresh.Size = New-Object System.Drawing.Size(520, 26)
$form.Controls.Add($refresh)

$modeLbl = New-Object System.Windows.Forms.Label
$modeLbl.Text = "Screen: $($cfg.Mode) mode"; $modeLbl.ForeColor = [System.Drawing.Color]::FromArgb(150, 140, 190)
$modeLbl.Location = New-Object System.Drawing.Point(560, 384); $modeLbl.Size = New-Object System.Drawing.Size(265, 22); $modeLbl.TextAlign = 'TopRight'
$form.Controls.Add($modeLbl)

function New-Btn($text, $x, $w, $color) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.Location = New-Object System.Drawing.Point($x, 412); $b.Size = New-Object System.Drawing.Size($w, 40)
    $b.FlatStyle = 'Flat'; $b.BackColor = $color; $b.ForeColor = [System.Drawing.Color]::Black
    $b.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10)
    $form.Controls.Add($b); return $b
}
$btnInstall = New-Btn 'INSTALL TABLE' 20 230 $Pink
$btnFiles   = New-Btn 'Add files...' 262 130 $Cyan
$btnFolder  = New-Btn 'Add folder...' 404 130 $Cyan
$btnClear   = New-Btn 'Clear' 546 100 ([System.Drawing.Color]::FromArgb(150, 140, 190))

$log = New-Object System.Windows.Forms.TextBox
$log.Multiline = $true; $log.ReadOnly = $true; $log.ScrollBars = 'Vertical'
$log.Location = New-Object System.Drawing.Point(20, 462); $log.Size = New-Object System.Drawing.Size(805, 175)
$log.BackColor = [System.Drawing.Color]::FromArgb(10, 6, 20); $log.ForeColor = $Cyan
$log.Font = New-Object System.Drawing.Font('Consolas', 9.5)
$form.Controls.Add($log)

function Write-Log([string]$s) { $log.AppendText($s + "`r`n"); [System.Windows.Forms.Application]::DoEvents() }

$script:paths = New-Object System.Collections.ArrayList
function Update-Checklist {
    $kinds = @($list.Items | ForEach-Object { $_.SubItems[1].Text })
    $all = ($kinds -join '|')
    $hasFolder = $kinds -contains 'Folder'
    $t = if ($all -match 'Table') { '[x] Table' } elseif ($hasFolder) { '[?] Table (in folder)' } else { '[ ] Table  <- needed' }
    $b = if ($all -match 'Backglass') { '[x] Backglass' } else { '[ ] Backglass' }
    $r = if ($all -match '\bROM\b') { '[x] ROM' } else { '[ ] ROM (only if the table uses one)' }
    $c = if ($all -match 'Colors') { '[x] Colors' } else { '[ ] Colors (optional)' }
    $w = if ($all -match 'Wheel') { '[x] Wheel' } else { '[ ] Wheel (optional)' }
    if ($hasFolder) { $b = '[?] Backglass'; $r = '[?] ROM'; $c = '[?] Colors'; $w = '[?] Wheel' }
    $check.Text = "$t     $b     $r     $c     $w"
}
function Add-Paths([string[]]$items) {
    foreach ($p in $items) {
        if (-not $p -or $script:paths -contains $p) { continue }
        [void]$script:paths.Add($p)
        $kind = Get-Kind $p
        $size = if (Test-Path -LiteralPath $p -PathType Container) { (Get-ChildItem -LiteralPath $p -Recurse -File | Measure-Object Length -Sum).Sum } else { (Get-Item -LiteralPath $p).Length }
        $it = New-Object System.Windows.Forms.ListViewItem([System.IO.Path]::GetFileName($p.TrimEnd('\')))
        [void]$it.SubItems.Add($kind); [void]$it.SubItems.Add(('{0:N1} MB' -f ($size / 1MB)))
        [void]$list.Items.Add($it)
        if (-not $name.Text) { $v = Find-VpxName $p; if ($v) { $name.Text = Get-TableNameFrom $v } }
    }
    Update-Checklist
}

$onDragEnter = { param($s, $e) if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) { $e.Effect = 'Copy' } }
$onDragDrop  = { param($s, $e) Add-Paths ([string[]]$e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)) }
$form.Add_DragEnter($onDragEnter); $form.Add_DragDrop($onDragDrop)
$list.Add_DragEnter($onDragEnter); $list.Add_DragDrop($onDragDrop)

$btnFiles.Add_Click({
    $d = New-Object System.Windows.Forms.OpenFileDialog; $d.Multiselect = $true; $d.Title = 'Pick the table files'
    $d.InitialDirectory = Join-Path $env:USERPROFILE 'Downloads'
    if ($d.ShowDialog() -eq 'OK') { Add-Paths $d.FileNames }
})
$btnFolder.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog; $d.Description = 'Pick the folder with the table files'
    $d.SelectedPath = Join-Path $env:USERPROFILE 'Downloads'
    if ($d.ShowDialog() -eq 'OK') { Add-Paths @($d.SelectedPath) }
})
$btnClear.Add_Click({ $script:paths.Clear(); $list.Items.Clear(); $name.Text = ''; $log.Clear(); Update-Checklist })

$btnInstall.Add_Click({
    if ($script:paths.Count -eq 0) { [void][System.Windows.Forms.MessageBox]::Show('Drag the table files in first.', 'Pinball Table Installer'); return }
    $tableName = $name.Text.Trim()
    if (-not $tableName) { [void][System.Windows.Forms.MessageBox]::Show('Type a table name first.', 'Pinball Table Installer'); return }
    if (Get-VpxProcess) { [void][System.Windows.Forms.MessageBox]::Show('A table is running. Quit it first, then press INSTALL again.', 'Pinball Table Installer'); return }
    $existing = Join-Path $cfg.Tables "$(($tableName -replace '[\\/:*?"<>|]', '').Trim()).vpx"
    if ((Test-Path -LiteralPath $existing) -and [System.Windows.Forms.MessageBox]::Show("'$tableName' is already installed. Replace it?", 'Pinball Table Installer', 'YesNo') -ne 'Yes') { return }
    $btnInstall.Enabled = $false; $log.Clear(); $form.Cursor = 'WaitCursor'
    try {
        $rc = Install-Table $cfg ([string[]]$script:paths.ToArray()) $tableName $refresh.Checked { param($s) Write-Log $s }
        if (@($rc)[-1] -eq 0) {
            Write-Log ''; Write-Log "All set! Look for '$((Get-NameMeta $tableName).Short)' in ES-DE > Visual Pinball."
            [System.Media.SystemSounds]::Asterisk.Play()
        } else { Write-Log 'Something went wrong - see the messages above.' }
    } catch {
        Write-Log "ERROR: $($_.Exception.Message)"
    } finally { $btnInstall.Enabled = $true; $form.Cursor = 'Default' }
})

Update-Checklist
[void]$form.ShowDialog()
