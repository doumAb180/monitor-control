#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="${VERSION:-0.2.1}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo 'VERSION must have the form 1.2.3' >&2
  exit 1
fi
swift build -c release --arch arm64
app="$PWD/dist/Monitor.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$(swift build -c release --arch arm64 --show-bin-path)/Monitor" "$app/Contents/MacOS/Monitor"
cp Resources/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app/Contents/Info.plist"
swift scripts/make-icon.swift .build/AppIcon.iconset
iconutil -c icns .build/AppIcon.iconset -o "$app/Contents/Resources/AppIcon.icns"
cp THIRD_PARTY_NOTICES.md LICENSE "$app/Contents/Resources/"
codesign --force --sign - --identifier io.github.doumAb180.Monitor "$app"
codesign --verify --deep --strict "$app"
archive="$PWD/dist/Monitor-$version-arm64.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
(cd dist && shasum -a 256 "$(basename "$archive")" > "$(basename "$archive").sha256")
bash scripts/package-dmg.sh "$app"
echo "Built: $app"
