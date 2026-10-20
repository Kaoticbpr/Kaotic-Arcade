# VPX Cabinet Kit - Pinball Display Mode
# Switches the cabinet between LANDSCAPE (TV flat/sideways: desktop view, backglass + DMD top-right, like a PC)
# and PORTRAIT (TV turned upright: Windows rotated, cabinet view, DMD at the top). Turn the TV, then press the button.

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()
. (Join-Path $PSScriptRoot 'Common.ps1')
try { $cfg = Get-KitConfig } catch { [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Pinball Display Mode'); exit 1 }

$Pink = [System.Drawing.Color]::FromArgb(255, 62, 200)
$Cyan = [System.Drawing.Color]::FromArgb(33, 232, 255)
$Bg   = [System.Drawing.Color]::FromArgb(18, 12, 34)
$Text = [System.Drawing.Color]::FromArgb(235, 230, 255)

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Pinball Display Mode'; $form.Size = New-Object System.Drawing.Size(600, 470)
$form.StartPosition = 'CenterScreen'; $form.BackColor = $Bg; $form.ForeColor = $Text
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10); $form.FormBorderStyle = 'FixedDialog'; $form.MaximizeBox = $false

$title = New-Object System.Windows.Forms.Label
$title.Text = 'DISPLAY MODE'; $title.ForeColor = $Pink; $title.Font = New-Object System.Drawing.Font('Segoe UI Black', 18)
$title.Location = New-Object System.Drawing.Point(18, 10); $title.AutoSize = $true; $form.Controls.Add($title)

$now = New-Object System.Windows.Forms.Label
$now.ForeColor = $Cyan; $now.Location = New-Object System.Drawing.Point(20, 52); $now.Size = New-Object System.Drawing.Size(550, 24)
$form.Controls.Add($now)
function Update-Now { $now.Text = "Now: $($cfg.Mode.ToUpper())   -   turn the TV first, then press the matching button." }

function New-Btn($text, $x, $y, $w, $h, $color) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.Location = New-Object System.Drawing.Point($x, $y); $b.Size = New-Object System.Drawing.Size($w, $h)
    $b.FlatStyle = 'Flat'; $b.BackColor = $color; $b.ForeColor = [System.Drawing.Color]::Black
    $b.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 11); $form.Controls.Add($b); return $b
}
$btnLand = New-Btn "LANDSCAPE`nTV sideways - desktop view" 20 88 265 80 $Cyan
$btnPort = New-Btn "PORTRAIT`nTV upright - cabinet view" 300 88 265 80 $Pink

$bgChk = New-Object System.Windows.Forms.CheckBox
$bgChk.Text = 'Portrait: show the backglass at the top of the screen (above the DMD)'
$bgChk.Checked = [bool]$cfg.PortraitBackglass; $bgChk.Location = New-Object System.Drawing.Point(20, 180); $bgChk.Size = New-Object System.Drawing.Size(550, 26)
$form.Controls.Add($bgChk)

$btnFlip = New-Btn 'Portrait picture is upside down - flip it' 20 214 545 36 ([System.Drawing.Color]::FromArgb(150, 140, 190))
$btnFlip.Font = New-Object System.Drawing.Font('Segoe UI', 10)

$log = New-Object System.Windows.Forms.TextBox
$log.Multiline = $true; $log.ReadOnly = $true; $log.ScrollBars = 'Vertical'
$log.Location = New-Object System.Drawing.Point(20, 262); $log.Size = New-Object System.Drawing.Size(545, 150)
$log.BackColor = [System.Drawing.Color]::FromArgb(10, 6, 20); $log.ForeColor = $Cyan; $log.Font = New-Object System.Drawing.Font('Consolas', 9.5)
$form.Controls.Add($log)
function Write-Log([string]$s) { $log.AppendText($s + "`r`n"); [System.Windows.Forms.Application]::DoEvents() }

function Invoke-Mode([string]$mode) {
    $form.Cursor = 'WaitCursor'; $log.Clear()
    try {
        $cfg.PortraitBackglass = $bgChk.Checked
        Write-Log "Switching to $mode..."
        if (Set-DisplayMode $cfg $mode { param($s) Write-Log $s }) { Write-Log 'Done.' }
        Update-Now
    } catch { Write-Log "ERROR: $($_.Exception.Message)" } finally { $form.Cursor = 'Default' }
}
$btnLand.Add_Click({ Invoke-Mode 'landscape' })
$btnPort.Add_Click({ Invoke-Mode 'portrait' })
$btnFlip.Add_Click({
    $cfg.PortraitTurn = if ([int]$cfg.PortraitTurn -eq 90) { 270 } else { 90 }
    Save-KitConfig $cfg
    Invoke-Mode 'portrait'
})
$bgChk.Add_CheckedChanged({
    $cfg.PortraitBackglass = $bgChk.Checked; Save-KitConfig $cfg
    if ($cfg.Mode -eq 'portrait') { Update-AllLayouts $cfg $null; Write-Log "Backglass in portrait: $(if ($bgChk.Checked) { 'on' } else { 'off' })" }
})

Update-Now
[void]$form.ShowDialog()
