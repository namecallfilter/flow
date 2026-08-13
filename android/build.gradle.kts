buildscript {
    dependencies {
        // AGP 9 provides built-in Kotlin. This overrides its bundled compiler so
        // the Kotlin and Compose compiler plugins remain on the same version.
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.3.21")
    }
}

plugins {
    id("com.android.application") version "9.2.1" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.3.21" apply false
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
