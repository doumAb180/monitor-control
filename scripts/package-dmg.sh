#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="${1:-$PWD/dist/Monitor.app}"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
codesign --verify --deep --strict "$app"
staging="$(mktemp -d "${TMPDIR:-/tmp}/monitor-dmg.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/Monitor.app"
ln -s /Applications "$staging/Applications"
image="$PWD/dist/Monitor-$version-arm64.dmg"
hdiutil create -volname "Monitor $version" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$image"
hdiutil verify "$image"
(cd dist && shasum -a 256 "$(basename "$image")" > "$(basename "$image").sha256")
