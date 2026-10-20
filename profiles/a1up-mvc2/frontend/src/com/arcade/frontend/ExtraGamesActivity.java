package com.arcade.frontend;

import android.app.Activity;
import android.content.Intent;
import android.content.res.Resources;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.GridLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

/**
 * "EXTRA GAMES" selection grid -- one logo per RetroArch-hosted game (see GameRegistry).
 * Built entirely in code (no layout XML) so this class links into the decompiled frontend
 * APK without needing a resource-aware rebuild of R.java: every drawable is looked up by
 * name at runtime via Resources.getIdentifier().
 *
 * The logos sit directly on the cabinet's character art -- no plates, frames or per-tile
 * boxes. What makes them readable instead is a dark halo baked into each PNG (see
 * _screens/tools/GlowTile.java) plus one page-wide wash that fades in below the header, so
 * the artwork still shows through and the banner and both logos along the top stay clear.
 *
 * Selection is shown the way the stock home screen shows it: yellow corner brackets around
 * the highlighted logo, with the unselected ones held back slightly. A box would defeat the
 * whole point of the layout, and a border is a box.
 *
 * Input convention matches the stock MainActivity exactly: any of the 6 physical action
 * buttons (Android keycodes 96-103) confirms the focused logo; the P2 Start button
 * (keycode 104) backs out to the home screen. D-pad navigation is Android's normal
 * focus-search over the GridLayout's children -- no custom code needed for that.
 */
public class ExtraGamesActivity extends Activity {

    /**
     * 5 x 4 = 20 games on the cabinet's 1280x960 panel.
     *
     * The header art (ARCADE1UP, SELECT YOUR FIGHTER, the KAOTIC ARCADE mark) runs to about
     * y=145, and the highlighted game's name takes the last 50px, so the grid gets the 760px
     * between them: four 190px rows. Five 248px columns leave a 20px margin each side. This
     * is why the top logos did NOT have to be shrunk to fit a fourth row -- the old layout
     * simply started too high and used rows that were too tall.
     */
    private static final int COLS = 5;
    private static final int CELL_W = 248;
    private static final int CELL_H = 190;
    private static final int GRID_TOP = 140;

    /** The wash is clear above this and full below it, so the header art keeps its contrast. */
    private static final int WASH_FADE_FROM = GRID_TOP - 18;
    private static final int WASH_FADE_TO = GRID_TOP + 26;
    private static final int WASH_TOP = 0x7A000000;
    private static final int WASH_BOTTOM = 0x85000000;

    /** Corner-bracket geometry for the focused logo. */
    private static final int BRACKET_LEN = 34;
    private static final int BRACKET_THICK = 6;
    private static final int BRACKET_INSET = 8;
    private static final int BRACKET_COLOR = 0xFFFFD24A;

    /** Unfocused logos are held back a little so the focused one reads first. */
    private static final float DIM_ALPHA = 0.72f;

    private TextView nameLabel;
    private int page;

