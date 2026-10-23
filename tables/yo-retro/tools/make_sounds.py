#!/usr/bin/env python3
"""Synthesize the table's sound effects into sounds/ (16-bit mono WAV, 44.1 kHz).

    python3 tools/make_sounds.py

Everything is generated from noise, damped resonances and square waves, so there is nothing to
license. Mechanical sounds (flippers, bumpers, targets, ...) aim for a real machine; the stingers under
the host callouts are 8-bit chiptune to fit the retro theme. Names are the ones the script plays
(see the sound effects table in DESIGN.md). Re-run after changing a recipe; the build picks the files up.
"""
import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, sosfilt

TABLE = Path(__file__).resolve().parent.parent
OUT = TABLE / "sounds"
RATE = 44100
rng = np.random.default_rng(1984)    # fixed seed: the same files every run


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(seconds, attack=0.002, decay=0.1):
    x = t(seconds)
    return np.minimum(x / attack, 1.0) * np.exp(-x / decay)


def noise(seconds):
    return rng.uniform(-1, 1, int(RATE * seconds))


def band(x, low, high, order=2):
    return sosfilt(butter(order, [low, high], btype="band", fs=RATE, output="sos"), x)


def lowpass(x, cutoff, order=2):
    return sosfilt(butter(order, cutoff, btype="low", fs=RATE, output="sos"), x)


def highpass(x, cutoff, order=2):
    return sosfilt(butter(order, cutoff, btype="high", fs=RATE, output="sos"), x)


def ring(seconds, freqs, decay):
    """Damped inharmonic partials: metal posts, coils, the cabinet."""
    x = t(seconds)
    return sum(np.sin(2 * np.pi * f * x + i) * np.exp(-x / (decay / (1 + 0.4 * i))) / (1 + i)
               for i, f in enumerate(freqs))


def thump(seconds, f0, f1, decay):
    """A pitched body hit that falls from f0 to f1 Hz: solenoids, the ball landing."""
    x = t(seconds)
    freq = f1 + (f0 - f1) * np.exp(-x / 0.02)
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-x / decay)


def click(seconds=0.03, low=2000, high=9000, decay=0.004):
    return band(noise(seconds), low, high) * env(seconds, 0.0003, decay)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def delay(x, seconds):
    return np.concatenate([np.zeros(int(RATE * seconds)), x])


# ---------------------------------------------------------------- chiptune

NOTES = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}


def hz(note):
    name, octave = note[:-1], int(note[-1])
    return 440.0 * 2 ** ((NOTES[name] + 12 * (octave - 4)) / 12)


def square(freq, seconds, duty=0.5, decay=0.25):
    x = t(seconds)
    wave_ = np.where((x * freq) % 1.0 < duty, 1.0, -1.0)
    return wave_ * np.minimum(x / 0.003, 1.0) * np.exp(-x / decay) * np.minimum((seconds - x) / 0.01, 1.0)


def triangle(freq, seconds, decay=0.4):
    x = t(seconds)
    return (2 * np.abs(2 * ((x * freq) % 1.0) - 1) - 1) * np.exp(-x / decay) * np.minimum((seconds - x) / 0.01, 1)


def tune(notes, step, duty=0.5, decay=0.25, bass=None):
    """notes: list of note names (or None for a rest), one every `step` seconds; bass: (note, seconds) pairs."""
    lead = np.concatenate([square(hz(n), step, duty, decay) if n else np.zeros(int(RATE * step)) for n in notes])
    if not bass:
        return lead
    low = np.concatenate([triangle(hz(n), s) for n, s in bass])
    return mix(lead * 0.7, low * 0.6)


# ---------------------------------------------------------------- recipes

def flipper_up():
    return mix(thump(0.25, 220, 90, 0.05) * 0.9, click(0.04, 1500, 7000, 0.006) * 0.8,
               ring(0.25, [610, 1450, 2380], 0.04) * 0.15)


def flipper_down():
    return mix(thump(0.15, 160, 80, 0.03) * 0.5, click(0.03, 1200, 5000, 0.004) * 0.4)


def flip_hit(pitch):
    return mix(ring(0.2, [900 * pitch, 2100 * pitch, 3300 * pitch], 0.035) * 0.5, click(0.03) * 0.6)


def bumper():
    return mix(thump(0.35, 260, 70, 0.07), click(0.05, 1800, 8000, 0.008) * 0.9,
               ring(0.35, [480, 1130, 1870, 2950], 0.09) * 0.35)


def slingshot(pitch):
    return mix(thump(0.25, 200 * pitch, 85, 0.05) * 0.9, click(0.04, 2200, 9000, 0.005),
               ring(0.25, [700 * pitch, 1600 * pitch], 0.05) * 0.2)


def drop_target():
    return mix(click(0.06, 900, 6000, 0.012) * 1.2, thump(0.15, 300, 140, 0.03) * 0.5)


def drop_reset():
    return mix(thump(0.35, 180, 60, 0.08), click(0.06, 600, 4000, 0.02),
               delay(click(0.04, 1500, 6000, 0.006) * 0.6, 0.03))


def standup():
    return mix(click(0.05, 1500, 8000, 0.008), ring(0.12, [1200, 2700], 0.02) * 0.3)


def spinner():
    return mix(click(0.03, 3000, 10000, 0.003) * 0.7, ring(0.05, [2600, 4100], 0.008) * 0.25)


