# Art

Sizes are set for the Legends 4KP running Legends Unchained (VPX standalone). Draw on top of the
templates in `templates/` (regenerate them with `python3 tools/render_layout.py` after layout changes).

| File | Size | Where it shows | Notes |
|---|---|---|---|
| `playfield.png` | 1353 x 3072 | the playfield | The 4KP caps textures at 3072 px (`MaxTexDimension`). Keep the parts' outlines from `playfield_template_labelled_1353x3072.png`: holes, inserts and lanes must line up. Inserts are the coloured dots; leave them as lighter, see-through shapes so the lights glow through. The build picks this file up automatically. |
| `backglass.png` | 1920 x 1080 | backglass screen | Becomes the `.directb2s` backglass, and the loading image in the Table Manager. |
| `launcher.png` | 640 x 960 | Legends launcher menu | Required by Legends Unchained. |
| `dmd.png` | 1920 x 480 (4:1) | DMD screen while loading | Optional. The in-game DMD is drawn by the script. |
| plastics | later | | Once the playfield is in, so they match. |

PNG is best. Only use art you made, commissioned or have rights to share: the table will be published.
