# Flow

Flow is a native Android Twitch client built with Kotlin and Jetpack Compose.
It compiles against and targets SDK 37 while supporting devices back to API 23.

## Prerequisites

- Android Studio with Android SDK Platform 37 and Build Tools 37 installed
- JDK 17

Open the `android` directory in Android Studio, or use the checked-in Gradle
wrapper from a terminal.

## Twitch configuration

Flow bundles its public Twitch OAuth client ID and redirect URI, so sign-in works
without local setup. The GraphQL client ID can optionally be overridden through
your user-level `~/.gradle/gradle.properties`:

```properties
TWITCH_GQL_CLIENT_ID=your_graphql_client_id
```

The same name can be exported as an environment variable instead. When omitted,
Flow uses Twitch's public web client ID just as the previous app did.

## Build and test

From the repository root on Windows:

```powershell
cd android
.\gradlew.bat testDebugUnitTest
.\gradlew.bat assembleDebug
.\gradlew.bat lintDebug
```

On macOS or Linux, use `./gradlew` in place of `.\gradlew.bat`. The debug APK
is written under `android/app/build/outputs/apk/debug/`.

## Run on a device

With USB debugging enabled and the device listed by `adb devices -l`, run:

```powershell
cd android
.\gradlew.bat :app:installDebug
adb shell am start -S -n com.namecallfilter.flow.debug/com.namecallfilter.flow.MainActivity
```

The debug build uses `com.namecallfilter.flow.debug`, so it can remain installed
beside an existing signed `com.namecallfilter.flow` release without a signature
conflict. Release builds retain the original application ID. On macOS or Linux,
replace `.\gradlew.bat` with `./gradlew`.
