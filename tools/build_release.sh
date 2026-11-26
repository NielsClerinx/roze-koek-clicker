#!/bin/sh
# Bouwt de webversie en de Android-APK in export/.
# Vereist: Godot 4.7 met exportsjablonen, een Android SDK-pad in de editorinstellingen
# en de release-keystore via omgevingsvariabelen:
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH, GODOT_ANDROID_KEYSTORE_RELEASE_USER, GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
set -e
GODOT=${GODOT:-godot}
cd "$(dirname "$0")/.."
mkdir -p export/web export/android
touch export/.gdignore   # Godot mag de exportmap niet als projectbestanden importeren
"$GODOT" --headless --path . --export-release "Web" export/web/index.html
"$GODOT" --headless --path . --export-release "Android" export/android/roze-koek-clicker.apk
ls -la export/web export/android