    private int drawableId(String name) {
        Resources r = getResources();
        return r.getIdentifier(name, "drawable", getPackageName());
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        page = getIntent().getIntExtra("page", 0);
        if (page < 0 || page >= GameRegistry.PAGES.length) {
            page = 0;
        }

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        // This page's own background if the build ships one, otherwise the home screen's.
        //
        // They are the same picture on the MvC2 cabinet and it has no bg_extra, so it takes the
        // fallback. The X-Men build needs the split: its wallpaper carries an X-Men '97 logo
        // that runs down to about y=350, which is below where this grid starts, so on this page
        // alone that logo is faded back into the sky. Doing it in the artwork rather than here
        // keeps this screen's drawing code the same on both cabinets.
        int bgId = drawableId("bg_extra");
        if (bgId == 0) {
            bgId = drawableId("bg");
        }
        if (bgId != 0) {
            root.setBackgroundResource(bgId);
        } else {
            root.setBackgroundColor(Color.BLACK);
        }
        root.setLayoutParams(new ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        // One page-wide wash under the grid, fading in from nothing so there is no visible
        // edge where it starts. Twenty logos have to read over the brightest part of the
        // character art; without this the pale ones (Garou, SF III) disappear into it. It is
        // deliberately gentle and deliberately full-width -- a per-logo scrim would just be
        // the boxes again.
        LinearLayout gridWrap = new LinearLayout(this);
        gridWrap.setOrientation(LinearLayout.VERTICAL);
        gridWrap.setGravity(Gravity.CENTER_HORIZONTAL | Gravity.TOP);
        gridWrap.setPadding(0, GRID_TOP, 0, 0);
        gridWrap.setBackground(new WashDrawable());
        LinearLayout.LayoutParams wrapLp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f);
        root.addView(gridWrap, wrapLp);

        GameRegistry.Game[] games = GameRegistry.PAGES[page];

        GridLayout grid = new GridLayout(this);
        grid.setColumnCount(COLS);
        // Rows follow the registry, so adding a game does not need a layout change.
        grid.setRowCount((games.length + COLS - 1) / COLS);
        LinearLayout.LayoutParams gridLp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        gridWrap.addView(grid, gridLp);

        // The highlighted game's title, once, under the grid. Twenty captions on the page
        // would be twenty more things covering the artwork; one that follows the selection
        // says the same thing and costs a single line.
        nameLabel = new TextView(this);
        nameLabel.setTextSize(16f);
        nameLabel.setTextColor(BRACKET_COLOR);
        nameLabel.setGravity(Gravity.CENTER);
        nameLabel.setShadowLayer(6f, 0f, 2f, Color.BLACK);
        nameLabel.setPadding(0, 2, 0, 2);

        LinearLayout footer = new LinearLayout(this);
        footer.setOrientation(LinearLayout.VERTICAL);
        footer.addView(nameLabel, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        if (GameRegistry.PAGES.length > 1) {
            footer.addView(buildPageDots(), new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        }
        root.addView(footer, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        ImageView firstTile = null;
        for (int i = 0; i < games.length; i++) {
            final GameRegistry.Game gm = games[i];
            ImageView iv = new ImageView(this);
            int resId = drawableId(gm.tile);
            if (resId != 0) {
                iv.setImageResource(resId);
            }
            iv.setScaleType(ImageView.ScaleType.FIT_CENTER);
            iv.setFocusable(true);
            iv.setFocusableInTouchMode(true);
            iv.setClickable(true);
            iv.setAlpha(DIM_ALPHA);
            iv.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    openControls(gm.id);
                }
            });
            iv.setOnFocusChangeListener(new View.OnFocusChangeListener() {
                @Override
                public void onFocusChange(View v, boolean hasFocus) {
                    v.setAlpha(hasFocus ? 1f : DIM_ALPHA);
                    v.setBackground(hasFocus ? new BracketDrawable() : null);
                    if (hasFocus) {
                        nameLabel.setText(gm.name);
                    }
                }
            });

            GridLayout.LayoutParams glp = new GridLayout.LayoutParams();
            glp.width = CELL_W;
            glp.height = CELL_H;
            glp.columnSpec = GridLayout.spec(i % COLS);
            glp.rowSpec = GridLayout.spec(i / COLS);
            grid.addView(iv, glp);

            if (i == 0) {
                firstTile = iv;
            }
        }

        setContentView(root);
        if (firstTile != null) {
            nameLabel.setText(games[0].name);
            firstTile.requestFocus();
        }
    }

    /** Dot size and gap, in px. Small on purpose -- this has to fit in the same slack the
     * name label already had; it isn't a new row so much as a second line under it. */
    private static final int DOT_SIZE = 12;
    private static final int DOT_GAP = 10;

