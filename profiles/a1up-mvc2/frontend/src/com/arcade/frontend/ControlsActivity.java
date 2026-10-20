package com.arcade.frontend;

import android.app.Activity;
import android.app.ActivityManager;
import android.content.ComponentName;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.res.Resources;
import android.graphics.Color;
import android.os.Bundle;
import android.os.Handler;
import android.view.KeyEvent;
import android.util.Log;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.Toast;

import java.io.File;

/**
 * Shows the full-screen control-panel diagram for one Extra Game, then launches it in
 * RetroArch on a face-button press. P2 Start (keycode 104) backs out to the game grid,
 * same convention as ExtraGamesActivity and the stock frontend's own MainActivity.
 *
 * RetroArch's own install paths (APK location, app-private data dir) are resolved through
 * PackageManager at launch time rather than hardcoded, so this survives RetroArch being
 * reinstalled or updated later (Android's numeric "-N" suffix on /data/app/<pkg>-N is not
 * stable across installs).
 */
public class ControlsActivity extends Activity {

    private static final String RETROARCH_PKG = "com.retroarch.aarch64";
    private static final String RETROARCH_ACTIVITY =
            "com.retroarch.browser.retroactivity.RetroActivityFuture";
    private static final String ROMS_DIR = "/storage/emulated/0/roms/";
    private static final String CONFIG_FILE = "/storage/emulated/0/RetroArch/cabinet.cfg";
    private static final String SDCARD_ROOT = "/storage/emulated/0";
    /** Where INSTALL.bat puts the libretro cores; see launchGame(). */
    private static final String PUSHED_CORES = "/data/local/tmp/cores/";

    /** Time for RetroArch to actually exit after killBackgroundProcesses() before relaunch. */
    private static final long LAUNCH_DELAY_MS = 1500;

    /** If we are still on screen this long after firing, the launch did not take. */
    private static final long RETRY_AFTER_MS = 4500;

    private GameRegistry.Game game;

