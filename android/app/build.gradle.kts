plugins {
    // Kotlin support is built into the Android plugin from AGP 9; applying
    // org.jetbrains.kotlin.android alongside it is now an error.
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "org.chotki.app"
    compileSdk = 37

    defaultConfig {
        applicationId = "org.chotki"
        // The floor, not the target: Android 8 and everything above it, which is
        // essentially every device in use. The test device runs 13.
        minSdk = 26
        targetSdk = 37
        versionCode = 1
        versionName = "0.1.0-alpha"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
}


dependencies {
    implementation(project(":core"))
    // NotificationCompat only — the notification API has changed enough between
    // 8 and 13 that hand-rolling it would be a source of bugs on exactly the
    // versions hardest to test.
    implementation("androidx.core:core-ktx:1.17.0")

    val compose = platform("androidx.compose:compose-bom:2025.09.00")
    implementation(compose)
    androidTestImplementation(compose)
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.activity:activity-compose:1.11.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.9.4")

    debugImplementation("androidx.compose.ui:ui-tooling")
    // The interface is driven, not photographed.
    debugImplementation("androidx.compose.ui:ui-test-manifest")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")

    // The interface will be driven, not photographed. Every macOS bug in this
    // project was a control that drew correctly and did nothing.
    // Navigation is decided by a value, so where back goes can be checked
    // without a device — and without finishing an activity mid-suite, which
    // crashes the instrumentation runner for everything after it.
    testImplementation("junit:junit:4.13.2")

    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
}
