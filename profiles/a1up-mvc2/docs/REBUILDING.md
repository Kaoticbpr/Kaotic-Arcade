# Modding the 1Up "com.arcade" cabinet family

A technical guide to adding games to Android arcade cabinets built on the **1Up
`com.arcade` launcher family**, without root, without replacing the emulator, and without
breaking online play.

It is written to be handed to an AI coding agent (or a person) working on a *different*
cabinet in the same family. It describes the reasoning and the exact commands, not just
"run our script".

**Eleven APKs across seven cabinets were examined**; Part 12 is the full survey with each
one's emulator, ROM discovery, update route and API endpoint. Throughout, the worked
example is:

| | **Cabinet A — Sonic** |
|---|---|
| Hardware | Umido, MediaTek MT8168, Android 10, 1280×1024 |
| Launcher | `com.arcade` v202605072 |
| Emulator | separate APK `com.umido.oneupsonicmd17`, libretro PicoDrive |
| ROMs | `/sdcard/roms/` + `assets/games/games.xml` |

Cabinet A is fully modded, tested on hardware and shipping. **Every other cabinet named in
this document has only been analysed statically — none has been modified or run.** Where a
statement rests on a real device it says so; where it is inference from the bytecode, it
says that too.

---

## Part 1 — Is your cabinet in this family?

Pull the launcher off the device and fingerprint it:

```bash
adb shell pm path com.arcade
adb pull /system/app/<dir>/<name>.apk ./stock.apk

aapt dump badging stock.apk | head -3
apksigner verify --print-certs stock.apk
aapt dump xmltree stock.apk AndroidManifest.xml | grep -i sharedUserId
```

You are in this family if **all three** hold:

1. **`package: name='com.arcade'`**
2. **Signer SHA-1 = `27196e386b875e76adf700e7ea84e4c6eee33dfa`**, DN `CN=Android, O=Android` — the **public AOSP `platform` test key**
3. **`android:sharedUserId="android.uid.system"`**

Both example cabinets match all three despite being different hardware, different Android
versions, different emulators and six years apart in build date.

### Why point 2 is the whole ballgame

The vendor signed a system app with a key whose private half is published in AOSP
(`build/target/product/security/platform.pk8`). Anyone can produce an APK Android accepts
as an **update to that system app**. It installs into `/data/app`; the original in
`/system` is never touched, which is also your rollback.

Also check for defences (neither example cabinet has any):

```bash
# self-signature verification — a self-check would compare its own cert at runtime
grep -rn "GET_SIGNATURES\|Landroid/content/pm/Signature;" smali/ --include=*.smali
# self-checksum — an APK hashing its own file
grep -rn "getPackageCodePath" smali/ --include=*.smali
```

Across all eleven APKs the only `Signature` hit is AndroidX `FontsContractCompat`
(font-provider cert pinning, unrelated) and every `getPackageInfo` call is for version
display or crash reporting. **No integrity check, no anti-tamper, no root detection
anywhere in the family.** Verify this for
yourself before assuming it; a later firmware could add one.

---

## Part 2 — Prerequisites

Everything is a download; nothing needs a network at build time once fetched. Versions
below are the ones this work was done with — newer usually works, and where it does not,
it is called out.

### Runtimes

| What | Version used | Where |
|---|---|---|
| **JDK / JRE** (to run the jars) | Temurin OpenJDK 23 | https://adoptium.net/temurin/releases/ |
| **JRE 8** (for `rt.jar` + `jce.jar` only) | Temurin `jre-8.0.432.6-hotspot` | https://adoptium.net/temurin/releases/?version=8 |
| **Python 3** | 3.10.5 | https://www.python.org/downloads/ |
| **Pillow** (image work) | 12.1.0 | `pip install Pillow` |
| **bash** | Git Bash on Windows | https://git-scm.com/downloads |

You need **both** a modern JDK and a JRE 8. The modern one runs apktool/ecj/d8; the JRE 8
is there purely because ecj needs a Java 8 `rt.jar` on the bootclasspath (see below). You
do not need to run anything with Java 8.

### Android SDK pieces

Get the command-line tools, then use `sdkmanager` — this is far easier than hunting
individual downloads:

```bash
# https://developer.android.com/studio#command-line-tools-only
sdkmanager "build-tools;34.0.0" "platform-tools" "platforms;android-34"
```

| From the SDK | Used for |
|---|---|
| `build-tools/34.0.0/d8` | `.class` → `classes.dex` |
| `build-tools/34.0.0/zipalign` | 4-byte alignment before signing |
| `build-tools/34.0.0/apksigner` | v1 + v2 signing |
| `build-tools/34.0.0/aapt` | `dump badging` / `dump xmltree` when fingerprinting |
| `platforms/android-34/android.jar` | compile-time Android API for ecj |
| `platform-tools/adb` (1.0.41) | talking to the cabinet |

On Windows these are `.exe` / `.bat`; on Linux/macOS they are plain executables.

### Standalone jars

| Jar | Version | Direct source |
|---|---|---|
| **apktool** | 2.9.3 | https://github.com/iBotPeaches/Apktool/releases — docs at https://apktool.org/ |
| **ecj** (Eclipse batch compiler) | any 3.x | https://repo1.maven.org/maven2/org/eclipse/jdt/ecj/ |
| **baksmali** | 2.5.2 | https://repo1.maven.org/maven2/org/smali/baksmali/2.5.2/ |
| **dexlib2** | 2.5.2 | https://repo1.maven.org/maven2/org/smali/dexlib2/2.5.2/ |
| **smali util** | 2.5.2 | https://repo1.maven.org/maven2/org/smali/util/2.5.2/ |
| **guava** | 33.0.0-jre | https://repo1.maven.org/maven2/com/google/guava/guava/33.0.0-jre/ |
| **jcommander** | 1.82 | https://repo1.maven.org/maven2/com/beust/jcommander/1.82/ |

baksmali needs **all five** on its classpath — the last four are its dependencies and it
will not start without them:

```bash
java -cp "baksmali-2.5.2.jar;dexlib2-2.5.2.jar;util-2.5.2.jar;guava-33.0.0-jre.jar;jcommander-1.82.jar" \
     org.jf.baksmali.Main d classes.dex -o smaliout
```

(Use `:` instead of `;` as the classpath separator on Linux/macOS.)

### The signing key

The **AOSP platform test key** — the reason any of this works. Two files:

```
https://android.googlesource.com/platform/build/+/refs/heads/main/target/product/security/platform.pk8
https://android.googlesource.com/platform/build/+/refs/heads/main/target/product/security/platform.x509.pem
```

Grab the raw blobs (googlesource serves base64 of the file when you append `?format=TEXT`;
decode that). Verify you have the right pair before relying on them:

```bash
keytool -printcert -file platform.x509.pem | grep SHA1
# must be:  27:19:6E:38:6B:87:5E:76:AD:F7:00:E7:EA:84:E4:C6:EE:E3:3D:FA
```

If that fingerprint does not match the fingerprint on the APK you pulled off the cabinet
(Part 1), stop — your cabinet is signed with something else and none of this applies.

`apksigner` takes the `.pk8` and the `.x509.pem` directly; no keystore conversion needed.

### Optional

| Tool | Why | Where |
|---|---|---|
| **jadx** | reading decompiled Java to *locate* code. Never used to rebuild. | https://github.com/skylot/jadx/releases |
| **7-Zip** | packaging a distributable stick | https://www.7-zip.org/ |

### Two classpath traps that will cost you an hour each

- **The Maven `android.jar` has no `java.lang.*`.** ecj needs a real Java 8 `rt.jar`
  alongside it, and `jce.jar` too if your code touches `javax.crypto`:

  ```
  -bootclasspath "<jre8>/lib/rt.jar;<jre8>/lib/jce.jar;android.jar"
  ```

- **`com.android.tools.smali:*` artifacts 404 on Maven Central.** The smali project moved
  coordinates and the new ones are not published where you would expect. Use the older
  `org.smali:*` 2.5.2 coordinates listed above.

### Sanity check

Before starting, confirm each piece runs:

```bash
java -version
java -jar apktool.jar --version                 # 2.9.3
java -jar ecj.jar -version                      # Eclipse Compiler
java -cp "baksmali-2.5.2.jar;dexlib2-2.5.2.jar;util-2.5.2.jar;guava-33.0.0-jre.jar;jcommander-1.82.jar" \
     org.jf.baksmali.Main --version
d8 --version
apksigner version
adb version
python -c "import PIL; print(PIL.__version__)"
ls <jre8>/lib/rt.jar <jre8>/lib/jce.jar
keytool -printcert -file platform.x509.pem | grep SHA1
```

