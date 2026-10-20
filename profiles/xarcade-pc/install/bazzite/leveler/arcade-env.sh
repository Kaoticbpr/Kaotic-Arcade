#!/bin/bash
# Steam launch-option wrapper for ES-DE ("arcade-env.sh %command%").
# EmuDeck rewrites its launchers on every game start, so anything that must survive lives here instead.
export SDL_GAMECONTROLLER_IGNORE_DEVICES="${SDL_GAMECONTROLLER_IGNORE_DEVICES:+$SDL_GAMECONTROLLER_IGNORE_DEVICES,}0x1430/0x4748,0x12ba/0x0100,0x0351/0x2000,0x0351/0x5500,0x0351/0x4161"  # hide CRKD guitar (PC + PS3 mode) from emulators
"$HOME/Emulation/tools/scripts/controls-guard.sh" >/dev/null 2>&1
python3 "$HOME/Emulation/tools/scripts/vpx-add.py" --apply-pending >/dev/null 2>&1   # pinball tables installed while a game was running
systemctl --user start arcade-leveler.service >/dev/null 2>&1   # even volume across games while ES-DE is open
python3 "$HOME/Emulation/tools/scripts/pinball-descriptions.py" >/dev/null 2>&1   # nicer pinball descriptions (only replaces the installer's generic line)
python3 "$HOME/Emulation/tools/scripts/esde-theme-for-mode.py" >/dev/null 2>&1   # portrait mode -> Kaotic Arcade theme, landscape -> CoinOPS
exec "$@"
