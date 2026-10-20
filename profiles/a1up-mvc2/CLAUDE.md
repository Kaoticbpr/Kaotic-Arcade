# Profile: a1up-mvc2

Arcade1Up Marvel vs Capcom 2 (and X-Men '97) Android cabinet expansion, installed over adb from a Windows or Mac
computer. No root; the original game stays untouched.

## Rules when working on this setup
1. Never commit APKs, emulator cores, adb binaries, ROMs, NVRAM dumps or firmware extracts (see the repo .gitignore).
2. Test on the cabinet before changing an installer; keep UNINSTALL working.
3. `docs/REBUILDING.md` marks what was tested on hardware vs only analysed; keep that distinction.
4. Do not publish vendor server addresses or account details.
