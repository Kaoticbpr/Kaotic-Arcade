# Art

Sizes are set for the Legends 4KP running Legends Unchained (VPX standalone). Draw on top of the
templates in `templates/` (regenerate them with `python3 tools/render_layout.py` after layout changes).

## Files

`tools/make_art.py` builds the backglass and launcher from the show art in `yo retro vpx table assets/`
(gitignored), and the build copies both into `dist/` for the Table Manager.

| File | Size | Where it shows | Notes |
|---|---|---|---|
| `playfield.png` | 1353 x 3072 | the playfield | The 4KP caps textures at 3072 px (`MaxTexDimension`). Keep the parts' outlines from `playfield_template_labelled_1353x3072.png`: holes, inserts and lanes must line up. Inserts are the coloured dots; leave them as lighter, see-through shapes so the lights glow through. The build picks this file up automatically. |
| `backglass.png` | 1920 x 1080 | backglass screen | **Made** by `tools/make_art.py`: the pixel-art hosts and logo on a synthwave backdrop. The loading image in the Table Manager; it can also become the `.directb2s` backglass. |
| `launcher.png` | 640 x 960 | Legends launcher menu | **Made** by `tools/make_art.py`, same style. Required by Legends Unchained. |
| `dmd.png` | 1920 x 480 (4:1) | DMD screen while loading | Optional. The in-game DMD is drawn by the script. |
| plastics | later | | Once the playfield is in, so they match. |

## Art brief: cartoon KaoticBPR and Half-A-Dozen

One consistent cartoon style for both hosts across every piece. A character sheet first (front, 3/4,
a few expressions: hyped, shocked, laughing, judging) makes everything after it faster and keeps
them on-model. Faces from the sheet can later become DMD animations too.

| Piece | Idea |
|---|---|
| Backglass | The hero shot: both hosts at the Yo! Retro review desk, a pinball machine between them, big Yo! Retro logo across the top. K hyped and pointing, H holding a scorecard. |
| Playfield, lower centre | The open area between the segment inserts and the flippers (roughly y 1150 to 1450 on the template) is the best spot for big art: the two hosts, or the logo. Nothing there blocks the ball. |
| Playfield, segment inserts | The five purple inserts in an arc below the scoop are the segments. Label each one: UNBOXING, FIRST FLIPS, CHAT ATTACK, BUG HUNT, THE VERDICT. |
| Playfield, shots | Small labels or icons at each shot: ramp "UNBOX", orbits "FIRST FLIPS", drop targets "BUG HUNT" (cartoon bugs), spinner "VERDICT", scoop "GO LIVE". |
| Sling plastics | K's face on one slingshot, H's on the other. |
| Launcher | Logo plus both hosts, shoulders up. Reads at a small size. |
| Colours | Retro: neon magenta, cyan, yellow on dark purple works well with the purple and blue inserts. Change the inserts to match, if not. |

## Rights

Only use art you made, commissioned or have rights to share: the table will be published. Keep
AtGames' logos and other companies' table art off the table. Saying "we review AtGames tables" is
fine, but their branding on a free table invites trouble.
