plugins {
    // Pinned to what the Android plugin brings with it. AGP 9.3.0 has Kotlin
    // built in at 2.2.0, and a `:core` compiled with anything newer produces
    // metadata `:app` cannot read — "expected version 2.2.0", on every class.
    // One Kotlin version for the whole project, chosen by the constraint that
    // is not ours to move.
    kotlin("jvm") version "2.2.0"
    kotlin("plugin.serialization") version "2.2.0"
}

// 17 rather than the JDK that happens to be running Gradle: this module becomes
// a dependency of an Android module at phase 9, and 17 is what Android accepts.
// Compiling on a newer JDK and targeting 17 is fine; the reverse is not.
kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        allWarningsAsErrors.set(true)
    }
}

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

dependencies {
    // Multiplatform and Android-free: the guard is against depending on the
    // platform, not against depending on anything.
    //
    // `api` rather than `implementation`: the generated serialisers are part of
    // what this module offers. The app encodes a NotificationRequest to carry it
    // on an alarm, and would otherwise have to declare the same dependency and
    // keep its version in step by hand.
    api("org.jetbrains.kotlinx:kotlinx-serialization-json:1.9.0")

    testImplementation(kotlin("test"))
    // Only the tests reach a real database. The store itself talks to `Db`,
    // which Android implements over its own SQLite and the tests implement over
    // JDBC — so the SQL and the migration ladder are exercised on every CI run
    // without `:core` knowing what a driver is.
    testImplementation("org.xerial:sqlite-jdbc:3.50.1.0")
}

tasks.test {
    useJUnitPlatform()
    testLogging { events("failed") }
}