    /** One dot per page, the current page's dot filled solid, the rest dim outlines. */
    private View buildPageDots() {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER);
        int pages = GameRegistry.PAGES.length;
        for (int p = 0; p < pages; p++) {
            View dot = new View(this);
            GradientDrawable gd = new GradientDrawable();
            gd.setShape(GradientDrawable.OVAL);
            if (p == page) {
                gd.setColor(BRACKET_COLOR);
            } else {
                gd.setColor(Color.TRANSPARENT);
                gd.setStroke(2, 0x99FFFFFF);
            }
            dot.setBackground(gd);
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(DOT_SIZE, DOT_SIZE);
            lp.leftMargin = p == 0 ? 0 : DOT_GAP;
            row.addView(dot, lp);
        }
        return row;
    }

    /**
     * The page wash: clear across the header, then a short fade to a steady dark tint behind
     * the grid.
     *
     * Written as a shader with explicit stop positions rather than a GradientDrawable because
     * GradientDrawable spaces its colours evenly, which on a 900px-tall view means the fade
     * takes hundreds of pixels -- it would still be brightening through the first row of logos
     * while already dimming the KAOTIC ARCADE mark above them. The fade has to be short and it
     * has to land in the gap between the two.
     */
    private static final class WashDrawable extends Drawable {

        private final Paint paint = new Paint();
        private int builtFor = -1;

        @Override
        public void draw(Canvas c) {
            Rect b = getBounds();
            if (b.height() != builtFor) {
                builtFor = b.height();
                float h = Math.max(1, b.height());
                paint.setShader(new android.graphics.LinearGradient(
                        0, 0, 0, h,
                        new int[]{0x00000000, 0x00000000, WASH_TOP, WASH_BOTTOM},
                        new float[]{0f, WASH_FADE_FROM / h, WASH_FADE_TO / h, 1f},
                        android.graphics.Shader.TileMode.CLAMP));
            }
            c.drawRect(b, paint);
        }

        @Override
        public void setAlpha(int a) {
            paint.setAlpha(a);
        }

        @Override
        public void setColorFilter(android.graphics.ColorFilter f) {
            paint.setColorFilter(f);
        }

        @Override
        public int getOpacity() {
            return android.graphics.PixelFormat.TRANSLUCENT;
        }
    }

    /**
     * Four yellow corner brackets, matching the selection marks the stock home screen draws
     * around the cabinet you have picked. Drawn rather than baked into a nine-patch so it
     * costs no drawable and tracks whatever cell size the grid ends up with.
     */
    private static final class BracketDrawable extends Drawable {

        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);

        BracketDrawable() {
            paint.setColor(BRACKET_COLOR);
            paint.setStyle(Paint.Style.FILL);
        }

        @Override
        public void draw(Canvas c) {
            Rect b = getBounds();
            int l = b.left + BRACKET_INSET, t = b.top + BRACKET_INSET;
            int r = b.right - BRACKET_INSET, o = b.bottom - BRACKET_INSET;
            int k = BRACKET_LEN, w = BRACKET_THICK;

            c.drawRect(l, t, l + k, t + w, paint);          // top-left
            c.drawRect(l, t, l + w, t + k, paint);
            c.drawRect(r - k, t, r, t + w, paint);          // top-right
            c.drawRect(r - w, t, r, t + k, paint);
            c.drawRect(l, o - w, l + k, o, paint);          // bottom-left
            c.drawRect(l, o - k, l + w, o, paint);
            c.drawRect(r - k, o - w, r, o, paint);          // bottom-right
            c.drawRect(r - w, o - k, r, o, paint);
        }

        @Override
        public void setAlpha(int a) {
            paint.setAlpha(a);
        }

        @Override
        public void setColorFilter(android.graphics.ColorFilter f) {
            paint.setColorFilter(f);
        }

        @Override
        public int getOpacity() {
            return android.graphics.PixelFormat.TRANSLUCENT;
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        // Direct path, independent of accessibility window events: this screen being up
        // always means a menu is on screen.
        MenuMusic.setMenuVisible(this, true);
    }

    private void openControls(String gameId) {
        Intent i = new Intent(this, ControlsActivity.class);
        i.putExtra("gameId", gameId);
        startActivity(i);
    }

    /**
     * Paging: pressing right past the last column of any row, or left past the first column,
     * flips to the next/previous page of GameRegistry.PAGES. Uses View.focusSearch() to ask
     * the framework directly whether a move in that direction is even possible -- it returns
     * null at a true boundary without touching focus -- rather than performing the move and
     * inspecting what changed, which is unreliable because focus changes are not guaranteed
     * to be visible synchronously right after the call that triggers them.
     */
    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (keyCode == KeyEvent.KEYCODE_DPAD_RIGHT || keyCode == KeyEvent.KEYCODE_DPAD_LEFT) {
            View current = getCurrentFocus();
            if (current != null) {
                boolean right = keyCode == KeyEvent.KEYCODE_DPAD_RIGHT;
                View candidate = current.focusSearch(right ? View.FOCUS_RIGHT : View.FOCUS_LEFT);
                if (candidate == null) {
                    int next = page + (right ? 1 : -1);
                    if (next >= 0 && next < GameRegistry.PAGES.length) {
                        goToPage(next);
                        return true;
                    }
                }
            }
        }
        return super.onKeyDown(keyCode, event);
    }

    private void goToPage(int newPage) {
        boolean forward = newPage > page;
        Intent i = new Intent(this, ExtraGamesActivity.class);
        i.putExtra("page", newPage);
        startActivity(i);
        finish();
        // Slides toward the side the player just pressed: paging right pulls the next page in
        // from the right while this one exits left, and back does the mirror of that. Anim
        // resource ids are looked up by name for the same reason drawables are (see
        // drawableId()) -- this class has no R.java in the decompiled APK it links into.
        int enter = getResources().getIdentifier(
                forward ? "page_slide_in_right" : "page_slide_in_left", "anim", getPackageName());
        int exit = getResources().getIdentifier(
                forward ? "page_slide_out_left" : "page_slide_out_right", "anim", getPackageName());
        if (enter != 0 && exit != 0) {
            overridePendingTransition(enter, exit);
        }
    }

    @Override
    public boolean onKeyUp(int keyCode, KeyEvent event) {
        if (keyCode == 104) { // P2 Start -> back to home
            finish();
            return true;
        }
        if ((keyCode >= 96 && keyCode <= 103) || keyCode == 23 || keyCode == 66) { // action button / DPAD_CENTER / ENTER -> confirm
            View v = getCurrentFocus();
            if (v != null) {
                v.performClick();
                return true;
            }
        }
        return super.onKeyUp(keyCode, event);
    }
}
