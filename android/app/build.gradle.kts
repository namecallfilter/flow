plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

fun String.asBuildConfigString(): String =
    buildString {
        append('"')
        this@asBuildConfigString.forEach { character ->
            when (character) {
                '\\' -> append("\\\\")
                '"' -> append("\\\"")
                '\n' -> append("\\n")
                '\r' -> append("\\r")
                '\t' -> append("\\t")
                else -> append(character)
            }
        }
        append('"')
    }

val twitchClientId = "deh8tdsvcsptv5sby686y9gamadiuo"
val twitchGraphQlClientId =
    providers.gradleProperty("TWITCH_GQL_CLIENT_ID")
        .orElse(providers.environmentVariable("TWITCH_GQL_CLIENT_ID"))
        .getOrElse("")
val twitchRedirectUri = "https://twitch.tv/login"

android {
    namespace = "com.namecallfilter.flow"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.namecallfilter.flow"
        minSdk = 23
        targetSdk = 37
        versionCode = 1
        versionName = "1.0.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        buildConfigField("String", "TWITCH_CLIENT_ID", twitchClientId.asBuildConfigString())
        buildConfigField(
            "String",
            "TWITCH_GQL_CLIENT_ID",
            twitchGraphQlClientId.asBuildConfigString(),
        )
        buildConfigField(
            "String",
            "TWITCH_REDIRECT_URI",
            twitchRedirectUri.asBuildConfigString(),
        )
    }

    buildFeatures {
        buildConfig = true
        compose = true
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildTypes {
        debug {
            // Keep the signed Flutter build available on a device as a visual/reference baseline.
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        release {
            // Preserve the existing installable release workflow for local builds.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2026.06.00")
    val lifecycleVersion = "2.10.0"
    val media3Version = "1.10.1"

    implementation(composeBom)
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.material3:material3")
    // Compose UI 1.12 preserves AndroidView virtual autofill nodes (b/490533969),
    // which lets password managers see credential fields hosted by WebView.
    implementation("androidx.compose.ui:ui:1.12.0-rc01")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:$lifecycleVersion")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:$lifecycleVersion")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:$lifecycleVersion")
    implementation("androidx.startup:startup-runtime:1.2.0")
    implementation("androidx.datastore:datastore-preferences:1.2.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
    implementation("com.squareup.okhttp3:okhttp:5.4.0")
    implementation("io.coil-kt:coil-compose:2.7.0")

    implementation("androidx.media3:media3-datasource-okhttp:$media3Version")
    implementation("androidx.media3:media3-exoplayer:$media3Version")
    implementation("androidx.media3:media3-exoplayer-hls:$media3Version")
    implementation("androidx.media3:media3-ui:$media3Version")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.11.0")
    testImplementation("org.json:json:20260719")

    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    // Espresso 3.7 stopped reflectively calling InputManager.getInstance(), which is absent on
    // Android 17 / API 37. Keep Compose tests runnable on the same target used by the app.
    androidTestImplementation("androidx.test.espresso:espresso-core:3.7.0")
    androidTestImplementation(composeBom)
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")

    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
