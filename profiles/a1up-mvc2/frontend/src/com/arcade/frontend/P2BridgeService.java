package com.arcade.frontend;

import android.app.Notification;
import android.app.Service;
import android.content.Intent;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.os.IBinder;
import android.util.Log;

import java.io.FileInputStream;
import java.io.InputStream;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.util.concurrent.atomic.AtomicIntegerArray;

/**
 * Feeds the arcade control panel to RetroArch's network gamepad.
 *
 * Only player 1 is mirrored into Android's input system (the "robot" evdev node). Player 2's
 * stick and action buttons never enter Android at all, so RetroArch -- which reads Android
 * input and nothing else -- can never see them. That is why every RetroArch-hosted game on
 * this cabinet has been one-player.
 *
 * The vendor core (libarcade.so) does not use Android input either: it reads the panel
 * directly from /dev/umidokey, which carries BOTH players and is mode crwxrwxrwx. So an
 * ordinary unprivileged app can read player 2 there and hand it to RetroArch over its UDP
 * remote-gamepad protocol. No root, no uinput, no signature permissions, no reflash.
 *
 * Panel word: 4 bytes, read as two 16-bit halves that share one bit layout.
 *     bytes 0..1 = player 1, bytes 2..3 = player 2
 *
 * Wire format is RetroArch's struct remote_message, little endian, 20 bytes:
 *     int port; int device; int index; int id; uint16_t state; (+2 pad)
 * One datagram per button transition, to port 55400 + user index.
 */
public class P2BridgeService extends Service {

    private static final String TAG = "P2Bridge";

    private static final String DEVICE = "/dev/umidokey";
    private static final String HOST = "127.0.0.1";
    private static final int BASE_PORT = 55400;

    /** RETRO_DEVICE_JOYPAD */
    private static final int RETRO_DEVICE_JOYPAD = 1;

    /** RETRO_DEVICE_ID_JOYPAD_* */
    private static final int ID_B = 0, ID_Y = 1, ID_SELECT = 2, ID_START = 3,
            ID_UP = 4, ID_DOWN = 5, ID_LEFT = 6, ID_RIGHT = 7,
            ID_A = 8, ID_X = 9, ID_L = 10, ID_R = 11;

    /** Panel bit masks, within one player's 16-bit half. Measured off the cabinet. */
    private static final int M_UP = 0x0400, M_DOWN = 0x0800, M_LEFT = 0x0200, M_RIGHT = 0x0100;
    private static final int M_TL = 0x0040, M_TM = 0x0002, M_TR = 0x0001;  // LP MP HP
    private static final int M_BL = 0x4000, M_BM = 0x8000, M_BR = 0x0080;  // LK MK HK
    private static final int M_START = 0x2000;

    /**
     * Panel mask -> retropad id, for the 6-button Capcom games. This is also RetroArch's
     * default, so these games need no remap file.
     */
    private static final int[][] MAP_CPS = {
            {M_UP, ID_UP}, {M_DOWN, ID_DOWN}, {M_LEFT, ID_LEFT}, {M_RIGHT, ID_RIGHT},
            {M_TL, ID_Y}, {M_TM, ID_X}, {M_TR, ID_L},
            {M_BL, ID_B}, {M_BM, ID_A}, {M_BR, ID_R},
    };

    /**
     * Neo Geo, in real cabinet order: A B C across the top, D bottom-left, and the AB / CD
     * combos on the two spare buttons.
     *
     * FinalBurn's own mapping is NeoGeo A=retro B, B=retro A, C=retro Y, D=retro X,
     * CD=retro L, AB=retro R -- which lands A and B on the BOTTOM row, backwards to anyone
     * who has played these games. So to put NeoGeo A under the top-left button we SEND retro
     * B from it, and so on down the list.
     *
     * These are the same substitutions the player-1 remap file makes. Player 2 needs its own
     * copy because **RetroArch does not apply remap files to network-gamepad input** --
     * verified on the cabinet by remapping a button to Coin and watching the credit counter
     * not move, while sending Coin directly did move it.
     */
    private static final int[][] MAP_ROW4 = {
            {M_UP, ID_UP}, {M_DOWN, ID_DOWN}, {M_LEFT, ID_LEFT}, {M_RIGHT, ID_RIGHT},
            {M_TL, ID_B}, {M_TM, ID_A}, {M_TR, ID_Y},
            {M_BL, ID_X}, {M_BM, ID_R}, {M_BR, ID_L},
    };