---

## Part 3 — The rebuild loop

Everything below is one full cycle. Automate it later; understand it first.

### 3.1 Decode

```bash
java -jar apktool.jar d -f -o work/launcher stock.apk
```

Gives you `work/launcher/smali*/`, `res/`, `assets/`, `AndroidManifest.xml`,
`apktool.yml`. Large APKs may produce `smali_classes2/`, `smali_classes3/` — a class can
be in **any** of them, so always search all of them.

**Decode from the pristine APK on every build.** Treat the decoded tree as disposable
output. Every modification must live in a script that reruns from scratch, or it will be
silently lost the first time someone re-decodes. This is the single most valuable habit
in this workflow.

### 3.2 Raise the versionCode

Edit `versionCode` in `work/launcher/apktool.yml` to **stock + N**, with N increasing on
every build. Two separate mechanisms require this:

**Reboot survival.** Both the original and your build exist: `/system/app/...` and
`/data/app/...`. On every boot PackageManagerService compares them and if the system
copy's versionCode is **greater than or equal to** yours, it deletes your update:

```
W PackageManager: System package updated; name: com.arcade;
                  202605072 --> 202605072;
                  /data/app/com.arcade-... --> /system/app/sonic
```

`adb install -r` happily accepts an equal versionCode, so the mod installs and runs
perfectly — until the first reboot. This is a genuinely nasty failure mode because
everything works during testing.

**The update route.** The launcher's own updater installs only a *strictly greater*
versionCode, so a fixed "stock + 1" installs once and then refuses forever. Use a
persistent counter, not a constant.

### 3.3 Write your changes in Java, not smali

Hand-written smali is where this goes wrong. Write a normal Java class, compile it, and
drop the resulting smali into the decoded tree. It can then be called from a one-line
smali patch.

```bash
# 1. compile
java -jar ecj.jar -source 8 -target 8 -nowarn \
     -bootclasspath "<jre8>/lib/rt.jar;android.jar" \
     -d javaout javasrc/com/arcade/game/Roster.java

# 2. dex
d8 --output dexout --min-api 21 --no-desugaring javaout/com/arcade/game/Roster.class

# 3. back to smali
java -cp "baksmali-2.5.2.jar;dexlib2-2.5.2.jar;util-2.5.2.jar;guava-33.0.0-jre.jar;jcommander-1.82.jar" \
     org.jf.baksmali.Main d dexout/classes.dex -o smaliout

# 4. install into the decoded tree, matching your package path
cp smaliout/com/arcade/game/Roster.smali work/launcher/smali/com/arcade/game/
```

`--no-desugaring` matters: desugaring pulls in support classes that will not resolve
inside the host APK.

**Never reference `R.something`.** Resource ids in your separately-compiled class will not
match the host APK's. Resolve at runtime:

```java
int id = c.getResources().getIdentifier("game_control_generic", "drawable", c.getPackageName());
```

Same for raw resources — `getIdentifier("yz_rom_104", "raw", pkg)`.

### 3.4 Patch the host's smali

Two techniques. Use the first wherever you can.

**(a) Replace a whole method.** Regex from `.method <exact signature>` to `.end method`
and substitute an entire body you wrote. Safe because you control every register in it.

```python
def replace_method(src, sig, body):
    pat = re.compile(r"^\.method " + re.escape(sig) + r"$.*?^\.end method$",
                     re.M | re.S)
    assert len(pat.findall(src)) == 1
    return pat.sub(".method " + sig + "\n" + body + "\n.end method", src)
```

**(b) Anchor on a literal and replace a span.** For edits inside a method you do not
control. Find a distinctive `const-string`, walk outward to the expression's boundaries,
replace between them.

```python
anchor = find_one(lines, 'const-string v9, "/storage/emulated/0/roms/"')
start = anchor
while "new-instance v8, Ljava/lang/StringBuilder;" not in lines[start]:
    start -= 1
end = anchor
while "move-result-object v8" not in lines[end]:
    end += 1
lines[start:end+1] = [
    "    invoke-static {v11}, Lcom/umido/raui/RomSrc;->resolve(Ljava/lang/String;)Ljava/lang/String;",
    "",
    "    move-result-object v8",
]
```

**Never match a multi-line block of instructions verbatim.** apktool interleaves `.line`
directives through the code and they shift whenever anything upstream changes. A patch
that matches literal text works once and breaks on the next build.

Make every patch **idempotent** — check for your own marker and return early:

```python
if any("RomSrc" in l for l in lines):
    print("already patched"); return
```

And **assert your assumptions**. `assert len(hits) == 1` turns a silent
wrong-site edit into a build failure. When a real variant had two call sites instead of
one, that assert is what caught it.

### 3.5 Register allocation — the one smali rule you must respect

Each method declares `.locals N` (or `.registers N`). Your injected instructions may only
use registers already available. Two safe habits:

- Reuse a register the surrounding code has already finished with (read the
  `.local` / `.end local` comments baksmali emits).
- Prefer replacing a span that already produced a value in register X with a call whose
  `move-result` also lands in X. The code after it keeps working unchanged.

If you need more registers, raise `.locals` at the top of that method — but be aware
`p0..pN` parameter registers sit *above* the locals, so raising `.locals` shifts nothing
but does add slots.

### 3.6 Build, align, sign

```bash
java -jar apktool.jar b work/launcher -o build/out-raw.apk
zipalign -p -f 4 build/out-raw.apk build/out-aligned.apk
apksigner sign --key platform.pk8 --cert platform.x509.pem \
    --v1-signing-enabled true --v2-signing-enabled true \
    --out build/out.apk build/out-aligned.apk
```

**Both v1 and v2 are required.** v1 (JAR signing) is what the system-app update path
checks; v2 is required by the target SDK. Signing with only one produces an APK that
either will not install or will not replace the system app.

Order matters: align **before** signing. apksigner preserves alignment; zipalign after
signing invalidates v2.

### 3.7 Install

```bash
adb install -r build/out.apk
```

If you get `INSTALL_FAILED_INSUFFICIENT_STORAGE` on a large APK, see Part 8.

---

## Part 4 — The three things you must locate in any variant

Class names differ between cabinets. The *shapes* do not. Find these three, and the rest
follows.

### 4.1 The ROM path builder

Where the launcher (or emulator) turns a game id into a file path.

```bash
grep -rn 'const-string.*"/storage\|const-string.*"/sdcard\|const-string.*roms/' smali*/ --include=*.smali
grep -rn 'yz_rom_\|openRawResource' smali*/ --include=*.smali
```

- **Cabinet A** builds `new StringBuilder("/storage/emulated/0/roms/").append(name)` inside
  the emulator's `EmulatorActivity`. Every game is pinned to one directory.
- **Every other cabinet** has no ROM directory in its code — games live in
  `res/raw/yz_rom_<id>.zip` with a companion `yz_init_<id>.init`, resolved by
  `ResUtil.getRawID(ctx, "yz_rom_" + id)`. They are still *extracted to a file* before use
  (`/mnt/sdcard/arcade/rom/`), which is the hook you want — see Part 5, Pattern 3.

Redirecting this is how a game gets to live anywhere you like — a USB stick, a different
folder. See Part 5.

### 4.2 The games table

The gameId → ROM mapping, and where it is read from.

```bash
grep -rn "games.xml\|assets/games" smali*/ --include=*.smali
```

- **Cabinet A** reads `assets/games/games.xml` from inside the APK once and caches it.
- **Every other cabinet** has no XML table; the id *is* the resource suffix, and richer
  metadata comes from the `Game` model (populated locally or from the shop API).

### 4.3 The CRC gate

```bash
grep -rn "CheckRom\|CheckRomListener\|ChecksumCRC32\|ROM_CRC" smali*/ --include=*.smali
```

Both cabinets share the same machinery: `com/arcade/api/check/CheckRom` hashes the ROM
file with `FileDownloader.ChecksumCRC32(path)` on a background thread and delivers the
result through `CheckRomListener.onCheckDone(JJ)V` — **an identical interface signature on
both**. The listener compares it to an expected value and refuses to launch on mismatch.

What differs is **where the expected value comes from**:

