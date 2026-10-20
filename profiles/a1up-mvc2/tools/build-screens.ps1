$ErrorActionPreference = 'Stop'

$Root = 'C:\path\to\mvc2-cabinet'
$Art  = Join-Path $Root '_frontend_art\xmen'
$Logo = Join-Path $Root 'kaoticarcade.png'

$SHOT_MVC2_HOME  = Join-Path $Art 'mvc2-home-extra.png'
$SHOT_MVC2_EXTRA = Join-Path $Art 'mvc2-extra.png'
$SHOT_XMEN_HOME  = Join-Path $Art 'home.png'
$SHOT_XMEN_EXTRA = Join-Path $Art 'xmen-extra-mk.png'

$PptOut = Join-Path $Root 'KaoticArcade-Screens.pptx'
$Png4   = Join-Path $Root 'KaoticArcade-Screens-4up.png'
$PngCab = Join-Path $Root 'KaoticArcade-Screens-Cabinets.png'
$PngExt = Join-Path $Root 'KaoticArcade-Screens-ExtraGames.png'

$MID = [string][char]0x00B7
$EMD = [string][char]0x2014
$APO = [string][char]0x2019
$PLUS = '+'

function Hx([string]$h) {
  $r = [Convert]::ToInt32($h.Substring(0,2),16)
  $g = [Convert]::ToInt32($h.Substring(2,2),16)
  $b = [Convert]::ToInt32($h.Substring(4,2),16)
  return ($r + $g*256 + $b*65536)
}

$C_BG1   = Hx '141A33'
$C_BG2   = Hx '06070E'
$C_RED   = Hx 'E12228'
$C_GOLD  = Hx 'F2C230'
$C_WHITE = Hx 'FFFFFF'
$C_TEXT  = Hx 'E8EAF2'
$C_MUTED = Hx 'A9B0C7'
$C_DIM   = Hx '7E86A0'

$msoTrue = -1; $msoFalse = 0

$ppt = New-Object -ComObject PowerPoint.Application
$ppt.Visible = $msoTrue
$pres = $ppt.Presentations.Add()
$pres.PageSetup.SlideWidth  = 960
$pres.PageSetup.SlideHeight = 540

function New-Slide {
  param([int]$Index)
  $s = $pres.Slides.Add($Index, 12)
  $s.FollowMasterBackground = $msoFalse
  try {
    $s.Background.Fill.TwoColorGradient(3, 1)
    $s.Background.Fill.ForeColor.RGB = $C_BG1
    $s.Background.Fill.BackColor.RGB = $C_BG2
  } catch {
    $s.Background.Fill.Solid()
    $s.Background.Fill.ForeColor.RGB = $C_BG2
  }
  return $s
}

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

# a screenshot in a rounded frame with border + drop shadow
function Add-Shot {
  param($Slide,[string]$Path,[double]$L,[double]$T,[double]$W,[double]$H,[int]$Border=$C_GOLD)
  $sh = $Slide.Shapes.AddShape(5,$L,$T,$W,$H)
  $sh.Adjustments.Item(1) = 0.035
  $sh.Fill.UserPicture($Path)
  $sh.Line.Visible = $msoTrue
  $sh.Line.ForeColor.RGB = $Border
  $sh.Line.Weight = 1.5
  $sh.Line.Transparency = 0.35
  try {
    $sh.Shadow.Type = 25
    $sh.Shadow.Visible = $msoTrue
    $sh.Shadow.ForeColor.RGB = 0
    $sh.Shadow.Transparency = 0.55
    $sh.Shadow.Blur = 14
    $sh.Shadow.OffsetX = 0
    $sh.Shadow.OffsetY = 5
  } catch {}
  return $sh
}

function Add-Dot {
  param($Slide,[double]$L,[double]$T,[double]$D,[int]$Color=$C_GOLD)
  $sh = $Slide.Shapes.AddShape(9,$L,$T,$D,$D)
  $sh.Fill.Solid(); $sh.Fill.ForeColor.RGB = $Color; $sh.Line.Visible = $msoFalse
  return $sh
}

# =====================================================================
# SLIDE 1 - four screens, one slide
# =====================================================================
$s1 = New-Slide 1

# ---- left brand column ----
$lx = 32.0
$s1.Shapes.AddPicture($Logo, $msoFalse, $msoTrue, $lx, 40, 236, (236*965.0/1529.0)) | Out-Null

Add-Box $s1 ($lx+4) 206 300 46 '48 GAMES' 'Arial Black' 42 $true $C_GOLD 1 1 | Out-Null
Add-Box $s1 ($lx+4) 254 300 26 'ON ONE CABINET' 'Arial Black' 19 $true $C_WHITE 1 1 | Out-Null
Add-Box $s1 ($lx+4) 292 292 44 ('Each built-in cabinet app carries its own game set, plus 20 more in EXTRA GAMES ' + $EMD + ' no duplicates.') 'Calibri' 12.5 $false $C_MUTED 1 1 1.05 | Out-Null

# NB: in PowerShell the comma binds tighter than +, so each element needs its own parens
$chips = @(
  ('Boots straight into the menu'),
  ('Player 1 ' + $PLUS + ' Player 2 on every game'),
  ('Software only ' + $EMD + ' nothing opened up')
)
$cy = 356.0
foreach ($c in $chips) {
  Add-Dot $s1 ($lx+6) ($cy+6) 7 $C_RED | Out-Null
  Add-Box $s1 ($lx+22) $cy 274 30 $c 'Calibri' 12.5 $false $C_TEXT 1 1 1.0 | Out-Null
  $cy += 34
}

