#!/bin/bash
# Arcade loudness leveler: runs the PipeWire filter in ~/Emulation/tools/arcade-leveler.conf only while
# ES-DE is open. It's a WirePlumber smart filter, so game sound passes through it automatically and goes
# straight back to the TV speaker the moment it stops. Paused while a guitar game (keeps their timing)
# or Visual Pinball (tables have their own sound mix; the fast stage ducked music on every flipper hit) runs.
# Started by ~/.local/bin/arcade-env.sh through arcade-leveler.service.
CONF="$HOME/Emulation/tools/arcade-leveler.conf"
GUITAR='[c]lonehero|[Y]ARG|[G]HWT_Definitive|[V]PinballX'   # guitar games + Visual Pinball (tables have their own sound balance)
PW=
start() { [ -n "$PW" ] && kill -0 "$PW" 2>/dev/null && return; pipewire -c "$CONF" >/dev/null 2>&1 & PW=$!; }
stop()  { [ -n "$PW" ] && { kill "$PW" 2>/dev/null; wait "$PW" 2>/dev/null; }; PW=; }
trap stop EXIT
trap 'exit 0' TERM INT
for _ in $(seq 60); do pgrep -x es-de >/dev/null && break; sleep 1; done     # wait for ES-DE to come up
while pgrep -x es-de >/dev/null; do
  if pgrep -f "$GUITAR" >/dev/null; then stop; else start; fi
  sleep 3
done
