package com.arcade.frontend;

import android.content.Context;
import android.provider.Settings;

/**
 * Runtime switches for the launch-path workarounds, read from Settings.System.
 *
 * The exit-and-relaunch path carries defences against RetroArch's launchMode="singleInstance"
 * behaviour (see ControlsActivity). They were added one at a time while chasing "the second game
 * reloads the first", and once a symptom stops it is very hard to tell which one is actually
 * carrying the fix -- turning one off would otherwise mean a rebuild, a reinstall and a fresh
 * test.
 *
 * So they are switchable without rebuilding:
 *
 *     adb shell settings put system cab_launch_retry 0
 *     adb shell settings put system cab_kill_bg 0
 *
 * This is how a third defence was retired: SwitchService used to clear RetroArch out of the
 * Recents list when LIVE was held, and flipping these proved it had never done anything.
 *
 * All default to 1, so a cabinet that has never had these set behaves exactly as shipped.
 * Settings.System is world-readable, so this needs no permission.
 */
final class Flags {

    /** ControlsActivity re-fires the launch intent if the control screen is still up. */
    static final String LAUNCH_RETRY = "cab_launch_retry";

    /** ControlsActivity calls killBackgroundProcesses before launching. */
    static final String KILL_BG = "cab_kill_bg";

    static boolean on(Context ctx, String name) {
        try {
            return Settings.System.getInt(ctx.getContentResolver(), name, 1) != 0;
        } catch (Throwable t) {
            return true;
        }
    }

    private Flags() {
    }
}