    /**
     * Mortal Kombat, laid out for THIS panel rather than for the original MK cabinet:
     *
     *     LOW PUNCH   HIGH PUNCH   BLOCK
     *     LOW KICK    HIGH KICK    RUN
     *
     * Punches along the top and kicks along the bottom is what every other game on this
     * cabinet does, so the hand already knows it; MK's own HP/BLOCK/HK over LP/RUN/LK splits
     * each limb across both rows and fights that. Block and Run land on the right-hand column,
     * where nothing else needs to be.
     *
     * FinalBurn's own MK mapping is retro Y=High Punch, X=High Kick, L=Block, B=Low Punch,
     * A=Low Kick, R=Run -- read off the core's own Port 1 Controls list, not guessed. MK1 and
     * MK2 have no Run and expose a second Block on R instead, so the bottom-right button
     * blocks on those two.
     */
    private static final int[][] MAP_MK = {
            {M_UP, ID_UP}, {M_DOWN, ID_DOWN}, {M_LEFT, ID_LEFT}, {M_RIGHT, ID_RIGHT},
            {M_TL, ID_B}, {M_TM, ID_Y}, {M_TR, ID_L},
            {M_BL, ID_A}, {M_BM, ID_X}, {M_BR, ID_R},
    };

    /** Set from the launch intent; see GameRegistry.PROFILE_*. */
    private static volatile int[][] activeMap = MAP_CPS;

    /**
     * Coins to drop before Start. Most games take one; the four Mortal Kombat boards ship from
     * the factory on "2 CREDITS TO START", verified on each board's own credits screen rather
     * than assumed.
     *
     * The package now also ships those boards' NVRAM set to FREE PLAY, which makes the coins
     * moot -- so this is kept at 2 purely as a fallback. If a board ever loses its CMOS (a
     * deleted or corrupt .fs file restores the factory settings), Start still works.
     */
    private static volatile int activeCoins = 1;

    /** One synthesised coin pulse: how long the Coin line is held, and the gap after it. */
    private static final int COIN_ON_MS = 50, COIN_OFF_MS = 60;

    /**
     * Shortest time Start is held once the coins are in. The boards poll at 60 Hz, so this only
     * has to comfortably exceed a frame -- it exists because the player may well have let go of
     * the panel button before the coin sequence even finished.
     */
    private static final int START_MIN_MS = 120;

    /** Volume is only re-asserted this soon after boot; never mid-session. */
    private static final long BOOT_ONLY_MS = 90000;

    /** Samples of no activity (~3 ms each) before the poll loop eases off. ~6 seconds. */
    private static final int IDLE_SAMPLES = 2000;

    /** Every mask the bridge owns, used to spot a change worth reacting to. */
    private static final int M_ALL;
    static {
        int all = M_START;
        for (int i = 0; i < MAP_CPS.length; i++) {
            all |= MAP_CPS[i][0];   // every profile covers the same physical buttons
        }
        M_ALL = all;
    }

    private volatile boolean running;
    private Thread worker;

    /**
     * Bumped on every Start PRESS -- not on the release -- so a running coin sequence can tell
     * whether a newer press has taken over from it.
     */
    private final AtomicIntegerArray startEpoch = new AtomicIntegerArray(2);

