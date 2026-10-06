# Profile: xarcade-pc

X-Arcade Arcade2TV-XR setup driven by a Windows, Linux or Mac computer, using
EmulationStation for arcade/console games and Visual Pinball X (VPX) standalone
for pinball. This is a separate mod from the `iconic-sf2-pi5` cabinet.

## Status

Scaffold only — nothing has been inspected yet. On first use, fill in
`machine.env` and update this file with what was found
(see "First setup checklist").

## Connection

Unlike the Pi cabinet, Claude Code usually runs **directly on the host
computer**, so no SSH is needed. If the host is a separate machine, record its
SSH details in `machine.env` (git-ignored) and use key-based login.

## Host layout (ES-DE defaults — confirm on the machine)

| What | Linux / Mac | Windows |
|---|---|---|
| ES-DE data | `~/ES-DE/` | `%USERPROFILE%\ES-DE\` (or portable folder) |
| ROMs | `~/ROMs/<system>/` | `%USERPROFILE%\ROMs\<system>\` |
| Game lists | `~/ES-DE/gamelists/<system>/gamelist.xml` | same, under `ES-DE\` |
| VPX tables | set in `machine.env` | set in `machine.env` |
| VPX config | `~/.vpinball/VPinballX.ini` | next to the VPX executable or in `%APPDATA%` (varies by version) |

If a different frontend or layout is in use, replace this table.

## Rules when working on this setup

1. **Back up before editing.** Copy any file you'll change into
   `backups/<YYYY-MM-DD>/` first (git-ignored).
2. **Curated files live in this profile** (`gamelists/`, `emulators/`,
   `controls/`, `vpx/`) and are copied to the host from here.
3. **Close ES-DE before writing `gamelist.xml`** — it rewrites the file on exit.
4. **Keep scripts cross-platform** where practical (Windows, Linux, Mac);
   if a script is OS-specific, say so in its name or header.
5. **Ask before** installing/upgrading software, deleting games or tables.
6. Don't commit ROMs, BIOS files, VPX tables, or scraped media — only configs
   and lists.

## Controls

The X-Arcade has a mode switch; its default mode acts as a **keyboard**, so
every button arrives as a key press. Record the active mode and the full key
map in `controls/README.md` before configuring emulators or VPX — every config
in this profile depends on it.

## Goals

- One seamless setup: ES-DE launches both emulated games and VPX tables.
- Consistent X-Arcade mappings across ES-DE, RetroArch and VPX
  (flippers, nudge, plunger, start/coin, exit).
- Clean, curated game and table lists.

## First setup checklist

- [ ] Record host OS, frontend and versions (ES-DE, RetroArch, VPX)
- [ ] Copy `machine.env.example` to `machine.env` and fill in paths
- [ ] Back up ES-DE settings, gamelists and VPX config into `backups/`
- [ ] Record X-Arcade mode + key map in `controls/README.md`
- [ ] Inventory systems, ROM counts and VPX tables
- [ ] Update this file with what was found
