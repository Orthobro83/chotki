# Chotki for Windows

Work in progress for **x86_64 Windows 11**. Current macOS is the visual and
functional specification. Full parity is the release gate: do not publish a
Windows release candidate until the port is complete. ARM64 is deferred.

The SwiftPM executable combines canonical ChotkiCore with a native Win32 UI.
Home includes grouped/collapsible navigation, week/month selection, separate
rule-card open/expand/complete actions and the original 365-image rotation.
Calendar retrieval caches to SQLite and posts native messages to repaint arriving
data. The editor uses core recurrence/scoped edits; Settings includes JSON
export/merge restore and daily backups. Reading uses shared texts and distinguishes
deliberate end scrolling from programmatic navigation.

Remaining work includes rich reading/glossary presentation, measured expansion,
artwork motion/reduced motion, appointed-kathisma interactions, remaining screen
layouts, physical input/accessibility, tray, notifications, audio, startup and
packaging. See [PORT.md](PORT.md).

## Build and verify

Follow [BUILD-ENVIRONMENT.md](BUILD-ENVIRONMENT.md) for every compilation and test.
Source stays on Mac; canonical core stays in `../core`. `shared-core` is generated.

```sh
python3 windows/tools/prepare-core.py
python3 windows/tools/prepare-assets.py
python3 windows/tools/run-vm.py --upload windows/assets.zip
python3 windows/tools/run-vm.py windows/tools/verify-vm.ps1
```

The SSH helper reads ignored `connection.local.md` fields `Host`, `Username` and
`Password`. Never commit credentials or host keys. It uploads a public-source
archive, verifies SHA-256 and synchronizes to native `C:\workspace-build`, bypassing
stale shared-drive reads. Its manifest removes obsolete compiler inputs while
preserving build caches and staged artwork. Re-upload `assets.zip` whenever its
catalog fingerprint changes. Do not edit guest sources independently.

PowerShell sets `MIMALLOC_DISABLE_REDIRECT=1` and `SWIFT_DRIVER_USE_FRONTEND=0`
before every compiler call. Never use default architecture or static runtime flags.

```powershell
swift build --triple x86_64-unknown-windows-msvc --build-system native -Xcc -IC:\vcpkg\installed\x64-windows\include -Xlinker -LC:\vcpkg\installed\x64-windows\lib
```

This toolchain needs the native backend to honor the triple. Build/run on C: only.
Helpers bundle matching Swift 6.4 and SQLite DLLs, verify AMD64 PE headers and isolate
the execution PATH. Runtime extraction tools unpack x64 installer DLLs without
changing the host compiler installation.

## Tests and review

`--self-test` checks SQLite/settings, backup and all 151 Psalter resources.
`--ui-smoke` drives native controls with an in-memory synthetic record. `--review`
opens synthetic practice. Normal launch stores a Windows record under
`%LOCALAPPDATA%\Chotki`; tests never open live records.

```sh
python3 windows/tools/prepare-test-fixtures.py
python3 windows/tools/run-vm.py windows/tools/test-core-vm.ps1
python3 windows/tools/run-vm.py windows/tools/verify-ui-desktop-vm.ps1
```

Desktop review uses a temporary interactive scheduled task, captures the synthetic
app window into ignored `.build/reviews/`, then removes the task. SSH's session 0
cannot supply reliable screenshots. Native control checks complement visual review;
physical input, accessibility and real x86_64 hardware acceptance remain required.

## Fonts and artwork

Four licensed XCharter cuts follow the Mac's Charter fallback. Keep
[Fonts/LICENSE.txt](Fonts/LICENSE.txt) with redistributed fonts. Apple's Iowan face
is not bundled. Artwork, focal metadata and original notices come from Mac resources.
