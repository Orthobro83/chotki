// Only `:core` for now, and deliberately so.
//
// Phases 1 to 7 of PORT.md are pure Kotlin: dates, the model, recurrence, the
// store, practice, scoring, the liturgical layer, reminders. None of it needs
// Android, and none of it should. The `:app` module arrives at phase 9, by
// which time the Android Gradle Plugin on this machine will have a stable
// release rather than the -dev build the current preview Studio ships.
//
// The happy side effect: `:core` has no Android dependency to import from, so
// the portability rule the Swift core needs a CI job to enforce is enforced
// here by the compiler.
rootProject.name = "chotki"

include(":core")

pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositories { mavenCentral() }
}
