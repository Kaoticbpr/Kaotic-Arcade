#!/bin/bash
# Prints the X-Arcade's current Visual Pinball device id base (without _1/_2).
# The id embeds the controller's USB firmware version, so a firmware update changes it (3.40 -> 3.42 did).
# Source: the newest "VPX UID" VPX logged for an Xbox-360-type pad; fallback = the id seen with firmware 3.42.
LOG="$HOME/.local/share/VPinballX/10.8/vpinball.log"
ID=$(grep -oE 'VPX UID: SDLJoy_030081b85e0400008e02[0-9a-f]{12}_1' "$LOG" 2>/dev/null | tail -1 | sed 's/^VPX UID: //; s/_1$//')
echo "${ID:-SDLJoy_030081b85e0400008e02000042030000}"