| | Expected CRC source | Verdict consumed in |
|---|---|---|
| Cabinet A | baked-in `ROM_CRC:[J` array field on the home activity | `SonicHomeActivity$checkRomListener` (inner class) |
| all others | `Game.romCrc` (a `String` field on the game model) | `NewHomeGameListView` |

This check exists so the launcher can self-heal a corrupted ROM from its own assets. It
is not anti-tamper. But a game you add has **no entry in the expected-CRC source**, so
every added game gets rejected until you deal with it.

---

## Part 5 — Adding games without touching the emulator

The goal is to add games while leaving the emulator binary, the online stack and the
existing games exactly as they are.

### Pattern 1 — redirect the ROM path (applies to every cabinet)

Replace the hardcoded path construction with a call into your own class:

```java
public static String resolve(String name) {
    if (name.startsWith("/")) return name;          // absolute passes through
    File in = new File(BASE + name);
    if (in.isFile()) return in.getAbsolutePath();   // internal storage
    String u = onUsb(name);                         // else look on a stick
    return u != null ? u : BASE + name;
}

private static String onUsb(String rel) {
    File[] vols = new File("/storage").listFiles();
    if (vols == null) return null;
    java.util.Arrays.sort(vols);
    for (File v : vols) {
        String n = v.getName();
        if ("emulated".equals(n) || "self".equals(n) || "sdcard0".equals(n)) continue;
        File f = new File(new File(v, "SonicCab"), "roms/" + rel);
        if (f.isFile()) return f.getAbsolutePath();
    }
    return null;
}
```

Walking `/storage` directly works without a `Context`. Where you have one, the tidier
route is `StorageManager.getVolumePaths()` / `getVolumeState()` by reflection — both
cabinets' own `Util` classes already do exactly that, so it is a supported path on this
firmware family.

### Pattern 2 — override the games table (Cabinet A)

The emulator read its gameId→ROM table from its own assets and cached it, so nothing could
be added at runtime. One anchor patch redirects it to a file the launcher writes:

```java
public static InputStream games(Context c) throws Exception {
    File f = new File("/storage/emulated/0/roms/games.xml");
    if (f.exists() && f.length() > 0) return new FileInputStream(f);
    return c.getApplicationContext().getAssets().open("games/games.xml");  // fallback
}
```

The launcher rewrites that file on every scan — bare names for built-in games, absolute
paths for external ones. **The baked-in copy stays as a fallback**, so the emulator still
works standalone if the launcher never runs. That fallback is worth keeping in any
variant: it means a half-installed mod degrades instead of bricking the menu.

### Pattern 3 — resource-backed ROMs (every non-Sonic cabinet)

At first glance these cabinets look unmoddable: their games are `res/raw/yz_rom_<id>.zip`
resources, with no ROM directory to redirect. **They are not.** The launcher extracts each
resource to a real file before the emulator ever sees it:

```
ResUtil.getRawID(ctx, "yz_rom_" + id)      # resource id by name
  -> Resources.openRawResource(id)         # InputStream
  -> new FileOutputStream(filepath)        # -> /mnt/sdcard/arcade/rom/<id>
  -> the emulator loads that FILE
```

So the property the whole mod depends on — *the emulator loads a game from a filesystem
path* — holds on every cabinet in the family. Find the extraction site and prefer an
external file when one exists:

```bash
grep -rn "openRawResource" smali*/ --include=*.smali | grep -v support/v
grep -rn "yz_rom_" smali*/ --include=*.smali | grep -v 'R\$raw'
```

On the TMNT build the call sites are in `view/newhome/gamelist/NewHomeGameListView`,
`view/newhome/gamelist/horizontal/HorizontalGameListView` and
`view/home/local/LocalGamePagerView`, with the target directory built in `util/Util`.

Prefer patching the *lookup*, not the resources. Adding new `res/raw/yz_rom_<id>` entries
means apktool must recompile resources and you inherit any risk of id renumbering — and
you would still have to extend whatever table maps menu entries to ids. Redirecting the
extraction is one anchor patch and touches nothing else.

**Watch the directory constants.** These builds use fixed literals like
`/mnt/sdcard/arcade/rom/` and `/mnt/sdcard/arcade/snes/`. Despite the name, `/mnt/sdcard`
is **internal storage** — on real hardware it resolves
`/mnt/sdcard -> /storage/self/primary -> /mnt/user/0/primary`, the same `/data/media`
filesystem as `/storage/emulated/0`. Removable media mounts separately at
`/storage/XXXX-XXXX`. A fixed `/mnt/sdcard/...` path will never see an inserted stick or
SD card, so if you want USB you must add the volume walk from Pattern 1 yourself.

### What you do *not* need to do

You do **not** need to install another emulator APK. Cabinet A already had a libretro
PicoDrive core covering the whole Mega Drive / Sega CD / 32X range, and the `libyzvs.so`
cabinets already carry MAME, FinalBurn and Genesis in one binary. Adding a game means giving the *existing* emulator a new file —
not shipping a new emulator. Cabinet A's launcher does install one companion APK, but that
is *its own rebuilt emulator*, carried in `assets/` and installed on first run so a single
file delivers both halves. It is not a second emulator.

### A note on cores — check before you add one

**Find out what the cabinet already emulates first.** Scan each native library for
system-specific symbols:

```bash
# per .so in lib/armeabi-v7a/, look for what it carries
grep -c "picodrive\|megadrive\|YM2612" lib.so     # Genesis
grep -c "neogeo\|cps1\|cps2\|romset"  lib.so     # MAME-family arcade
grep -c "FinalBurn\|burn_drv"           lib.so     # FinalBurn
grep -c "snes9x\|SPC700"                lib.so     # SNES
grep -c "retro_run\|retro_load_game"    lib.so     # libretro API
```

(Use a Python regex over the raw bytes — `strings` may not work, see Part 9.)

Every cabinet in this family carries more emulation than it exposes. The `libyzvs.so`
cabinets (TMNT, Ridge, Simpsons) already contain **MAME + FinalBurn + Genesis**. Cabinet
A's launcher ships a 32 MB `libfba.so` covering **MAME, FinalBurn, SNES, Genesis, Sega CD
and NES** that the mod never touches. Adding a game is usually a ROM problem, not an
emulator problem.

**Swapping a core is only possible on Cabinet A.** Its `libraui.so` resolves the standard
`retro_*` entry points out of `picodrive_libretro_android.so` **by filename** via `dlsym`,
making it a generic libretro frontend — any libretro core renamed to that filename loads
(verified by building a Genesis Plus GX variant). No other cabinet's emulator exports or
imports `retro_*` at all; they are monolithic binaries with no plugin interface.

Even where you can, do not swap a core to gain one feature — it changes behaviour for
every existing game. Check the stock core first; ours already did what we needed.

---

## Part 6 — Neutralising the CRC gate without disabling it

The wrong fix is to rip the check out. The right fix is to make it **skip only the games
that have no expected value**, so a corrupt stock ROM is still caught.

### Variant 1: the expected CRC is a baked-in array (Sonic)

Stock smali, in the listener:

```smali
iget-object vN, p0, ...$checkRomListener;->this$0:...HomeActivity;
# ... reads ROM_CRC[gameId] ...
    ->ROM_CRC:[J
cmp-long vX, vA, vB
if-nez  vX, :cond_N          # values differ -> reject
```

The patch locates the single `->ROM_CRC:[J` read, walks back to the `this$0` load that
starts the lookup, walks forward past `cmp-long` to the `if-nez`, and replaces that entire
span — lookup, comparison and branch — with a call into Java:

```smali
iget-object p4, p0, ...$checkRomListener;->this$0:Lcom/arcade/activity/SonicHomeActivity;
invoke-static {p4}, Lcom/arcade/activity/SonicHomeActivity;->access$900(...)I
move-result p4
invoke-static {p4, p1, p2}, Lcom/arcade/game/Roster;->crcOk(IJ)Z
move-result p3
if-eqz p3, :cond_N
```

```java
public static boolean crcOk(int gameId, long actual) {
    long expected = romCrc(gameId);
    return expected < 0L || expected == actual;   // -1 == no expected value, accept
}
```

**Two things to get right, both of which will silently reject every game if you miss
them:**

1. **The branch sense inverts.** `cmp-long` + `if-nez` branched to the failure label when
   the values *differed*. `crcOk` returns `true` when they *match*. So the branch must
   become `if-eqz`.
