#!/bin/bash
cd ~/pinball-portrait
~/Applications/VPinballX/VPinballX_BGFX -ini base.ini -tableini "$1" -play "$2" > "$3.log" 2>&1 &
sleep 50
gamescopectl screenshot "$HOME/pinball-portrait/$3.png"
sleep 5
kill %1
