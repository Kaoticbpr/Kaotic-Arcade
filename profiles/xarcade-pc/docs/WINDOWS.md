# Windows 11 setup

> The installer is `profiles/xarcade-pc/install/windows/Setup.cmd` in this repo.

The `windows/` folder is a complete, one-click installer. Full instructions: [windows/README.txt](../windows/README.txt).

## In short
1. Download/clone the kit, open the `windows` folder, double-click **Setup.cmd**
   (if Windows says "Windows protected your PC": More info → Run anyway; allow the Visual C++ install).
2. It installs Visual Pinball X 10.8.1 + ES-DE into `C:\Pinball` and puts three shortcuts on the desktop:
   - **Start Pinball** – the ES-DE game menu
   - **Pinball Table Installer** – drag a table's downloads in, check the name, press INSTALL TABLE
   - **Pinball Display Mode** – switch between a sideways (landscape) and upright (portrait) TV
3. Add tables from [TABLES.md](../TABLES.md).

## Same as the Bazzite build
- Graphics: SMAA anti-aliasing, screen-space reflections, no supersampling, FPS counter off
- Black DMD (unlit dots off + black DMD glass)
- Backglass + DMD placed next to the table; table cameras are never changed (portrait mode uses each table's own
  cabinet view)

## Different on Windows
- **Haptic kit:** VPX can send table sounds to a second sound device by itself – see [HAPTICS.md](HAPTICS.md#windows).
  The filtered haptics for other pinball games and the loudness leveler are Linux-only.
- **Linux script fixes** ([LINUX-FIXES.md](LINUX-FIXES.md)) are not needed – Windows runs table scripts natively.
  The volume tips (machine volume via the coin door, per-table gain) apply to both.