2. **`access$900` is a synthetic accessor** the compiler generated to let the inner class
   read the outer class's gameId field. Its number is specific to this build — find yours
   by grepping the inner class for `access$` and checking what each returns.

There is often a **second, separate guard** on the id range. Cabinet A had:

```smali
const/4 p4, 0x4
if-gt p3, p4, :cond_4        # gameId > 4 -> reject
```

Widened to `const/16 p4, 0x7fff`. Search for small `const/4` comparisons against the game
id near the check; a variant with more stock games will have a different constant.

### Variant 2: the expected CRC is a model field (Marvel, XvS and the rest)

On every other launcher examined there is **no `ROM_CRC` array at all**. The expected
value is `Game.romCrc`, a `String` field on the game model (populated locally or from the
shop API), and the verdict is consumed in the game-list view — `NewHomeGameListView` on the
builds checked, not in an inner class of the home activity.

The same principle applies, but the hook moves: make an empty or absent `romCrc` mean
"accept". Patch at the comparison site in the view, **not** in `CheckRom` — `CheckRom` only
*computes* the hash on a background thread and hands it to the listener; it does not judge
it. This has not been done on hardware; the shape is from bytecode only.

### Keep the hashing

Do not remove the `ChecksumCRC32` call. Hashing every ROM on a large external library at
every launch would make startup crawl, so store `-1` for added games and let `crcOk`
short-circuit *before* any comparison — but the stock games still get hashed and checked
exactly as before.

---

## Part 7 — Preserving online play

This is the single most common way a cabinet mod goes wrong, and it is worth understanding
before you touch anything. **People who flash another cabinet's launcher lose online play,
and this is why.**

### How a cabinet identifies itself online

Every launcher in the family reads a hardware serial from the character device
**`/dev/swdevice`** — surfaced in Settings as "Serial #:", falling back to the literal
`1UPTESTID00001` when the node cannot be read. That serial is attached to **every single
API call**. On the TMNT launcher alone it is read by:

```
api/auth/QueryAuth              api/autoregister/QueryAutoRegister
api/guestregister/QueryGuestRegister    api/startlogin/QueryStartLogin
api/allplayerinfo/QueryUserAll  api/loginstates/QueryLoginStates
api/buy/QueryBuyInfo            api/consume/QueryConsume
api/rank/QueryRank              api/rank/QueryCoopRank
api/report/alive/QueryReportAlive       api/report/start/QueryReportGameStart
api/game/QueryGameList          api/product/QueryProduct
api/screensaver/QueryScreenSaver        api/oneupupdate/OneUpUpdate
```

### Every cabinet model talks to its own backend

The serial is registered on **its own model's server**, and each model ships a different
API base URL:

| Launcher | Primary API base |
|---|---|
| XvS, Marvel | `https://52.52.162.195/api/vsjj_oneup/` |

Every non-Sonic build also carries `https://47.254.82.31/api/vsjj_oneup/` as a second
endpoint.

### So: why online dies

Flash the Simpsons launcher onto a TMNT cabinet and nothing about the hardware changes —
`/dev/swdevice` still returns the same serial. But the launcher now asks
`/api/new_simpson/` instead of `/api/tmnt/`. **That server has never heard of this
cabinet.** Auth and registration fail, so there are no accounts, no leaderboards, no
online matches. The cabinet is not "de-authorised" — it is talking to the wrong server.

**The rule that follows is the most important one in this document:**

> **Always start from the APK you pulled off the cabinet you are modding. Never
> cross-flash another model's launcher.**

Modding your own cabinet's launcher keeps the API base untouched, so online keeps working.
That is exactly what was done on Cabinet A, which still authenticates normally after the
mod.

If someone has already cross-flashed and lost online, the fix is to go back to their own
model's launcher — not to patch URLs. Pointing a cabinet at a backend it is not registered
with will not make it register.

### What to leave alone when patching

**Touch only the local roster, ROM-path, artwork and CRC paths. Never touch
`com/arcade/api/**`.**

On Cabinet A the mod changes the roster arrays and paging, ROM path resolution, the
games-table source, the CRC comparison, the control-screen image lookup and the
update-prompt guard — and changes **nothing** in `api/auth`, `api/login`, `api/game`,
`api/download`, `api/buy`, `api/charge`, `api/coininfo` or the HTTPS stack.

Specific traps:

- **Keep the launch extras.** Games start with `game_id`, `game_mode`, `user_id` and
  `login_token`; the last two come from `API.getUserID()` / `API.getmLoginToken()` and are
  how the server attributes a session. When you rewrite the launch path, pass them through
  unchanged. Dropping them because local play does not need them is the quiet way to break
  online.
- **Never renumber existing gameIds.** Server records, saves and entitlements are keyed by
  id. Add new games *above* the stock range. Cabinet A pins ids 1–4 permanently.
- **Never change the API base URL**, even to a model that looks similar.
- **Do not strip the `INTERNET` permission** or delete API classes to slim the APK.
- **Widening an id guard is safe; narrowing one is not.**
- **Do not alter shop or entitlement gates.** Adding your own games alongside is fine;
  changing the gate desyncs you from the server.

Sanity check before shipping: confirm the online menu still authenticates and a stock
online-capable game still launches.

## Part 8 — Installing and distributing

### The update file format (family-wide)

Both cabinets contain `com/arcade/api/oneupupdate/OneUpUpdateFileUtil` with **byte-for-byte
identical crypto**:

```
cipher : AES/CFB/NoPadding
key    : PBKDF2WithHmacSHA1(seed, salt = seed bytes, 1000 iterations, 256 bit)
seed   : "R5OKtDvDSPkVIpeZ"
iv     : blockSize zero bytes
stream : 1024-byte chunks, each passed through doFinal()   <-- NOT update()
```

That last line is the whole trick. The vendor calls `doFinal()` per chunk, so **every
1024-byte block restarts CFB from the zero IV**. Implementing it with `update()` produces
a file the cabinet rejects. Ciphertext length equals plaintext length exactly, which is
also a useful property (see below).

A ~70-line Java reimplementation encrypts an APK into the vendor's format and decrypts it
back byte-identically. Because the seed and algorithm are shared, **the same tool works on
both cabinets.**

### Where the cabinet looks for it — this is what varies most

Nine APKs from this family were surveyed. **Only one has a USB update path.**

| Launcher | Version | Local update file | USB route? | Softmod difficulty |
|---|---|---|---|---|
| **Sonic** | 202605072 | `SonicUpdate.state` at a **USB root** | **yes** | **easy — stick only** |
| TMNT (`turtle`) | 202106171 | `/mnt/sdcard/arcade/update/update_aes.aes` | no | adb needed |
| Simpsons | 202107291 | same | no | adb needed |
| Ridge Racer | 202109221 | same | no | adb needed |
| 1Up V1.3.5 | 202208041 | same | no | adb needed |
| XvS | 1912312419 | same | no | adb needed |
| Marvel (MvSC) | 1912312417 | same | no | adb needed |
| BigBlue | 202203251 | same | no | adb needed |
| SF2CE 2022 (Yoga) | 202208091 | same | no | adb needed |
| **MvC2** | 202211091 | same | no | **special case — Rockchip + vendor key; see Part 12** |

**Do not be fooled by `MEDIA_MOUNTED`, and do not look for `StartupReceiver`.** Every
launcher registers `MEDIA_MOUNTED`, almost always from `com/test/OneUpSDCardTestActivity`
and `com/test/OneUpUSBATestActivity` — factory hardware-test screens that print "Read TF
card data successfully" and have nothing to do with updating.

`StartupReceiver` is a red herring too. The boot log line

```
D StartupReceiver: media is mounted to '/storage/B009-A7B0'. To check local update.
```

comes from **`com.fjtech.ComAssistant`**, a separate vendor app present on the device
whatever launcher is installed — the string does not appear in any launcher APK, including
Sonic's.

The real discriminator is **a `MEDIA_MOUNTED` receiver that is not under `com/test/`**,
paired with a `.state` filename built onto a *volume* path:

```bash
# the receiver classes, minus factory test code
grep -rl "MEDIA_MOUNTED" smali*/ --include=*.smali | grep -v "com/test/"
# Sonic is the only one with a hit: SonicHomeActivity$SdStatusReceiver
grep -rhoE '"[A-Za-z0-9_]{3,30}\.(state|aes)"' smali*/ --include=*.smali | sort -u
```

