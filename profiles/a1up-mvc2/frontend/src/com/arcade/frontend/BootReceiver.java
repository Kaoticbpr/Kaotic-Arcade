package com.arcade.frontend;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.provider.Settings;
import android.util.Log;

/**
 * Re-arms the LIVE button after a power cycle.
 *
 * This cabinet clears Settings.Secure.enabled_accessibility_services on every boot, which
 * silently disables SwitchService -- and with it the LIVE-hold that exits a game back to the
 * frontend. The P1+P2 Start combo never had this problem because it was handled inside the
 * vendor apps rather than by an accessibility service. Until now the only cure was re-running
 * an adb one-liner by hand, which is no cure at all on someone else's cabinet.
 *
 * Writing Settings.Secure needs WRITE_SECURE_SETTINGS, which is signature|privileged|development.
 * The "development" part is what makes this possible without root: it can be granted once over
 * adb with `pm grant`, and the grant itself survives reboots.
 *
 * Also restarts the 2-player bridge, which otherwise would not come back until someone opened
 * a game's control page.
 */
public class BootReceiver extends BroadcastReceiver {

    private static final String TAG = "P2Bridge";
    private static final String SERVICE = "com.arcade.frontend/com.arcade.frontend.SwitchService";

    @Override
    public void onReceive(Context ctx, Intent intent) {
        try {
            String cur = Settings.Secure.getString(
                    ctx.getContentResolver(), Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
            if (cur == null || cur.indexOf(SERVICE) < 0) {
                String next = (cur == null || cur.length() == 0) ? SERVICE : cur + ":" + SERVICE;
                Settings.Secure.putString(ctx.getContentResolver(),
                        Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES, next);
            }
            Settings.Secure.putInt(ctx.getContentResolver(),
                    Settings.Secure.ACCESSIBILITY_ENABLED, 1);
            Log.i(TAG, "boot: accessibility re-armed");
        } catch (Throwable t) {
            // Thrown when WRITE_SECURE_SETTINGS was never granted. Nothing else to try -- the
            // LIVE button will be dead this session and the grant needs re-running over adb.
            Log.e(TAG, "boot: could not re-arm accessibility: " + t);
        }

        try {
            ctx.startService(new Intent(ctx, P2BridgeService.class));
        } catch (Throwable t) {
            Log.e(TAG, "boot: could not start bridge: " + t);
        }
    }
}
