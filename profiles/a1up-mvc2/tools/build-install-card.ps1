$ErrorActionPreference = 'Stop'

$Root  = 'C:\path\to\mvc2-cabinet'
$PngOut = Join-Path $Root 'KaoticArcade-Install-Card.png'
$PptOut = Join-Path $Root 'KaoticArcade-Install-Card.pptx'
$Logo  = Join-Path $Root 'kaoticarcade.png'
$BgArt = Join-Path $Root '_frontend_art\bg_1280x960.jpg'

$CHK = [string][char]0x2713
$MID = [string][char]0x00B7
$EMD = [string][char]0x2014
$LDQ = [string][char]0x201C
$RDQ = [string][char]0x201D
$APO = [string][char]0x2019

function Hx([string]$h) {
  $r = [Convert]::ToInt32($h.Substring(0,2),16)
  $g = [Convert]::ToInt32($h.Substring(2,2),16)
  $b = [Convert]::ToInt32($h.Substring(4,2),16)
  return ($r + $g*256 + $b*65536)
}

$C_BG    = Hx '0B0D1A'
$C_PANEL = Hx '141829'
$C_RED   = Hx 'E12228'
$C_GOLD  = Hx 'F2C230'
$C_WHITE = Hx 'FFFFFF'
$C_TEXT  = Hx 'E8EAF2'
$C_MUTED = Hx 'A9B0C7'
$C_DARK  = Hx '0B0D1A'

$msoTrue = -1; $msoFalse = 0

$ppt = New-Object -ComObject PowerPoint.Application
$ppt.Visible = $msoTrue
$pres = $ppt.Presentations.Add()
$pres.PageSetup.SlideWidth  = 960
$pres.PageSetup.SlideHeight = 540

$s = $pres.Slides.Add(1, 12)
$s.FollowMasterBackground = $msoFalse
$s.Background.Fill.Solid()
$s.Background.Fill.ForeColor.RGB = $C_BG

function Add-Box {
  param($Slide,[double]$L,[double]$T,[double]$W,[double]$H,[string]$Text,
        [string]$Font='Calibri',[double]$Size=13,[bool]$Bold=$false,[int]$Color=$C_TEXT,
        [int]$Align=1,[int]$Anchor=1,[double]$Space=0)
  $sh = $Slide.Shapes.AddTextbox(1,$L,$T,$W,$H)
  $tf = $sh.TextFrame
  $tf.WordWrap = $msoTrue
  $tf.AutoSize = 0
  $tf.MarginLeft = 0; $tf.MarginRight = 0; $tf.MarginTop = 0; $tf.MarginBottom = 0
  $tf.VerticalAnchor = $Anchor
  $tr = $tf.TextRange
  $tr.Text = $Text
  $tr.Font.Name = $Font
  $tr.Font.Size = $Size
  if ($Bold) { $tr.Font.Bold = $msoTrue } else { $tr.Font.Bold = $msoFalse }
  $tr.Font.Color.RGB = $Color
  $tr.ParagraphFormat.Alignment = $Align
  if ($Space -gt 0) { $tr.ParagraphFormat.SpaceWithin = $Space }
  return $sh
}

function Emph {
  param($Shape,[string[]]$Phrases,[int]$Color=$C_GOLD)
  $tr = $Shape.TextFrame.TextRange
  $txt = $tr.Text
  foreach ($p in $Phrases) {
    $i = $txt.IndexOf($p)
    if ($i -ge 0) {
      $c = $tr.Characters($i+1, $p.Length)
      $c.Font.Bold = $msoTrue
      $c.Font.Color.RGB = $Color
    }
  }
}

function Add-Panel {
  param($Slide,[double]$L,[double]$T,[double]$W,[double]$H,[int]$Fill=$C_PANEL,[double]$Radius=0.05,[double]$Trans=0)
  $sh = $Slide.Shapes.AddShape(5,$L,$T,$W,$H)
  $sh.Adjustments.Item(1) = $Radius
  $sh.Fill.Solid()
  $sh.Fill.ForeColor.RGB = $Fill
  if ($Trans -gt 0) { $sh.Fill.Transparency = $Trans }
  $sh.Line.Visible = $msoFalse
  return $sh
}

