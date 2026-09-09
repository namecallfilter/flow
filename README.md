# Flow

A Flutter Twitch client for Android with channel browsing, search, following,
and native Media3 live playback.

## Development

Use Flutter with Dart 3.12.2 or newer, the Android SDK, and a JDK compatible
with the project's Android Gradle plugin. This project is tested with Flutter
3.44.8. Android Studio supplies the Android tooling and JDK.

```sh
flutter pub get
dart run build_runner build
flutter run
```

Twitch sign-in uses the public client ID and redirect URI in
`lib/api/twitch_auth.dart`. Normal `flutter run` and `flutter build apk`
commands include this configuration; no `.env` file or extra flags are needed.

## Checks

```sh
flutter analyze
flutter test
```

Run native playback and proxy tests from `android/`:

```powershell
.\gradlew.bat :app:testDebugUnitTest
```

Release builds currently use the development signing key; configure release
signing before distributing through an app store.

## Code layout

- `lib/app`: app settings, theme, and retained tab navigation.
- `lib/features`: screens and MobX state for browsing, following, channels,
  settings, and the Dart side of playback.
- `lib/api`: Twitch authentication, GraphQL requests, and session caching.
- `lib/shared`: preferences, display models, and shared widgets.
- `android/app/src/main/kotlin/com/namecallfilter/flow`: Media3 playback,
  HLS handling, and the Flutter platform bridge.
- `lib/graphql/*.graphql`: the operations used by the app.
- `lib/graphql/schema.graphqls`: inferred schema used for code generation.
- `docs/twitch/graphql`: saved reference operations, excluded from code generation.

After changing GraphQL operations or MobX annotations, run
`dart run build_runner build`. Generated Dart files (`*.g.dart`, `*.graphql.dart`,
and `*.graphqls.dart`) are ignored by Git; regenerate them after cloning and edit
their sources instead. `build.yaml` disables unused GraphQL `copyWith` helpers to
keep generated code smaller.
