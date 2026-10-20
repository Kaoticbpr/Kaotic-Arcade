package com.arcade.frontend;

import android.accessibilityservice.AccessibilityService;
import android.content.Intent;
import android.os.Handler;
import android.os.SystemClock;
import android.view.KeyEvent;
import android.view.accessibility.AccessibilityEvent;

/**
 * The frontend's accessibility service. Two jobs:
 *
 *  1. LIVE-button escape. Holding LIVE (keycode 105) for 3 seconds returns to the frontend from
 *     whatever is running. This has to be an accessibility service because it must see keys
 *     while another app owns the screen. The key is consumed either way so LIVE never leaks
 *     into the game -- FBNeo maps R2 to the service switch, which used to drop CPS2 games into
 *     their TEST MENU.
 *
 *  2. Telling MenuMusic whether a frontend menu is on screen, from window-state events. Doing it
 *     here rather than in the Activities means it covers every launch path, including the vendor
 *     apps (MVC2, BigBlue, YogaFlame) whose Activities we do not own.
 *
 * Rewritten from the original vendor smali so the music hook could be added; the LIVE timing and
 * the boot behaviour below are reproduced deliberately -- do not "simplify" them away.
 */
public class SwitchService extends AccessibilityService implements Runnable {

    private static final String PKG = "com.arcade.frontend";

    /** The stock MvC2 app, the one thing the boot-time reclaim below exists to fight. */
    private static final String STOCK_PKG = "com.arcade";
    private static final int KEY_LIVE = 105;
    private static final long HOLD_MS = 3000;

    /** Within this long after boot, the frontend gets pulled to the front (see onServiceConnected). */
    private static final long BOOT_WINDOW_MS = 90000;
    private static final long BOOT_KICK_MS = 6000;

    /** How long after boot the frontend keeps reclaiming the screen from the stock app. */
    private static final long BOOT_RECLAIM_MS = 45000;



    private final Handler h = new Handler();
    private boolean pending;

    /**
     * Whether the last app we saw take the screen was ours. Starts true because at boot the
     * frontend is the home activity, so it owns the screen until something says otherwise.
     */
    private static boolean lastWasOurs = true;

    /**
     * Package of the last app we saw take the screen, or null if none has identified itself
     * yet. The reclaim below needs to know WHAT is on screen, not just whether it is ours: it
     * must take the screen back from the stock app and from nothing else.
     */
    private static volatile String lastPkg;

    /**
     * Starts the music if a frontend menu is on screen. Needed because music otherwise waits
     * for the next window CHANGE -- so a boot that lands straight on the menu played nothing.
     *
     * Deliberately does not call getRootInActiveWindow(): it returns null here even with
     * canRetrieveWindowContent granted, which made an earlier version of this fail silently.
     * The event stream already tells us what we need.
     */
    private final Runnable musicCheck = new Runnable() {
        @Override
        public void run() {
            if (lastWasOurs) {
                MenuMusic.setMenuVisible(SwitchService.this, true);
            }
        }
    };

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();

        // Listen for every event type. What actually matters is TYPE_WINDOW_STATE_CHANGED, which
        // is how the music learns whether a menu or a game is on screen.
        try {
            android.accessibilityservice.AccessibilityServiceInfo info = getServiceInfo();
            if (info != null) {
                info.eventTypes = AccessibilityEvent.TYPES_ALL_MASK;
                setServiceInfo(info);
            }
        } catch (Throwable ignored) {
        }