function Add-Badge {
  param($Slide,[double]$L,[double]$T,[double]$D,[string]$Text,[int]$Fill=$C_RED,
        [int]$TextColor=$C_WHITE,[double]$Size=13,[string]$Font='Arial')
  $sh = $Slide.Shapes.AddShape(9,$L,$T,$D,$D)
  $sh.Fill.Solid()
  $sh.Fill.ForeColor.RGB = $Fill
  $sh.Line.Visible = $msoFalse
  $tf = $sh.TextFrame
  $tf.MarginLeft = 0; $tf.MarginRight = 0; $tf.MarginTop = 0; $tf.MarginBottom = 0
  $tf.VerticalAnchor = 3
  $tr = $tf.TextRange
  $tr.Text = $Text
  $tr.Font.Name = $Font
  $tr.Font.Size = $Size
  $tr.Font.Bold = $msoTrue
  $tr.Font.Color.RGB = $TextColor
  $tr.ParagraphFormat.Alignment = 2
  return $sh
}

# ---------------- background ----------------
$s.Shapes.AddPicture($BgArt, $msoFalse, $msoTrue, 0, -168, 960, 720) | Out-Null
$scrim = $s.Shapes.AddShape(1, 0, 0, 960, 540)
$scrim.Fill.Solid()
$scrim.Fill.ForeColor.RGB = $C_DARK
$scrim.Fill.Transparency = 0.12
$scrim.Line.Visible = $msoFalse

# ---------------- header ----------------
$logoW = 168.0
$logoH = $logoW * 965.0 / 1529.0
$s.Shapes.AddPicture($Logo, $msoFalse, $msoTrue, 36, 22, $logoW, $logoH) | Out-Null

Add-Box $s 222 46 700 34 'REQUIREMENTS & INSTALL' 'Arial Black' 27 $true $C_WHITE 1 1 | Out-Null
Add-Box $s 224 84 700 22 ('Arcade1Up Marvel vs. Capcom 2 / X-Men ' + $APO + '97 cabinet soft mod') 'Calibri' 14 $true $C_GOLD 1 1 | Out-Null

$panelTop = 142.0; $panelBot = 502.0; $panelH = $panelBot - $panelTop

# ---------------- column 1 : requirements ----------------
$c1x = 36.0; $c1w = 300.0
Add-Panel $s $c1x $panelTop $c1w $panelH $C_PANEL 0.05 0.06 | Out-Null
Add-Badge $s ($c1x+20) 156 26 $CHK $C_GOLD $C_DARK 14 'Calibri' | Out-Null
Add-Box $s ($c1x+56) 158 220 22 'WHAT YOU NEED' 'Arial Black' 15 $true $C_WHITE 1 1 | Out-Null

$reqs = @(
  @{ N='Arcade1Up cabinet'; D=('Marvel vs. Capcom 2 or X-Men ' + $APO + '97 ' + $EMD + ' the mod is built for these two.') },
  @{ N='Micro-USB data cable'; D='Must carry data, not charge-only. Cabinet to computer.' },
  @{ N='PC or Mac'; D='Desktop or laptop with a free USB port. Both installers are included.' },
  @{ N='USB keyboard'; D='Plugged into the cabinet. Needed to reach the Android settings.' }
)
$iy = 208.0
foreach ($r in $reqs) {
  $dot = $s.Shapes.AddShape(9, ($c1x+24), ($iy+6), 8, 8)
  $dot.Fill.Solid(); $dot.Fill.ForeColor.RGB = $C_GOLD; $dot.Line.Visible = $msoFalse
  Add-Box $s ($c1x+44) $iy 236 19 $r.N 'Calibri' 14 $true $C_WHITE 1 1 | Out-Null
  Add-Box $s ($c1x+44) ($iy+21) 236 36 $r.D 'Calibri' 11.5 $false $C_MUTED 1 1 1.02 | Out-Null
  $iy += 74
}

# ---------------- column 2 : instructions ----------------
$c2x = 352.0; $c2w = 572.0
Add-Panel $s $c2x $panelTop $c2w $panelH $C_PANEL 0.05 0.06 | Out-Null

