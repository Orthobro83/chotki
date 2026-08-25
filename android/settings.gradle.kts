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
include(":app")

pluginManagement {
    repositories {
        google()
        gradlePluginPortal()
        mavenCentral()
    }
    plugins {
        // The last stable Android Gradle Plugin. The Studio installed here is a
        // preview build shipping 9.4.0-dev; there is no reason to found the port
        // on a -dev toolchain that moves under it.
        id("com.android.application") version "9.3.0"
        // Compose's compiler is a Kotlin plugin, and must match the Kotlin that
        // AGP brings with it rather than the newest available.
        id("org.jetbrains.kotlin.plugin.compose") version "2.2.0"
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