        // Early in boot, make sure the frontend is what the cabinet actually shows.
        if (SystemClock.elapsedRealtime() < BOOT_WINDOW_MS) {
            h.postDelayed(reclaim, BOOT_KICK_MS);
        }
        // Decode the menu track now, while the cabinet is still booting and nobody is
        // listening. Preparing it costs seconds on this hardware, and doing it on demand is
        // what used to leave the menu silent for a while after it appeared.
        MenuMusic.prewarm(this);
        // Re-check once the boot-quiet period has passed, and again shortly after, so the
        // music starts on its own instead of waiting for the player to move around.
        h.postDelayed(musicCheck, 19000);
        h.postDelayed(musicCheck, 26000);
        h.postDelayed(musicCheck, 34000);
    }

    @Override
    protected boolean onKeyEvent(KeyEvent event) {
        if (event.getKeyCode() != KEY_LIVE) {
            return false;
        }
        if (event.getAction() == KeyEvent.ACTION_DOWN) {
            // Guard against auto-repeat restarting the timer on every repeated DOWN.
            if (!pending) {
                pending = true;
                h.postDelayed(this, HOLD_MS);
            }
        } else {
            pending = false;
            h.removeCallbacks(this);
        }
        return true;
    }

    /**
     * LIVE was held: leave the running game and go back to the menu. That is all this does.
     *
     * It does NOT try to kill the game. It used to: RetroArch's activity is
     * launchMode="singleInstance", so a second launch never creates a new instance -- the intent
     * goes to onNewIntent(), which RetroArch ignores -- and the next game you picked would
     * silently reload the previous one. The fix attempted here was to open Recents and dismiss
     * RetroArch's card, which is a task removal and does take the process with it.
     *
     * Measured on the cabinet, that never worked and was not what fixed the bug. Swapping
     * Street Fighter Alpha for Mortal Kombat 3 through the real menus, with the Recents
     * dismissal on and ControlsActivity's launch retry off, the second game did not load and
     * RetroArch loaded a core only once -- so the dismissal had not killed anything. With the
     * dismissal off and the retry on, the second game loaded and RetroArch loaded a core twice.
     * The retry is carrying the fix on its own; this was doing nothing but flashing the Recents
     * list on screen every time a player quit a game.
     *
     * (Why it could not work: dismissing a card needs getRootInActiveWindow(), which returns
     * null on this firmware even with canRetrieveWindowContent granted and
     * FLAG_RETRIEVE_INTERACTIVE_WINDOWS set at runtime. There was nothing to click.)
     */
    @Override
    public void run() {
        goHome();
    }

    private void goHome() {
        Intent i = new Intent();
        i.setClassName(PKG, PKG + ".MainActivity");
        // CLEAR_TOP matters: with NEW_TASK alone the frontend's existing task just comes
        // forward at whatever was on top of it, so quitting a game landed you back on that
        // game's control-panel screen instead of the main menu.
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                | Intent.FLAG_ACTIVITY_CLEAR_TOP
                | Intent.FLAG_ACTIVITY_RETAIN_IN_RECENTS);
        startActivity(i);
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        if (event == null || event.getEventType() != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            return;
        }
        CharSequence pkg = event.getPackageName();
        if (pkg == null) {
            return;
        }
        // The volume dialog, toasts and other system chrome are separate packages but do NOT
        // mean the player left the menus. Treating them as "another app" stopped the music
        // every time the volume rocker was touched.
        if ("android".contentEquals(pkg) || "com.android.systemui".contentEquals(pkg)) {
            return;
        }
        lastPkg = pkg.toString();
        boolean ours = PKG.contentEquals(pkg);
        lastWasOurs = ours;
        MenuMusic.setMenuVisible(this, ours);
        if (STOCK_PKG.contentEquals(pkg) && SystemClock.elapsedRealtime() < BOOT_RECLAIM_MS) {
            // The stock MVC2 app auto-launches itself over the frontend at boot
            // (com.arcade.AuToStartReciver). Shell cannot disable that receiver -- it fails
            // with a SecurityException -- so instead take the screen back when it appears.
            // Only during the boot window, so that later on the player can actually open MVC2.
            //
            // Match the stock app BY NAME. This used to reclaim from anything that was not
            // ours, which meant RetroArch too: pick an Extra Game inside the first 45 seconds
            // of uptime and its window would appear, this would fire 400 ms later, and the
            // player would land back on the menu. Pressing Start again did the same thing, so
            // it read as "that game is broken" -- reported against the two NAOMI titles, but
            // nothing about them was special beyond being what got tested after a power-up.
            h.removeCallbacks(reclaim);
            h.postDelayed(reclaim, 400);
        }
    }

    /**
     * Boot-time screen reclaim. Deliberately NOT run(): that ends a running game by clearing
     * it out of Recents, which at boot would flash the Recents list on screen and dismiss the
     * stock app's task while the player is just watching the cabinet start up. All this needs
     * to do is put the frontend back in front.
     */
    private final Runnable reclaim = new Runnable() {
        @Override
        public void run() {
            // Take the screen back FROM THE STOCK APP, or when nothing has identified itself
            // yet -- that second case is the one onServiceConnected schedules for, where the
            // stock app grabbed the screen before this service was bound so no event was ever
            // seen. Without this test the boot kick fired blind six seconds after binding and
            // closed whatever happened to be running, which for anyone who picked an Extra
            // Game the moment the menu appeared meant the game was shot down on its way up.
            String p = lastPkg;
            if (p == null || STOCK_PKG.equals(p)) {
                goHome();
            }
        }
    };

    @Override
    public void onInterrupt() {
    }
}