**Watch out for save-states.** A `.state` filename is not automatically an update file.
MvC2 contains `mvsc2u.state`, which looks like a sibling of `SonicUpdate.state` until you
see the path: `/sdcard/flycast/data/mvsc2u.state` — Flycast's save slot for the MvC2 ROM.
Check what directory the name is joined to. Sonic's is built as
`<mounted volume> + File.separator + "SonicUpdate.state"`, which is what makes it a USB
route; a fixed emulator data directory is not.

`tools/survey_apk.py` applies all of this automatically.

**What this means practically.** On a Sonic cabinet an end user can install a mod with
nothing but a USB stick — no PC, no cables, no developer mode. On every other cabinet in
this family they will need adb, which means enabling developer options first. If you are
writing install instructions, that difference decides how the whole thing is packaged.

You *can* add a USB route to a variant that lacks one — you have the launcher in smali and
the crypto below is shared family-wide — but it is a chicken-and-egg problem: installing
the launcher that adds the USB route still needs adb the first time. It only pays off if
you expect to ship repeated updates.

### Suppressing the endless re-prompt

The stock updater offers the upgrade whenever the file **merely exists**. There is no
version comparison anywhere in that path, so a stick left in the cabinet prompts on every
boot forever, including after installing.

Because the `.state` is a stream cipher of the APK, its length equals the APK's length
exactly — which gives a cheap check that needs no decryption:

```java
public static boolean updateNeeded(Context c, File state) {
    long self = new File(c.getPackageCodePath()).length();
    return self > 0L && self != state.length();
}
```

Patch the `File.exists()` guard in front of `showUpdateDialog(File)` to call this instead.
**Find every call site** — Cabinet A had two (the boot path and a factory-test path), and
patching only the obvious one leaves the prompt alive on the other.

### INSTALL_FAILED_INSUFFICIENT_STORAGE