# ---- 2x2 grid ----
$gx = 356.0; $cw = 280.0; $ch = 210.0; $gapx = 12.0
$col = @($gx, ($gx+$cw+$gapx))
$hdrY = 38.0; $r1 = 62.0; $capH = 14.0; $r2 = 292.0

Add-Box $s1 $col[0] $hdrY $cw 20 'MARVEL VS. CAPCOM 2 CABINET' 'Arial Black' 12.5 $true $C_WHITE 1 1 | Out-Null
Add-Box $s1 $col[1] $hdrY $cw 20 ('X-MEN ' + $APO + '97 CABINET') 'Arial Black' 12.5 $true $C_WHITE 1 1 | Out-Null

Add-Shot $s1 $SHOT_MVC2_HOME  $col[0] $r1 $cw $ch $C_RED  | Out-Null
Add-Shot $s1 $SHOT_XMEN_HOME  $col[1] $r1 $cw $ch $C_GOLD | Out-Null
Add-Shot $s1 $SHOT_MVC2_EXTRA $col[0] $r2 $cw $ch $C_RED  | Out-Null
Add-Shot $s1 $SHOT_XMEN_EXTRA $col[1] $r2 $cw $ch $C_GOLD | Out-Null

Add-Box $s1 $col[0] ($r1+$ch+4) $cw $capH 'MAIN MENU' 'Calibri' 10.5 $true $C_DIM 1 1 | Out-Null
Add-Box $s1 $col[1] ($r1+$ch+4) $cw $capH 'MAIN MENU' 'Calibri' 10.5 $true $C_DIM 1 1 | Out-Null
Add-Box $s1 $col[0] ($r2+$ch+4) $cw $capH 'EXTRA GAMES' 'Calibri' 10.5 $true $C_DIM 1 1 | Out-Null
Add-Box $s1 $col[1] ($r2+$ch+4) $cw $capH 'EXTRA GAMES' 'Calibri' 10.5 $true $C_DIM 1 1 | Out-Null

# =====================================================================
# helper for the two-up slides
# =====================================================================
function Build-TwoUp {
  param([int]$Index,[string]$Title,[string]$Sub,[string]$LeftShot,[string]$RightShot,
        [string]$LeftCap,[string]$RightCap,[string]$Footer)
  $s = New-Slide $Index
  $s.Shapes.AddPicture($Logo, $msoFalse, $msoTrue, 34, 22, 150, (150*965.0/1529.0)) | Out-Null
  Add-Box $s 206 30 700 34 $Title 'Arial Black' 28 $true $C_WHITE 1 1 | Out-Null
  Add-Box $s 208 68 700 22 $Sub 'Calibri' 14.5 $true $C_GOLD 1 1 | Out-Null

  $w = 435.0; $h = $w * 3.0 / 4.0
  $x1 = 36.0; $x2 = 960.0 - 36.0 - $w
  $y  = 128.0
  Add-Shot $s $LeftShot  $x1 $y $w $h $C_RED  | Out-Null
  Add-Shot $s $RightShot $x2 $y $w $h $C_GOLD | Out-Null
  Add-Box $s $x1 ($y+$h+8) $w 18 $LeftCap  'Arial Black' 12.5 $true $C_TEXT 2 1 | Out-Null
  Add-Box $s $x2 ($y+$h+8) $w 18 $RightCap 'Arial Black' 12.5 $true $C_TEXT 2 1 | Out-Null
  Add-Box $s 36 ($y+$h+38) 888 20 $Footer 'Calibri' 13 $false $C_MUTED 2 1 | Out-Null
  return $s
}

$s2 = Build-TwoUp 2 'THE TWO CABINETS' ('Same soft mod, same menu ' + $EMD + ' art to match the cabinet') `
      $SHOT_MVC2_HOME $SHOT_XMEN_HOME 'MARVEL VS. CAPCOM 2' ('X-MEN ' + $APO + '97') `
      ('Every built-in cabinet keeps its own game set  ' + $MID + '  EXTRA GAMES adds 20 more  ' + $MID + '  48 unique games in all')

$s3 = Build-TwoUp 3 '20 EXTRA GAMES' 'Capcom, SNK and Midway boards, on either cabinet' `
      $SHOT_MVC2_EXTRA $SHOT_XMEN_EXTRA 'MARVEL VS. CAPCOM 2' ('X-MEN ' + $APO + '97') `
      ('Street Fighter Alpha 1-3  ' + $MID + '  SF III New Generation / 2nd Impact / 3rd Strike  ' + $MID + '  Red Earth  ' + $MID + '  Cyberbots  ' + $MID + '  The Punisher  ' + $MID + '  Power Stone  ' + $MID + '  Guilty Gear X  ' + $MID + '  KOF ' + $APO + '98  ' + $MID + '  Garou  ' + $MID + '  Real Bout  ' + $MID + '  Samurai Shodown V  ' + $MID + '  SVC Chaos  ' + $MID + '  Mortal Kombat 1-3 ' + $PLUS + ' UMK3')

# =====================================================================
if (Test-Path $PptOut) { Remove-Item $PptOut -Force }
$pres.SaveAs($PptOut, 24)
foreach ($p in @($Png4,$PngCab,$PngExt)) { if (Test-Path $p) { Remove-Item $p -Force } }
$s1.Export($Png4,  'PNG', 1920, 1080)
$s2.Export($PngCab,'PNG', 1920, 1080)
$s3.Export($PngExt,'PNG', 1920, 1080)
$pres.Close()
$ppt.Quit()
"OK"
