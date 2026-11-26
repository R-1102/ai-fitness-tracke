#!/usr/bin/env bash
# Generates the android/ and ios/ folders and applies the settings this app needs.
# Run once from the project root:   bash scripts/setup_platforms.sh com.yourname
set -euo pipefail

ORG="${1:-com.example}"

echo "→ Generating platform folders (org: $ORG)"
flutter create . --org "$ORG" --project-name fitness_tracker --platforms android,ios
rm -f test/widget_test.dart   # template test refers to the counter app

# ---------- Android: ML Kit + Firebase Auth need minSdk 23 ----------
for f in android/app/build.gradle.kts android/app/build.gradle; do
  if [ -f "$f" ]; then
    sed -i.bak -E 's/minSdk(Version)? *=? *flutter\.minSdkVersion/minSdk = 23/' "$f" && rm -f "$f.bak"
    echo "→ Set minSdk = 23 in $f"
  fi
done

# ---------- Android 11+: allow flutter_tts to find the text-to-speech engine ----------
MANIFEST=android/app/src/main/AndroidManifest.xml
if [ -f "$MANIFEST" ] && ! grep -q TTS_SERVICE "$MANIFEST"; then
  if grep -q "<queries>" "$MANIFEST"; then
    perl -0pi -e 's#<queries>#<queries>\n        <intent>\n            <action android:name="android.intent.action.TTS_SERVICE" />\n        </intent>#' "$MANIFEST"
  else
    perl -0pi -e 's#(\s*)<application#$1<queries>\n        <intent>\n            <action android:name="android.intent.action.TTS_SERVICE" />\n        </intent>\n    </queries>$1<application#' "$MANIFEST"
  fi
  echo "→ Added TTS_SERVICE query to AndroidManifest.xml (voice coaching)"
fi

# ---------- iOS: camera permission + iOS 15.5 (required by ML Kit) ----------
PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ] && ! grep -q NSCameraUsageDescription "$PLIST"; then
  if command -v /usr/libexec/PlistBuddy >/dev/null; then
    /usr/libexec/PlistBuddy -c "Add :NSCameraUsageDescription string 'The camera is used to detect your body pose and count your reps. Video never leaves your device.'" "$PLIST"
    echo "→ Added NSCameraUsageDescription to Info.plist"
  else
    echo "!! Add NSCameraUsageDescription to $PLIST manually (see README)"
  fi
fi

if [ -f ios/Podfile ]; then
  sed -i.bak -E "s/^# *platform :ios, '[0-9.]+'/platform :ios, '15.5'/" ios/Podfile && rm -f ios/Podfile.bak
  echo "→ Set iOS platform 15.5 in Podfile"
fi

echo
echo "✓ Done. Next: run 'flutterfire configure' (see README), then 'flutter run'."
echo "  iOS: also set the deployment target to 15.5 in Xcode (Runner → General → Minimum Deployments)."