Add-Badge $s ($c2x+20) 154 28 '1' $C_RED $C_WHITE 15 'Arial Black' | Out-Null
Add-Box $s ($c2x+58) 157 280 22 'ON THE CABINET' 'Arial Black' 15 $true $C_WHITE 1 1 | Out-Null
Add-Box $s ($c2x+300) 160 ($c2w-320) 18 'powered on, USB keyboard plugged in' 'Calibri' 11.5 $false $C_GOLD 3 1 | Out-Null

$steps1 = @(
  @{ T='Press Windows key + N to pull down the notification shade.'; E=@('Windows key + N') },
  @{ T=('Press Arrow Up once, then Arrow Right three times, then Enter on the settings cog.'); E=@('Arrow Up once','Arrow Right three times','Enter') },
  @{ T='Scroll down to About tablet and open it.'; E=@('About tablet') },
  @{ T='Highlight Build number and press Enter 7 times to enable Developer options.'; E=@('Build number','Enter 7 times') },
  @{ T='Press Esc, open Developer options, and turn on USB debugging.'; E=@('Esc','Developer options','USB debugging') },
  @{ T='Select USB configuration and choose MTP.'; E=@('USB configuration','MTP') }
)
$ry = 188.0; $rh = 23.0
for ($i=0; $i -lt $steps1.Count; $i++) {
  $y = $ry + $i*$rh
  Add-Badge $s ($c2x+24) ($y+4) 16 ([string]($i+1)) $C_RED $C_WHITE 9 'Arial' | Out-Null
  $b = Add-Box $s ($c2x+50) $y ($c2w-72) $rh $steps1[$i].T 'Calibri' 13 $false $C_TEXT 1 3
  Emph $b $steps1[$i].E $C_GOLD
}

$g2 = 340.0
Add-Badge $s ($c2x+20) ($g2-3) 28 '2' $C_RED $C_WHITE 15 'Arial Black' | Out-Null
Add-Box $s ($c2x+58) $g2 280 22 'ON YOUR COMPUTER' 'Arial Black' 15 $true $C_WHITE 1 1 | Out-Null
Add-Box $s ($c2x+300) ($g2+3) ($c2w-320) 18 'cabinet still on and connected' 'Calibri' 11.5 $false $C_GOLD 3 1 | Out-Null

$steps2 = @(
  @{ T='Connect the micro-USB cable from the cabinet to the computer.'; E=@('micro-USB cable') },
  @{ T='Extract the Kaotic Arcade mod ZIP file.'; E=@('Extract') },
  @{ T=('Run INSTALL.bat in the extracted folder  ' + $MID + '  on a Mac, run mac/INSTALL.command'); E=@('INSTALL.bat','mac/INSTALL.command') },
  @{ T='Leave the cable plugged in and wait for it to finish.'; E=@('wait for it to finish') },
  @{ T=('Answer Y to ' + $LDQ + 'Reboot the cabinet now?' + $RDQ + ' ' + $EMD + ' and you' + $APO + 're done.'); E=@('Y') }
)
$ry2 = 372.0
for ($i=0; $i -lt $steps2.Count; $i++) {
  $y = $ry2 + $i*$rh
  Add-Badge $s ($c2x+24) ($y+4) 16 ([string]($i+1)) $C_RED $C_WHITE 9 'Arial' | Out-Null
  $b = Add-Box $s ($c2x+50) $y ($c2w-72) $rh $steps2[$i].T 'Calibri' 13 $false $C_TEXT 1 3
  Emph $b $steps2[$i].E $C_GOLD
}

# ---------------- footer tip ----------------
$ft = Add-Box $s 36 510 888 20 ('If the cabinet asks ' + $LDQ + 'Allow USB debugging?' + $RDQ + ', highlight OK with the keyboard and press Enter, then let the installer continue.') 'Calibri' 12 $false $C_MUTED 2 1
Emph $ft @('Allow USB debugging?') $C_GOLD

# ---------------- output ----------------
if (Test-Path $PptOut) { Remove-Item $PptOut -Force }
$pres.SaveAs($PptOut, 24)
if (Test-Path $PngOut) { Remove-Item $PngOut -Force }
$s.Export($PngOut, 'PNG', 1920, 1080)
$pres.Close()
$ppt.Quit()
"PNG: $PngOut"
"PPT: $PptOut"
