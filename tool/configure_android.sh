#!/usr/bin/env bash
# Android-specific configuration for Noted.
# Run from the project root, AFTER:
#   flutter create --project-name noted --org com.noted --platforms=android .
# Safe to run more than once.
set -euo pipefail

RES=android/app/src/main/res
MANIFEST=android/app/src/main/AndroidManifest.xml

[ -f "$MANIFEST" ] || { echo "Run 'flutter create ... --platforms=android .' first."; exit 1; }

# 1) App name, and opt out of Android's cloud backup: notes stay on the phone.
sed 's/android:label="[^"]*"/android:label="Noted."/' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
if ! grep -q 'android:allowBackup' "$MANIFEST"; then
  sed 's/<application/<application android:allowBackup="false"/' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
fi

# 2) Native launch screen colour = the splash background, light and dark,
#    so there's no white/black flash before the Flutter splash draws.
mkdir -p "$RES/values" "$RES/values-night"
cat > "$RES/values/noted_colors.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="noted_launch_bg">#F4F3EE</color>
</resources>
XML
cat > "$RES/values-night/noted_colors.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="noted_launch_bg">#000000</color>
</resources>
XML
for d in "$RES"/drawable "$RES"/drawable-v21; do
  mkdir -p "$d"
  cat > "$d/launch_background.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/noted_launch_bg" />
</layer-list>
XML
done


# 3) Light/dark launcher icons. Two <activity-alias> entries (LightIcon is on by
#    default, DarkIcon off); MainActivity.kt flips them when the app tells it
#    the theme changed. The LAUNCHER intent-filter moves from MainActivity to the
#    aliases, so exactly one icon shows at a time.
cp -R assets/icon/android_dark/res/. "$RES/"

if ! grep -q '<activity-alias' "$MANIFEST"; then
  ALIASES="$(mktemp)"
  cat > "$ALIASES" <<'XML'
        <activity-alias
            android:name=".LightIcon"
            android:targetActivity=".MainActivity"
            android:enabled="true"
            android:exported="true"
            android:icon="@mipmap/ic_launcher"
            android:label="Noted.">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity-alias>
        <activity-alias
            android:name=".DarkIcon"
            android:targetActivity=".MainActivity"
            android:enabled="false"
            android:exported="true"
            android:icon="@mipmap/ic_launcher_dark"
            android:label="Noted.">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity-alias>
XML
  awk -v aliasfile="$ALIASES" '
    /<intent-filter>/ && !inf { inf=1; buf=$0 ORS; next }
    inf { buf = buf $0 ORS
          if ($0 ~ /<\/intent-filter>/) { inf=0; if (buf !~ /android.intent.category.LAUNCHER/) printf "%s", buf; buf="" }
          next }
    /<\/application>/ { while ((getline l < aliasfile) > 0) print l; close(aliasfile) }
    { print }
  ' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
  rm -f "$ALIASES"
fi

# 4) MainActivity: same as Flutter's, plus the "noted/app_icon" channel.
MAIN="$(find android/app/src/main -name 'MainActivity.kt' -o -name 'MainActivity.java' | head -n 1)"
[ -n "$MAIN" ] || { echo "MainActivity not found"; exit 1; }
DIR="$(dirname "$MAIN")"
PKG="$(echo "$DIR" | sed -E 's#.*/src/main/(kotlin|java)/##; s#/#.#g')"
rm -f "$DIR/MainActivity.java" "$DIR/MainActivity.kt"
cat > "$DIR/MainActivity.kt" <<'KOTLIN'
package __PKG__

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Lets the Dart side switch the launcher icon between light and dark. */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "noted/app_icon")
            .setMethodCallHandler { call, result ->
                if (call.method == "setIcon") {
                    val dark = call.argument<Boolean>("dark") ?: false
                    try {
                        setLauncherIcon(dark)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("icon_failed", "Could not switch the app icon", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun setLauncherIcon(dark: Boolean) {
        val light = ComponentName(packageName, "__PKG__.LightIcon")
        val darkAlias = ComponentName(packageName, "__PKG__.DarkIcon")
        val on = if (dark) darkAlias else light
        val off = if (dark) light else darkAlias
        // Enable the new one first so there is never a moment with no launcher entry.
        packageManager.setComponentEnabledSetting(
            on, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
        packageManager.setComponentEnabledSetting(
            off, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
    }
}
KOTLIN
sed "s/__PKG__/$PKG/g" "$DIR/MainActivity.kt" > "$DIR/MainActivity.kt.tmp" && mv "$DIR/MainActivity.kt.tmp" "$DIR/MainActivity.kt"

echo "Android configuration applied."
