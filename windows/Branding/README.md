# Windows application resources

`tools/prepare-branding.py` generates the icon from canonical ChotkiCore vector
geometry and reads the version from `Branding/version.json` (Windows alpha candidate/build counters). Regenerate after changing
either; do not hand-edit `Version.h` or the icon. The SDK resource compiler embeds
these alongside `Chotki.manifest`. Builds select the resource by content hash so
an icon/version change also invalidates the incremental linker input.

`LICENSE.txt` is the repository's distribution notice. `Swift-LICENSE.txt` is the
unaltered Apache 2.0 license with runtime exception from the Swift project's
[official license](https://github.com/swiftlang/swift/blob/main/LICENSE.txt), saved
2026-10-04 for the separately bundled runtime. Font and notification-helper
notices are copied from their existing source locations; artwork notices travel
with the unchanged resource bundle.