    /** 1 while the panel's Start button is physically down, per player. */
    private final AtomicIntegerArray startHeld = new AtomicIntegerArray(2);

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onCreate() {
        super.onCreate();

        // Foreground so the frontend's process is not reclaimed while RetroArch (300 MB+)
        // is in front. If the bridge dies mid-match, player 2 goes dead with it.
        Notification n = new Notification.Builder(this)
                .setContentTitle("Arcade")
                .setContentText("2-player bridge active")
                .setSmallIcon(android.R.drawable.ic_menu_info_details)
                .build();
        startForeground(1, n);

        running = true;
        worker = new Thread(new Runnable() {
            @Override
            public void run() {
                pump();
            }
        }, "p2bridge");
        worker.setPriority(Thread.MAX_PRIORITY);
        worker.start();

        // NO volume restoring here any more. VolumeKeeper caused two regressions: it slammed
        // a stale value back when the player touched the rocker mid-session, and it latched a
        // bad reading (media volume pinned at 1/15). Android already persists stream volume
        // across reboots on its own -- let it.
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // ControlsActivity sets these immediately before launching a game.
        if (intent != null && intent.hasExtra("profile")) {
            int p = intent.getIntExtra("profile", GameRegistry.PROFILE_CPS);
            String named;
            if (p == GameRegistry.PROFILE_ROW4) {
                activeMap = MAP_ROW4;
                named = "row4";
            } else if (p == GameRegistry.PROFILE_MK) {
                activeMap = MAP_MK;
                named = "mk";
            } else {
                activeMap = MAP_CPS;
                named = "cps";
            }
            activeCoins = Math.max(1, intent.getIntExtra("coins", 1));
            Log.i(TAG, "input profile = " + named + ", coins = " + activeCoins);
        }
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        running = false;
        if (worker != null) {
            worker.interrupt();
        }
        super.onDestroy();
    }

    // ---------------------------------------------------------------- the pump

    private DatagramSocket sock;
    private InetAddress host;

    private void pump() {
        try {
            sock = new DatagramSocket();
            host = InetAddress.getByName(HOST);
        } catch (Throwable t) {
            Log.e(TAG, "no socket, bridge disabled: " + t);
            return;
        }

        byte[] buf = new byte[4];
        int prev1 = 0, prev2 = 0;
        int idle = 0;
        InputStream in = null;

        while (running) {
            try {
                if (in == null) {
                    in = new FileInputStream(DEVICE);
                }
                if (!readFully(in, buf)) {
                    in.close();
                    in = null;
                    Thread.sleep(50);
                    continue;
                }

                // Half order confirmed in-game, not from the capture logs: with the halves
                // the other way round, player 1 drove both characters (local Android input
                // plus the bridge's user-2 packets) while player 2 drove only character 1.
                int p1 = ((buf[0] & 0xFF) << 8) | (buf[1] & 0xFF);
                int p2 = ((buf[2] & 0xFF) << 8) | (buf[3] & 0xFF);

                boolean changed = false;
                if ((p1 & M_ALL) != (prev1 & M_ALL)) {
                    emit(0, prev1, p1);
                    changed = true;
                }
                if ((p2 & M_ALL) != (prev2 & M_ALL)) {
                    emit(1, prev2, p2);
                    changed = true;
                }
                prev1 = p1;
                prev2 = p2;

                // Poll hard while the panel is in use, and only ease off after a long quiet
                // spell. The backoff must never bite between inputs: player 1 also arrives
                // through Android directly, so any extra latency here would show up as
                // player 2 feeling a frame behind player 1.
                if (changed) {
                    idle = 0;
                } else if (idle < IDLE_SAMPLES) {
                    idle++;
                }
                Thread.sleep(idle >= IDLE_SAMPLES ? 8 : 3);
            } catch (InterruptedException ie) {
                break;
            } catch (Throwable t) {
                Log.w(TAG, "pump: " + t);
                try {
                    if (in != null) {
                        in.close();
                    }
                } catch (Throwable ignored) {
                }
                in = null;
                try {
                    Thread.sleep(250);
                } catch (InterruptedException ie) {
                    break;
                }
            }
        }

        try {
            if (in != null) {
                in.close();
            }
        } catch (Throwable ignored) {
        }
        sock.close();
    }

    /** Char device hands back the whole 4-byte word per read; loop anyway for short reads. */
    private boolean readFully(InputStream in, byte[] buf) throws Exception {
        int off = 0;
        while (off < buf.length) {
            int n = in.read(buf, off, buf.length - off);
            if (n < 0) {
                return false;
            }
            off += n;
        }
        return true;
    }

