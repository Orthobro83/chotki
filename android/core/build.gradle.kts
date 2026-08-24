plugins {
    kotlin("jvm") version "2.4.0"
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
    testImplementation(kotlin("test"))
}

tasks.test {
    useJUnitPlatform()
    testLogging { events("failed") }
}
