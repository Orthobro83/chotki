# The shipped calendar: how it is made and when to refresh it

The apps carry the church calendar for **2026-01-01 to 2031-12-31**, under both reckonings, in
`core/Sources/ChotkiCore/Resources/calendar/` (and byte-for-byte in
`android/core/src/main/resources/calendar/`). The bundle is read-only, answers before the cache or
the network, and is built by `calendar-bundle.py` from days generated with Orthocal's open-source code
(its maintainer has permitted this) and audited so that every word of scripture is public-domain King
James Version. orthocal.info is asked only for dates beyond the bundle.

## When to refresh

**Ship a build with the next five years at least a year before `manifest.json`'s `last` date**, which
means before the end of 2030. An app past its horizon falls back to asking orthocal.info and, if that
is unreachable, to the "cached" state it had before the bundle: it never fails outright. The date is
also in `checklist.md`.

## How

1. Pin a new commit of Orthocal's code locally and diff its output against the recorded API fixtures
   in `core/Tests/ChotkiCoreTests/Fixtures/`. An upstream correction shows up as a difference: review
   it rather than accepting it blindly.
2. Generate the next window of days under both reckonings, audit them (every reading's verses must
   match the public-domain King James text; Composite readings are resolved from the chapters they
   cite), and resolve anything unresolved. The generation and audit scripts are kept locally, not in
   this repository.
3. Rebuild the bundle: `python3 core/Tools/calendar-bundle.py --sanitised DIR --db orthocal.sqlite
   --composites composites.json --commit SHA --generated-at YYYY-MM-DD`.
4. Copy it to Android with `CHOTKI_WRITE_CONTENT=1 swift test --package-path core --filter CalendarExport`.
5. Run every suite: `swift test` in `core/` and `macos/`, the iOS and Windows suites and the Android
   tests. They hold the text and the fields of every day to digests written into `manifest.json`,
   in Swift and in Kotlin, so a mistake anywhere shows up as a failing digest.
6. Spot-check against the live service, politely: `python3 core/Tools/accuracy-check.py` (a few dozen
   requests, two seconds apart, identifying the app). Run it before every release and whenever the
   bundle is regenerated. A commemoration that upstream has since added is reported separately and is
   harmless; anything else is a bug in the bundle or an upstream change to look at.
