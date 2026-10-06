# Iconic SF2 cabinet (Raspberry Pi 5)

Profile for the Iconic Street Fighter II cabinet. See `CLAUDE.md` for device
details and working rules.

```
iconic-sf2-pi5/
├── CLAUDE.md          # device facts + rules Claude Code follows here
├── host.env.example   # copy to host.env and fill in (git-ignored)
├── controls/          # button/encoder mappings
├── emulators/         # batocera.conf / RetroArch overrides
├── gamelists/         # curated gamelist.xml per system (gamelists/<system>/gamelist.xml)
└── backups/           # local snapshots pulled from the cabinet (git-ignored)
```

## Getting started

```sh
cp host.env.example host.env    # fill in host/user
source host.env
ssh-copy-id "$CAB_USER@$CAB_HOST"
ssh "$CAB_USER@$CAB_HOST" 'cat /usr/share/batocera/batocera.version'
```

Then open Claude Code in this folder and work through the
"First connection checklist" in `CLAUDE.md`.
