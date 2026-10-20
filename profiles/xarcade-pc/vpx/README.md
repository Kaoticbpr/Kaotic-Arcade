# Visual Pinball X

- [`TABLES.md`](TABLES.md): every table on the arcade with download links and ROM names (no table files here).
- [`portrait/`](portrait): generates a portrait layout per table for a 1080x1920 screen: the backglass and DMD in a
  strip across the top, the playfield filling the rest. `overrides.json` holds the per-table tweaks
  (`VOfs`, `stretch_x`, `stretch_y`, `bg_off`, `dmd_off`, `bg_right`, `player_extra`), `apply_layout.py` applies one,
  `layout_test.py` renders a headless test frame with gamescope. Paths assume Bazzite + EmuDeck.
- Control mapping for the X-Arcade: see [`../controls/README.md`](../controls/README.md).
