#!/bin/bash
# Writes the X-Arcade Arcade2TV-XR pinball-mode (purple) layout into VPinballX.ini for this Linux mini PC.
# VPX only auto-detects the Arcade2TV-XR by its Windows controller ID; on Linux the X-Arcade reports
# 030081b8..., and Linux numbers the Guide/stick-click buttons differently (Win 8/9/10 -> Linux 9/10/8).
# Pad 1 (USB interface 1.0) carries the pinball controls; pad 2 is idle in purple mode.
# Measured in purple mode: left joystick = d-pad/hat (256 L, 257 R, 258 U, 259 D) -> nudge like Pinball FX;
# right joystick Y (516) = plunger; left-stick axes 512/513 = the X-Arcade's bump accelerometer -> VPX
# "Game Controller" nudge (type 0) at scale 1.0: VPX only fires a nudge above 1 m/s^2 (value*strength*g/2),
# so VPX's own Arcade2TV default scale 0.2 could never trigger. Dead zone 0.05 hides the resting jitter (~0.02).
# In VPX's menus the joystick moves/changes items (not the bump sensor).
# User's choice: coin = P2 X (button 6, Back), start = P2 Start (7), exit = hold P2 X + P2 Start
# (same Back+Start exit combo as the other emulators; a short tap opens VPX's menu, held ~2 s it closes VPX).
# NoAutoLayout stops VPX asking "use the default layout?" for the X-Arcade pads and the guitar.
# Only run while VPX is closed (it rewrites its settings on exit).
XB=$("$(dirname "$0")/xarcade-vpx-id.sh")     # changes with X-Arcade firmware
D="${XB}_1"
D2="${XB}_2"
GTR="SDLJoy_0300cc8e510300000020000005010000_1"
python3 "$HOME/Emulation/tools/scripts/vpxset.py" \
  "Input::Devices=Key;$D" "Input::Device.$D.Name=Arcade2TV-XR #1" "Input::Device.$D.Type=2" "Input::Device.$D.NoAutoLayout=1" \
  "Input::Device.$D2.Name=Arcade2TV-XR #2 (idle)" "Input::Device.$D2.Type=2" "Input::Device.$D2.NoAutoLayout=1" \
  "Input::Device.$GTR.Name=CRKD LP Black Tribal" "Input::Device.$GTR.Type=2" "Input::Device.$GTR.NoAutoLayout=1" \
  "Input::Mapping.LeftFlipper=Key;225 | $D;4"        "Input::Mapping.LeftStagedFlipper=Key;225 | $D;4" \
  "Input::Mapping.RightFlipper=Key;229 | $D;5"       "Input::Mapping.RightStagedFlipper=Key;229 | $D;5" \
  "Input::Mapping.LeftMagna=Key;224 | $D;2"          "Input::Mapping.RightMagna=Key;228 | $D;9" \
  "Input::Mapping.Credit1=Key;34 | $D;6"             "Input::Mapping.Start=Key;30 | $D;7" \
  "Input::Mapping.LaunchBall=Key;40 | $D;10"         "Input::Mapping.ExitGame=Key;41 | $D;6 & $D;7" \
  "Input::Mapping.VolumeUp=Key;46"                   "Input::Mapping.VolumeDown=Key;45" \
  "Input::Mapping.InGameUI=Key;69" \
  "Input::Mapping.LeftNudge=Key;29 | $D;256"         "Input::Mapping.RightNudge=Key;56 | $D;257" \
  "Input::Mapping.CenterNudge=Key;44 | $D;258 | $D;259" \
  "Input::Mapping.UIUp=Key;224 | $D;258"             "Input::Mapping.UIDown=Key;228 | $D;259" \
  "Input::Mapping.UILeft=Key;225 | $D;256"           "Input::Mapping.UIRight=Key;229 | $D;257" \
  "Input::PlungerSensorCount=1" "Input::Mapping.Plunger0.Position=$D;516;P;0;1;1" \
  "Input::NudgeSensorCount=1" "Input::Mapping.Nudge0.Type=0" "Input::Mapping.Nudge0.Strength=1" \
  "Input::Mapping.Nudge0.X=$D;512;A;0.05;1;1" "Input::Mapping.Nudge0.Y=$D;513;A;0.05;1;1" \
  "Input::Mapping.Nudge0.AccX=" "Input::Mapping.Nudge0.AccY="