    private int drawableId(String name) {
        Resources r = getResources();
        return r.getIdentifier(name, "drawable", getPackageName());
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        String gameId = getIntent().getStringExtra("gameId");
        game = GameRegistry.find(gameId);

        if (game == null) {
            finish();
            return;
        }

        ImageView iv = new ImageView(this);
        iv.setScaleType(ImageView.ScaleType.FIT_CENTER);
        iv.setBackgroundColor(Color.BLACK);
        int resId = drawableId(game.ctrl);
        if (resId != 0) {
            iv.setImageResource(resId);
        }
        iv.setLayoutParams(new ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        iv.setFocusable(true);
        iv.setFocusableInTouchMode(true);

        // Panel bridge: feeds player 2 (and both players' coin/start) to RetroArch over its
        // network gamepad. Started here because this screen always runs immediately before a
        // game launches, which is also when the input profile has to be set.
        try {
            Intent svc = new Intent(this, P2BridgeService.class);
            svc.putExtra("profile", game.profile);
            svc.putExtra("coins", game.coins);
            startService(svc);
        } catch (Throwable ignored) {
        }

        setContentView(iv);
        iv.requestFocus();
    }

    /**
     * Guards against a second launch. The launch is deferred ~1.5 s while RetroArch exits, so
     * two quick presses would schedule two of them -- and the second killBackgroundProcesses
     * would shoot down the instance the first one just started.
     */
    private boolean launching;

    /** True while this screen is the resumed activity; see the retry in launchGame(). */
    private boolean resumed;

    private void launchGame() {
        if (launching) {
            return;
        }
        launching = true;
        try {
            PackageManager pm = getPackageManager();
            ApplicationInfo ai = pm.getApplicationInfo(RETROARCH_PKG, 0);
            String apkPath = ai.sourceDir;
            String dataDir = ai.dataDir;
            // Prefer the cores the installer drops in /data/local/tmp. /data is mounted
            // exec-capable and that directory is world-traversable, so RetroArch can dlopen
            // from there -- which means the cores can be shipped instead of making the user
            // fetch them through RetroArch's Online Updater. Falls back to RetroArch's own
            // private cores directory for anyone who did use the updater.
            String coreFile = game.core + "_libretro_android.so";
            String corePath = PUSHED_CORES + coreFile;
            if (!new File(corePath).exists()) {
                corePath = dataDir + "/cores/" + coreFile;
            }

            // Free the audio device before RetroArch starts. Doing this here rather than
            // relying on a window-change event is deliberate: that event does not reliably
            // arrive for RetroArch's window, and a MediaPlayer still holding STREAM_MUSIC
            // makes the game come up black or hang.
            MenuMusic.stopNow();

            // RetroArch MUST be gone before we fire the intent. If its task is still alive,
            // Android just brings it forward and SILENTLY DROPS the extras -- so it reloads
            // whatever it had last, which shows up as "the first game works, every game after
            // it is a black screen". killBackgroundProcesses needs only the normal-level
            // KILL_BACKGROUND_PROCESSES permission, and RetroArch is backgrounded by the time
            // this screen is up.
            if (Flags.on(this, Flags.KILL_BG)) {
                try {
                    ActivityManager am = (ActivityManager) getSystemService(ACTIVITY_SERVICE);
                    am.killBackgroundProcesses(RETROARCH_PKG);
                } catch (Throwable ignored) {
                }
            }

            // game.rom is normally a filename resolved against ROMS_DIR, but the Dreamcast
            // titles live on the SD card (internal storage doesn't have room for multi-GB GDI
            // dumps) and are given as a full path there instead -- pass those straight through.
            String romPath = game.rom.startsWith("/") ? game.rom : (ROMS_DIR + game.rom);

            final Intent i = new Intent();
            i.setComponent(new ComponentName(RETROARCH_PKG, RETROARCH_ACTIVITY));
            i.putExtra("ROM", romPath);
            i.putExtra("LIBRETRO", corePath);
            i.putExtra("CONFIGFILE", CONFIG_FILE);
            i.putExtra("DATADIR", dataDir);
            i.putExtra("APK", apkPath);
            i.putExtra("SDCARD", SDCARD_ROOT);
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);

            // killBackgroundProcesses() returns immediately, so the process is still tearing
            // down when we get here. Launching into that window aborts, which showed up as
            // every OTHER game failing: kill -> race -> nothing, then the next attempt works
            // because RetroArch is already gone. Post the launch instead of sleeping, so the
            // UI thread stays live while the old process finishes dying.
            final Runnable fire = new Runnable() {
                @Override
                public void run() {
                    try {
                        startActivity(i);
                    } catch (Throwable t) {
                        Log.w("P2Bridge", "launch: " + t);
                    }
                }
            };
            new Handler().postDelayed(fire, LAUNCH_DELAY_MS);

            // Auto-retry. RetroArch is launchMode="singleInstance", so if a stale instance is
            // still being torn down the first start lands on nothing and we end up back on
            // this screen -- which players saw as "press START twice". If we are STILL the
            // resumed activity a few seconds later, the launch clearly did not take, so fire
            // it again. Harmless when the first one worked: we are paused by then.
            if (Flags.on(this, Flags.LAUNCH_RETRY)) {
                new Handler().postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        if (resumed) {
                            Log.i("P2Bridge", "launch did not take, retrying");
                            fire.run();
                        }
                    }
                }, LAUNCH_DELAY_MS + RETRY_AFTER_MS);
            }
        } catch (Throwable t) {
            Toast.makeText(this, "RetroArch is not installed", Toast.LENGTH_LONG).show();
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        resumed = true;
        // LIVE brings the player back here; allow launching again.
        launching = false;
    }

    @Override
    protected void onPause() {
        super.onPause();
        resumed = false;
    }

    @Override
    public boolean onKeyUp(int keyCode, KeyEvent event) {
        if (keyCode == 104) { // P2 Start -> back to the game grid
            finish();
            return true;
        }
        // P1 Start (108), any action button, or the DPAD_CENTER/ENTER fallback Android
        // synthesizes for an unhandled gamepad button on a focused-but-unclickable view.
        // 108 matters because every control page -- stock and custom -- tells the player to
        // press 1P START, so it has to actually start the game.
        if (keyCode == 108 || (keyCode >= 96 && keyCode <= 103) || keyCode == 23 || keyCode == 66) {
            launchGame();
            return true;
        }
        return super.onKeyUp(keyCode, event);
    }
}
