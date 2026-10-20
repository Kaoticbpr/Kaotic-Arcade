package com.arcade.frontend;

/**
 * Static table of the RetroArch-hosted "Extra Games". Deliberately pure java.util/lang -- no
 * android.* here so it stays trivial to read -- but IS compiled against android.jar since it's
 * linked into the same dex as the Activities. Order here is grid order, row-major.
 */
final class GameRegistry {

    /**
     * Which button layout the game wants. This is the ONE source of truth for button mapping:
     * player 1 gets it from a RetroArch remap file, player 2 gets it from P2BridgeService,
     * and both are generated from this same choice.
     *
     * PROFILE_CPS   - the 6-button Capcom layout, which is also RetroArch's default, so it
     *                 needs no remap file at all.
     * PROFILE_ROW4  - games with 3 or 4 buttons (Neo Geo, Guilty Gear X, Power Stone,
     *                 Cyberbots). Their cores number buttons in retro order B, A, Y, X, which
     *                 lands the FIRST two functions on the BOTTOM row -- backwards to anyone
     *                 who knows these games. This profile lays them out in reading order:
     *                 1 2 3 across the top, 4 bottom-left.
     * PROFILE_MK    - Mortal Kombat. FBNeo's default puts High Kick top-middle and Block on
     *                 the shoulder, which is nothing like the real cabinet. Every MK panel
     *                 ever built reads HIGH PUNCH / BLOCK / HIGH KICK across the top and
     *                 LOW PUNCH / RUN / LOW KICK underneath, and muscle memory for Block in
     *                 the middle is the whole game -- so this profile restores it.
     */
    static final int PROFILE_CPS = 0;
    static final int PROFILE_ROW4 = 1;
    static final int PROFILE_MK = 2;

    /**
     * The SD card's mount point, for Dreamcast titles too large for internal storage. This is
     * the card's own volume ID, derived from its filesystem serial -- stable across reboots as
     * long as the same physical card stays inserted and unformatted, but it WOULD change if the
     * card were ever swapped or reformatted.
     */
    private static final String SD_ROMS = "/storage/48A9-166C/roms/";

    static final class Game {
        final String id;
        final String rom;
        final String core;     // "fbneo" or "flycast"
        final String tile;     // drawable name for the grid tile
        final String ctrl;     // drawable name for the control page
        final int profile;     // PROFILE_*
        final int coins;       // credits the board wants before Start does anything
        final String name;     // shown under the grid while this game is highlighted

        Game(String id, String rom, String core, String tile, String ctrl, int profile,
             int coins, String name) {
            this.id = id;
            this.rom = rom;
            this.core = core;
            this.tile = tile;
            this.ctrl = ctrl;
            this.profile = profile;
            this.coins = coins;
            this.name = name;
        }
    }

    /**
     * Grid order, grouped by family rather than by the order games were added: Capcom
     * fighters, then the rest of Capcom, then SNK, then Midway. Twenty games, five per row.
     */
    static final Game[] ALL = new Game[]{
        // --- Capcom: Street Fighter ---------------------------------------------------
        new Game("sfa",      "sfa.zip",      "fbneo",   "tile_sfa",      "ctrl_sfa",      PROFILE_CPS,  1, "Street Fighter Alpha"),
        new Game("sfa2",     "sfa2u.zip",    "fbneo",   "tile_sfa2",     "ctrl_sfa2",     PROFILE_CPS,  1, "Street Fighter Alpha 2"),
        new Game("sfa3",     "sfa3u.zip",    "fbneo",   "tile_sfa3",     "ctrl_sfa3",     PROFILE_CPS,  1, "Street Fighter Alpha 3"),
        new Game("sfiii",    "sfiii.zip",    "fbneo",   "tile_sfiii",    "ctrl_sfiii",    PROFILE_CPS,  1, "Street Fighter III: New Generation"),
        new Game("sfiii2",   "sfiii2.zip",   "fbneo",   "tile_sfiii2",   "ctrl_sfiii2",   PROFILE_CPS,  1, "Street Fighter III: 2nd Impact"),
        // --- Capcom: the rest ---------------------------------------------------------
        new Game("sfiii3",   "sfiii3.zip",   "fbneo",   "tile_sfiii3",   "ctrl_sfiii3",   PROFILE_CPS,  1, "Street Fighter III: 3rd Strike"),
        new Game("redearth", "redearth.zip", "fbneo",   "tile_redearth", "ctrl_redearth", PROFILE_CPS,  1, "Red Earth"),
        new Game("cybots",   "cybots.zip",   "fbneo",   "tile_cybots",   "ctrl_cybots",   PROFILE_ROW4, 1, "Cyberbots: Fullmetal Madness"),
        new Game("punisher", "punisher.zip", "fbneo",   "tile_punisher", "ctrl_punisher", PROFILE_ROW4, 1, "The Punisher"),
        new Game("pstone",   "pstone.zip",   "flycast", "tile_pstone",   "ctrl_pstone",   PROFILE_ROW4, 1, "Power Stone"),
        // --- SNK, plus Guilty Gear ----------------------------------------------------
        new Game("ggx",      "ggx.zip",      "flycast", "tile_ggx",      "ctrl_ggx",      PROFILE_ROW4, 1, "Guilty Gear X"),
        new Game("kof98",    "kof98.zip",    "fbneo",   "tile_kof98",    "ctrl_kof98",    PROFILE_ROW4, 1, "The King of Fighters '98"),
        new Game("garou",    "garou.zip",    "fbneo",   "tile_garou",    "ctrl_garou",    PROFILE_ROW4, 1, "Garou: Mark of the Wolves"),
        new Game("rbffspec", "rbffspec.zip", "fbneo",   "tile_rbffspec", "ctrl_rbffspec", PROFILE_ROW4, 1, "Real Bout Fatal Fury Special"),
        new Game("samsh5sp", "samsh5sp.zip", "fbneo",   "tile_samsh5sp", "ctrl_samsh5sp", PROFILE_ROW4, 1, "Samurai Shodown V Special"),
        // --- SNK vs Capcom, then Midway -----------------------------------------------
        new Game("svc",      "svc.zip",      "fbneo",   "tile_svc",      "ctrl_svc",      PROFILE_ROW4, 1, "SVC Chaos: SNK vs. Capcom"),
        new Game("mk",       "mk.zip",       "fbneo",   "tile_mk",       "ctrl_mk",       PROFILE_MK,   2, "Mortal Kombat"),
        new Game("mk2",      "mk2.zip",      "fbneo",   "tile_mk2",      "ctrl_mk2",      PROFILE_MK,   2, "Mortal Kombat II"),
        new Game("mk3",      "mk3.zip",      "fbneo",   "tile_mk3",      "ctrl_mk3",      PROFILE_MK,   2, "Mortal Kombat 3"),
        new Game("umk3",     "umk3.zip",     "fbneo",   "tile_umk3",     "ctrl_umk3",     PROFILE_MK,   2, "Ultimate Mortal Kombat 3"),
    };

