# Chotki for Android

**Status: not started.** This folder holds the groundwork only — the plan, the
specification, and the decisions still to make. No Kotlin, no Gradle, nothing
built. Work begins 23 August 2026.

- **[PORT.md](PORT.md)** — the phases, in order, each with a "done when"
- **[PARITY.md](PARITY.md)** — what `core/` defines and the port must satisfy
- **[../retrospective.md](../retrospective.md)** — how the macOS build went
  wrong, and the guard rails that came out of it

## The one thing to understand first

Swift does not run on Android in any practical way. This is a **reimplementation
in Kotlin**, not shared code — so `core/` and its 280 tests stop being an
implementation and become a *specification*. Everything this app decides is
stated there once. A Kotlin core that passes a translation of those tests is the
same application underneath, and anything left undone shows up as a missing
test rather than as a bug Ryan finds three weeks later.

## Toolchain on this machine, as of 22 August 2026

Checked, not assumed:

| | |
|---|---|
| JDK | **26.0.2 (Temurin)** — the only one installed |
| Android Studio | Not installed |
| Android SDK / `adb` | Not installed |
| Gradle | Not installed |
| Kotlin compiler | Not installed |
| Homebrew | Present, at `/opt/homebrew` |
| Space on the 2TB volume | 1.8 TB free |

**The one real problem: JDK 26 is too new.** The Android Gradle Plugin supports
JDK 17 and 21; it will not build against 26. So a second JDK is needed
regardless of what else is installed — either the one Android Studio bundles
(JetBrains Runtime, currently 21) or a standalone `openjdk@21`.

### What needs installing, in order

Android Studio is the shortest path: it brings the SDK, the emulator, and a
compatible JDK in one install, and the SDK licences have to be accepted
interactively anyway.

```bash
brew install --cask android-studio
```

Then, for building and testing from the command line without going through the
IDE:

```bash
brew install openjdk@21 gradle
```

**These are Ryan's to run, not mine.** The Android SDK requires accepting
Google's licence agreements, which is not something to click through on someone
else's behalf. Once Android Studio is installed, its first run downloads the SDK
platform and build tools — allow twenty minutes and several gigabytes.

Worth doing tonight if the machine is free, so tomorrow starts at Phase 0
instead of at a download.

## Provisional stack

Recommendations, not decisions. Phase 0 settles them.

| | Proposed | Why |
|---|---|---|
| Language | Kotlin | The only sane option; Swift is out |
| Modules | `:core` (pure Kotlin/JVM), `:app` (Android) | Mirrors the Swift split, and the same CI guard applies |
| UI | Jetpack Compose, Material 3 | Declarative, closest to the SwiftUI already written |
| Database | SQLDelight, or raw `androidx.sqlite` | Keeps the existing schema and migration ladder verbatim. **Not Room**, which wants to own a schema this one already has |
| Dates | No date library | `CalendarDate` is timezone-free integer arithmetic and depends on nothing. Keep it that way |
| HTTP | OkHttp or Ktor, behind `HttpFetching` | Same interface as Swift, so tests stay offline |
| JSON | kotlinx.serialization | Orthocal decoding, and possibly shared content |
| Reminders | `AlarmManager` + `NotificationManager` | Exact alarms need permission from Android 12 |
| Background | `WorkManager` | Daily liturgical fetch, backups |
| Min SDK | 26 (Android 8) | Covers essentially every live device; nothing here needs newer |
| Tests | JUnit + `kotlin.test`; Compose UI tests | The 280 core tests translate; UI must be *driven*, not screenshotted |
| Repo | This one, as `android/` | One history, one licence, shared content in view |

## Open questions for Phase 0

Answers change the work; guesses would be expensive.

1. **Feature scope for v1** — everything the Mac app does, or a subset to start?
   Launch-at-login has no Android equivalent and drops out either way.

   My answer: everything the Mac app has, please.

2. **Which device**, and which Android version does it run? That sets the real
   minimum, and the emulator profile to test against.

    My answer: The app should run cleanly on the largest number of Android devices currently in use today. I have an S21 FE running Android 13 (Kernel version 4.19.113-29223811) and OneUI 5.1. To my understanding this is fairly old, and should suffice as a minimum requirement sicne most Android devices in use today will have at least this versionor above.

3. **Should the database be interchangeable** with the macOS one — copy the file
   across and it opens? That is nearly free if decided now, and awkward later.
   Note this is *not* sync; syncing between devices is a separate, much larger
   feature.

    My answer: We're not going to worry about sync at all for now. The idea will be that you'll run it on one device, and this device will *the* device the user uses for this app.

4. **Distribution to the Brotherhood** — a direct APK, as with the Mac alpha, or
   the Play Store? Play means a developer account, a review process, and a
   privacy policy; direct means asking people to permit installing from an
   unknown source.

    My answer: Direct APK for now. I will worry about a developer account and the rest later.

5. **Shared content as JSON?** Exporting prayers, glossary, library and readings
   to JSON that both platforms read would make drift impossible — but it changes
   the macOS app too. Worth it if Windows and Linux ports are still planned.

 My answer: As the app may see feature updates and changes that will have to be implemented across platforms, we should account for this in the most efficient way going forward.

6. **Where the priest review stands.** The glossary and prayer texts still need
   it, and duplicating unreviewed content onto a second platform doubles what
   has to be corrected later.


 My answer: I've yet to find a priest running Apple Silicon. Part of why I'm moving forward with the Android SDK now is that this will make it more accessible to more priests -- it'll help me find one to review it.

## Still outstanding on macOS

Not blockers for Android, but they do not disappear:

- Universal binary — needs Xcode, which is still not installed
- Notarisation — needs the $99/year Apple Developer Program, Ryan's call
- Priest review of the glossary, prayer texts and patristic attributions
- Confirming the parish reckoning (Julian is the default)
