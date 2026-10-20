package com.arcade.frontend;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.widget.Toast;

import java.util.List;

/**
 * Starts one of the sibling arcade apps from a home-screen tile.
 *
 * The tiles used to build an explicit ComponentName and start it, which is fine right up until
 * the same board ships under a different cabinet. The X-Men '97 deluxe uses this same PCB and
 * this same "com.arcade" package, but its entry activity is named
 * com.arcade.activity.legal.XmenLegalActivity rather than ...legal.LegalActivity -- so every
 * MvC2 tile press died in ActivityNotFoundException and toasted "com.arcade is not installed"
 * on a cabinet where it plainly was.
 *
 * Rather than ship one build per cabinet, the class name passed in is treated as a hint. If it
 * resolves, it is used unchanged, so nothing about the MvC2 cabinet's behaviour moves. If it
 * does not, the entry point is looked up instead: these apps declare their start activity as
 * the package's CATEGORY_HOME activity, whatever the vendor happened to call it.
 */
final class Launcher {

    private Launcher() {
    }

    static void go(Activity from, String pkg, String cls) {
        // 1. The name we were given. The overwhelmingly common case, and free.
        if (start(from, pkg, cls)) {
            return;
        }
        // 2. The package's own HOME activity. This is what LegalActivity/XmenLegalActivity are
        //    declared as, so it finds the entry point under any name.
        String home = resolveHome(from, pkg);
        if (home != null && start(from, pkg, home)) {
            return;
        }
        // 3. A conventional CATEGORY_LAUNCHER entry, in case some build has one. The cabinet's
        //    own apps do not, which is why this cannot be the only lookup.
        try {
            Intent i = from.getPackageManager().getLaunchIntentForPackage(pkg);
            if (i != null) {
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                from.startActivity(i);
                return;
            }
        } catch (Throwable ignored) {
        }
        Toast.makeText(from, pkg + " is not installed", Toast.LENGTH_LONG).show();
    }

    private static boolean start(Activity from, String pkg, String cls) {
        try {
            Intent i = new Intent(Intent.ACTION_MAIN);
            i.setComponent(new ComponentName(pkg, cls));
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            from.startActivity(i);
            return true;
        } catch (Throwable t) {
            return false;
        }
    }

    /** Name of pkg's CATEGORY_HOME activity, or null if it declares none. */
    private static String resolveHome(Activity from, String pkg) {
        try {
            Intent home = new Intent(Intent.ACTION_MAIN);
            home.addCategory(Intent.CATEGORY_HOME);
            home.setPackage(pkg);
            PackageManager pm = from.getPackageManager();
            List<ResolveInfo> hits = pm.queryIntentActivities(home, 0);
            if (hits != null) {
                for (int n = 0; n < hits.size(); n++) {
                    ResolveInfo ri = hits.get(n);
                    if (ri != null && ri.activityInfo != null && ri.activityInfo.name != null) {
                        return ri.activityInfo.name;
                    }
                }
            }
        } catch (Throwable ignored) {
        }
        return null;
    }
}
