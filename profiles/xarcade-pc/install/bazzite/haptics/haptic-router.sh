#!/bin/bash
# Moves pinball games' audio to the "Pinball Game (haptic)" output so the pedestal haptic kit feels them.
# Games listed by their PipeWire application.name. Run by arcade-haptic-lp.service.
GAMES='(?i)^Pinball Wicked$|zaccaria'
while true; do
  pactl -f json list sink-inputs 2>/dev/null | python3 -c '
import json,sys,re
g=re.compile(sys.argv[1])  # case-insensitive via (?i)
for s in json.load(sys.stdin):
    n=s.get("properties",{}).get("application.name","")
    if g.search(n): print(s["index"], s["sink"])' "$GAMES" | while read idx sink; do
    tgt=$(pactl list short sinks | awk '$2=="pinball_game_haptic"{print $1}')
    [ -n "$tgt" ] && [ "$sink" != "$tgt" ] && pactl move-sink-input "$idx" pinball_game_haptic
  done
  sleep 2
done