A large launcher (Cabinet A's is 127 MB) needs roughly twice its size free. Two real
causes, in order of likelihood:

1. **Orphaned install staging in `/data/app`** from earlier failed installs. Only
   PackageManager reaps these, and only on boot. On Cabinet A, `adb reboot` took free
   space from **391 MB to 1.5 GB**. If free space has been *falling* across repeated
   attempts, this is your problem — reboot before deleting anything.
2. The existing update genuinely occupying the space. `pm uninstall-system-updates
   com.arcade` reverts to `/system` and frees it; install immediately after.

---

## Part 9 — Emulator capabilities you may already have

Before adding anything, find out what the stock emulator can already do. On Cabinet A
this was worth several days.

The libretro PicoDrive core supports **CD-audio enhanced cartridges in three formats** —
MSU-MD, MD+/MegaSD, and Mega CD Mode 1 — all of which ship as a group of files:

```
X.cue        <- load THIS
X.md         the cartridge
X.bin        or a pile of "Track NN.wav"
```

**You must load the `.cue`, not the `.md`.** Load the ROM directly and the game either
prints its own refusal screen ("This game requires an NTSC system and CD hardware") or
plays silent. This is documented behaviour, not a hack. Any scanner you write should rank
launch candidates:

```
.cue  >  .chd  >  .md / .gen / .smd / .32x  >  .bin
```

and group files by base name so a package becomes one menu entry, not three. Additionally,
**a directory containing a `.cue`/`.chd` must treat every `.bin` in it as payload** — a
disc's tracks are often named unlike its sheet (`Sonic CD (USA) (Track 02).bin`), and
grouping by base name alone turns one game into twenty.

Two lessons from getting this wrong twice:

- A `strings` scan of the core reported no MSU support. **`strings` was returning zero
  lines for every input** in that environment, including for text known to be present.
  Always sanity-check a search tool against a known-present string before trusting a null
  result.
- Two games were written off as hanging on a black screen based on a single screenshot at
  a fixed delay. Both were mid-intro and run fine. **Sample several frames over time**;
  one frame is not a boot test.

Audio cannot be verified over adb at all. Only a human at the cabinet can confirm it.

---

## Part 10 — Practical notes on driving the cabinet

- **Key activities are usually not exported**, and `adb shell` is uid 2000 without
  `START_ANY_ACTIVITY`, so `am start -n com.arcade/.activity.HomeActivity` is always a
  permission denial. The launcher is the **home app**, so restart it with
  `adb shell input keyevent 3`. Get this wrong and you force-stop the launcher, leave the
  cabinet with none running, and keep screenshotting the *previous* instance — which
  invalidates every test you run afterwards.
- Look for an **exported** activity to launch a game directly for testing. On Cabinet A the
  emulator's `MainActivity` is exported and takes the same extras the launcher passes.
- The controls screen may swallow every synthetic key (Cabinet A's `dispatchKeyEvent`
  returns `true` unconditionally), so you cannot dismiss it over adb.
- Verify state from data, not from the screen: package versionCode and `codePath`
  (`/system/...` vs `/data/app/...`) tell you what is actually installed.

### Windows / Git Bash specifics

- Git Bash rewrites `/system/...` into `C:/Program Files/Git/system/...`. Set
  `export MSYS_NO_PATHCONV=1` in every script.
- `adb shell` consumes stdin — any `adb` call inside a `while read` loop needs `</dev/null`
  or the loop eats its own input.
- adb output has CRLF; pipe through `tr -d '\r'` before comparing.
- Some shells mangle backslash escapes inside heredocs — a `"\\r"` can arrive as a literal
  CR. Build such strings from `chr()` / `bytes([...])`, or write files with an editor tool
  rather than a heredoc.

---

## Part 11 — Suggested project layout

```
apk/            pristine APKs pulled from the device. Never edited.
work/           apktool output. Disposable, recreated every build.
javasrc/        your Java classes
tools/          every script that transforms apk/ into build/
build/          signed output
staging/        payloads (USB contents, update files)
```

The build script should run end to end from `apk/` with no manual step, in this order:

1. decode both APKs from `apk/`
2. bump versionCode
3. generate any data files and your Java sources from a single roster definition
4. compile Java → dex → smali → inject
5. patch the host smali
6. generate artwork
7. build, align, sign
8. package the update file / payload

Keeping one roster definition as the source of truth — game ids, ROM filenames, display
names, artwork, CRCs, page layout — is what stops these from drifting apart. Everything
else is generated from it.

---

## Part 12 — Every APK surveyed

Eleven APKs examined. **Only Cabinet A (Sonic) has been modified and run** — everything
about the others is static analysis and has not been tested on hardware.

### Launchers

All are package `com.arcade`, all signed with the AOSP platform key
`27196e386b875e76adf700e7ea84e4c6eee33dfa`, all `sharedUserId="android.uid.system"`, and
none contains a self-signature or self-checksum check.

| Launcher | Version | Signer | API base | Emulator libs | ROM discovery | USB |
|---|---|---|---|---|---|---|
| Marvel (MvSC) | 1912312417 | AOSP | `52.52.162.195/api/vsjj_oneup/` | `libarcade.so` 791 KB + `libsnes.so` | same | no |
| XvS | 1912312419 | AOSP | `52.52.162.195/api/vsjj_oneup/` | `libarcade.so` 791 KB + `libsnes.so` | same | no |

Observed slugs, which must agree across the API base, the OTA script
(`version_yz_jj_oneup_<slug>_v4.php`) and chip registration
(`chip_reg_api_<slug>_oneup.php`): `sonic`, `tmnt`, `simpson`, `ridgeracer`, `mvsc`,
`xmvsf`, `bigblue`, `sf2ce2022red`, `mvc2`. **MvC2 breaks the naming pattern** — its OTA
script is `version_yz_jj_oneup_mvc2.php` with **no `_v4` suffix**.

### MvC2 — the Rockchip exception (and the root path around it)

MvC2 is the one cabinet in the family that is **not** softmoddable the way the rest are,
and the only one built on a **Rockchip RK3399** — Android **7.1.2, API 25** (build
`rk3399_all` / `NHG47K` / `user.mhf.20221013`), not 7.0/API 24 as first recorded — rather
than the MediaTek/other SoCs the AOSP-signed cabinets use.

> **Verified on hardware 2026-09-03.** This section was written from static analysis with
> no MvC2 unit available. It has since been probed over adb on a real cabinet (serial
> `524B4D00008987`), and **five of its six open questions are now answered — several
> against the original reasoning.** Corrections are marked ✅ confirmed / ❌ was wrong.
> The one item still untested is whether the boot image repacks and reflashes cleanly (Q4).

Two findings dominate everything below, and neither was known when this was first written:

- ❌ **SELinux is not enforcing.** `getenforce` returns `Permissive`, and
  `ro.boot.selinux=permissive` makes it permissive from boot, every boot. The MAC gate that
  the whole root argument below was built around **does not exist on this build.**
- ❌ **`/dev/swdevice` does not exist on this cabinet.** `/dev` carries only `sw_sync`, an
  unrelated kernel fence node. The hardware serial is in `ro.serialno` (`524B4D00008987`).
  Whatever `V1.0.27` did, this firmware has no such node.

The analysed APK is also stale: this doc examined `MvC2_V1.0.27.apk`, but a stock cabinet
self-updates to **`V1.0.64`** (versionCode `202401241`, 276 MB) at
`/data/app/com.arcade-1/base.apk` — world-readable and pullable over adb.
**Rebuild from V1.0.64, not V1.0.27.**

**Why the normal approach fails.** Two independent walls:

1. **Not the AOSP platform key.** `MvC2_V1.0.27.apk` is signed
   `41791c9b8faf15e1acd5aaf59210fd42467d8277` — a **vendor-private** key (generated Dec
   2014, 2048-bit RSA, modulus `A1D8F059…`). Its certificate DN is byte-identical to the
   AOSP one (`EMAILADDRESS=android@android.com, CN=Android, …`), and its modulus matches
   **none** of the four public AOSP test keys (platform `9C780592…`, testkey `D6931904…`,
   shared `C8C2DBFD…`, media `AE250C5A…`), nor any indexed leaked-key set.
   **Always compare the SHA-1/modulus, never the DN — the DN is a decoy on every cabinet.**
   Without that private key you cannot produce an update Android accepts for `com.arcade`
   on that cabinet, and a rebuilt app cannot keep `android.uid.system` (PackageManager
   enforces the shared-UID signature match at scan time — being in `/system` does not waive
   it, and neither does root).

2. **The headline game is a second APK on a different ABI.** MvC2 bundles
   `assets/apks/mvc2.apk` — `com.flycast.emulator` v17, a 22 MB `libflycast.so`,
   **arm64-v8a only** — while the launcher is armeabi-v7a only. One `primaryCpuAbi` per
   app means they can never merge; the floor is two APKs, which is the vendor's own design.

**Why online specifically breaks on a plain rebuild — ❌ superseded.** The original
argument ran: the backend identifies a cabinet by a serial read from `/dev/swdevice`; that
node is DAC-open (`crwxrwxrwx`) so the only thing gating it is **SELinux MAC** (label
`swdevice_device:s0`); a rebuild that loses `android.uid.system` drops to `untrusted_app`,
is denied the node, falls back to the literal `1UPTESTID00001`, and online dies.

**On this cabinet no link in that chain holds.** There is no `/dev/swdevice`, and SELinux is
permissive — so there is no MAC gate to be denied by in the first place. A resigned,
non-system-UID rebuild is **not** blocked from reading anything DAC permits.

That does not mean online works. It means *the reason given here was wrong*. Online is dead
signature costs you `android.uid.system` and its privileged permissions — but on this
build it costs you **nothing** via SELinux. **The CRC and USB-scan patches remain harmless.**

#### The root path (RK3399) — ❌ largely unnecessary, and the escape hatch is closed

This section argued root was *the practical way in* for MvC2, because it was the only way to
open the SELinux gate on the serial node. **That justification is gone** (see above). In
particular:

- ❌ **The sepolicy patch is a no-op.** `allow untrusted_app swdevice_device:chr_file
  { read open };` changes nothing against a permissive kernel, and there is no node to
  label. Strike it.
- ❌ **`setenforce 0` is a no-op** for the same reason — it is already permissive.
- ✅ **dm-verity is OFF.** `/system` mounts straight off
  `/dev/block/platform/fe330000.sdhci/by-name/system`, *not* a `dm-0` device. `/verity_key`
  and the `verity_mode` partition (`mmcblk1p12`) exist but are unused. Nothing has to be
  defeated to modify `/system` — only mounted rw.
- ✅ **`/system/priv-app` placement really does do nothing**, exactly as warned. And on
  API 25 the `privapp-permissions*.xml` allowlist **is not enforced at all** (enforcement
  begins at API 26); none exist in `/system/etc/permissions/`. Adding one is a no-op.
  No file on disk grants a shared UID.

**What root is still good for: permanent ADB.** That is now its entire value — a real one,
but far smaller than this section originally implied.

**How to get it (no Magisk, no `su` binary).** Because the kernel is already permissive you
do not need a root manager at all. Patch three lines in the boot ramdisk's `default.prop`:

```
ro.secure=0
ro.debuggable=1
ro.adb.secure=0
```

`ro.secure=0` makes adbd run as root outright; `ro.adb.secure=0` removes the RSA
authorisation prompt entirely. Add an init `.rc` stanza forcing `sys.usb.config=adb` so ADB
does not depend on the `persist` value in `/data`. That is the whole root story here.

**❌ The no-root delivery route is closed.** Q5 hoped MvC2's recovery might trust the public
AOSP testkey, which would let a testkey-signed `update.zip` deliver a modified `/system`
with no root at all. It does not. `/system/etc/security/otacerts.zip` holds a single cert,
`notBefore Dec 23 06:44:08 2014`, SHA-1
`9C:66:40:20:9F:F5:E7:1C:38:BB:2D:A5:ED:63:6A:46:9D:ED:9E:DD` — **not** the public testkey
(`27:19:6E:38:…`). It was minted **27 seconds after** the platform key (`06:43:41`, same
day): the vendor generated the entire key set in one `make_key` batch, which is also why
its DN looks AOSP-identical. Recovery is vendor-locked too, so **`rkdeveloptool` plus a
patched boot image is the only route to `/system` on this cabinet.**

**⚠ `/system` has no room for an in-place APK swap.** `mmcblk1p10` is 1499760 KB with only
**127608 KB free (91% full)**, against a 249 MB `/system/app/mvsc2/mvsc2.apk` plus 17 MB of
oat. You cannot stage a replacement beside the original, so there is no atomic swap and no
rollback mid-operation. Either delete-then-push and accept the window, or rebuild
`system.img` offline and flash it. `/data` has 4.2 GB free — installing a renamed clone
there is far safer, and is exactly what the bigblue/yoga mod already does.

**The `INSTALL_PACKAGES` gap — ✅ mostly moot in practice.** The launcher installs its
bundled Flycast APK via `INSTALL_PACKAGES`, which an ordinary-signed app will not be
granted. But `com.flycast.emulator` is **already installed** on a stock cabinet
(`/system/app/flycast/flycast.apk`), so a clone that never needs to install it still
launches it fine via `Intent.setClassName`. Only a factory-reset or flycast-less unit would
need a manual `pm install`. The remaining privileged permissions (`REBOOT`, `SET_TIME`,
`MASTER_CLEAR`) are conveniences, not needed for play.

#### What was confirmed on the actual MvC2 cabinet (2026-09-03)

Probed over adb on serial `524B4D00008987`. Five of six answered; Q4 remains open.

| # | Question | Answer |
|---|---|---|
| 1 | Does `sys.rkadb.root` grant root? | ❌ **No.** The property *accepts* the write (`setprop sys.rkadb.root 1`, `getprop` returns `1`) but is inert on a `user` build — `adb root` still returns *"adbd cannot run as root in production builds"* and `id` stays `uid=2000(shell)`. `ro.secure=1`, `ro.debuggable=0`, no `su` anywhere. |
| 2 | Is SELinux enforcing, and can root change it? | ❌ **Already `Permissive`**, from `ro.boot.selinux=permissive`. Nothing to change. |
| 3 | swdevice label and app-domain rule? | ❌ **No `/dev/swdevice` on this build** — only `sw_sync`. Shell's own domain is `u:r:shell:s0`. Serial is `ro.serialno`. |
| 4 | Boot image repackable with a stock RK3399 toolchain? | ⏳ **Still untested** — the one genuinely open item. `boot` is `mmcblk1p6` (32768 KB). Note this layout also carries a **separate `kernel` partition** (`mmcblk1p5`, 24576 KB), so boot.img here is essentially the ramdisk container. |
| 5 | Does recovery trust the public AOSP testkey? | ❌ **No — vendor-private.** See the otacerts detail above. The no-root `update.zip` route is closed. |
| 6 | *(new)* Can boot.img be dumped over adb? | ❌ **No.** `shell` gets `Permission denied` on `dd if=…/by-name/boot`, and there is no root. Chicken-and-egg: read it with `rkdeveloptool rl` in loader mode instead. `adb reboot loader` works as plain shell — reboot is not privileged. |

**⚠ The entry problem — the actual hard part of distributing this.** `/default.prop` ships
`persist.sys.usb.config=none`, and the live persist value lives in `/data/property`. A
stock, never-touched cabinet therefore exposes **no ADB over USB at all**. Everything above
presupposes adb access you do not yet have. Entry is either the one-time on-screen escape
into developer settings, or hardware maskrom entry on the RK3399 board. Once a patched boot
image is flashed, `ro.adb.secure=0` makes ADB permanent and prompt-free from then on — but
that first step is unavoidable, and should be stated honestly to anyone following this.

**✅ USB scanning needs none of this.** Pattern 1's volume walk reads `/storage`, which is
`drwxr-xr-x root root` — listable by any app — and needs only `READ_EXTERNAL_STORAGE`,
which `com.arcade` already requests. The factory `OneUpUSBATestActivity` already enumerates
sticks successfully on this firmware via `StorageManager.getVolumes()` reflection, and
`android.hardware.usb.host.xml` is present with vold managing `/mnt/media_rw`. So the
USB-scan mod is a plain userspace patch on a resigned clone: **no root, no `/system`, no
sepolicy, no permissions file.**

#### Advanced / theoretical: one app, per-game online endpoint switching

A natural extension of the root path is to bundle **every** cabinet's ROMs into one
launcher and switch the online backend per game, so a single unit could play any title
online against that title's own player pool. The *mechanism* is sound and small; the
*server-side assumption underneath it is unverified and probably the hard part.* Document
it as a design, not a working feature.

**The mechanism (knowable, small).** The launcher already reads the serial once, holds a
base URL, and signs each request with `sha1(device_id + app_vcode + salt)`. Nothing about
that is per-model except the base URL and the OTA/chip-reg script slug. Make the base URL a
function of the game being launched instead of a constant:

- Build a table `gameId → { base, slug }` (see the data below).
- At the point the launcher resolves a game to launch (the same site you already patch for
  the ROM path, Part 5), set the active API base and slug from that table before the online
  handshake runs.
- Leave the serial, token derivation and every `com/arcade/api/**` call untouched — only
  the base string changes. The token is not keyed to the model, so it stays valid.

**⚠ The switch must cover gameplay/session calls ONLY — never the update path.** This is
the load-bearing safety rule, and it holds *regardless of which ROM is loaded*. The OTA
check (`com/arcade/api/oneupupdate/OneUpUpdate` → `version_yz_jj_oneup_<slug>.php`) runs off
the same API base. If the dynamic base leaks into it, loading, say, a TMNT ROM makes the
cabinet ask the **TMNT** update server for a newer build — and then offer to install
*TMNT firmware onto an MvC2 unit*. That is a wrong-model flash: at best a confusing prompt,
at worst a bricked or cross-flashed cabinet. So:

- **Pin the OTA/update endpoint to the cabinet's own slug permanently** (`mvc2`), hardcoded,
  independent of the game table. The update check must always ask MvC2's own server and
  nobody else's.
- Apply the dynamic base only to the **gameplay/session** endpoints — auth, login,
  guest/chip register, rank, the `notify_vs_*` / `notify_coop_*` / `report_*` calls. Those
  are the ones that need to reach the game's own backend; nothing else does.
- The cleanest implementation is to give the update classes their own fixed base and route
  *only* the session calls through the switchable one, rather than flipping one global base
  and hoping nothing else reads it mid-session. A single global base is exactly what makes
  this bug easy to hit. Better still, keep the existing update-prompt suppression from
  Part 8 (`updateNeeded`) so a stray cross-model update can never surface at all.

**The blocking assumption (server-side, unverifiable from the client).** Each backend keeps
its **own** device registry, populated per model via `chip_reg_api_<slug>_oneup.php`. A
cabinet's `/dev/swdevice` serial was provisioned on **one** backend — its own. Pointing the
app at another model's endpoint sends a real serial that *that* server has very likely never
registered, so auth/registration may simply be refused, and online *play* (matchmaking,
leaderboards) may require the unit to be a known/paid device on that specific backend.
`guest_register_oneup_v2.php` exists and *might* allow self-registration, but whether a
guest can actually matchmake, and whether one serial may register on several backends at
once, cannot be determined without the live servers and the hardware. **Assume this does
not work until proven on a real cabinet against live servers.** Several of these backends
were also reported returning 404 (Part 12), so confirm each is alive first.

**ROM ids are shared — so the mapping is an authoring choice, not automatic.** This is the
part that breaks the naive "if the ROM matches a cabinet, use its endpoint" idea. The
gameId namespace is global and heavily overlapped:

| Cabinet | slug | API base | res/raw ROM ids |
|---|---|---|---|
| Marvel (MvSC) | `mvsc` | `52.52.162.195/api/vsjj_oneup/` | 46, 100, 101, 106, 668 |
| XvS | `xmvsf` | `52.52.162.195/api/vsjj_oneup/` | 46, 100, 105, 667 |

Notice the collisions: **id 46/100/106** are in MvC2, Marvel and XvS; **id 112** is in
Sonic, Yoga and BigBlue; **id 2/39/45/107/111** are in both Yoga and BigBlue; **id 96** is
in Simpsons, Ridge and 1Up. So a gameId does **not** identify a backend. The `gameId →
{base, slug}` table must be authored by hand, and it is only unambiguous for
cabinet-exclusive titles (TMNT's 703–707, MvC2's own set, etc.). For a shared id you pick
which model's backend that bundled copy reports to — and picking one means the others'
online pools are not reachable from that same entry.

**Practical shape, if you attempt it.**

- The online that matters here is the **versus fighting** set (`vsjj_oneup`, `sf2ce2022`,
  `mvc2` — the `notify_vs_*` endpoints). Sonic / TMNT / Simpsons / Ridge are largely
  single-player or local co-op, so per-game endpoint switching buys little for them.
- Author one row per bundled game with an explicit backend, defaulting a shared id to the
  cabinet you are actually building on (MvC2 → `mvc2`) so its native games keep working, and
  only re-point a game at a foreign backend after you have proven that backend accepts this
  unit's serial.
- ❌ **This no longer presupposes the root + SELinux work above.** That caveat assumed the
  handshake could only succeed once `/dev/swdevice` was readable. On this cabinet SELinux is
  permissive and no such node exists, so nothing client-side gates the handshake — the
  serial comes from `ro.serialno`, readable by any app. The blocker is purely server-side
  registration, plus the fact that the MvC2 backend currently 404s.

**Bottom line.** The client-side switch is a couple of hours of work and fully within what
this guide already covers. Whether it yields *working* cross-model online depends entirely
on server-side registration behaviour that can only be tested on a live cabinet against
live servers — treat a working single-model online (the cabinet's own backend, its own
serial) as the realistic target, and anything cross-model as an experiment to validate, not
a feature to promise.


#### The alternative nobody should skip: is online even alive for MvC2?

`/mvc2/`, `/sf2ce2022/` and `/common/` endpoints returning 404 while the TMNT and Sonic
endpoints are demonstrably still up (a live `{"ret":0,"msg":"ok"}` was observed this
project). **Confirm whether the MvC2 backend still answers** (`tools/ota_query.py --cab
mvc2`, or a direct probe of one of its API scripts) before investing in the root+sepolicy
work purely to preserve online — if the server is gone there is nothing to preserve, and a
plain renamed clone (losing system UID) is then perfectly acceptable for offline play.

BigBlue and SF2CE 2022 **are** AOSP-signed and are ordinary members of the family — the
Rockchip / vendor-key situation is unique to MvC2.

The per-cabinet slug appears in three places that must agree: the API base, the OTA script
(`version_yz_jj_oneup_<slug>_v4.php`) and the chip registration
(`chip_reg_api_<slug>_oneup.php`). Observed slugs: `sonic`, `tmnt`, `simpson`,
`ridgeracer`, `mvsc`, `xmvsf`.

### Companion / game APKs

| APK | Package | Native | Notes |
|---|---|---|---|
| Sonic's emulator | `com.umido.oneupsonicmd17` | `libraui.so` + `picodrive_libretro_android.so` | **libretro frontend** — swappable core |
| Arcade1Up 1.43 | `umido.androidemu.mame` | `libarcade1up-native.so` 8 MB | MAME |
| ArcadeBowling | `umido.androidemu.mame` | `libmame.so` 7.2 MB | MAME |
| RidgeRacer_en | `com.arcade1up.RidgeRacer_en` | Unity (`libil2cpp.so`, `libunity.so`, `libSys22Plugin.so`) | a native Unity port, not emulation — no ROM to add |

### What emulation each cabinet already has

Detected by scanning each native library for system-specific symbols and strings.

| Library | Seen on | Systems it carries |
|---|---|---|
| `libyzvs.so` | TMNT, Ridge, Simpsons, 1Up V1.3.5 | **MAME + FinalBurn + Genesis** |
| `libarcade.so` + `libsnes.so` | Marvel, XvS | arcade + SNES |
| `libfba.so` (32 MB) | **Sonic** | **MAME, FinalBurn, SNES, Genesis, Sega CD, NES** |
| `libretro.so` | **Sonic** | Genesis / Sega CD, libretro API |
| `picodrive_libretro_android.so` | Sonic's emulator APK | Genesis / Sega CD / 32X, libretro API |
| `libmame.so`, `libarcade1up-native.so` | companion APKs | MAME |

Two things worth acting on:

- **The `libyzvs.so` cabinets already contain a MAME + FinalBurn + Genesis emulator.** If you
  want to add arcade or Mega Drive games to a TMNT or Simpsons cabinet, the emulator for
  them is already on the machine. You are adding a ROM, not an emulator.
- **The Sonic launcher itself ships a 32 MB `libfba.so`** covering MAME, FinalBurn, SNES,
  Genesis, Sega CD and NES, plus `libsnes.so` — none of which the Sonic mod uses. It
  drives the separate PicoDrive emulator APK instead. There is unused capability sitting
  on that cabinet.

### Can new cores be added?

**Only on Sonic.** Its emulator's `libraui.so` resolves the standard `retro_*` entry points
out of `picodrive_libretro_android.so` **by filename** via `dlsym`, so it is a generic
libretro frontend — any libretro core renamed to that filename loads. Verified by building
a Genesis Plus GX variant.

Every other cabinet's emulator (`libyzvs.so`, `libarcade.so`, `libmame.so`,
`libarcade1up-native.so`) exports no `retro_*` symbols at all. They are monolithic
binaries with no plugin interface — there is nothing to swap a core into. On those you are
limited to the systems the shipped binary already supports, which as noted is usually more
than the cabinet exposes.

