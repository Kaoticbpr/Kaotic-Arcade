# Profile: iconic-sf2-pi5

Iconic Street Fighter II arcade cabinet with a Raspberry Pi 5 inside.
Claude Code manages it **over SSH from a local machine** on the same network
(cloud sessions cannot reach the home LAN).

## Status

Scaffold only — the cabinet has not been inspected yet. Everything below assumes
**Batocera**. On first connect, confirm the OS and update this file
(see "First connection checklist").

## Connection

- Settings live in `host.env` (copied from `host.env.example`; git-ignored).
- Use key-based SSH: `ssh "$CAB_USER@$CAB_HOST"`. Never store passwords in the repo.
- Batocera ships with `root` / `linux` — change that password on first login.

## Device layout (Batocera)

| What | Path |
|---|---|
| ROMs | `/userdata/roms/<system>/` |
| Game lists | `/userdata/roms/<system>/gamelist.xml` |
| BIOS | `/userdata/bios/` |
| Saves | `/userdata/saves/` |
| Main config | `/userdata/system/batocera.conf` |
| RetroArch overrides | `/userdata/system/configs/retroarch/` |

If the cabinet runs RetroPie instead: ROMs in `~/RetroPie/roms/<system>/`,
game lists in `~/.emulationstation/gamelists/<system>/gamelist.xml`.

## Rules when working on the cabinet

1. **Back up before editing.** Pull any device file you'll change into
   `backups/<YYYY-MM-DD>/` first (backups are git-ignored).
2. **Edit locally, then deploy.** Curated files live in this profile
   (`gamelists/`, `emulators/`, `controls/`); push them with `rsync`/`scp`.
3. **Stop EmulationStation before writing `gamelist.xml`.** It rewrites the file
   on exit and will clobber changes. On Batocera: `batocera-es-swissknife --emukill`
   then `/etc/init.d/S31emulationstation stop`; start it again afterwards.
4. **Ask before** OS upgrades (`batocera-upgrade`), deleting ROMs, or reboots.
5. Don't commit ROMs, BIOS files, or scraped media — only configs and lists.

## Goals for this cabinet

- Street Fighter / fighting-game focused lineup (CPS1/CPS2/CPS3, Neo Geo,
  Naomi/Atomiswave via Flycast).
- 1 frame of run-ahead on CPS/Neo Geo cores to cut input lag.
- Clean, curated game list (no duplicates, clones hidden, favorites set).

## First connection checklist

- [ ] Find the cabinet's IP/hostname; fill in `host.env`
- [ ] Confirm OS + version (`cat /usr/share/batocera/batocera.version` or `/etc/os-release`)
- [ ] Change default password; install SSH key
- [ ] Back up `batocera.conf` and all `gamelist.xml` files into `backups/`
- [ ] Inventory systems and ROM counts (`ls /userdata/roms/*/ | wc -l` per folder)
- [ ] Record control panel layout / encoder type in `controls/README.md`
- [ ] Update this file with what was found
