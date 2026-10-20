package com.arcade.frontend;

import android.content.Context;
import android.media.MediaPlayer;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;

/**
 * Background music for the frontend menus only.
 *
 * The player lives here rather than in an Activity because the music has to survive moving
 * between the home screen and the Extra Games grid -- if each Activity owned it, the track
 * would restart from bar one every time you stepped between menus.
 *
 * It is driven by SwitchService's window-state events, so it stops for EVERY launch path, not
 * just RetroArch: MVC2, BigBlue and YogaFlame all bring their own music and must not be played
 * over.
 *
 * On hide we pause immediately but release the MediaPlayer a few seconds later. Pausing alone
 * would keep an AudioTrack open on STREAM_MUSIC for the whole time a game is running, and this
 * cabinet has already shown one audio-layer deadlock (Flycast against the OpenSL driver) -- so
 * the safe thing is to own no audio resources at all during gameplay. The delay means stepping
 * between menus still resumes seamlessly.
 *
 * PREPARING IS SLOW AND MUST NOT BE DONE INLINE. MediaPlayer.create() decodes and prepares
 * synchronously on whatever thread calls it, and this is a multi-megabyte MP3 on an RK3399,
 * so it takes seconds. It used to be called straight from the accessibility service's main
 * thread the moment a menu appeared, which is exactly why the music came in well after the
 * screen did. Loading now happens on a worker thread, and prewarm() gets it done during boot
 * so the first menu can start it instantly.
 */
final class MenuMusic {

    private static final String TAG = "P2Bridge";
    private static final String RES = "menu_music";
    private static final long RELEASE_DELAY_MS = 4000;
    private static final float VOLUME = 0.65f;

    /**
     * How long after boot the music stays silent. The cabinet flashes the frontend while the
     * stock app is still starting, and music there would be an audible blip that immediately
     * stops. Kept short because prewarm() has the track ready by then -- the wait is only to
     * let the boot fight settle, not to load anything.
     */
    private static final long BOOT_QUIET_MS = 18000;

    private static final Handler H = new Handler(Looper.getMainLooper());
    private static MediaPlayer mp;
    private static boolean enabled = true;

    /** A load is in flight on the worker thread; do not start a second one. */
    private static boolean loading;

    /** Whether a menu is on screen right now. The loader checks this before it starts playing. */
    private static boolean wanted;


    private static final Runnable RELEASE = new Runnable() {
        @Override
        public void run() {
            release();
        }
    };

    private MenuMusic() {
    }

    /**
     * Decode the track now, without playing it, so the first menu does not have to wait for it.
     * Called from SwitchService.onServiceConnected -- i.e. during boot, while nothing is
     * listening anyway.
     */
    static void prewarm(Context ctx) {
        load(ctx);
    }

    /**
     * Stop and free the player immediately, synchronously.
     *
     * Called on the launch path rather than left to a window-change event. Holding an
     * AudioTrack on STREAM_MUSIC while RetroArch starts makes its OpenSL init contend and the
     * game comes up as a black screen or ANRs -- the same way Flycast deadlocked against
     * opensl. Nothing may own audio when a game starts, and "nothing" has to be guaranteed,
     * not hoped for. Clearing `wanted` also covers a load still in flight: when it lands it
     * sees nobody wants it and releases the player instead of starting it.
     */
    static void stopNow() {
        wanted = false;
        H.removeCallbacks(RELEASE);
        pause();
        release();
    }

    static void setMenuVisible(Context ctx, boolean visible) {
        if (!enabled) {
            return;
        }
        if (visible && SystemClock.elapsedRealtime() < BOOT_QUIET_MS) {
            // Still get the track decoded, so it can start the moment the gate opens.
            load(ctx);
            return;
        }
        wanted = visible;
        if (visible) {
            H.removeCallbacks(RELEASE);
            play(ctx);
        } else {
            pause();
            H.removeCallbacks(RELEASE);
            H.postDelayed(RELEASE, RELEASE_DELAY_MS);
        }
    }

    /** Start, or kick off a load that will start when it lands. */
    private static void play(Context ctx) {
        if (mp == null) {
            load(ctx);
            return;
        }
        try {
            if (!mp.isPlaying()) {
                mp.start();
            }
        } catch (Throwable t) {
            Log.w(TAG, "music: play: " + t);
            release();
        }
    }

    /**
     * Prepare the MediaPlayer on a worker thread and hand it back to the main thread.
     *
     * Everything that touches the static fields runs on the main thread, so `loading`, `mp`
     * and `wanted` need no locking: the worker only reads the resource id it was given.
     */
    private static void load(Context ctx) {
        if (mp != null || loading || !enabled) {
            return;
        }
        final Context app = ctx.getApplicationContext();
        final int id = app.getResources().getIdentifier(RES, "raw", app.getPackageName());
        if (id == 0) {
            Log.w(TAG, "music: no raw/" + RES + ", disabling");
            enabled = false;
            return;
        }
        loading = true;
        new Thread(new Runnable() {
            @Override
            public void run() {
                final long t0 = SystemClock.elapsedRealtime();
                MediaPlayer built = null;
                try {
                    built = MediaPlayer.create(app, id);
                } catch (Throwable t) {
                    Log.w(TAG, "music: create: " + t);
                }
                final MediaPlayer made = built;
                final long took = SystemClock.elapsedRealtime() - t0;
                H.post(new Runnable() {
                    @Override
                    public void run() {
                        loading = false;
                        if (made == null) {
                            Log.w(TAG, "music: MediaPlayer.create failed, disabling");
                            enabled = false;
                            return;
                        }
                        Log.i(TAG, "music: ready in " + took + " ms");
                        try {
                            made.setLooping(true);
                            made.setVolume(VOLUME, VOLUME);
                        } catch (Throwable ignored) {
                        }
                        // Nobody is on a menu any more -- a game may even be starting. Do not
                        // hold an AudioTrack we are not using.
                        if (!wanted) {
                            try {
                                made.release();
                            } catch (Throwable ignored) {
                            }
                            return;
                        }
                        mp = made;
                        try {
                            mp.start();
                        } catch (Throwable t) {
                            Log.w(TAG, "music: start: " + t);
                            release();
                        }
                    }
                });
            }
        }, "menu-music-load").start();
    }

    private static void pause() {
        try {
            if (mp != null && mp.isPlaying()) {
                mp.pause();
            }
        } catch (Throwable t) {
            Log.w(TAG, "music: pause: " + t);
        }
    }

    private static void release() {
        try {
            if (mp != null) {
                mp.release();
            }
        } catch (Throwable t) {
            Log.w(TAG, "music: release: " + t);
        }
        mp = null;
    }
}