### Will USB scanning work on the others?

**Yes, and this is the most useful finding for porting the mod.** It is not obvious, because
their games live in `res/raw` rather than a ROM folder — but they do not *run* from there.
The launcher extracts them to disk first:

```
ResUtil.getRawID(ctx, "yz_rom_" + id)       # resource id
  -> Resources.openRawResource(id)          # InputStream
  -> new FileOutputStream(filepath)         # written to /mnt/sdcard/arcade/rom/<id>
  -> emulator loads that FILE
```

Also seen: `/mnt/sdcard/arcade/snes/` for SNES titles, `/mnt/sdcard/arcade/save`,
`/mnt/sdcard/arcade/images/` for downloaded icons.

So **the emulator on every cabinet in this family loads a game from a filesystem path**,
which is exactly the property the Sonic mod exploits. The port is:

1. find the extract-to-file site (grep `openRawResource` near `yz_rom_`)
2. before extracting, check whether an external file exists for that entry — on a stick, or
   in an arbitrary directory — and if so use it instead
3. reuse the scanner, `order.txt` and artwork logic unchanged

The one caveat: `/mnt/sdcard` is **not** a card slot. On real hardware it resolves
`/mnt/sdcard -> /storage/self/primary -> /mnt/user/0/primary`, the same `/data/media`
filesystem as `/storage/emulated/0`. Removable media mounts separately at
`/storage/XXXX-XXXX`. Anything that reads a fixed `/mnt/sdcard/...` path will never see an
inserted stick or card — you have to add the volume walk yourself (Part 5).