def ramp_enter():
    x = t(0.6)
    roll = band(noise(0.6), 150, 900) * np.minimum(x / 0.08, 1) * np.exp(-x / 0.25)
    return mix(roll * 1.4, click(0.04, 800, 3000, 0.008) * 0.6)


def kicker_enter():
    return mix(thump(0.3, 140, 55, 0.06), click(0.05, 400, 2500, 0.015) * 0.7)


def kicker_eject():
    return mix(thump(0.3, 240, 70, 0.06), click(0.05, 1500, 7000, 0.008), ring(0.3, [520, 1240], 0.06) * 0.25)


def plunger_pull():
    x = t(0.6)
    creak = band(noise(0.6), 2500, 6000) * 0.25 * np.minimum(x / 0.2, 1) * np.exp(-x / 0.4)
    spring = ring(0.6, [330, 680], 0.3) * 0.12 * (1 + np.sin(2 * np.pi * 9 * x)) / 2
    return mix(creak, spring)


def plunger_release():
    return mix(thump(0.35, 180, 60, 0.06), ring(0.5, [260, 540, 1210], 0.12) * 0.35, click(0.04, 1500, 8000, 0.006))


def ball_release():
    return mix(click(0.05, 600, 3500, 0.012) * 0.8, delay(thump(0.2, 150, 90, 0.04) * 0.5, 0.05))


def drain():
    return mix(thump(0.45, 120, 45, 0.12) * 1.1, lowpass(noise(0.45), 400) * env(0.45, 0.005, 0.1) * 0.8,
               delay(click(0.04, 300, 1500, 0.01) * 0.4, 0.12))


def stinger_start():
    return tune(["C5", "E5", "G5", "C6", None, "G5", "C6"], 0.07, decay=0.12,
                bass=[("C3", 0.28), ("G3", 0.21)])


def stinger_skillshot():
    return tune(["G5", "C6", "E6", "G6", "C7"], 0.06, duty=0.25, decay=0.15)


def stinger_jackpot():
    return tune(["C5", "E5", "G5", "C6", "E6", "G6", "C7", None, "C7", "C7"], 0.065, decay=0.2,
                bass=[("C3", 0.26), ("G3", 0.26), ("C4", 0.13)])


def stinger_extraball():
    return tune(["E5", "G5", "E6", "C6", "D6", "G6"], 0.09, duty=0.25, decay=0.3,
                bass=[("C3", 0.27), ("G3", 0.27)])


def stinger_lock():
    return tune(["G4", "D5", "G5", None, "G5"], 0.08, decay=0.15, bass=[("G2", 0.4)])


def stinger_multiball():
    return tune(["C5", "C5", "G5", "G5", "A#5", "A#5", "C6", None, "C6", "G5", "C6", "E6"], 0.075, decay=0.15,
                bass=[("C3", 0.3), ("C3", 0.3), ("G2", 0.3)])


def stinger_modestart():
    return tune(["A4", "C5", "E5", "A5"], 0.08, duty=0.25, decay=0.2, bass=[("A2", 0.32)])


def stinger_modecomplete():
    return tune(["C5", "G5", "C6", None, "D6", "E6", "C6"], 0.08, decay=0.22,
                bass=[("C3", 0.32), ("G3", 0.24)])


def stinger_warning():
    return tune(["A5", None, "A5"], 0.09, duty=0.5, decay=0.06)


def stinger_tilt():
    return tune(["E4", "D#4", "D4", "C#4", "C4"], 0.14, duty=0.5, decay=0.3, bass=[("C2", 0.7)])


SOUNDS = {
    "fx_flipperup": flipper_up, "fx_flipperdown": flipper_down,
    "flip_hit_1": lambda: flip_hit(1.0), "flip_hit_2": lambda: flip_hit(1.12), "flip_hit_3": lambda: flip_hit(0.9),
    "plungerpull": plunger_pull, "plunger": plunger_release, "ballrelease": ball_release, "drain": drain,
    "fx_bumper": bumper, "left_slingshot": lambda: slingshot(1.0), "right_slingshot": lambda: slingshot(1.06),
    "fx_droptarget": drop_target, "fx_resetdrop": drop_reset, "fx_target": standup, "fx_spinner": spinner,
    "fx_rampenter": ramp_enter, "fx_kicker_enter": kicker_enter, "fx_kicker": kicker_eject,
    "fx_start": stinger_start, "fx_skillshot": stinger_skillshot, "fx_jackpot": stinger_jackpot,
    "fx_extraball": stinger_extraball, "fx_lock": stinger_lock, "fx_multiball": stinger_multiball,
    "fx_modestart": stinger_modestart, "fx_modecomplete": stinger_modecomplete,
    "fx_warning": stinger_warning, "fx_tilt": stinger_tilt,
}
# Stingers play under the host callouts, so they sit lower than the mechanical sounds.
LEVELS = {name: (0.45 if name.startswith("fx_") and recipe.__name__.startswith("stinger") else 0.9)
          for name, recipe in SOUNDS.items()}


def write(name, samples, peak):
    samples = highpass(samples, 30)                      # no DC or sub rumble
    samples = samples / (np.max(np.abs(samples)) or 1) * peak
    fade = min(len(samples), int(RATE * 0.005))
    samples[-fade:] *= np.linspace(1, 0, fade)           # no click at the end
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((samples * 32767).astype("<i2").tobytes())


def main():
    for name, recipe in SOUNDS.items():
        write(name, recipe(), LEVELS[name])
    print(f"wrote {len(SOUNDS)} sounds to sounds/")


if __name__ == "__main__":
    main()