    /**
     * Page 2. Page 1 already fills its four-row ceiling (see ExtraGamesActivity's layout
     * comment), so newer additions get their own page rather than shrinking the grid.
     * Control-page artwork (ctrl_*) isn't built yet for these -- ControlsActivity falls back
     * to a plain black background when a ctrl drawable is missing, so that's safe to ship
     * ahead of the artwork and fill in per game.
     */
    static final Game[] PAGE2 = new Game[]{
        new Game("avsp",     "avsp.zip",     "fbneo", "tile_avsp",     "ctrl_avsp",     PROFILE_CPS, 1, "Alien vs. Predator"),
        new Game("ghouls",   "ghouls.zip",   "fbneo", "tile_ghouls",   "ctrl_ghouls",   PROFILE_CPS, 1, "Ghouls'n Ghosts"),
        new Game("gng",      "gng.zip",      "fbneo", "tile_gng",      "ctrl_gng",      PROFILE_CPS, 1, "Ghosts'n Goblins"),
        new Game("megaman",  "megaman.zip",  "fbneo", "tile_megaman",  "ctrl_megaman",  PROFILE_CPS, 1, "Mega Man: The Power Battle"),
        new Game("megaman2", "megaman2.zip", "fbneo", "tile_megaman2", "ctrl_megaman2", PROFILE_CPS, 1, "Mega Man 2: The Power Fighters"),
        // --- MAME (Atari GT) ------------------------------------------------------------
        new Game("primrage", "primrage.zip", "mamearcade", "tile_primrage", "ctrl_primrage", PROFILE_CPS, 1, "Primal Rage"),
        // --- Dreamcast, via Flycast. ROMs are full paths onto the SD card (48A9-166C) --
        // internal storage doesn't have room for multi-GB GDI dumps; see ControlsActivity.
        new Game("mkgold",       SD_ROMS + "mkgold/game.gdi",           "flycast", "tile_mkgold",       "ctrl_mkgold",       PROFILE_CPS, 1, "Mortal Kombat Gold"),
        new Game("nflblitz2000", SD_ROMS + "nflblitz2000/game.gdi",     "flycast", "tile_nflblitz2000", "ctrl_nflblitz2000", PROFILE_CPS, 1, "NFL Blitz 2000"),
        new Game("soulcalibur",  SD_ROMS + "soulcalibur/game.gdi",      "flycast", "tile_soulcalibur",  "ctrl_soulcalibur",  PROFILE_CPS, 1, "Soul Calibur"),
        new Game("projectjustice", SD_ROMS + "projectjustice/game.gdi", "flycast", "tile_projectjustice", "ctrl_projectjustice", PROFILE_CPS, 1, "Project Justice"),
        new Game("vampirechronicle", SD_ROMS + "vampirechronicle/game.gdi", "flycast", "tile_vampirechronicle", "ctrl_vampirechronicle", PROFILE_CPS, 1, "Vampire Chronicle"),
        new Game("vf3tb",  SD_ROMS + "vf3tb/game.gdi",  "flycast", "tile_vf3tb",  "ctrl_vf3tb",  PROFILE_CPS, 1, "Virtua Fighter 3tb"),
        new Game("cvssnk", SD_ROMS + "cvssnk/game.chd", "flycast", "tile_cvssnk", "ctrl_cvssnk", PROFILE_CPS, 1, "Capcom vs. SNK"),
        new Game("powerstone2", SD_ROMS + "powerstone2/game.cdi", "flycast", "tile_powerstone2", "ctrl_powerstone2", PROFILE_CPS, 2, "Power Stone 2"),
    };

    /** Every page, in page order. ExtraGamesActivity pages through this, not ALL directly. */
    static final Game[][] PAGES = new Game[][]{ ALL, PAGE2 };

    static Game find(String id) {
        if (id == null) {
            return null;
        }
        for (Game[] page : PAGES) {
            for (int i = 0; i < page.length; i++) {
                if (page[i].id.equals(id)) {
                    return page[i];
                }
            }
        }
        return null;
    }

    private GameRegistry() {
    }
}
