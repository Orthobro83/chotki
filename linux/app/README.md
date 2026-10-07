# Linux desktop foundation

The Phase 1 Qt/QML shell talks to a persistent Swift process that imports the
canonical `core/` package. One line of versioned JSON is sent per request and
response. The UI process owns the window and Linux behavior; the Swift helper
owns record access and existing Chotki decisions. This is a foundation, not
yet a usable Linux edition. The main card is intentionally a placeholder.

## Build and review in the Ubuntu guest

Install Swift 6.4, SQLite development headers, CMake, Ninja, a C++ compiler,
Qt 6 Quick/declarative development packages, Qt Quick QML modules, and `rsync`.
The UTM share is mounted read-only at `/mnt/utm/chotki-1`. Run:

```sh
/mnt/utm/chotki-1/linux/tools/build-guest.sh
/mnt/utm/chotki-1/linux/tools/review-guest.sh
```

The build script copies `core/` and `linux/app/` into
`~/chotki-linux-build` before compiling. Override the source and staging
locations with `CHOTKI_SOURCE_ROOT` and `CHOTKI_STAGE_ROOT`. No compiler
output is written to the shared source tree.

The review helper uses `~/.cache/chotki-linux-review/chotki.sqlite`, seeded
with a sample name. Normal mode uses `XDG_DATA_HOME/Chotki/chotki.sqlite`,
falling back to `~/.local/share/Chotki/chotki.sqlite`. The two modes also use
different single-instance sockets. Do not use normal mode for screenshots or
automated tests.

## What has been checked

- Ubuntu 26.04.1 ARM64: Swift helper and Qt shell compile and launch on GNOME.
- Core greeting/date and bundled Psalm data reach the shell through the helper.
- A duplicate launch exits and keeps a single window and helper.
- Killing the helper starts a new helper and reconnects the shell.
- Closing the window also closes the helper.
- A Qt input test clicks the Prayers entry and observes the route change.

GitHub Actions [run 37696472735](https://github.com/rjmac83/chotki/actions/runs/37696472735)
passed `amd64` compilation, bridge/core checks, and a headless shell launch
on Ubuntu 24.04. The VM's forwarded mouse clicks have not yet provided a
reliable physical navigation check. The automated Qt input test covers the
click path, but a real guest pointer check remains before Phase 1 closes.
No `.deb` exists yet.
