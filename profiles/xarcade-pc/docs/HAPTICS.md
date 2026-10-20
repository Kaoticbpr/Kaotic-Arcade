# Haptic kit (feel the flippers and bumpers)

A bass shaker / tactile transducer bolted into the cabinet or pedestal, driven by a small amplifier from the PC's
**headphone jack**. You *feel* every flipper, bumper, sling and drain while the TV plays the full sound.

## Hardware
- Bass shaker (e.g. Dayton Audio BST-1, Aura Pro) – screw it to the pedestal/cabinet frame, not to a panel that rattles.
- Small amplifier (e.g. Fosi / Dayton mini amp) + 3.5 mm cable from the PC's headphone jack.
- Turn the amp's own volume to about half to start.

## How the audio is routed (Bazzite, `install.sh --haptics`)
```
Visual Pinball X ──(table/mechanical sounds)──► "Pinball Playfield" ──► TV  +  haptic kit
                 ──(ROM music + voices)───────────────────────────────► TV only

Pinball Wicked / Zaccaria ──► "Pinball Game (haptic)" ──► TV (full sound)
                                                       └► low-pass 80 Hz ► +12 dB ► limiter ► haptic kit
```
- **VPX** already separates mechanical sounds from music, so its haptics are clean: VPX setting
  `Player.SoundDevice = Pinball Playfield` (the installer sets it).
- **Other pinball games** mix everything into one stream, so the haptic kit gets a filtered copy: 80 Hz steep low-pass
  (voices are cut), +12 dB boost, then a saturating limiter (CAPS *CompressX2*) so loud tables don't clip.
- A small service moves those games' sound to the haptic output within ~2 s of starting.
  Add games in `~/.config/arcade-haptic-games` – one regular expression matched against the game's PipeWire
  name (see it while the game runs: `pactl list sink-inputs | grep application.name`). Default:
  ```
  (?i)^Pinball Wicked$|zaccaria
  ```

## Tuning (edit `~/Emulation/tools/arcade-haptic-lp.conf`, then `systemctl --user restart arcade-haptic-lp`)
| Problem | Change |
|---|---|
| Voices / music buzz in the shaker | lower `"Freq" = 80.0` (all 8 lines) to 70 |
| Thumps too weak | raise `"Mult" = 4.0` (gL/gR) – 4.0 = +12 dB |
| Rattling / clipping on loud tables | lower the limiter `"threshold"` (0.15 → 0.10) or `Mult` |
| Haptics for VPX too strong/weak | the amp's volume knob (VPX's output isn't filtered or boosted) |

Turn it off for non-VPX games: `systemctl --user disable --now arcade-haptic-lp`.

## Windows
VPX on Windows can send table sounds to a second sound device by itself:
F12 (or VPX's video/audio options) → **Playfield sound device** = your second output (USB sound card or the headphone jack
if it is a separate device). For a TV + shaker split of one device, use a virtual mixer such as Voicemeeter.
The filtered routing for other games is Linux-only in this kit.
