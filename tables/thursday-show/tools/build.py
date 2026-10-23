#!/usr/bin/env python3
"""Build the table: starter table + layout + script + art -> dist/<TABLE_FILE>.vpx

Needs vpxtool on the PATH (https://github.com/francisdb/vpxtool, or `cargo install vpxtool --locked`).

    python3 tools/build.py            # build dist/ThursdayShow.vpx
    python3 tools/build.py --no-pack  # only write build/expanded (handy for diffing)
"""
import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TABLE = HERE.parent
sys.path.insert(0, str(HERE))
import layout  # noqa: E402

TABLE_FILE = "ThursdayShow"          # rename once the show's name is final
TABLE_NAME = "Thursday Show (Original 2026)"
AUTHOR = "KaoticBPR"
VERSION = "0.1.0"

# Art the build picks up when present (see art/README.md). Missing files are fine.
ART = {
    "playfield": TABLE / "art" / "playfield.png",
}


def run(*cmd):
    print("+", " ".join(str(c) for c in cmd))
    subprocess.run([str(c) for c in cmd], check=True)


def write_script(expanded):
    parts = sorted((TABLE / "script").glob("*.vbs"))
    text = "\r\n".join(p.read_text().replace("\r\n", "\n").replace("\n", "\r\n") for p in parts)
    text = text.replace("@@VERSION@@", VERSION)
    (expanded / "script.vbs").write_text(text, newline="")


def write_info(expanded):
    info_path = expanded / "info.json"
    info = json.loads(info_path.read_text())
    info.update(table_name=TABLE_NAME, author_name=AUTHOR, table_version=VERSION,
                table_blurb="An original table based on a Thursday YouTube show.",
                table_description="Built from source in the Kaotic-Arcade repo (tables/thursday-show).")
    info_path.write_text(json.dumps(info, indent=2))


def add_art(expanded):
    gamedata_path = expanded / "gamedata.json"
    gamedata = json.loads(gamedata_path.read_text())
    images_path = expanded / "images.json"
    images = json.loads(images_path.read_text())
    playfield = ART["playfield"]
    if playfield.exists():
        (expanded / "images").mkdir(exist_ok=True)
        shutil.copy(playfield, expanded / "images" / "playfield.png")
        images.append({"name": "playfield", "path": "playfield.png", "alpha_test_value": -1.0,
                       "is_opaque": True})
        gamedata["image"] = "playfield"
        print("art: playfield.png added")
    else:
        print("art: no art/playfield.png yet, using the plain playfield")
    images_path.write_text(json.dumps(images, indent=2))
    gamedata_path.write_text(json.dumps(gamedata, indent=2))


def add_sounds(expanded):
    """Every sounds/<name>.wav|ogg|mp3 becomes a table sound the script can play by <name>."""
    files = [f for f in sorted((TABLE / "sounds").glob("*")) if f.suffix.lower() in (".wav", ".ogg", ".mp3")]
    sounds_path = expanded / "sounds.json"
    sounds = json.loads(sounds_path.read_text())
    if files:
        (expanded / "sounds").mkdir(exist_ok=True)
    for f in files:
        shutil.copy(f, expanded / "sounds" / f.name)
        sounds.append({"name": f.stem, "path": f.name, "internal_name": f.stem, "fade": 0, "volume": 0,
                       "balance": 0, "output_target": "table"})
    sounds_path.write_text(json.dumps(sounds, indent=2))
    print(f"sounds: {len(files)} added")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-pack", action="store_true", help="stop after writing build/expanded")
    args = ap.parse_args()

    build = TABLE / "build"
    expanded = build / "expanded"
    if build.exists():
        shutil.rmtree(build)
    shutil.copytree(TABLE / "base", expanded)

    names = layout.apply(expanded)
    print(f"layout: {len(names)} parts added")
    write_script(expanded)
    write_info(expanded)
    add_art(expanded)
    add_sounds(expanded)
    if args.no_pack:
        return

    vpxtool = shutil.which("vpxtool")
    if not vpxtool:
        sys.exit("vpxtool not found on PATH: install it from https://github.com/francisdb/vpxtool")
    dist = TABLE / "dist"
    dist.mkdir(exist_ok=True)
    out = dist / f"{TABLE_FILE}.vpx"
    run(vpxtool, "assemble", "-f", expanded, out)
    run(vpxtool, "verify", out)
    print(f"built {out}")


if __name__ == "__main__":
    main()
