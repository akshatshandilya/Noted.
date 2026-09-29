# Noted.

A calm, private, local-first notes app. Flutter + Dart. Notes live only on the
device (Hive); there is no account, no analytics, no network access, and the
app currently requests **no device permissions**. Fonts (Fraunces, Inter — SIL
OFL) are bundled, so nothing is fetched at runtime.

> **Status:** source written by hand. Every file parses cleanly with a Dart
> grammar, but it has **not been compiled or run** (the authoring environment
> had no Flutter/Android toolchain). The first cloud build is the real test;
> if it fails, the log shows exactly which line, and that's a quick fix.

## Get it on your Android phone (no installs on your computer)

A GitHub Actions workflow (`.github/workflows/build-apk.yml`) builds the APK
in the cloud for free.

1. Create a **private** GitHub repository (it contains a fixed signing key, see
   below) and push this folder to it:
   ```bash
   cd noted_flutter
   git init -b main && git add . && git commit -m "Noted."
   git remote add origin https://github.com/<you>/noted.git
   git push -u origin main
   ```
2. Open the repo → **Actions** tab → wait for *Build Android APK* (about
   6-10 minutes). If a step is red, open it and send me the log.
3. On your phone, open the repo → **Releases** → *Noted. (latest build)* →
   download **Noted.apk** and open it. Android will ask you to allow installs
   from your browser ("Install unknown apps"), and Play Protect may show an
   "unrecognised developer" notice, which is normal for a sideloaded app.
4. Every later push rebuilds and refreshes that same release. Installing the
   new APK **updates in place and keeps your notes**.

### Why there's a keystore in `ci/`
Android refuses to update an app signed with a different key, and CI would
otherwise generate a new random key each run, forcing an uninstall (which
deletes your notes). `ci/debug.keystore` is a fixed key so builds update in
place. It is a debug-grade key, so keep the repo private; publishing to the
Play Store would need a proper, secret upload key instead.

## Build locally instead

```bash
cd noted_flutter
flutter create --project-name noted --org com.noted --platforms=android .
rm -f test/widget_test.dart          # default template test, not ours
flutter pub get
dart run flutter_launcher_icons
bash tool/configure_android.sh       # app name, launch colour, no cloud backup, light/dark icons
flutter test
flutter build apk --release          # build/app/outputs/flutter-apk/app-release.apk
```

## App icons: light + dark, following the theme

Both icons are the splash identity (Fraunces serif **N**, accent period, two
ruled lines) in each theme's own palette:

| | background | N | period + lines |
|---|---|---|---|
| Light | `#F4F3EE` | `#1C1B1A` | `#2C4A8C` |
| Dark | `#000000` | `#F0EFEA` | `#7B9CF0` |

`assets/icon/` holds full-bleed and adaptive-foreground PNGs for each, plus
`android_dark/res/` (ready-made Android resources for the dark icon) and
`icons_preview.png`. Regenerate everything with
`pip install pillow && python3 tool/make_icons.py`.

**How the icon follows the theme (Android):** the manifest gets two launcher
aliases, `LightIcon` (on by default) and `DarkIcon` (off). `AppIconSync`
watches the resolved theme (so *System* follows the phone), and a small native
channel in `MainActivity.kt` enables the matching alias. Both are added by
`tool/configure_android.sh`. Settings has a **Match app icon to theme** switch
(on by default); turning it off restores the light icon.

Things Android imposes, worth knowing:
- The icon can only change while Noted. is running, so if the phone's theme
  flips while the app is closed, the icon catches up next time you open it.
- Some launchers briefly refresh the icon, or drop a pinned home-screen icon,
  when it swaps. If that happens, re-pin it from the app drawer or switch the
  option off.
- Android 13's system "themed icons" (which follow the wallpaper) are separate
  and not used here.

`dart run flutter_launcher_icons` (config in `pubspec.yaml`) still generates
the light launcher icon and iOS icon; the dark alias resources are copied in by
the configure script.

## Structure (`lib/`)

| Folder | Purpose |
|---|---|
| `core/theme`, `core/utils`, `core/platform` | Design tokens/ThemeData (light + dark), color + date helpers, native icon-switch channel |
| `data/models`, `data/database` | `Note` model (plain-map serialization, no codegen), Hive repository |
| `providers` | `NotesProvider` (filter/search/sort/trash), `ThemeProvider` |
| `features/splash` | Launch animation: config, logo animation, screen |
| `screens/home`, `screens/editor` | Home (search, chips, grid/list, settings) and note editor |
| `widgets` | `NoteCard`, `EmptyState`, `NotedWordmark`, `AppIconSync` |

## Implemented

Create / edit / autosave (500 ms debounce, "Saving…/Saved"), checklists with
progress + animated check + haptics, pin, favorite, archive, Trash (restore,
delete forever, empty trash, 30-day auto-purge), Undo snackbars, search
(title/content/tags), filter chips, grid/list, sort, tags, note colors,
light/dark/system theme (persisted), word count + reading time, empty states,
splash animation with reduced-motion path, semantic labels + 44dp targets,
text-scale-aware card heights.

## Not built yet (from the spec)

Rich-text formatting, photos, GIFs, stickers, drawing, voice notes, reminders,
templates, export/import backup, app lock (biometric via `local_auth`) and the
private-notes space, onboarding, widgets, tag management screen.
Each needs its platform permission wired only at point of use.

## Notes

- Native launch screen: after `flutter create`, set the Android
  `launch_background` / iOS LaunchScreen color to `#F4F3EE` (light) so there's
  no flash before the Flutter splash draws.
- Trash age uses `updatedAt` (bumped when a note is trashed).
- `tool/configure_android.sh` sets `allowBackup="false"`, so Android's cloud
  backup never copies notes off the phone. Trade-off: notes don't come back
  automatically on a new phone until the export/import feature exists.
- The release build has no `INTERNET` permission (Flutter only adds it to
  debug builds for hot reload).