    /**
     * Send one datagram per bit that actually changed.
     *
     * Player 1 gets ONLY the coin/start pair. Its stick and buttons come through Android's own
     * input, which RetroArch does remap -- so if the bridge also sent them, a remapped game
     * would receive both the remapped and the unremapped button for every press.
     */
    private void emit(int user, int was, int now) throws Exception {
        if (user != 0) {
            int[][] map = activeMap;
            for (int i = 0; i < map.length; i++) {
                int mask = map[i][0];
                if (((was ^ now) & mask) != 0) {
                    send(user, map[i][1], (now & mask) != 0 ? 1 : 0);
                }
            }
        }

        // The panel has no coin button -- the cabinet was built for a vendor core that never
        // needed one. Synthesise it: a Start press drops a credit first, then presses Start,
        // so one button both coins in and starts, for either player.
        //
        // The release edge is deliberately NOT forwarded from here -- coinThenStart owns the
        // whole press, including letting Start back up. See the note on it.
        if (((was ^ now) & M_START) != 0) {
            boolean down = (now & M_START) != 0;
            startHeld.set(user, down ? 1 : 0);
            if (down) {
                coinThenStart(user, startEpoch.incrementAndGet(user));
            }
        }
    }

    /**
     * Drop the credits the board wants, press Start, then let Start back up.
     *
     * Off the pump thread on purpose: each coin takes ~110 ms to pulse and settle, and blocking
     * the pump that long would stall BOTH players' input every time anyone hits Start.
     *
     * THE RELEASE IS SENT FROM HERE, NOT FROM emit(). It used to be the other way round, and
     * the epoch was bumped on the release too, so letting go of the button abandoned the
     * sequence. That meant a normal tap was cancelled before Start had ever been sent. It
     * showed up on the Mortal Kombat boards, which want two credits to start: their window was
     * ~220 ms, longer than anyone actually holds a button, so each press bought one credit and
     * no Start, and the player had to bank about ten credits before some press happened to be
     * long enough. The one-credit games hid it -- their window is only ~110 ms, and the credit
     * from a cancelled press is still sitting there for the next one, so it read as normal.
     *
     * So a release must cancel nothing. Only a NEWER press supersedes, and that press's own
     * sequence then owns Start.
     */
    private void coinThenStart(final int user, final int epoch) {
        new Thread(new Runnable() {
            @Override
            public void run() {
                boolean pressed = false;
                try {
                    int coins = activeCoins;
                    for (int c = 0; c < coins; c++) {
                        if (startEpoch.get(user) != epoch) {
                            return;
                        }
                        send(user, ID_SELECT, 1);
                        Thread.sleep(COIN_ON_MS);
                        send(user, ID_SELECT, 0);
                        Thread.sleep(COIN_OFF_MS);
                    }
                    if (startEpoch.get(user) != epoch) {
                        return;
                    }
                    send(user, ID_START, 1);
                    pressed = true;
                    // Hold long enough that the board cannot miss it, and keep holding for as
                    // long as the player is still leaning on the panel button.
                    long until = SystemClock.elapsedRealtime() + START_MIN_MS;
                    while (startEpoch.get(user) == epoch
                            && (SystemClock.elapsedRealtime() < until
                                || startHeld.get(user) != 0)) {
                        Thread.sleep(10);
                    }
                } catch (Throwable err) {
                    Log.w(TAG, "coin: " + err);
                } finally {
                    // Only when we still own Start. If a newer press superseded us, releasing
                    // here would cut ITS press short.
                    if (pressed && startEpoch.get(user) == epoch) {
                        try {
                            send(user, ID_START, 0);
                        } catch (Throwable err) {
                            Log.w(TAG, "start release: " + err);
                        }
                    }
                }
            }
        }, "p2bridge-coin").start();
    }

    private void send(int user, int id, int state) throws Exception {
        byte[] p = new byte[20];
        putInt(p, 0, 0);                     // port  (unused for joypad; socket picks the user)
        putInt(p, 4, RETRO_DEVICE_JOYPAD);   // device
        putInt(p, 8, 0);                     // index
        putInt(p, 12, id);                   // id
        p[16] = (byte) (state & 0xFF);       // uint16 state, little endian
        p[17] = (byte) ((state >> 8) & 0xFF);
        sock.send(new DatagramPacket(p, p.length, host, BASE_PORT + user));
    }

    private static void putInt(byte[] b, int off, int v) {
        b[off] = (byte) (v & 0xFF);
        b[off + 1] = (byte) ((v >> 8) & 0xFF);
        b[off + 2] = (byte) ((v >> 16) & 0xFF);
        b[off + 3] = (byte) ((v >> 24) & 0xFF);
    }
}