### What is constant across the whole family

- package, signing key and `sharedUserId`
- no anti-tamper of any kind in any of the eleven
- `CheckRom` → `CheckRomListener.onCheckDone(JJ)V` — identical interface everywhere
- `OneUpUpdateFileUtil` — identical AES/CFB + PBKDF2, seed `R5OKtDvDSPkVIpeZ`
- `API.sha1` salt `jAhk3Px632KOxBmc`; `/dev/swdevice` as the hardware serial, on every call
- `yz_rom_<id>` / `yz_init_<id>` resource naming, and `/mnt/sdcard/arcade/` as the workspace
- the emulator always loads a game from a **file path**

### What varies

- **the API base URL** — one per model, and the reason cross-flashing kills online
- the emulator: in-process native library, or a separate `umido.androidemu.*` package
- whether that emulator is libretro (Sonic only) or monolithic
- where ROMs start: a folder + XML table, or `res/raw` resources extracted on demand
- where the expected CRC comes from: a baked `ROM_CRC:[J`, or a `Game.romCrc` field
- the update route: USB stick (Sonic only) or internal storage
- home-activity name: `SonicHomeActivity`, `HomeActivity`, `NewHomeActivity`

Fingerprint those seven and the rest of this document applies directly.

### Not `marvel.apk`

Note that `marvel.apk` is **`mvsc`** (Marvel vs Capcom 1) on the `vsjj_oneup` backend — an
ordinary AOSP-signed member of the family — **not** MvC2. MvC2 is the separate
`MvC2_V1.0.27.apk` on Rockchip with its own vendor key, covered above. Do not conflate the
two: `mvsc` mods like the rest, MvC2 does not.

---

## Part 13 — Cataloguing a new cabinet

When a launcher from another cabinet turns up, run the survey tool before anything else.
It reads the APK directly — no apktool decode — and answers every question Part 12
tabulates in a few seconds:

```bash
python tools/survey_apk.py --build-tools <sdk>/build-tools/34.0.0 path/to/new.apk
```

It reports, and prints a ready-made Part 12 table row:

| Section | What it tells you | Why it matters |
|---|---|---|
| identity | package, versionCode/Name, sharedUserId, **signer SHA-1** | if the signer is not `27196e38…`, stop — nothing here applies |
| online | API base, OTA script, chip-reg script, `/dev/swdevice` | the per-model backend. Never change it (Part 7) |
| updates | update filenames, and whether a **real** USB route exists | decides whether users need adb |
| ROM discovery | `games.xml` + folder, or `res/raw` extracted to a file | tells you which Pattern in Part 5 to use |
| CRC gate | baked-in `ROM_CRC` array vs `Game.romCrc` field | tells you which variant in Part 6 to patch |
| defences | `GET_SIGNATURES` / `getPackageCodePath` | anti-tamper that none of the eleven had |
| emulation | each native lib and the systems it carries | often you already have the emulator you need |

It deliberately extracts strings with a Python regex over the raw bytes rather than
shelling out to `strings` — see Part 9 for why that matters.

Two results need a follow-up grep, because the tool is being careful rather than
confident:

- **`MEDIA_MOUNTED` present but no USB route.** Four launchers register that broadcast
  only in factory hardware-test code. Confirm with
  `grep -rl MEDIA_MOUNTED smali*/ | grep com/test` — if every hit is under `com/test/`,
  there is no USB update path.
- **`pm/Signature` referenced.** Usually just AndroidX `FontsContractCompat` doing
  font-provider cert pinning, not a self-check. `GET_SIGNATURES` is the flag that would
  actually matter.

Then decode and confirm the three hooks by hand (Part 4), because class names move between
builds:

```bash
java -jar apktool.jar d -f -o work/new new.apk
grep -rn "openRawResource" work/new/smali*/ --include=*.smali | grep -v support/v
grep -rn "yz_rom_"        work/new/smali*/ --include=*.smali | grep -v 'R\$raw'
grep -rn "ROM_CRC\|romCrc\|CheckRomListener" work/new/smali*/ --include=*.smali
grep -rn "To check local update\|StartupReceiver" work/new/smali*/ --include=*.smali
```

Add the resulting row to Part 12, and note explicitly whether the cabinet was tested on
hardware or only read — that distinction is the most useful thing in this document and the
easiest to lose.

